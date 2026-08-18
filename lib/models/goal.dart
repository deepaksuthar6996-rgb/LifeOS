class Goal {
  final String id;
  final String title;
  final String description;
  final String category; // e.g. "VLSI", "Cybersecurity", "GameDev"
  final DateTime targetDate;
  final double priority; // 1.0 to 5.0 scale

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetDate,
    this.priority = 3.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'targetDate': targetDate.toIso8601String(),
      'priority': priority,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      targetDate: DateTime.parse(map['targetDate'] as String),
      priority: (map['priority'] as num?)?.toDouble() ?? 3.0,
    );
  }
}