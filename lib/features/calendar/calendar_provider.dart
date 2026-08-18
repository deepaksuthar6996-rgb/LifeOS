import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_helper.dart';
import '../../models/event.dart';
import '../../models/task.dart';
import '../../models/dashboard_task_item.dart';
import '../../models/milestone.dart';
import '../dashboard/dashboard_provider.dart';
import '../goals/goal_detail_provider.dart';
import '../goals/goal_provider.dart';

class CalendarState {
  final DateTime selectedDate;
  final List<Event> events;
  final List<DashboardTaskItem> scheduledTasks;
  final String sleepStart; // e.g. "22:00" (10:00 PM)
  final String sleepEnd;   // e.g. "04:00" (04:00 AM)

  static const int totalDayMinutes = 1440; // 24 Hours

  CalendarState({
    required this.selectedDate,
    required this.events,
    required this.scheduledTasks,
    this.sleepStart = '22:00',
    this.sleepEnd = '04:00',
  });

  /// Base sleep duration in minutes (defaults to 360 mins / 6 hours for 22:00 -> 04:00)
  int get sleepDurationMinutes {
    final startParts = Event.parseTimeParts(sleepStart);
    final endParts = Event.parseTimeParts(sleepEnd);
    final startMins = startParts[0] * 60 + startParts[1];
    final endMins = endParts[0] * 60 + endParts[1];

    if (endMins >= startMins) {
      return endMins - startMins;
    } else {
      // Crosses midnight (e.g. 22:00 to 04:00 -> 120m + 240m = 360m)
      return (totalDayMinutes - startMins) + endMins;
    }
  }

  /// Total Waking Capacity = 24 Hours - Daily Sleep Duration (e.g., 1440 - 360 = 1080 mins / 18h)
  int get totalWakingCapacityMinutes => totalDayMinutes - sleepDurationMinutes;

  /// Fixed Event Time = Sum of non-overlapping event durations for selected date
  int get fixedEventMinutes => calculateNonOverlappingEventMinutes(events);

  /// Backward-compatible alias for total blocked event time
  int get totalBlockedMinutes => fixedEventMinutes;

  /// Total allocated time across fixed events and scheduled tasks
  int get totalAllocatedMinutes => fixedEventMinutes + totalScheduledTaskMinutes;

  /// Total Estimated Time of Today's Scheduled Tasks
  int get totalScheduledTaskMinutes =>
      scheduledTasks.fold<int>(0, (sum, t) => sum + t.task.estimatedMinutes);

  int get completedTaskMinutes => scheduledTasks
      .where((t) => t.task.isDone)
      .fold<int>(0, (sum, t) => sum + t.task.estimatedMinutes);

  int get pendingTaskMinutes => scheduledTasks
      .where((t) => !t.task.isDone)
      .fold<int>(0, (sum, t) => sum + t.task.estimatedMinutes);

  /// Focus Capacity = 24h - Sleep Hours - Fixed Event Hours
  int get focusCapacityMinutes =>
      max(0, totalWakingCapacityMinutes - fixedEventMinutes);

  /// Remaining Capacity = Focus Capacity - Total Estimated Time of Today's Scheduled Tasks
  /// (Can be negative if overcommitted!)
  int get remainingCapacityMinutes =>
      focusCapacityMinutes - totalScheduledTaskMinutes;

  /// Free Buffer Time (clamped to 0 if overcommitted)
  int get freeBufferMinutes => max(0, remainingCapacityMinutes);

  /// Overcommitment deficit in minutes (> 0 when overcommitted)
  int get overcommittedDeficitMinutes =>
      remainingCapacityMinutes < 0 ? -remainingCapacityMinutes : 0;

  /// True if remaining capacity < 0 (scheduled workload exceeds focus capacity)
  bool get isOvercommitted => remainingCapacityMinutes < 0;

  /// Legacy alias
  bool get isOverbooked => isOvercommitted;

  /// Total allocated time across sleep, fixed events, and focus tasks
  int get totalAllocatedDayMinutes =>
      sleepDurationMinutes + fixedEventMinutes + totalScheduledTaskMinutes;

