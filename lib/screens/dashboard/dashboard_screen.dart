import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_card.dart';
import '../../core/widgets/ambient_glow_background.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../models/dashboard_task_item.dart';
import '../../models/pause_mode.dart';
import '../goals/goal_detail_screen.dart';
import '../goals/goal_list_screen.dart';
import 'widgets/analytics_section.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedFilter = 'All';
  bool _isSystemInsightsExpanded = false;

  Color _getCategoryColor(String category) {
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

  List<DashboardTaskItem> _filterTasks(List<DashboardTaskItem> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case 'High Priority':
        return tasks.where((t) => t.goalPriority >= 4.0).toList();
      case 'Today':
        return tasks.where((t) {
          if (t.task.scheduledDate == null) return false;
          final d = t.task.scheduledDate!;
          final taskDate = DateTime(d.year, d.month, d.day);
          return taskDate.isAtSameMomentAs(today) || taskDate.isBefore(today);
        }).toList();
      case 'All':
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bolt_rounded,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Mission Control',
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
            icon: Icon(
              dashboardAsync.value?.isPauseModeActive == true
                  ? Icons.pause_circle_filled_rounded
                  : Icons.pause_circle_outline_rounded,
              color: dashboardAsync.value?.isPauseModeActive == true
                  ? Colors.amberAccent
                  : Colors.orangeAccent,
            ),
            tooltip: dashboardAsync.value?.isPauseModeActive == true
                ? 'Active Pause Mode (Exam / Holiday)'
                : 'Pause System / Exam Mode',
            onPressed: () => _showPauseSystemDialog(
              context,
              ref,
              dashboardAsync.value?.activePauseMode,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Dashboard',
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.flag_rounded, color: Colors.indigoAccent),
            tooltip: 'All Goals',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GoalListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AmbientGlowBackground(
          child: dashboardAsync.when(
        data: (state) {
          final filteredTasks = _filterTasks(state.incompleteTasks);

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(dashboardProvider.notifier).refresh();
            },
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: AppTheme.cardBackground,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Active Strict Pause / Exam Mode Banner
                  if (state.isPauseModeActive) ...[
                    _buildActivePauseModeBanner(
                        context, ref, state.activePauseMode!),
                    const SizedBox(height: 18),
                  ],

                  // 1. Top Daily Overview Header Banner
                  _buildDailyOverviewBanner(state),
                  const SizedBox(height: 18),

                  // 2. Metrics Row
                  _buildMetricsRow(state),
                  const SizedBox(height: 22),

                  // System Insights Expandable Card
                  _buildSystemInsightsCard(context, ref, state),
                  const SizedBox(height: 22),

                  // 3. Analytics & Consistency Section (Weekly Bar Chart, Consistency Ratio, Goal Balance Indicator)
                  AnalyticsSection(
                    analytics: state.analytics,
                    goalBalanceEfforts: state.systemInsights.categoryEfforts,
                  ),
                  const SizedBox(height: 26),

                  // 4. Today's Focus Header & Filters
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Colors.indigoAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Today's Focus",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.incompleteTasks.length} pending',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigoAccent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Filter chips
                      _buildFilterChip('All'),
                      const SizedBox(width: 6),
                      _buildFilterChip('High Priority'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Task List
                  if (state.incompleteTasks.isEmpty)
                    _buildAllCaughtUpState(context)
                  else if (filteredTasks.isEmpty)
                    _buildEmptyFilterState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final item = filteredTasks[index];
                        return _DashboardTaskCard(
                          item: item,
                          categoryColor: _getCategoryColor(item.goalCategory),
                          onToggle: () => ref
                              .read(dashboardProvider.notifier)
                              .toggleTask(item.task),
                          onDelete: () => ref
                              .read(dashboardProvider.notifier)
                              .deleteTask(item.task.id),
                          onTapGoal: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    GoalDetailScreen(goalId: item.goalId),
                              ),
                            );
                          },
                        );
                      },
                    ),

                  // 4.5. Missed Execution Log Section
                  if (state.missedTasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildMissedExecutionLogSection(context, ref, state),
                  ],

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
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                      ref.read(dashboardProvider.notifier).refresh(),
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
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GoalListScreen(),
            ),
          );
        },
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.track_changes_rounded),
        label: const Text(
          'Manage Goals',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
        ),
      ),
    );
  }

  Widget _buildDailyOverviewBanner(DashboardState state) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 13, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'DAILY OVERVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppTheme.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Welcome back, here is today's focus.",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.totalIncompleteTasks > 0
                ? "You have ${state.totalIncompleteTasks} pending ${state.totalIncompleteTasks == 1 ? 'task' : 'tasks'} (${state.formattedEstimatedTime} total) ready for focused execution."
                : "All pending tasks completed. Outstanding execution today!",
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterName) {
    final isSelected = _selectedFilter == filterName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.cyanAccent
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.cyanAccent
                : AppTheme.borderColor,
          ),
        ),
        child: Text(
          filterName,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(DashboardState state) {
    return Row(
      children: [
        // Pending Focus Tasks Metric
        Expanded(
          child: HoverCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pending Tasks',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.checklist_rounded,
                      color: AppTheme.cyanAccent,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.totalIncompleteTasks}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'across ${state.totalActiveGoals} active goals',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Estimated Time Metric
        Expanded(
          child: HoverCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Est. Focus Time',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.timer_outlined,
                      color: AppTheme.purpleAccent,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.formattedEstimatedTime,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.purpleAccent,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'targeted execution',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInsightsCard(
      BuildContext context, WidgetRef ref, DashboardState state) {
    final insights = state.systemInsights;
    final bool hasIssues = insights.weakPoints.isNotEmpty;
    final int issueCount = insights.weakPoints.length;
    final bool hasCritical = insights.weakPoints.any((wp) => wp.isCriticallyOverdue);

    final Color borderColor = hasCritical
        ? Colors.redAccent.withValues(alpha: 0.4)
        : (hasIssues
            ? Colors.orangeAccent.withValues(alpha: 0.4)
            : AppTheme.borderColor);

    return HoverCard(
      borderColor: borderColor,
      borderWidth: 1.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isSystemInsightsExpanded = !_isSystemInsightsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasCritical
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : (hasIssues
                              ? Colors.orangeAccent.withValues(alpha: 0.15)
                              : Colors.indigoAccent.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasCritical
                          ? Icons.warning_amber_rounded
                          : (hasIssues
                              ? Icons.insights_rounded
                              : Icons.psychology_rounded),
                      color: hasCritical
                          ? Colors.redAccent
                          : (hasIssues ? Colors.orangeAccent : Colors.indigoAccent),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'System Insights',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasIssues)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasCritical
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : Colors.orangeAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasCritical
                            ? '$issueCount Alerts'
                            : '$issueCount Needs Attention',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasCritical ? Colors.redAccent : Colors.orangeAccent,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'On Track',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    _isSystemInsightsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_isSystemInsightsExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Strongest Area (Past 14d): ',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (insights.strongestArea != 'None') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(insights.strongestArea).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            insights.strongestArea,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(insights.strongestArea),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${insights.strongestAreaPercentage.toStringAsFixed(0)}% effort)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'No focus logged yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Needs Attention Flags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (insights.weakPoints.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text(
                            'No goals flagged. Keep it up!',
                            style: TextStyle(fontSize: 12.5, color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  else
                    ...insights.weakPoints.map((wp) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: wp.isCriticallyOverdue
                                  ? Colors.redAccent.withValues(alpha: 0.08)
                                  : Colors.orangeAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: wp.isCriticallyOverdue
                                    ? Colors.redAccent.withValues(alpha: 0.25)
                                    : Colors.orangeAccent.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      wp.isCriticallyOverdue
                                          ? Icons.error_rounded
                                          : Icons.warning_amber_rounded,
                                      size: 15,
                                      color: wp.isCriticallyOverdue
                                          ? Colors.redAccent
                                          : Colors.orangeAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        wp.goal.title,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(wp.goal.category).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        wp.goal.category,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: _getCategoryColor(wp.goal.category),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  wp.reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: wp.isCriticallyOverdue
                                        ? Colors.redAccent.withValues(alpha: 0.9)
                                        : Colors.orangeAccent.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'Actionable Recommendations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...insights.recommendations.map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigoAccent,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rec,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAllCaughtUpState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      margin: const EdgeInsets.only(top: 12),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.greenAccent,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Focus Queue Cleared! 🎉',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No incomplete tasks remaining across your goals. Add new milestone tasks or review your roadmap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white60,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GoalListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.flag_rounded),
              label: const Text('View Strategic Goals'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  Widget _buildEmptyFilterState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'No tasks match filter "$_selectedFilter"',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }

  // ==========================================
  // STRICT PAUSE / EXAM MODE UI HELPERS
  // ==========================================

  Widget _buildActivePauseModeBanner(
      BuildContext context, WidgetRef ref, PauseMode mode) {
    final now = DateTime.now();
    final remainingDays = mode.remainingDays(now);
    final formattedEndDate = DateFormat('EEE, MMM dd, yyyy').format(mode.endDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade900.withValues(alpha: 0.35),
            AppTheme.cardBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amberAccent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.amberAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'STRICT PAUSE MODE ACTIVE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.amberAccent,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$remainingDays days left',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded,
                    color: Colors.amberAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Active Focus Routine: "${mode.activeRoutineTitle}"',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white60, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-Resumes: $formattedEndDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text(
                  'Resume Now',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await ref
                      .read(dashboardProvider.notifier)
                      .deactivatePauseMode(mode.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Standard operating mode resumed.'),
                        backgroundColor: AppTheme.cardBackground,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPauseSystemDialog(
      BuildContext context, WidgetRef ref, PauseMode? currentActiveMode) {
    final titleController = TextEditingController(
        text: currentActiveMode?.title ?? 'Final Exams Sprint');
    final routineController = TextEditingController(
        text: currentActiveMode?.activeRoutineTitle ??
            'Focused Study & Recovery');
    DateTime startDate = currentActiveMode?.startDate ?? DateTime.now();
    DateTime endDate = currentActiveMode?.endDate ??
        DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pause_circle_filled_rounded,
                        color: Colors.amberAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Pause System / Exam Mode',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activate a temporary pause window to suspend missed-task logging for standard goals during exams, vacations, or hackathons.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.white54, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    // Quick Presets
                    const Text(
                      'QUICK PRESETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'Final Exams Sprint',
                        'Holiday Break',
                        'Hackathon Sprint',
                        'Health Recovery',
                      ].map((preset) {
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              titleController.text = preset;
                              if (preset.contains('Exam')) {
                                routineController.text =
                                    'Revision & Past Papers';
                              } else if (preset.contains('Holiday')) {
                                routineController.text = 'Rest & Rejuvenation';
                              } else if (preset.contains('Hackathon')) {
                                routineController.text =
                                    'High-Intensity Prototyping';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    Colors.amberAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.amberAccent),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Title Field
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Mode Title',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Active Routine Title Field
                    TextField(
                      controller: routineController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Active Routine / Priority',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Date Range Picker Trigger
                    const Text(
                      'PAUSE DURATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange:
                              DateTimeRange(start: startDate, end: endDate),
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          builder: (ctx, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.amberAccent,
                                  onPrimary: AppTheme.background,
                                  surface: AppTheme.cardBackground,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            startDate = picked.start;
                            endDate = picked.end;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.amberAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range_rounded,
                                    color: Colors.amberAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('MMM dd').format(startDate)} → ${DateFormat('MMM dd, yyyy').format(endDate)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const Text(
                              'Change',
                              style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final mode = PauseMode(
                      id: currentActiveMode?.id ??
                          'pause_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startDate: startDate,
                      endDate: endDate,
                      activeRoutineTitle: routineController.text.trim().isEmpty
                          ? 'Focused Study'
                          : routineController.text.trim(),
                      isActive: true,
                    );

                    await ref
                        .read(dashboardProvider.notifier)
                        .activatePauseMode(mode);

                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.cardBackground,
                          content: Text(
                            'Strict Pause Mode "${mode.title}" activated!',
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Activate Mode',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MISSED EXECUTION LOG UI HELPERS
  // ==========================================

  Widget _buildMissedExecutionLogSection(
      BuildContext context, WidgetRef ref, DashboardState state) {
    return HoverCard(
      borderColor: Colors.redAccent.withValues(alpha: 0.3),
      borderWidth: 1.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Missed Execution Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.missedTasks.length} missed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tasks scheduled in previous cycles that were not completed. Reschedule to today or mark done.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.missedTasks.length,
            itemBuilder: (context, index) {
              final item = state.missedTasks[index];
              final categoryColor = _getCategoryColor(item.goalCategory);
              final scheduledDateFormatted = item.task.scheduledDate != null
                  ? DateFormat('MMM dd, yyyy').format(item.task.scheduledDate!)
                  : 'Past cycle';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.task.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    item.goalTitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const Text(
                                    ' • ',
                                    style: TextStyle(
                                        color: Colors.white24, fontSize: 10),
                                  ),
                                  Text(
                                    item.milestoneTitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Missed: $scheduledDateFormatted',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Reschedule to Today Button
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.today_rounded, size: 15),
                          label: const Text('Today',
                              style: TextStyle(fontSize: 11.5)),
                          onPressed: () {
                            ref
                                .read(dashboardProvider.notifier)
                                .rescheduleTask(item.task.id, DateTime.now());
                          },
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 15),
                          label: const Text('Reschedule',
                              style: TextStyle(fontSize: 11.5)),
                          onPressed: () =>
                              _showRescheduleDatePicker(context, ref, item),
                        ),
                        const SizedBox(width: 4),
                        // Mark Done Button
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 15),
                          label: const Text('Complete',
                              style: TextStyle(fontSize: 11.5)),
                          onPressed: () {
                            ref
                                .read(dashboardProvider.notifier)
                                .toggleTask(item.task);
                          },
                        ),
                        const SizedBox(width: 4),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.white38),
                          tooltip: 'Delete Task',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            ref
                                .read(dashboardProvider.notifier)
                                .deleteTask(item.task.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleDatePicker(
      BuildContext context, WidgetRef ref, DashboardTaskItem item) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.cyanAccent,
              onPrimary: Colors.white,
              surface: AppTheme.cardBackground,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      await ref
          .read(dashboardProvider.notifier)
          .rescheduleTask(item.task.id, pickedDate);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.cardBackground,
            content: Text(
              'Rescheduled to ${DateFormat('MMM dd, yyyy').format(pickedDate)}',
              style: const TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _DashboardTaskCard extends StatelessWidget {
  final DashboardTaskItem item;
  final Color categoryColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTapGoal;

  const _DashboardTaskCard({
    required this.item,
    required this.categoryColor,
    required this.onToggle,
    required this.onDelete,
    required this.onTapGoal,
  });

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final scheduledDateFormatted = task.scheduledDate != null
        ? DateFormat('MMM dd').format(task.scheduledDate!)
        : null;

    final isOverdue = task.scheduledDate != null &&
        task.scheduledDate!.isBefore(
          DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day),
        );

    return HoverCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14.0),
      onTap: onTapGoal,
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Context Header: Goal Category Tag, Goal Title & Milestone Title
                Row(
                  children: [
                    // Subtle Goal Tag (e.g. "VLSI")
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item.goalCategory.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Goal and Milestone hierarchy
                    Expanded(
                      child: Text(
                        '${item.goalTitle} › ${item.milestoneTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Delete task action
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white30,
                      ),
                      tooltip: 'Dismiss task',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Main Task Row: Checkbox, Title, and Time Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive Checkbox
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: task.isDone,
                        activeColor: Colors.indigoAccent,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white38, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (_) => onToggle(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Task Title and Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: task.isDone ? Colors.white38 : Colors.white,
                              decoration:
                                  task.isDone ? TextDecoration.lineThrough : null,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Estimated Time Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        size: 12, color: Colors.white60),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.estimatedMinutes}m',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (scheduledDateFormatted != null) ...[
                                const SizedBox(width: 8),
                                // Scheduled Date Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isOverdue
                                        ? Colors.redAccent.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: isOverdue
                                        ? Border.all(
                                            color: Colors.redAccent
                                                .withValues(alpha: 0.4),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 11,
                                        color: isOverdue
                                            ? Colors.redAccent
                                            : Colors.white60,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOverdue
                                            ? 'Overdue ($scheduledDateFormatted)'
                                            : scheduledDateFormatted,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOverdue
                                              ? Colors.redAccent
                                              : Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Direct navigation indicator
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Goal Roadmap',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.indigoAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 10,
                                    color: Colors.indigoAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
