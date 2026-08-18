import 'task.dart';

class DashboardTaskItem {
  final Task task;
  final String milestoneTitle;
  final String goalId;
  final String goalTitle;
  final String goalCategory;
  final double goalPriority;

  DashboardTaskItem({
    required this.task,
    required this.milestoneTitle,
    required this.goalId,
    required this.goalTitle,
    required this.goalCategory,
    required this.goalPriority,
  });

  factory DashboardTaskItem.fromMap(Map<String, dynamic> map) {
    return DashboardTaskItem(
      task: Task.fromMap(map),
      milestoneTitle: map['milestoneTitle'] as String? ?? 'Milestone',
      goalId: map['goalId'] as String? ?? '',
      goalTitle: map['goalTitle'] as String? ?? 'Goal',
      goalCategory: map['goalCategory'] as String? ?? 'General',
      goalPriority: (map['goalPriority'] as num?)?.toDouble() ?? 3.0,
    );
  }
}
