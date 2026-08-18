import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/goals/goal_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/dashboard/widgets/quick_add_dialog.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/database/db_helper.dart';
import 'core/theme/settings_provider.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-load settings from database to prevent theme flickering
  final dbHelper = DBHelper.instance;
  await dbHelper.database; // force DB initialization
  final rawSettings = await dbHelper.getAllSettings();

  ThemeMode themeMode = ThemeMode.system;
  final themeModeStr = rawSettings['theme_mode'];
  if (themeModeStr == 'dark') themeMode = ThemeMode.dark;
  if (themeModeStr == 'light') themeMode = ThemeMode.light;

  Color accentColor = const Color(0xFF38BDF8); // default glacierBlue
  final accentColorStr = rawSettings['accent_color'];
  if (accentColorStr != null) {
    final parsed = int.tryParse(accentColorStr);
    if (parsed != null) accentColor = Color(parsed);
  }

  final Map<String, Color> categoryColors = {};
  rawSettings.forEach((key, value) {
    if (key.startsWith('category_color_')) {
      final category = key.substring('category_color_'.length);
      final parsed = int.tryParse(value);
      if (parsed != null) {
        categoryColors[category] = Color(parsed);
      }
    }
  });

  final loadedSettings = AppSettings(
    themeMode: themeMode,
    accentColor: accentColor,
    categoryColors: categoryColors,
  );

  // Initialize notifications and schedule initial alerts
  try {
    await NotificationService.instance.init();
    final allEvents = await dbHelper.getAllEvents();
    await NotificationService.instance.scheduleEventNotifications(allEvents);
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => SettingsNotifier(loadedSettings)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Ascend LifeOS',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.lightThemeWithAccent(settings.accentColor),
      darkTheme: AppTheme.themeWithAccent(settings.accentColor),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    CalendarScreen(),
    GoalListScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _openQuickAddDialog() {
    showDialog(
      context: context,
      builder: (context) => const QuickAddDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
          setState(() {
            _currentIndex = 0;
          });
        },
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
          setState(() {
            _currentIndex = 1;
          });
        },
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
          setState(() {
            _currentIndex = 2;
          });
        },
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
          setState(() {
            _currentIndex = 3;
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _openQuickAddDialog();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: accentColor.withValues(alpha: 0.15),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    );
                  }
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: accentColor, size: 24);
                  }
                  return const IconThemeData(color: AppTheme.textSecondary, size: 22);
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: AppTheme.cardBackground,
                elevation: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.bolt_outlined),
                    selectedIcon: Icon(Icons.bolt_rounded),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.flag_outlined),
                    selectedIcon: Icon(Icons.flag_rounded),
                    label: 'All Goals',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
