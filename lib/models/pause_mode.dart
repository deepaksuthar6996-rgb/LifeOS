class PauseMode {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String activeRoutineTitle;
  final bool isActive;

  PauseMode({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.activeRoutineTitle = 'Rest & Focused Study',
    this.isActive = true,
  });

  bool isCurrentActive(DateTime now) {
    if (!isActive) return false;
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return now.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
        now.isBefore(endOfDay.add(const Duration(milliseconds: 1)));
  }

  bool hasExpired(DateTime now) {
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return now.isAfter(endOfDay);
  }

  int remainingDays(DateTime now) {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = endOfDay.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  PauseMode copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? activeRoutineTitle,
    bool? isActive,
  }) {
    return PauseMode(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      activeRoutineTitle: activeRoutineTitle ?? this.activeRoutineTitle,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'activeRoutineTitle': activeRoutineTitle,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory PauseMode.fromMap(Map<String, dynamic> map) {
    return PauseMode(
      id: map['id'] as String,
      title: map['title'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      activeRoutineTitle:
          map['activeRoutineTitle'] as String? ?? 'Rest & Focused Study',
      isActive: map['isActive'] == 1 || map['isActive'] == true,
    );
  }
}
