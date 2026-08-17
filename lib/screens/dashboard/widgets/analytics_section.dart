import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/analytics_service.dart';
import '../../../models/analytics_data.dart';
import '../../../core/theme/app_theme.dart';

class AnalyticsSection extends StatelessWidget {
  final AnalyticsData analytics;
  final List<Category14DayEffort> goalBalanceEfforts;

  const AnalyticsSection({
    super.key,
    required this.analytics,
    this.goalBalanceEfforts = const [],
  });

  Color _getCategoryColor(BuildContext context, String category) {
    return AppTheme.getCategoryColor(context, category);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytics Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insights_rounded,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Analytics & Momentum',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    '${analytics.totalWeeklyMinutes}m logged',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Weekly Progress Bar Chart Card
        _buildWeeklyChartCard(context),
        const SizedBox(height: 14),

        // 2. Consistency Ratio & Streak Card
        _buildConsistencyCard(context),
        const SizedBox(height: 14),

        // 3. Goal Balance Indicator (14d Proportional Effort Split)
        _buildGoalBalanceIndicatorCard(context),
      ],
    );
  }

  Widget _buildWeeklyChartCard(BuildContext context) {
    final stats = analytics.weeklyFocusStats;
    final maxMinutes = stats.isEmpty
        ? 60
        : stats.map((s) => s.totalMinutes).reduce(max);
    // Dynamic upper bound for Y axis
    final double maxY = max(60.0, (maxMinutes * 1.25).ceilToDouble());
    final double yInterval = maxY > 120 ? 60.0 : 30.0;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 17, color: accentColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Weekly Focus Time',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '7-Day Total: ${analytics.formattedWeeklyTime}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 175,
            child: stats.isEmpty
                ? const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => AppTheme.background,
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (group.x.toInt() < 0 ||
                                group.x.toInt() >= stats.length) {
                              return null;
                            }
                            final stat = stats[group.x.toInt()];
                            return BarTooltipItem(
                              '${stat.dayLabel}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${stat.totalMinutes}m (${stat.taskCount} ${stat.taskCount == 1 ? 'task' : 'tasks'})',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value > maxY) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${value.toInt()}m',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= stats.length) {
                                return const SizedBox.shrink();
                              }
                              final stat = stats[index];
                              final isToday = index == stats.length - 1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  stat.dayLabel,
                                  style: TextStyle(
                                    color: isToday
                                        ? accentColor
                                        : Colors.white60,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: stats.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final stat = entry.value;
                        final isToday = idx == stats.length - 1;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: stat.totalMinutes.toDouble(),
                              gradient: LinearGradient(
                                colors: isToday
                                    ? [
                                        accentColor,
                                        Colors.tealAccent,
                                      ]
                                    : [
                                        Colors.indigoAccent,
                                        accentColor.withValues(alpha: 0.8),
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: Colors.white.withValues(alpha: 0.03),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    swapAnimationDuration: Duration.zero,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyCard(BuildContext context) {
    final activeDays = analytics.activeDaysCount;
    final totalDays = analytics.totalDaysCount;
    final consistencyPercent = (analytics.consistencyRatio * 100).toInt();
    final stats = analytics.weeklyFocusStats;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 18, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text(
                    'Consistency Ratio',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activeDays/$totalDays days ($consistencyPercent%)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7-Day Visual Tracker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stats.map((stat) {
              final isActive = stat.taskCount > 0;
              final isToday = stat.date.day == DateTime.now().day &&
                  stat.date.month == DateTime.now().month &&
                  stat.date.year == DateTime.now().year;

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.amberAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? accentColor
                            : (isActive
                                ? Colors.amberAccent.withValues(alpha: 0.6)
                                : Colors.white12),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.amberAccent,
                            )
                          : Text(
                              stat.dayLabel.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.dayLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? accentColor : Colors.white54,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Motivational streak status
          Row(
            children: [
              Icon(
                activeDays >= 4
                    ? Icons.auto_awesome_rounded
                    : Icons.track_changes_rounded,
                size: 14,
                color: activeDays >= 4 ? Colors.amberAccent : Colors.white54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activeDays >= 5
                      ? 'High Momentum! Exceptional weekly consistency 🔥'
                      : (activeDays > 0
                          ? 'Consistent progress logged. Keep building your streak!'
                          : 'Complete your first task today to ignite your streak!'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalBalanceIndicatorCard(BuildContext context) {
    final efforts = goalBalanceEfforts.isNotEmpty
        ? goalBalanceEfforts
        : analytics.categoryEfforts
            .map((e) => Category14DayEffort(
                  category: e.category,
                  completedTasksCount: e.taskCount,
                  totalMinutes: e.totalMinutes,
                  percentage: e.percentage,
                ))
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.balance_rounded,
                      size: 18, color: Colors.purpleAccent),
                  SizedBox(width: 8),
                  Text(
                    'Goal Effort Distribution',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (efforts.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${efforts.length} Ambitions',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (efforts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text(
                'No active goals or effort logged in the past 14 days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12.5,
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: (() {
                    final totalMinutes = efforts.fold<int>(0, (sum, e) => sum + e.totalMinutes);
                    if (totalMinutes == 0) {
                      return efforts.map((eff) {
                        final color = _getCategoryColor(context, eff.category).withValues(alpha: 0.2);
                        return Expanded(
                          child: Container(
                            color: color,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          ),
                        );
                      }).toList();
                    }
                    
                    return efforts.map((eff) {
                      final color = _getCategoryColor(context, eff.category);
                      final weight = max(1, eff.percentage.round());
                      return Expanded(
                        flex: weight,
                        child: Container(
                          color: color,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        ),
                      );
                    }).toList();
                  })(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: efforts.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final eff = efforts[index];
                final color = _getCategoryColor(context, eff.category);
                final isNeglected = eff.totalMinutes == 0;

                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isNeglected ? color.withValues(alpha: 0.3) : color,
                        shape: BoxShape.circle,
                        boxShadow: isNeglected
                            ? []
                            : [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            eff.category,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isNeglected ? Colors.white38 : Colors.white,
                            ),
                          ),
                          if (isNeglected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Neglected',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${eff.formattedTime} (${eff.completedTasksCount} ${eff.completedTasksCount == 1 ? 'task' : 'tasks'})',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNeglected ? Colors.white24 : Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNeglected
                            ? Colors.white.withValues(alpha: 0.05)
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${eff.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNeglected ? Colors.white38 : color,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