  /// Helper to calculate non-overlapping event duration in minutes
  static int calculateNonOverlappingEventMinutes(List<Event> eventList) {
    if (eventList.isEmpty) return 0;

    final intervals = <List<int>>[];
    for (final event in eventList) {
      try {
        final startParts = Event.parseTimeParts(event.startTime);
        final endParts = Event.parseTimeParts(event.endTime);
        final startMins = startParts[0] * 60 + startParts[1];
        var endMins = endParts[0] * 60 + endParts[1];
        if (endMins <= startMins) {
          endMins = startMins + event.durationMinutes;
        }
        intervals.add([startMins, endMins]);
      } catch (_) {
        intervals.add([0, 60]);
      }
    }

    intervals.sort((a, b) => a[0].compareTo(b[0]));

    final merged = <List<int>>[];
    for (final interval in intervals) {
      if (merged.isEmpty) {
        merged.add(List<int>.from(interval));
      } else {
        final last = merged.last;
        if (interval[0] <= last[1]) {
          last[1] = max(last[1], interval[1]);
        } else {
          merged.add(List<int>.from(interval));
        }
      }
    }

    return merged.fold<int>(0, (sum, iv) => sum + (iv[1] - iv[0]));
  }

  String formatMinutes(int minutes) {
    final absMinutes = minutes.abs();
    if (absMinutes < 60) {
      return '${absMinutes}m';
    }
    final hours = absMinutes ~/ 60;
    final mins = absMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

class CalendarNotifier extends AsyncNotifier<CalendarState> {
  DateTime _currentSelectedDate = DateTime.now();
  String _sleepStart = '22:00';
  String _sleepEnd = '04:00';

  @override
  Future<CalendarState> build() async {
    return _fetchCalendarData(_currentSelectedDate);
  }

  Future<CalendarState> _fetchCalendarData(DateTime date) async {
    final events = await DBHelper.instance.getEventsForDate(date);
    final tasks = await DBHelper.instance.getScheduledTasksForDate(date);

    return CalendarState(
      selectedDate: date,
      events: events,
      scheduledTasks: tasks,
      sleepStart: _sleepStart,
      sleepEnd: _sleepEnd,
    );
  }

  Future<void> selectDate(DateTime date) async {
    _currentSelectedDate = DateTime(date.year, date.month, date.day);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCalendarData(_currentSelectedDate));
  }

  Future<void> updateSleepSchedule({
    required String sleepStart,
    required String sleepEnd,
  }) async {
    _sleepStart = sleepStart;
    _sleepEnd = sleepEnd;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCalendarData(_currentSelectedDate));
  }

  Future<void> addEvent({
    required String title,
    required String startTime,
    required String endTime,
    DateTime? date,
    bool isFixed = true,
    bool isRecurring = false,
    String recurringDays = '',
  }) async {
    final eventDate = date ?? _currentSelectedDate;
    final event = Event(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      startTime: startTime,
      endTime: endTime,
      date: DateTime(eventDate.year, eventDate.month, eventDate.day),
      isFixed: isFixed,
      isRecurring: isRecurring,
      recurringDays: recurringDays,
    );

    await DBHelper.instance.insertEvent(event);
    await refresh();
    ref.invalidate(dashboardProvider);
  }

  Future<void> updateEvent(Event event) async {
    await DBHelper.instance.updateEvent(event);
    await refresh();
    ref.invalidate(dashboardProvider);
  }

  Future<void> deleteEvent(String eventId) async {
    await DBHelper.instance.deleteEvent(eventId);
    await refresh();
    ref.invalidate(dashboardProvider);
  }

  Future<void> toggleTask(Task task) async {
    final bool newIsDone = !task.isDone;
    final updated = Task(
      id: task.id,
      milestoneId: task.milestoneId,
      title: task.title,
      estimatedMinutes: task.estimatedMinutes,
      isDone: newIsDone,
      scheduledDate: task.scheduledDate,
      completedAt: newIsDone ? DateTime.now() : null,
    );
    await DBHelper.instance.updateTask(updated);

    // Auto-update milestone if needed
    final currentTasks =
        await DBHelper.instance.getTasksByMilestoneId(task.milestoneId);
    final allDone = currentTasks.isNotEmpty &&
        currentTasks.every((t) => t.id == task.id ? updated.isDone : t.isDone);
    final milestone =
        await DBHelper.instance.getMilestoneById(task.milestoneId);
    if (milestone != null && milestone.isCompleted != allDone) {
      final updatedMilestone = Milestone(
        id: milestone.id,
        goalId: milestone.goalId,
        title: milestone.title,
        targetDate: milestone.targetDate,
        isCompleted: allDone,
      );
      await DBHelper.instance.updateMilestone(updatedMilestone);
    }

    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(goalDetailProvider);
  }

  Future<void> deleteTask(String taskId) async {
    await DBHelper.instance.deleteTask(taskId);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(goalDetailProvider);
  }
}

final calendarProvider =
    AsyncNotifierProvider<CalendarNotifier, CalendarState>(() {
  return CalendarNotifier();
});
