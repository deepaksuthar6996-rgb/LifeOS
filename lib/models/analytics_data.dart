class DailyFocusStat {
  final DateTime date;
  final String dayLabel; // e.g. "Mon", "Tue"
  final int totalMinutes;
  final int taskCount;

  DailyFocusStat({
    required this.date,
    required this.dayLabel,
    required this.totalMinutes,
    required this.taskCount,
  });
}

class CategoryEffortStat {
  final String category;
  final int totalMinutes;
  final int taskCount;
  final double percentage; // 0.0 to 100.0

  CategoryEffortStat({
    required this.category,
    required this.totalMinutes,
    required this.taskCount,
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

class AnalyticsData {
  final List<DailyFocusStat> weeklyFocusStats;
  final List<CategoryEffortStat> categoryEfforts;
  final int activeDaysCount;
  final int totalDaysCount;
  final int totalWeeklyMinutes;
  final int completedTasksCount;

  AnalyticsData({
    required this.weeklyFocusStats,
    required this.categoryEfforts,
    required this.activeDaysCount,
    this.totalDaysCount = 7,
    required this.totalWeeklyMinutes,
    required this.completedTasksCount,
  });

  factory AnalyticsData.empty() {
    return AnalyticsData(
      weeklyFocusStats: [],
      categoryEfforts: [],
      activeDaysCount: 0,
      totalDaysCount: 7,
      totalWeeklyMinutes: 0,
      completedTasksCount: 0,
    );
  }

  double get consistencyRatio =>
      totalDaysCount > 0 ? activeDaysCount / totalDaysCount : 0.0;

  String get consistencyFormatted =>
      '$activeDaysCount/$totalDaysCount days active this week';

  String get formattedWeeklyTime {
    if (totalWeeklyMinutes < 60) {
      return '${totalWeeklyMinutes}m';
    }
    final hours = totalWeeklyMinutes ~/ 60;
    final mins = totalWeeklyMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
