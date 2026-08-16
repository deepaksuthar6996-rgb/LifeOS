import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/calendar/calendar_provider.dart';
import '../../models/event.dart';
import '../../models/dashboard_task_item.dart';
import '../goals/goal_detail_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_card.dart';
import '../../core/widgets/ambient_glow_background.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  Color get _accentColor => Theme.of(context).colorScheme.primary;

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'vlsi':
        return _accentColor;
      case 'cybersecurity':
        return AppTheme.crimsonAccent;
      case 'gamedev':
        return AppTheme.purpleAccent;
      case 'fitness':
      case 'health':
        return Colors.greenAccent;
      case 'career':
        return Colors.amberAccent;
      default:
        return _accentColor;
    }
  }

  void _showAddEventDialog(BuildContext context, DateTime selectedDate) {
    final titleController = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 30);
    bool isFixed = true;
    bool isRecurring = false;
    final Set<String> selectedRecurringDays = {
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri'
    };
    DateTime eventDate = selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatTimeOfDay(TimeOfDay tod) {
              final h = tod.hour.toString().padLeft(2, '0');
              final m = tod.minute.toString().padLeft(2, '0');
              return '$h:$m';
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                color: _accentColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Calendar Event',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title input
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: 'e.g., Team Sync, VLSI Lab, Deep Work Block',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: _accentColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time pickers row
                    Row(
                      children: [
                        // Date picker button
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: eventDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: _accentColor,
                                        surface: AppTheme.cardBackground,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() {
                                  eventDate = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event,
                                      size: 16, color: _accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('MMM d, yyyy')
                                          .format(eventDate),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Start & End Time row
                    Row(
                      children: [
                        // Start Time
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Time',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatTimeOfDay(startTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // End Time
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  endTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Time',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatTimeOfDay(endTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Fixed Event Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_clock_rounded,
                                  size: 18, color: Colors.amberAccent),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fixed Block Event',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    'Blocks daily productive capacity',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: isFixed,
                            activeThumbColor: _accentColor,
                            onChanged: (val) {
                              setModalState(() {
                                isFixed = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Recurring Routine Switch & Weekday Chips
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRecurring
                              ? _accentColor.withValues(alpha: 0.3)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.repeat_rounded,
                                      size: 18, color: _accentColor),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recurring Fixed Routine',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        'Repeats weekly on selected days',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: isRecurring,
                                activeThumbColor: _accentColor,
                                onChanged: (val) {
                                  setModalState(() {
                                    isRecurring = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (isRecurring) ...[
                            const SizedBox(height: 12),
                            // Quick presets
                            Row(
                              children: [
                                _buildRecurringPresetChip(
                                  label: 'Weekdays',
                                  isSelected: selectedRecurringDays.length == 5 &&
                                      selectedRecurringDays.contains('Mon') &&
                                      selectedRecurringDays.contains('Fri'),
                                  onTap: () {
                                    setModalState(() {
                                      selectedRecurringDays.clear();
                                      selectedRecurringDays.addAll([
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri'
                                      ]);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                _buildRecurringPresetChip(
                                  label: 'Daily',
                                  isSelected: selectedRecurringDays.length == 7,
                                  onTap: () {
                                    setModalState(() {
                                      selectedRecurringDays.clear();
                                      selectedRecurringDays.addAll([
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat',
                                        'Sun'
                                      ]);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                _buildRecurringPresetChip(
                                  label: 'Weekends',
                                  isSelected: selectedRecurringDays.length == 2 &&
                                      selectedRecurringDays.contains('Sat') &&
                                      selectedRecurringDays.contains('Sun'),
                                  onTap: () {
                                    setModalState(() {
                                      selectedRecurringDays.clear();
                                      selectedRecurringDays
                                          .addAll(['Sat', 'Sun']);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // 7 Day selector chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun'
                              ].map((day) {
                                final isDaySelected =
                                    selectedRecurringDays.contains(day);
                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isDaySelected) {
                                        if (selectedRecurringDays.length > 1) {
                                          selectedRecurringDays.remove(day);
                                        }
                                      } else {
                                        selectedRecurringDays.add(day);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 38,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDaySelected
                                          ? _accentColor
                                              .withValues(alpha: 0.2)
                                          : AppTheme.cardBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDaySelected
                                            ? _accentColor
                                            : AppTheme.borderColor,
                                      ),
                                    ),
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDaySelected
                                            ? _accentColor
                                            : Colors.white60,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: AppTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final recurringString = isRecurring
                              ? selectedRecurringDays.join(',')
                              : '';

                          await ref.read(calendarProvider.notifier).addEvent(
                                title: title,
                                startTime: formatTimeOfDay(startTime),
                                endTime: formatTimeOfDay(endTime),
                                date: eventDate,
                                isFixed: isFixed,
                                isRecurring: isRecurring,
                                recurringDays: recurringString,
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text(
                          'Save Event',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: _accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ascend LifeOS',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Daily Calendar & Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.today_rounded, color: _accentColor),
            tooltip: 'Jump to Today',
            onPressed: () {
              ref.read(calendarProvider.notifier).selectDate(DateTime.now());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Calendar',
            onPressed: () => ref.read(calendarProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentColor,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          calendarAsync.whenData((state) {
            _showAddEventDialog(context, state.selectedDate);
          });
        },
      ),
      body: AmbientGlowBackground(
        child: calendarAsync.when(
        data: (state) {
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(calendarProvider.notifier).refresh();
            },
            color: _accentColor,
            backgroundColor: AppTheme.cardBackground,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Date Selector Strip
                  _buildDateStrip(state),
                  const SizedBox(height: 18),

                  // 2. Capacity Planner Card (Blocked vs Focus vs Remaining)
                  _buildCapacityPlannerCard(state),
                  const SizedBox(height: 22),

                  // 3. Timeline Section Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.view_timeline_rounded,
                          color: _accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d').format(state.selectedDate),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${state.events.length} Events • ${state.scheduledTasks.length} Tasks',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Daily Timeline View
                  _buildTimelineView(state),
                  const SizedBox(height: 80), // Padding for FAB
                ],
              ),
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: _accentColor),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Error loading calendar: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(calendarProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDateStrip(CalendarState state) {
    final selected = state.selectedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate 14 days around the selected date (-3 to +10)
    final days = List.generate(14, (i) {
      return selected.subtract(Duration(days: 3)).add(Duration(days: i));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(selected),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            IconButton(
              icon: Icon(Icons.calendar_month_outlined,
                  size: 20, color: _accentColor),
              tooltip: 'Choose Date',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: _accentColor,
                          surface: AppTheme.cardBackground,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  ref.read(calendarProvider.notifier).selectDate(picked);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((day) {
              final isSelected = day.year == selected.year &&
                  day.month == selected.month &&
                  day.day == selected.day;
              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    ref.read(calendarProvider.notifier).selectDate(day);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 70,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accentColor.withValues(alpha: 0.2)
                          : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? _accentColor
                            : (isToday
                                ? _accentColor.withValues(alpha: 0.6)
                                : AppTheme.borderColor),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _accentColor.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(day).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? _accentColor
                                : (isToday ? Colors.amberAccent : Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showSleepScheduleDialog(BuildContext context, CalendarState state) {
    TimeOfDay sleepStart = const TimeOfDay(hour: 22, minute: 0);
    TimeOfDay sleepEnd = const TimeOfDay(hour: 4, minute: 0);

    try {
      final sParts = Event.parseTimeParts(state.sleepStart);
      final eParts = Event.parseTimeParts(state.sleepEnd);
      sleepStart = TimeOfDay(hour: sParts[0], minute: sParts[1]);
      sleepEnd = TimeOfDay(hour: eParts[0], minute: eParts[1]);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatTod(TimeOfDay tod) {
              final h = tod.hour.toString().padLeft(2, '0');
              final m = tod.minute.toString().padLeft(2, '0');
              return '$h:$m';
            }

            final startM = sleepStart.hour * 60 + sleepStart.minute;
            final endM = sleepEnd.hour * 60 + sleepEnd.minute;
            final sleepMins = endM >= startM
                ? (endM - startM)
                : ((1440 - startM) + endM);
            final sleepHours = sleepMins / 60.0;

            return Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bedtime_rounded,
                              color: Colors.indigoAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Baseline Sleep Routine',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configures base sleep duration to automatically calculate daily waking capacity (24h - Sleep).',
                    style: TextStyle(fontSize: 12.5, color: Colors.white54),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: sleepStart,
                            );
                            if (picked != null) {
                              setModalState(() {
                                sleepStart = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sleep Start',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  formatTod(sleepStart),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: sleepEnd,
                            );
                            if (picked != null) {
                              setModalState(() {
                                sleepEnd = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Wake Up',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  formatTod(sleepEnd),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: Colors.indigoAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Total Sleep: ${sleepHours.toStringAsFixed(1)}h | Waking: ${(24 - sleepHours).toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigoAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await ref
                            .read(calendarProvider.notifier)
                            .updateSleepSchedule(
                              sleepStart: formatTod(sleepStart),
                              sleepEnd: formatTod(sleepEnd),
                            );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Save Routine',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCapacityPlannerCard(CalendarState state) {
    final sleepMins = state.sleepDurationMinutes; // e.g. 360m (6h)
    final fixedEventMins = state.fixedEventMinutes; // e.g. non-overlapping event time
    final taskMins = state.totalScheduledTaskMinutes; // scheduled focus tasks
    final freeBufferMins = state.freeBufferMinutes; // free remaining capacity
    final isOvercommitted = state.isOvercommitted;
    final deficitMins = state.overcommittedDeficitMinutes;

    // Flex values for the visual 24h bar
    final sleepFlex = max(1, sleepMins);
    final eventFlex = max(1, fixedEventMins);
    final taskFlex = max(1, taskMins);
    final bufferFlex = max(1, freeBufferMins);

    return HoverCard(
      borderColor: isOvercommitted
          ? Colors.redAccent.withValues(alpha: 0.6)
          : AppTheme.borderColor,
      borderWidth: isOvercommitted ? 1.5 : 1.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Sleep Routine Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isOvercommitted
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isOvercommitted
                          ? Icons.warning_amber_rounded
                          : Icons.speed_rounded,
                      size: 18,
                      color: isOvercommitted
                          ? Colors.redAccent
                          : _accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Capacity Planner',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Sleep Routine config button
              InkWell(
                onTap: () => _showSleepScheduleDialog(context, state),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.indigoAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bedtime_outlined,
                          size: 12, color: Colors.indigoAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Sleep: ${state.formatMinutes(sleepMins)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Overcommitment Alert Tag / Banner
          if (isOvercommitted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OVERCOMMITMENT ALERT: Workload exceeds focus capacity by ${state.formatMinutes(deficitMins)}! Rebalance scheduled tasks to avoid burnout.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 24-Hour Visual Multi-Segment Capacity Bar:
          // [Sleep Block (Fixed)] | [Events] | [Scheduled Tasks] | [Free Buffer Time]
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '24-Hour Day Allocation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                  Text(
                    'Waking Focus Capacity: ${state.formatMinutes(state.focusCapacityMinutes)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOvercommitted
                          ? Colors.redAccent
                          : Colors.tealAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      // 1. Sleep Block (Fixed)
                      Expanded(
                        flex: sleepFlex,
                        child: Container(
                          color: const Color(0xFF475569), // Slate dark
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        ),
                      ),
                      // 2. Events (Fixed)
                      if (fixedEventMins > 0)
                        Expanded(
                          flex: eventFlex,
                          child: Container(
                            color: Colors.amberAccent,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 0.5),
                          ),
                        ),
                      // 3. Scheduled Tasks
                      if (taskMins > 0)
                        Expanded(
                          flex: taskFlex,
                          child: Container(
                            color: isOvercommitted
                                ? Colors.redAccent
                                : Colors.indigoAccent,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 0.5),
                          ),
                        ),
                      // 4. Free Buffer Time
                      if (freeBufferMins > 0)
                        Expanded(
                          flex: bufferFlex,
                          child: Container(
                            color: Colors.tealAccent.withValues(alpha: 0.7),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Legend Row for 24h Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBarLegend(color: const Color(0xFF475569), label: 'Sleep'),
              _buildBarLegend(color: Colors.amberAccent, label: 'Events'),
              _buildBarLegend(
                  color: isOvercommitted ? Colors.redAccent : Colors.indigoAccent,
                  label: isOvercommitted ? 'Tasks (Deficit)' : 'Tasks'),
              _buildBarLegend(
                  color: Colors.tealAccent.withValues(alpha: 0.7),
                  label: 'Free Buffer'),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Breakdown Stat Badges: Sleep | Events | Tasks | Free Buffer
          Row(
            children: [
              // 1. Sleep Baseline
              Expanded(
                child: _buildCapacityStatPill(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep',
                  value: state.formatMinutes(sleepMins),
                  subText: '${state.sleepStart}-${state.sleepEnd}',
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 6),
              // 2. Fixed Events
              Expanded(
                child: _buildCapacityStatPill(
                  icon: Icons.lock_outline_rounded,
                  label: 'Events',
                  value: state.formatMinutes(fixedEventMins),
                  subText: '${state.events.length} fixed',
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 6),
              // 3. Focus Tasks
              Expanded(
                child: _buildCapacityStatPill(
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  value: state.formatMinutes(taskMins),
                  subText: '${state.scheduledTasks.length} tasks',
                  color: isOvercommitted
                      ? Colors.redAccent
                      : Colors.indigoAccent,
                ),
              ),
              const SizedBox(width: 6),
              // 4. Free Buffer / Remaining Capacity
              Expanded(
                child: _buildCapacityStatPill(
                  icon: isOvercommitted
                      ? Icons.warning_amber_rounded
                      : Icons.bolt_rounded,
                  label: isOvercommitted ? 'Deficit' : 'Buffer',
                  value: isOvercommitted
                      ? '-${state.formatMinutes(deficitMins)}'
                      : state.formatMinutes(freeBufferMins),
                  subText: isOvercommitted ? 'Overbooked' : 'Available',
                  color: isOvercommitted
                      ? Colors.redAccent
                      : Colors.tealAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityStatPill({
    required IconData icon,
    required String label,
    required String value,
    required String subText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(CalendarState state) {
    final events = state.events;
    final tasks = state.scheduledTasks;

    if (events.isEmpty && tasks.isEmpty) {
      return HoverCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clear Schedule Ahead',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No events or focus tasks scheduled for this day.\nTap "+ Add Event" to block calendar time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Events Section
        if (events.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.lock_clock_rounded,
                  size: 14, color: Colors.amberAccent),
              SizedBox(width: 6),
              Text(
                'FIXED EVENTS & BLOCKS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...events.map((e) => _buildEventCard(e)),
          const SizedBox(height: 18),
        ],

        // Scheduled Tasks Section
        if (tasks.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.radar_rounded,
                  size: 14, color: Colors.indigoAccent),
              SizedBox(width: 6),
              Text(
                'SCHEDULED FOCUS TASKS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigoAccent,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tasks.map((t) => _buildScheduledTaskCard(t)),
        ],
      ],
    );
  }

  Widget _buildEventCard(Event event) {
    return HoverCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  event.startTime,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
                const Icon(Icons.arrow_downward_rounded,
                    size: 11, color: Colors.white38),
                Text(
                  event.endTime,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Event Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.formattedDuration,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (event.isFixed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 10, color: Colors.amberAccent),
                            SizedBox(width: 3),
                            Text(
                              'Fixed Block',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (event.isRecurring) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat_rounded,
                                size: 10, color: _accentColor),
                            const SizedBox(width: 3),
                            Text(
                              event.recurringDays.isNotEmpty
                                  ? event.recurringDays
                                  : 'Recurring',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: Colors.white38),
            onPressed: () async {
              await ref.read(calendarProvider.notifier).deleteEvent(event.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTaskCard(DashboardTaskItem item) {
    final catColor = _getCategoryColor(item.goalCategory);
    final task = item.task;

    return HoverCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: task.isDone
          ? AppTheme.borderColor
          : catColor.withValues(alpha: 0.25),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalDetailScreen(goalId: item.goalId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
              children: [
                // Interactive Checkbox
                Transform.scale(
                  scale: 1.05,
                  child: Checkbox(
                    value: task.isDone,
                    activeColor: catColor,
                    checkColor: AppTheme.background,
                    side: BorderSide(
                      color: catColor.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (val) async {
                      await ref
                          .read(calendarProvider.notifier)
                          .toggleTask(task);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Task details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Goal Category & Milestone Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.goalCategory.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• ${item.milestoneTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Task Title
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: task.isDone ? Colors.white38 : Colors.white,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        '${task.estimatedMinutes}m',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildRecurringPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.2)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _accentColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? _accentColor : Colors.white60,
          ),
        ),
      ),
    );
  }
}
