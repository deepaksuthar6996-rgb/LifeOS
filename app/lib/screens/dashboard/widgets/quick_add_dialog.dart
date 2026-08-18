import 'package:flutter/material.dart';
import '../../../features/goals/category_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/goal.dart';
import '../../../models/milestone.dart';
import '../../../models/task.dart';
import '../../../features/goals/goal_provider.dart';
import '../../../features/dashboard/dashboard_provider.dart';
import '../../../features/calendar/calendar_provider.dart';
import '../../../features/goals/goal_detail_provider.dart';

class QuickAddDialog extends ConsumerStatefulWidget {
  const QuickAddDialog({super.key});

  @override
  ConsumerState<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<QuickAddDialog> {
  bool _isTaskMode = true; // true = Task, false = Goal
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Task Form State
  String? _selectedGoalId;
  String? _selectedMilestoneId;
  final _taskTitleController = TextEditingController();
  int _estimatedMinutes = 30;
  DateTime? _scheduledDate;
  bool _isRecurring = false;
  final Set<String> _selectedRecurringDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
  List<Goal> _goals = [];
  List<Milestone> _milestones = [];
  bool _isLoadingGoals = true;

  // Goal Form State
  final _goalTitleController = TextEditingController();
  final _goalDescController = TextEditingController();
  String _selectedCategory = 'Career';
  DateTime _goalTargetDate = DateTime.now().add(const Duration(days: 30));
  double _goalPriority = 3.0;


  final List<int> _presetMinutes = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _goalTitleController.dispose();
    _goalDescController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await DBHelper.instance.getAllGoals();
      setState(() {
        _goals = goals;
        if (goals.isNotEmpty) {
          _selectedGoalId = goals.first.id;
          _loadMilestones(goals.first.id);
        }
        _isLoadingGoals = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingGoals = false;
      });
    }
  }

  Future<void> _loadMilestones(String goalId) async {
    try {
      final milestones = await DBHelper.instance.getMilestonesByGoalId(goalId);
      setState(() {
        _milestones = milestones;
        if (milestones.isNotEmpty) {
          _selectedMilestoneId = milestones.first.id;
        } else {
          _selectedMilestoneId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickGoalTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _goalTargetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _goalTargetDate = picked;
      });
    }
  }

  Future<void> _pickTaskScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

    Future<void> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newCat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Custom Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Category Name',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a category name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCat != null && newCat.isNotEmpty) {
      await ref.read(categoryProvider.notifier).addCategory(newCat);
      setState(() {
        _selectedCategory = newCat;
      });
    }
  }

Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isTaskMode) {
        if (_selectedGoalId == null) {
          throw Exception('Please create a Goal first.');
        }

        String milestoneId;
        if (_selectedMilestoneId == null) {
          // Auto-create a default milestone
          final mId = 'milestone_def_${DateTime.now().millisecondsSinceEpoch}';
          final newMilestone = Milestone(
            id: mId,
            goalId: _selectedGoalId!,
            title: 'General Execution',
            targetDate: DateTime.now().add(const Duration(days: 14)),
            isCompleted: false,
          );
          await DBHelper.instance.insertMilestone(newMilestone);
          milestoneId = mId;
        } else {
          milestoneId = _selectedMilestoneId!;
        }

        final task = Task(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}',
          milestoneId: milestoneId,
          title: _taskTitleController.text.trim(),
          estimatedMinutes: _estimatedMinutes,
          scheduledDate: _scheduledDate ?? (_isRecurring ? DateTime.now() : null),
          isRecurring: _isRecurring,
          recurringDays: _isRecurring ? _selectedRecurringDays.join(',') : '',
        );

        await DBHelper.instance.insertTask(task);

        // Invalidate providers
        ref.invalidate(dashboardProvider);
        ref.invalidate(calendarProvider);
        ref.invalidate(goalDetailProvider(_selectedGoalId!));
      } else {
        final id = 'goal_${DateTime.now().millisecondsSinceEpoch}';
        final categoryStr = _selectedCategory.trim();
        if (categoryStr.isNotEmpty) {
          await ref.read(categoryProvider.notifier).addCategory(categoryStr);
        }

        final goal = Goal(
          id: id,
          title: _goalTitleController.text.trim(),
          description: _goalDescController.text.trim(),
          category: _selectedCategory,
          targetDate: _goalTargetDate,
          priority: _goalPriority,
        );

        await DBHelper.instance.insertGoal(goal);

        // Invalidate providers
        ref.invalidate(goalProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(calendarProvider);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Text(
              _isTaskMode ? 'Task added successfully!' : 'Goal added successfully!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accentCrimson,
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Add Workspace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segment selector (Task vs Goal)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTaskMode = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isTaskMode
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isTaskMode
                                ? Theme.of(context).colorScheme.primary
                                : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Add Task',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isTaskMode ? Theme.of(context).colorScheme.primary : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTaskMode = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isTaskMode
                              ? AppColors.accentPurple.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_isTaskMode
                                ? AppColors.accentPurple
                                : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Add Goal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isTaskMode ? AppColors.accentPurple : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic content fields
              if (_isTaskMode) ...[
                if (_isLoadingGoals)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    ),
                  )
                else if (_goals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.accentAmber, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'No active goals found.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please create a goal first to attach tasks.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPurple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isTaskMode = false;
                              });
                            },
                            child: const Text('Create a Goal'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Goal Selection Dropdown
                  const Text('Select Goal',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGoalId,
                        dropdownColor: AppColors.surfaceElevated,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        items: _goals.map((g) {
                          return DropdownMenuItem<String>(
                            value: g.id,
                            child: Text(g.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedGoalId = val;
                              _loadMilestones(val);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Milestone Selection Dropdown
                  const Text('Select Milestone (Optional)',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedMilestoneId,
                        dropdownColor: AppColors.surfaceElevated,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        hint: const Text('Auto-create default roadmap', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Auto-create default roadmap', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ),
                          ..._milestones.map((m) {
                            return DropdownMenuItem<String?>(
                              value: m.id,
                              child: Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedMilestoneId = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Task Title Field
                  TextFormField(
                    controller: _taskTitleController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      labelText: 'Task Title',
                      hintText: 'e.g. Prepare system test vectors',
                      prefixIcon: Icons.task_alt_rounded,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a task title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Duration selector
                  const Text('Estimated Time',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetMinutes.map((minutes) {
                      final isSelected = _estimatedMinutes == minutes;
                      return ChoiceChip(
                        label: Text('${minutes}m'),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.background : Colors.white70,
                        ),
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.border,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _estimatedMinutes = minutes;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Scheduled date picker
                  InkWell(
                    onTap: _pickTaskScheduledDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            _scheduledDate == null
                                ? 'Schedule Date (Optional)'
                                : 'Scheduled: ${DateFormat('MMM dd, yyyy').format(_scheduledDate!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _scheduledDate == null ? Colors.white54 : Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (_scheduledDate != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _scheduledDate = null;
                                });
                              },
                              child: const Icon(Icons.clear_rounded, size: 16, color: Colors.white38),
                            )
                          else
                            const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Recurrence toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                            const SizedBox(width: 12),
                            const Text('Recurring Habit', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _isRecurring = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  if (_isRecurring) ...[
                    const SizedBox(height: 10),
                    // 7-day selection row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        final isDaySelected = _selectedRecurringDays.contains(day);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isDaySelected) {
                                if (_selectedRecurringDays.length > 1) {
                                  _selectedRecurringDays.remove(day);
                                }
                              } else {
                                _selectedRecurringDays.add(day);
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
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDaySelected
                                    ? Theme.of(context).colorScheme.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              day.substring(0, 1),
                              style: TextStyle(
                                color: isDaySelected ? Theme.of(context).colorScheme.primary : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ] else ...[
                // Goal Title Field
                TextFormField(
                  controller: _goalTitleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. Master RISC-V VLSI Design',
                    prefixIcon: Icons.flag_rounded,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Goal Desc Field
                TextFormField(
                  controller: _goalDescController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Core motivations, roadmap outline...',
                    prefixIcon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 14),

                // Category Chips Selector
                const Text('Category',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final categoriesAsync = ref.watch(categoryProvider);
                    return categoriesAsync.when(
                      data: (categories) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.map((cat) {
                              final isSelected = _selectedCategory.toLowerCase().trim() == cat.toLowerCase().trim();
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppColors.accentPurple,
                                backgroundColor: AppColors.background,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                                side: BorderSide(
                                  color: isSelected ? AppColors.accentPurple : AppColors.border,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  }
                                },
                              );
                            }),
                            ChoiceChip(
                              avatar: const Icon(Icons.add_rounded, size: 16, color: Colors.white70),
                              label: const Text('Add Custom'),
                              selected: false,
                              backgroundColor: AppColors.background,
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.white70),
                              side: const BorderSide(color: AppColors.border),
                              onSelected: (_) => _showAddCategoryDialog(context),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent),
                        ),
                      ),
                      error: (err, stack) => Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Target Date picker
                InkWell(
                  onTap: _pickGoalTargetDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.accentPurple, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          'Target Completion: ${DateFormat('MMM dd, yyyy').format(_goalTargetDate)}',
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Priority slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Priority Level',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      'L${_goalPriority.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                Slider(
                  value: _goalPriority,
                  min: 1.0,
                  max: 5.0,
                  divisions: 4,
                  activeColor: AppColors.accentPurple,
                  inactiveColor: AppColors.border,
                  onChanged: (val) {
                    setState(() {
                      _goalPriority = val;
                    });
                  },
                ),
              ],
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTaskMode ? Theme.of(context).colorScheme.primary : AppColors.accentPurple,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              _isTaskMode ? 'Save Task' : 'Save Goal',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: _isTaskMode ? Theme.of(context).colorScheme.primary : AppColors.accentPurple, size: 18),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _isTaskMode ? Theme.of(context).colorScheme.primary : AppColors.accentPurple,
          width: 1.5,
        ),
      ),
    );
  }
}
