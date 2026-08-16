class Task {
  final String id;
  final String milestoneId; // Links back to a Milestone
  final String title;
  final int estimatedMinutes;
  final bool isDone;
  final bool isMissed;
  final DateTime? scheduledDate;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.milestoneId,
    required this.title,
    this.estimatedMinutes = 30,
    this.isDone = false,
    this.isMissed = false,
    this.scheduledDate,
    this.completedAt,
  });

  Task copyWith({
    String? id,
    String? milestoneId,
    String? title,
    int? estimatedMinutes,
    bool? isDone,
    bool? isMissed,
    DateTime? scheduledDate,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      milestoneId: milestoneId ?? this.milestoneId,
      title: title ?? this.title,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isDone: isDone ?? this.isDone,
      isMissed: isMissed ?? this.isMissed,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'milestoneId': milestoneId,
      'title': title,
      'estimatedMinutes': estimatedMinutes,
      'isDone': isDone ? 1 : 0,
      'isMissed': isMissed ? 1 : 0,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      milestoneId: map['milestoneId'] as String,
      title: map['title'] as String,
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 30,
      isDone: map['isDone'] == 1 || map['isDone'] == true,
      isMissed: map['isMissed'] == 1 || map['isMissed'] == true,
      scheduledDate: map['scheduledDate'] != null
          ? DateTime.tryParse(map['scheduledDate'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
    );
  }
}