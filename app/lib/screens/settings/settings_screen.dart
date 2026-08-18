import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/settings_provider.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/database/backup_service.dart';
import '../../features/calendar/calendar_provider.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../features/goals/goal_provider.dart';
import '../../features/goals/goal_detail_provider.dart';
import '../../features/goals/category_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return const TimeOfDay(hour: 0, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDisplayTime(String timeStr) {
    final tod = _parseTimeString(timeStr);
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _handleExportData(BuildContext context) async {
    try {
      final path = await BackupService.instance.exportBackupFile();
      if (!context.mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.cardBackground,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Backup saved: ${path.split(RegExp(r'[/\\]')).last}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Export failed: $e',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _handleImportData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Restore Database Backup',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Restoring data will replace your existing goals, milestones, tasks, and calendar events with the contents of the backup JSON file.\n\nDo you wish to proceed?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Select File & Restore',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await BackupService.instance.importBackupFile();
      if (!context.mounted) return;

      if (result == null) {
        return; // User cancelled
      }

      if (result.success) {
        ref.invalidate(dashboardProvider);
        ref.invalidate(goalProvider);
        ref.invalidate(calendarProvider);
        ref.invalidate(goalDetailProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.cardBackground,
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.tealAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.summaryMessage,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text(
              result.errorMessage ?? 'Restore failed.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Import failed: $e',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Widget _buildThemeModeChip(BuildContext context, WidgetRef ref, String label, ThemeMode mode) {
    final settings = ref.watch(settingsProvider);
    final isSelected = settings.themeMode == mode;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: AppTheme.background,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.black : Colors.white70,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : AppTheme.borderColor,
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(settingsProvider.notifier).updateThemeMode(mode);
        }
      },
    );
  }

  void _showCategoryColorPicker(BuildContext context, WidgetRef ref, String category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Text('Select Accent for $category', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(ThemeNotifier.presets.length, (index) {
              final color = ThemeNotifier.presets[index];
              return InkWell(
                onTap: () {
                  ref.read(settingsProvider.notifier).updateCategoryColor(category, color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final activeAccent = settings.accentColor;
    final calendarState = ref.watch(calendarProvider);

    final sleepStart = calendarState.value?.sleepStart ?? '22:00';
    final sleepEnd = calendarState.value?.sleepEnd ?? '04:00';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.borderColor,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header: Appearance
            _buildSectionHeader('Appearance', Icons.palette_outlined, activeAccent),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme Accent Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a color to personalize glows, borders, and buttons.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(ThemeNotifier.presets.length, (index) {
                      final color = ThemeNotifier.presets[index];
                      final name = ThemeNotifier.presetNames[index];
                      final isSelected = activeAccent == color;

                      return Tooltip(
                        message: name,
                        child: InkWell(
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateAccentColor(color);
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.6
                                        ? Colors.black
                                        : Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.borderColor, height: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Theme Mode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toggle overall app interface between Light, Dark, or System mode.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildThemeModeChip(context, ref, 'System', ThemeMode.system),
                      const SizedBox(width: 8),
                      _buildThemeModeChip(context, ref, 'Light', ThemeMode.light),
                      const SizedBox(width: 8),
                      _buildThemeModeChip(context, ref, 'Dark', ThemeMode.dark),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section Header: Category Accent Colors
            _buildSectionHeader('Category Accent Colors', Icons.color_lens_outlined, activeAccent),
            const SizedBox(height: 12),
            ref.watch(categoryProvider).when(
              data: (categories) {
                return GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Category Accents',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap a category to customize its specific color accent.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const Divider(color: AppTheme.borderColor, height: 16),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final catColor = AppTheme.getCategoryColor(context, cat);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: InkWell(
                              onTap: () => _showCategoryColorPicker(context, ref, cat),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),

            const SizedBox(height: 28),

            // Section Header: Sleep & Capacity
            _buildSectionHeader('Sleep & Capacity Plan', Icons.nights_stay_outlined, activeAccent),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Baseline Sleep Routine',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure sleep bounds to automatically calculate daily waking capacity.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      // Sleep Start Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final initial = _parseTimeString(sleepStart);
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initial,
                            );
                            if (picked != null) {
                              final formatted = _formatTimeOfDay(picked);
                              await ref
                                  .read(calendarProvider.notifier)
                                  .updateSleepSchedule(
                                    sleepStart: formatted,
                                    sleepEnd: sleepEnd,
                                  );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sleep Start',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDisplayTime(sleepStart),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Icon(
                                      Icons.access_time_filled_rounded,
                                      color: activeAccent,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sleep End Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final initial = _parseTimeString(sleepEnd);
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initial,
                            );
                            if (picked != null) {
                              final formatted = _formatTimeOfDay(picked);
                              await ref
                                  .read(calendarProvider.notifier)
                                  .updateSleepSchedule(
                                    sleepStart: sleepStart,
                                    sleepEnd: formatted,
                                  );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sleep End',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDisplayTime(sleepEnd),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Icon(
                                      Icons.access_time_filled_rounded,
                                      color: activeAccent,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section Header: Data Management
            _buildSectionHeader('Data Management', Icons.storage_outlined, activeAccent),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Offline Workspace Backup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Safely export your entire workspace JSON file locally or restore previous configurations.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      // Export Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.background,
                            foregroundColor: activeAccent,
                            side: BorderSide(
                              color: activeAccent.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text(
                            'Export Backup',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () => _handleExportData(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Import Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeAccent,
                            foregroundColor: AppTheme.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 18),
                          label: const Text(
                            'Import Backup',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () => _handleImportData(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Developer Info Section
            _buildSectionHeader('Architect', Icons.badge_outlined, activeAccent),
            const SizedBox(height: 12),
            _DeveloperCard(accentColor: activeAccent),

            const SizedBox(height: 36),

            // About Section / Version
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activeAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Project Ascend LifeOS Gamma v1.5',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final Color accentColor;
  const _DeveloperCard({required this.accentColor});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                child: Icon(Icons.person_outline_rounded, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deepak Suthar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Lead Architect',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.email_rounded,
            label: 'suthardeepak@proton.me',
            onTap: () => _launchUrl('mailto:suthardeepak@proton.me'),
            color: accentColor,
          ),
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.code_rounded,
            label: 'github/suthardeepak-95',
            onTap: () => _launchUrl('https://github.com/suthardeepak-95'),
            color: accentColor,
          ),
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.camera_alt_rounded,
            label: '@d_suthar.95',
            onTap: () => _launchUrl('https://instagram.com/d_suthar.95'),
            color: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }
}
