import '../database/db_helper.dart';
import '../../models/goal.dart';

class WeakPoint {
  final Goal goal;
  final String reason;
  final String recommendation;
  final bool isCriticallyOverdue; // true if approaching target date with low progress

  WeakPoint({
    required this.goal,
    required this.reason,
    required this.recommendation,
    this.isCriticallyOverdue = false,
  });
}

class Category14DayEffort {
  final String category;
  final int completedTasksCount;
  final int totalMinutes;
  final double percentage; // Proportional effort compared to total minutes logged

  Category14DayEffort({
    required this.category,
    required this.completedTasksCount,
    required this.totalMinutes,
    required this.percentage,
  });

  String get formattedTime {
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

class SystemInsights {
  final String strongestArea;
  final double strongestAreaPercentage;
  final List<WeakPoint> weakPoints;
  final List<String> recommendations;
  final List<Category14DayEffort> categoryEfforts;

  SystemInsights({
    required this.strongestArea,
    required this.strongestAreaPercentage,
    required this.weakPoints,
    required this.recommendations,
    required this.categoryEfforts,
  });

  factory SystemInsights.empty() {
    return SystemInsights(
      strongestArea: 'None',
      strongestAreaPercentage: 0.0,
      weakPoints: [],
      recommendations: ['No active goals found. Create goals to see insights.'],
      categoryEfforts: [],
    );
  }
}

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._init();
  AnalyticsService._init();

  /// Calculates overall execution progress for a specific Goal.
  Future<double> getGoalProgress(String goalId) async {
    final milestones = await DBHelper.instance.getMilestonesByGoalId(goalId);
    int totalTasksCount = 0;
    int completedTasksCount = 0;

    for (final milestone in milestones) {
      final tasks = await DBHelper.instance.getTasksByMilestoneId(milestone.id);
      totalTasksCount += tasks.length;
      completedTasksCount += tasks.where((t) => t.isDone).length;
    }

    if (totalTasksCount > 0) {
      return completedTasksCount / totalTasksCount;
    } else if (milestones.isNotEmpty) {
      final completedMilestones = milestones.where((m) => m.isCompleted).length;
      return completedMilestones / milestones.length;
    }
    return 0.0;
  }

  /// Evaluates tasks completed in the past 14 days, groups them by Goal category,
  /// detects weak points for active goals, and returns dashboard-ready insights.
  Future<SystemInsights> getSystemInsights([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();
    // 14-day window bounds (inclusive of today)
    final fourteenDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 13)); // 14 days counting today

    final goals = await DBHelper.instance.getAllGoals();
    if (goals.isEmpty) {
      return SystemInsights.empty();
    }

    final completedTasks = await DBHelper.instance.getCompletedTasks();

    // Filter completions strictly in the 14-day window
    final tasks14Days = completedTasks.where((item) {
      final completedDate = item.task.completedAt ?? item.task.scheduledDate;
      if (completedDate == null) return false;
      
      // Zero out time for clean day-by-day comparison
      final completedDay = DateTime(completedDate.year, completedDate.month, completedDate.day);
      final todayDay = DateTime(now.year, now.month, now.day);
      
      return !completedDay.isBefore(fourteenDaysAgo) && !completedDay.isAfter(todayDay);
    }).toList();

    // 1. Group completions and minutes by Category in the past 14 days
    final Map<String, int> minutesByCategory = {};
    final Map<String, int> taskCountByCategory = {};
    int totalMinutes14Days = 0;

    for (final item in tasks14Days) {
      final rawCat = item.goalCategory.trim();
      final category = rawCat.isNotEmpty ? rawCat : 'General';
      final minutes = item.task.estimatedMinutes;

      minutesByCategory[category] = (minutesByCategory[category] ?? 0) + minutes;
      taskCountByCategory[category] = (taskCountByCategory[category] ?? 0) + 1;
      totalMinutes14Days += minutes;
    }

    // Identify all categories that currently have active goals (active ambitions)
    final Set<String> activeAmbitions = {};
    final Map<String, List<Goal>> activeGoalsByCategory = {};
    final Map<String, double> goalProgressMap = {};

    for (final goal in goals) {
      final progress = await getGoalProgress(goal.id);
      goalProgressMap[goal.id] = progress;

      // An "active" goal has progress < 100%
      if (progress < 1.0) {
        final rawCat = goal.category.trim();
        final category = rawCat.isNotEmpty ? rawCat : 'General';
        activeAmbitions.add(category);
        
        activeGoalsByCategory.putIfAbsent(category, () => []);
        activeGoalsByCategory[category]!.add(goal);
      }
    }

    // 2. Build proportional effort splits for 14-day review
    // Ensure all active ambitions are listed in the split, even if they have 0 minutes logged
    final Set<String> allEffortCategories = {...minutesByCategory.keys, ...activeAmbitions};
    final List<Category14DayEffort> categoryEfforts = [];

    for (final category in allEffortCategories) {
      final minutes = minutesByCategory[category] ?? 0;
      final taskCount = taskCountByCategory[category] ?? 0;
      final percentage = totalMinutes14Days > 0 ? (minutes / totalMinutes14Days) * 100.0 : 0.0;

      categoryEfforts.add(Category14DayEffort(
        category: category,
        completedTasksCount: taskCount,
        totalMinutes: minutes,
        percentage: percentage,
      ));
    }

    // Sort: categories with effort first, then alphabetically
    categoryEfforts.sort((a, b) {
      if (b.totalMinutes != a.totalMinutes) {
        return b.totalMinutes.compareTo(a.totalMinutes);
      }
      return a.category.compareTo(b.category);
    });

    // Determine strongest area
    final strongestAreaEffort = categoryEfforts.firstWhere(
      (e) => e.totalMinutes > 0,
      orElse: () => Category14DayEffort(category: 'None', completedTasksCount: 0, totalMinutes: 0, percentage: 0.0),
    );
    final strongestArea = strongestAreaEffort.category;
    final strongestAreaPercentage = strongestAreaEffort.percentage;

    // 3. Rule-Based Weak Point Detection for active goals
    final List<WeakPoint> weakPoints = [];

    // Tally completed tasks and minutes by specific Goal ID in the last 14 days
    final Map<String, int> tasksCompletedByGoal = {};
    final Map<String, int> minutesByGoal = {};

    for (final item in tasks14Days) {
      if (item.goalId.isNotEmpty) {
        tasksCompletedByGoal[item.goalId] = (tasksCompletedByGoal[item.goalId] ?? 0) + 1;
        minutesByGoal[item.goalId] = (minutesByGoal[item.goalId] ?? 0) + item.task.estimatedMinutes;
      }
    }

    for (final goal in goals) {
      final progress = goalProgressMap[goal.id] ?? 0.0;
      if (progress >= 1.0) continue; // Goal is fully complete, skip

      final completedInLast14Days = tasksCompletedByGoal[goal.id] ?? 0;
      final minutesInLast14Days = minutesByGoal[goal.id] ?? 0;
      
      // Proportion of total focus time allocated to this goal
      final double focusTimePercent = totalMinutes14Days > 0
          ? (minutesInLast14Days / totalMinutes14Days)
          : 0.0;

      bool isFlagged = false;

      // Rule 3: Flag goals approaching target date with < 50% progress (High Priority Rule)
      final daysRemaining = goal.targetDate.difference(now).inDays;
      if (progress < 0.50) {
        if (daysRemaining <= 14) {
          final progressPercent = (progress * 100).toStringAsFixed(0);
          final timeLabel = daysRemaining < 0
              ? 'Target date has passed by ${-daysRemaining} days'
              : 'Target date is approaching in $daysRemaining days';
          
          weakPoints.add(WeakPoint(
            goal: goal,
            reason: '$timeLabel with only $progressPercent% progress',
            recommendation: 'Critically re-evaluate target date for "${goal.title}". Break down remaining milestones and schedule urgent tasks.',
            isCriticallyOverdue: true,
          ));
          isFlagged = true; // Avoid double flagging under other rules if critical
        }
      }

      // Rule 1: Active Goal with 0 completed tasks in the last 14 days
      if (!isFlagged && completedInLast14Days == 0) {
        weakPoints.add(WeakPoint(
          goal: goal,
          reason: '0 completed tasks in the last 14 days',
          recommendation: 'Neglect Alert: Schedule at least one milestone task for "${goal.title}" to restart momentum.',
        ));
        isFlagged = true;
      }

      // Rule 2: Active Goal with <10% focus time in the last 14 days
      // (Only check if they completed at least 1 task, otherwise Rule 1 covers it. Also only if total minutes > 0)
      if (!isFlagged && totalMinutes14Days > 0 && focusTimePercent < 0.10) {
        final pctStr = (focusTimePercent * 100).toStringAsFixed(1);
        weakPoints.add(WeakPoint(
          goal: goal,
          reason: 'Low focus ($pctStr% of total effort) in the last 14 days',
          recommendation: 'Increase focus time allocation for "${goal.title}" to maintain a healthy balance.',
        ));
      }
    }

    // 4. Generate Actionable Recommendations
    final List<String> recommendations = [];
    if (weakPoints.isNotEmpty) {
      // Sort weak points so critically overdue are first
      weakPoints.sort((a, b) {
        if (a.isCriticallyOverdue && !b.isCriticallyOverdue) return -1;
        if (!a.isCriticallyOverdue && b.isCriticallyOverdue) return 1;
        return b.goal.priority.compareTo(a.goal.priority); // fallback to priority
      });

      for (final wp in weakPoints) {
        recommendations.add(wp.recommendation);
      }
    } else {
      recommendations.add('All active goals are on track! Keep maintaining a balanced focus.');
    }

    return SystemInsights(
      strongestArea: strongestArea,
      strongestAreaPercentage: strongestAreaPercentage,
      weakPoints: weakPoints,
      recommendations: recommendations.toSet().toList(), // Deduplicate
      categoryEfforts: categoryEfforts,
    );
  }
}
