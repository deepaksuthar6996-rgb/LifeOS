import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/goals/goal_detail_provider.dart';
import '../../models/goal.dart';
import '../../models/task.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_card.dart';
import '../../core/widgets/ambient_glow_background.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  Color _getCategoryColor(BuildContext context, String category) {
    return AppTheme.getCategoryColor(context, category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(goalDetailProvider(goalId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Goal Roadmap',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(goalDetailProvider(goalId).notifier).refresh(),
          ),
        ],
      ),
      body: AmbientGlowBackground(
        child: detailAsync.when(
        data: (detailState) {
          if (detailState == null) {
            return const Center(
              child: Text(
                'Goal not found',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final goal = detailState.goal;
          final milestonesWithTasks = detailState.milestonesWithTasks;
          final categoryColor = _getCategoryColor(context, goal.category);
          final formattedDate =
              DateFormat('MMM dd, yyyy').format(goal.targetDate);
          final progress = detailState.overallProgress;
          final percent = (progress * 100).toInt();

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(goalDetailProvider(goalId).notifier).refresh();
            },
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: AppTheme.cardBackground,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Goal Header Card
                  _buildGoalHeaderCard(
                    goal: goal,
                    categoryColor: categoryColor,
                    formattedDate: formattedDate,
                    progress: progress,
                    percent: percent,
                    totalTasks: detailState.totalTasks,
                    completedTasks: detailState.completedTasks,
                  ),
                  const SizedBox(height: 24),

                  // Milestones Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.alt_route_rounded,
                            color: Colors.indigoAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Strategic Milestones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${milestonesWithTasks.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddMilestoneModal(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Milestone',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Milestones List or Empty State
                  if (milestonesWithTasks.isEmpty)
                    _buildEmptyMilestonesState(context, ref)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: milestonesWithTasks.length,
                      itemBuilder: (context, index) {
                        final item = milestonesWithTasks[index];
                        return _MilestoneExpandableCard(
                          goalId: goalId,
                          milestoneWithTasks: item,
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.indigoAccent),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to load goal roadmap',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGoalHeaderCard({
    required Goal goal,
    required Color categoryColor,
    required String formattedDate,
    required double progress,
    required int percent,
    required int totalTasks,
    required int completedTasks,
  }) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ],
          ),
          const SizedBox(height: 14),
          Text(
            goal.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              goal.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                'Target Date: $formattedDate',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Visual Progress Bar Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Execution Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$completedTasks / $totalTasks tasks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100 ? Colors.greenAccent : Colors.indigoAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMilestonesState(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 44,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            const Text(
              'No Milestones Added Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Break down this strategic goal into key milestones and bite-sized executable tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openAddMilestoneModal(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Milestone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMilestoneModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateMilestoneBottomSheet(goalId: goalId),
    );
  }
}

class _MilestoneExpandableCard extends ConsumerStatefulWidget {
  final String goalId;
  final MilestoneWithTasks milestoneWithTasks;

  const _MilestoneExpandableCard({
    required this.goalId,
    required this.milestoneWithTasks,
  });

  @override
  ConsumerState<_MilestoneExpandableCard> createState() =>
      _MilestoneExpandableCardState();
}

class _MilestoneExpandableCardState
    extends ConsumerState<_MilestoneExpandableCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestoneWithTasks.milestone;
    final tasks = widget.milestoneWithTasks.tasks;
    final formattedDate =
        DateFormat('MMM dd, yyyy').format(milestone.targetDate);
    final completedCount = widget.milestoneWithTasks.completedTasks;
    final totalCount = widget.milestoneWithTasks.totalTasks;
    final progress = widget.milestoneWithTasks.progress;

    return HoverCard(
      margin: const EdgeInsets.only(bottom: 14),
      borderColor: milestone.isCompleted
          ? Colors.greenAccent.withValues(alpha: 0.3)
          : AppTheme.borderColor,
      child: Column(
        children: [
          // Milestone Header Clickable Area
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Checkbox for Milestone
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(goalDetailProvider(widget.goalId).notifier)
                              .toggleMilestone(milestone);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: milestone.isCompleted
                                ? Colors.greenAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: milestone.isCompleted
                                  ? Colors.greenAccent
                                  : Colors.white38,
                              width: 1.8,
                            ),
                          ),
                          child: milestone.isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              milestone.title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: milestone.isCompleted
                                    ? Colors.white54
                                    : Colors.white,
                                decoration: milestone.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target: $formattedDate',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: milestone.isCompleted
                              ? Colors.greenAccent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$completedCount/$totalCount done',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: milestone.isCompleted
                                ? Colors.greenAccent
                                : Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        color: AppTheme.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteMilestoneDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ],
                  ),
                  if (totalCount > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          milestone.isCompleted
                              ? Colors.greenAccent
                              : Colors.indigoAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Tasks Section
          if (_isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppTheme.background.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Center(
                        child: Text(
                          'No tasks in this milestone yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      itemBuilder: (context, taskIndex) {
                        final task = tasks[taskIndex];
                        return _TaskItemTile(
                          goalId: widget.goalId,
                          task: task,
                        );
                      },
                    ),

                  const SizedBox(height: 6),
                  // Add Task Row
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openAddTaskDialog(context, milestone.id),
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: const Text('Add Task',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        backgroundColor: Colors.indigoAccent.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAddTaskDialog(BuildContext context, String milestoneId) {
    showDialog(
      context: context,
      builder: (context) => _CreateTaskDialog(
        goalId: widget.goalId,
        milestoneId: milestoneId,
      ),
    );
  }

  void _showDeleteMilestoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Milestone',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "${widget.milestoneWithTasks.milestone.title}" and its tasks?',
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
              await ref
                  .read(goalDetailProvider(widget.goalId).notifier)
                  .deleteMilestone(widget.milestoneWithTasks.milestone.id);
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

class _TaskItemTile extends ConsumerWidget {
  final String goalId;
  final Task task;

  const _TaskItemTile({
    required this.goalId,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HoverCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 10,
      child: Row(
        children: [
          // Checkbox
          Transform.scale(
            scale: 0.95,
            child: Checkbox(
              value: task.isDone,
              activeColor: Colors.indigoAccent,
              checkColor: Colors.white,
              side: const BorderSide(color: Colors.white38, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: (_) {
                ref
                    .read(goalDetailProvider(goalId).notifier)
                    .toggleTask(task);
              },
            ),
          ),
          const SizedBox(width: 4),
          // Task Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: task.isDone ? Colors.white38 : Colors.white,
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.scheduledDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 11, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d')
                            .format(task.scheduledDate!),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Estimated minutes badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${task.estimatedMinutes}m',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Delete Task Icon
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: Colors.white38),
            tooltip: 'Delete Task',
            onPressed: () {
              ref.read(goalDetailProvider(goalId).notifier).deleteTask(task.id);
            },
          ),
        ],
      ),
    );
  }
}

class _CreateMilestoneBottomSheet extends ConsumerStatefulWidget {
  final String goalId;

  const _CreateMilestoneBottomSheet({required this.goalId});

  @override
  ConsumerState<_CreateMilestoneBottomSheet> createState() =>
      _CreateMilestoneBottomSheetState();
}

class _CreateMilestoneBottomSheetState
    extends ConsumerState<_CreateMilestoneBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 14));
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
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
              surface: AppTheme.cardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.cardBackground,
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

  Future<void> _submitMilestone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(goalDetailProvider(widget.goalId).notifier).addMilestone(
            title: _titleController.text.trim(),
            targetDate: _selectedDate,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone added successfully!'),
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
            content: Text('Error adding milestone: $e'),
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Milestone',
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
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Milestone Title',
                hintText: 'e.g. Complete ALU & Register File Testbench',
                labelStyle:
                    const TextStyle(color: Colors.white60, fontSize: 13),
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon: Icon(Icons.flag_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a milestone title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Target Date',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
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
                    const Icon(Icons.edit_calendar_rounded,
                        color: Colors.white38, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitMilestone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
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
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Milestone',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTaskDialog extends ConsumerStatefulWidget {
  final String goalId;
  final String milestoneId;

  const _CreateTaskDialog({
    required this.goalId,
    required this.milestoneId,
  });

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  int _estimatedMinutes = 30;
  DateTime? _scheduledDate;
  bool _isRecurring = false;
  final Set<String> _selectedRecurringDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
  bool _isSaving = false;

  final List<int> _presetMinutes = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
              surface: AppTheme.cardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.cardBackground,
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

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(goalDetailProvider(widget.goalId).notifier).addTask(
            milestoneId: widget.milestoneId,
            title: _titleController.text.trim(),
            estimatedMinutes: _estimatedMinutes,
            scheduledDate: _scheduledDate ?? (_isRecurring ? DateTime.now() : null),
            isRecurring: _isRecurring,
            recurringDays: _isRecurring ? _selectedRecurringDays.join(',') : '',
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task added successfully!'),
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
            content: Text('Error adding task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_task_rounded,
                            color: Colors.indigoAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Add New Task',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g. Write test vector generator for 32-bit adder',
                    labelStyle:
                        const TextStyle(color: Colors.white60, fontSize: 13),
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                     prefixIcon: Icon(Icons.task_alt_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                      ),
                    ),
                     focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Estimated Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetMinutes.map((minutes) {
                    final isSelected = _estimatedMinutes == minutes;
                    return ChoiceChip(
                      label: Text(
                        '${minutes}m',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      selected: isSelected,
                       selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: AppTheme.background,
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.borderColor,
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
                const SizedBox(height: 18),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                         Icon(Icons.calendar_today_rounded,
                            color: Theme.of(context).colorScheme.primary, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _scheduledDate == null
                              ? 'Schedule Date (Optional)'
                              : 'Scheduled: ${DateFormat('MMM dd, yyyy').format(_scheduledDate!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _scheduledDate == null
                                ? Colors.white54
                                : Colors.white,
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
                            child: const Icon(Icons.clear_rounded,
                                size: 16, color: Colors.white38),
                          )
                        else
                          const Icon(Icons.edit_calendar_rounded,
                              size: 16, color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Recurrence toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
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
                                : AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDaySelected
                                  ? Theme.of(context).colorScheme.primary
                                  : AppTheme.borderColor,
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

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitTask,
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
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
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Task',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

