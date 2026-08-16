import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/goals/goal_provider.dart';
import '../../models/goal.dart';
import '../dashboard/dashboard_screen.dart';
import 'goal_detail_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_card.dart';

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background, // Dark slate aesthetic
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.flag_rounded,
                color: Theme.of(context).colorScheme.primary,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'My Strategic Goals',
                  style: TextStyle(
                    fontSize: 19,
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
            icon: const Icon(Icons.bolt_rounded, color: Colors.amberAccent),
            tooltip: "Today's Focus Dashboard",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: () => ref.read(goalProvider.notifier).refreshGoals(),
          ),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(goalProvider.notifier).refreshGoals();
            },
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: AppColors.surface,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return _GoalCard(goal: goal);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Colors.indigoAccent,
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(goalProvider.notifier).refreshGoals(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGoalModal(context),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Goal',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.track_changes_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Goals Defined Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chart your path to mastery. Set your first strategic milestone and track your execution offline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCreateGoalModal(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Create Your First Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateGoalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateGoalBottomSheet(),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final Goal goal;

  const _GoalCard({required this.goal});

  Color _getCategoryColor(BuildContext context, String category) {
    switch (category.toLowerCase().trim()) {
      case 'vlsi':
        return Theme.of(context).colorScheme.primary;
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
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _getCategoryColor(context, goal.category);
    final formattedDate = DateFormat('MMM dd, yyyy').format(goal.targetDate);
    final daysRemaining =
        goal.targetDate.difference(DateTime.now()).inDays;

    return HoverCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16.0),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalDetailScreen(goalId: goal.id),
          ),
        );
      },
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category tag & Priority badge & Action Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        goal.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Priority indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'P ${goal.priority.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      color: AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDialog(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  goal.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (goal.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    goal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                // Target date & countdown & arrow hint
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Target: $formattedDate',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: daysRemaining < 0
                            ? Colors.red.withValues(alpha: 0.2)
                            : (daysRemaining <= 7
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        daysRemaining < 0
                            ? 'Overdue (${-daysRemaining}d)'
                            : (daysRemaining == 0
                                ? 'Due Today'
                                : '$daysRemaining days left'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: daysRemaining < 0
                              ? Colors.redAccent
                              : (daysRemaining <= 7
                                  ? Colors.orangeAccent
                                  : Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Goal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${goal.title}"? Associated milestones and tasks will also be deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(goalProvider.notifier).deleteGoal(goal.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Goal "${goal.title}" deleted.'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class CreateGoalBottomSheet extends ConsumerStatefulWidget {
  const CreateGoalBottomSheet({super.key});

  @override
  ConsumerState<CreateGoalBottomSheet> createState() =>
      _CreateGoalBottomSheetState();
}

class _CreateGoalBottomSheetState
    extends ConsumerState<CreateGoalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'VLSI');

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  double _priority = 3.0;
  bool _isSaving = false;

  final List<String> _suggestedCategories = [
    'VLSI',
    'Cybersecurity',
    'GameDev',
    'Career',
    'Health',
    'Learning',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final newGoal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryController.text.trim(),
      targetDate: _selectedDate,
      priority: _priority,
    );

    try {
      await ref.read(goalProvider.notifier).addGoal(newGoal);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal "${newGoal.title}" created!'),
            backgroundColor: Colors.indigoAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving goal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final formattedDate = DateFormat('EEE, MMM dd, yyyy').format(_selectedDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Goal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title Field
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText: 'Goal Title',
                  hintText: 'e.g. Master Verilog & FPGA Synthesis',
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
              // Category Field with chips
              TextFormField(
                controller: _categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. VLSI, Cybersecurity, GameDev',
                  prefixIcon: Icons.category_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please specify a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _suggestedCategories.map((cat) {
                  final isSelected =
                      _categoryController.text.trim().toLowerCase() ==
                          cat.toLowerCase();
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: AppColors.background,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _categoryController.text = cat;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Key milestones, target outcomes, or motivations...',
                  prefixIcon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 16),
              // Target Date Selector
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Completion Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_calendar_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Priority Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Priority Level',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'P ${_priority.toStringAsFixed(1)} / 5.0',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.indigoAccent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.indigoAccent,
                  overlayColor: Colors.indigoAccent.withValues(alpha: 0.2),
                  valueIndicatorColor: Colors.indigoAccent,
                ),
                child: Slider(
                  value: _priority,
                  min: 1.0,
                  max: 5.0,
                  divisions: 8,
                  label: _priority.toStringAsFixed(1),
                  onChanged: (val) {
                    setState(() {
                      _priority = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
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
      prefixIcon: Icon(prefixIcon, color: Theme.of(context).colorScheme.primary, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentCrimson, width: 1),
      ),
    );
  }
}
