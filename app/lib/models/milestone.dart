class Milestone {
  final String id;
  final String goalId; // Links back to a Goal
  final String title;
  final DateTime targetDate;
  final bool isCompleted;

  Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.targetDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'title': title,
      'targetDate': targetDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'] as String,
      goalId: map['goalId'] as String,
      title: map['title'] as String,
      targetDate: DateTime.parse(map['targetDate'] as String),
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
    );
  }
}