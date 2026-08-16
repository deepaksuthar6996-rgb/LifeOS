class Event {
  final String id;
  final String title;
  final String startTime; // e.g. "09:00" or "09:30"
  final String endTime;   // e.g. "10:30" or "11:00"
  final DateTime date;
  final bool isFixed;
  final bool isRecurring;
  final String recurringDays; // e.g. "Mon,Tue,Wed,Thu,Fri" or "Mon,Wed,Fri"

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.date,
    this.isFixed = true,
    this.isRecurring = false,
    this.recurringDays = '',
  });

  Event copyWith({
    String? id,
    String? title,
    String? startTime,
    String? endTime,
    DateTime? date,
    bool? isFixed,
    bool? isRecurring,
    String? recurringDays,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      isFixed: isFixed ?? this.isFixed,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
    );
  }

  /// Calculates duration in minutes from startTime and endTime strings (e.g. "09:30" to "11:00")
  int get durationMinutes {
    try {
      final startParts = parseTimeParts(startTime);
      final endParts = parseTimeParts(endTime);

      final startMins = startParts[0] * 60 + startParts[1];
      final endMins = endParts[0] * 60 + endParts[1];

      final diff = endMins - startMins;
      return diff > 0 ? diff : 60; // fallback to 60 if negative or invalid
    } catch (_) {
      return 60;
    }
  }

  String get formattedDuration {
    final mins = durationMinutes;
    if (mins < 60) {
      return '${mins}m';
    }
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
  }

  List<String> get recurringDaysList => recurringDays
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Check if the event occurs on a given date (either single-instance match or recurring day of week match)
  bool occursOnDay(DateTime targetDate) {
    if (!isRecurring) {
      return targetDate.year == date.year &&
          targetDate.month == date.month &&
          targetDate.day == date.day;
    }

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayLabel = dayLabels[targetDate.weekday - 1];
    return recurringDaysList.contains(weekdayLabel);
  }

  static List<int> parseTimeParts(String timeStr) {
    final trimmed = timeStr.trim();
    // Check if format is "09:30" or "9:30" or "09:30 AM"
    final hasAmPm = trimmed.toLowerCase().contains('am') ||
        trimmed.toLowerCase().contains('pm');
    final isPm = trimmed.toLowerCase().contains('pm');

    final cleanStr = trimmed.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
    final parts = cleanStr.split(':');

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (hasAmPm) {
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    }

    return [hour, minute];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'isFixed': isFixed ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringDays': recurringDays,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      date: DateTime.parse(map['date'] as String),
      isFixed: map['isFixed'] == 1 || map['isFixed'] == true,
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
      recurringDays: (map['recurringDays'] as String?) ?? '',
    );
  }
}
