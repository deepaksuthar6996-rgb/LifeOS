import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/analytics_service.dart';
import '../../models/dashboard_task_item.dart';
import '../../models/milestone.dart';
import '../../models/task.dart';
import '../../models/analytics_data.dart';
import '../../models/pause_mode.dart';
import '../calendar/calendar_provider.dart';
import '../goals/goal_detail_provider.dart';
import '../goals/goal_provider.dart';

class DashboardState {
  final List<DashboardTaskItem> incompleteTasks;
  final List<DashboardTaskItem> missedTasks;
  final PauseMode? activePauseMode;
  final int totalActiveGoals;
  final int totalEstimatedMinutes;
  final AnalyticsData analytics;
  final SystemInsights systemInsights;

  DashboardState({
    required this.incompleteTasks,
    required this.missedTasks,
    this.activePauseMode,
    required this.totalActiveGoals,
    required this.totalEstimatedMinutes,
    required this.analytics,
    required this.systemInsights,
  });

  int get totalIncompleteTasks => incompleteTasks.length;
  int get totalMissedTasks => missedTasks.length;

  bool get isPauseModeActive =>
      activePauseMode != null &&
      activePauseMode!.isCurrentActive(DateTime.now());

  String get formattedEstimatedTime {
    if (totalEstimatedMinutes < 60) {
      return '${totalEstimatedMinutes}m';
    }
    final hours = totalEstimatedMinutes ~/ 60;
    final mins = totalEstimatedMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    return _fetchDashboardData();
  }

  Future<DashboardState> _fetchDashboardData() async {
    // 1. Run midnight check to flag overdue tasks
    await DBHelper.instance.checkAndMarkMissedTasks();

    // 2. Query today's pending tasks, missed tasks, active pause mode, goals, analytics, and system insights
    final tasks = await DBHelper.instance.getPendingTasksForToday();
    final missedTasks = await DBHelper.instance.getMissedTasks();
    final activePauseMode = await DBHelper.instance.getActivePauseMode();
    final goals = await DBHelper.instance.getAllGoals();
    final analytics = await DBHelper.instance.getAnalyticsData();
    final systemInsights = await AnalyticsService.instance.getSystemInsights();

    int totalMinutes = 0;
    for (final item in tasks) {
      totalMinutes += item.task.estimatedMinutes;
    }

    return DashboardState(
      incompleteTasks: tasks,
      missedTasks: missedTasks,
      activePauseMode: activePauseMode,
      totalActiveGoals: goals.length,
      totalEstimatedMinutes: totalMinutes,
      analytics: analytics,
      systemInsights: systemInsights,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchDashboardData());
  }

  Future<void> toggleTask(Task task) async {
    final bool newIsDone = !task.isDone;
    final updated = task.copyWith(
      isDone: newIsDone,
      isMissed: newIsDone ? false : task.isMissed,
      completedAt: newIsDone ? DateTime.now() : null,
    );
    await DBHelper.instance.updateTask(updated);

    // Auto-update milestone completion status
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
    ref.invalidate(goalProvider);
    ref.invalidate(goalDetailProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> rescheduleTask(String taskId, DateTime newDate) async {
    await DBHelper.instance.rescheduleTask(taskId, newDate);
    await refresh();
    ref.invalidate(goalProvider);
    ref.invalidate(goalDetailProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> activatePauseMode(PauseMode mode) async {
    await DBHelper.instance.insertPauseMode(mode);
    await refresh();
    ref.invalidate(calendarProvider);
  }

  Future<void> deactivatePauseMode(String modeId) async {
    await DBHelper.instance.deactivatePauseMode(modeId);
    await refresh();
    ref.invalidate(calendarProvider);
  }

  Future<void> deleteTask(String taskId) async {
    await DBHelper.instance.deleteTask(taskId);
    await refresh();
    ref.invalidate(goalProvider);
    ref.invalidate(goalDetailProvider);
    ref.invalidate(calendarProvider);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
