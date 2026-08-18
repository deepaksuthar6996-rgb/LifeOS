import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_helper.dart';
import '../../models/goal.dart';
import '../../models/milestone.dart';
import '../../models/task.dart';
import '../calendar/calendar_provider.dart';
import '../dashboard/dashboard_provider.dart';
import 'goal_provider.dart';

class MilestoneWithTasks {
  final Milestone milestone;
  final List<Task> tasks;

  MilestoneWithTasks({
    required this.milestone,
    required this.tasks,
  });

  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isDone).length;
  double get progress =>
      totalTasks == 0 ? (milestone.isCompleted ? 1.0 : 0.0) : (completedTasks / totalTasks);
}

class GoalDetailState {
  final Goal goal;
  final List<MilestoneWithTasks> milestonesWithTasks;

  GoalDetailState({
    required this.goal,
    required this.milestonesWithTasks,
  });

  int get totalTasks {
    int count = 0;
    for (final m in milestonesWithTasks) {
      count += m.tasks.length;
    }
    return count;
  }

  int get completedTasks {
    int count = 0;
    for (final m in milestonesWithTasks) {
      count += m.tasks.where((t) => t.isDone).length;
    }
    return count;
  }

  double get overallProgress {
    if (totalTasks == 0) {
      if (milestonesWithTasks.isEmpty) return 0.0;
      final completedMilestones =
          milestonesWithTasks.where((m) => m.milestone.isCompleted).length;
      return completedMilestones / milestonesWithTasks.length;
    }
    return completedTasks / totalTasks;
  }
}

class GoalDetailNotifier
    extends FamilyAsyncNotifier<GoalDetailState?, String> {
  @override
  Future<GoalDetailState?> build(String arg) async {
    return _fetchGoalDetail(arg);
  }

  Future<GoalDetailState?> _fetchGoalDetail(String goalId) async {
    final goal = await DBHelper.instance.getGoalById(goalId);
    if (goal == null) return null;

    final milestones = await DBHelper.instance.getMilestonesByGoalId(goalId);
    final List<MilestoneWithTasks> milestonesWithTasks = [];

    for (final milestone in milestones) {
      final tasks = await DBHelper.instance.getTasksByMilestoneId(milestone.id);
      milestonesWithTasks.add(
        MilestoneWithTasks(milestone: milestone, tasks: tasks),
      );
    }

    return GoalDetailState(
      goal: goal,
      milestonesWithTasks: milestonesWithTasks,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchGoalDetail(arg));
  }

  Future<void> addMilestone({
    required String title,
    required DateTime targetDate,
  }) async {
    final milestone = Milestone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goalId: arg,
      title: title,
      targetDate: targetDate,
      isCompleted: false,
    );
    await DBHelper.instance.insertMilestone(milestone);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> deleteMilestone(String milestoneId) async {
    await DBHelper.instance.deleteMilestone(milestoneId);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> toggleMilestone(Milestone milestone) async {
    final updated = Milestone(
      id: milestone.id,
      goalId: milestone.goalId,
      title: milestone.title,
      targetDate: milestone.targetDate,
      isCompleted: !milestone.isCompleted,
    );
    await DBHelper.instance.updateMilestone(updated);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> addTask({
    required String milestoneId,
    required String title,
    int estimatedMinutes = 30,
    DateTime? scheduledDate,
    bool isRecurring = false,
    String recurringDays = '',
  }) async {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      milestoneId: milestoneId,
      title: title,
      estimatedMinutes: estimatedMinutes,
      isDone: false,
      scheduledDate: scheduledDate,
      isRecurring: isRecurring,
      recurringDays: recurringDays,
    );
    await DBHelper.instance.insertTask(task);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(calendarProvider);
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

    // Auto-update milestone if all tasks completed or toggled
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
    ref.invalidate(calendarProvider);
  }

  Future<void> deleteTask(String taskId) async {
    await DBHelper.instance.deleteTask(taskId);
    await refresh();
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(calendarProvider);
  }
}

final goalDetailProvider =
    AsyncNotifierProvider.family<GoalDetailNotifier, GoalDetailState?, String>(
        () {
  return GoalDetailNotifier();
});

