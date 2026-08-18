import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/main.dart';
import 'package:app/core/database/db_helper.dart';
import 'package:app/models/goal.dart';
import 'package:app/models/milestone.dart';
import 'package:app/models/task.dart';
import 'package:app/models/analytics_data.dart';
import 'package:app/models/event.dart';
import 'package:app/features/dashboard/dashboard_provider.dart';
import 'package:app/features/goals/goal_detail_provider.dart';
import 'package:app/features/calendar/calendar_provider.dart';
import 'package:app/screens/dashboard/dashboard_screen.dart';
import 'package:app/screens/dashboard/widgets/analytics_section.dart';
import 'dart:convert';
import 'package:app/core/database/backup_service.dart';
import 'package:app/models/pause_mode.dart';
import 'package:app/screens/calendar/calendar_screen.dart';

void main() {
  setUpAll(() {
    DBHelper.databaseName = inMemoryDatabasePath;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    await DBHelper.instance.clearAllData();
  });

  tearDown(() async {
    await DBHelper.instance.close();
  });


  testWidgets('App renders DashboardScreen as default home with bottom navigation', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Verify Mission Control & Daily Overview are present on default launch
    expect(find.text('Mission Control'), findsOneWidget);
    expect(find.text('DAILY OVERVIEW'), findsOneWidget);
    expect(find.text("Welcome back, here is today's focus."), findsOneWidget);

    // Verify Bottom Navigation items
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('All Goals'), findsOneWidget);

    // Tap on Calendar tab in bottom navigation
    await tester.tap(find.text('Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify CalendarScreen is visible
    expect(find.text('Daily Calendar & Timeline'), findsOneWidget);
    expect(find.text('Capacity Planner'), findsOneWidget);

    // Tap on All Goals tab in bottom navigation
    await tester.tap(find.text('All Goals'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify GoalListScreen is visible
    expect(find.text('My Strategic Goals'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders standalone smoke test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text("Mission Control"), findsOneWidget);
    expect(find.text("DAILY OVERVIEW"), findsOneWidget);
  });

  test('DBHelper desktop FFI initialization and Goal CRUD smoke test', () async {
    final dbHelper = DBHelper.instance;

    final testGoal = Goal(
      id: 'test_goal_1',
      title: 'Master FPGA Architecture',
      description: 'Design and synthesize high-speed DSP pipeline in Verilog',
      category: 'VLSI',
      targetDate: DateTime.now().add(const Duration(days: 90)),
      priority: 4.5,
    );

    // Insert
    await dbHelper.insertGoal(testGoal);

    // Retrieve
    final retrieved = await dbHelper.getGoalById('test_goal_1');
    expect(retrieved, isNotNull);
    expect(retrieved!.title, equals('Master FPGA Architecture'));
    expect(retrieved.priority, equals(4.5));

    // Cleanup
    await dbHelper.deleteGoal('test_goal_1');
    final deleted = await dbHelper.getGoalById('test_goal_1');
    expect(deleted, isNull);
  });

  test('Milestone and Task CRUD with progress bar calculation test', () async {
    final dbHelper = DBHelper.instance;

    final goal = Goal(
      id: 'goal_detail_test',
      title: 'Reverse Engineering Firmware',
      description: 'Analyze secure bootloader vulnerabilities',
      category: 'Cybersecurity',
      targetDate: DateTime.now().add(const Duration(days: 60)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final milestone1 = Milestone(
      id: 'ms_1',
      goalId: 'goal_detail_test',
      title: 'Decompile SPI Flash image',
      targetDate: DateTime.now().add(const Duration(days: 14)),
      isCompleted: false,
    );
    await dbHelper.insertMilestone(milestone1);

    final task1 = Task(
      id: 'task_1',
      milestoneId: 'ms_1',
      title: 'Dump ROM using Logic Analyzer',
      estimatedMinutes: 45,
      isDone: true,
    );
    final task2 = Task(
      id: 'task_2',
      milestoneId: 'ms_1',
      title: 'Locate crypto keys in Ghidra',
      estimatedMinutes: 60,
      isDone: false,
    );
    await dbHelper.insertTask(task1);
    await dbHelper.insertTask(task2);

    final milestones = await dbHelper.getMilestonesByGoalId('goal_detail_test');
    expect(milestones.length, equals(1));

    final tasks = await dbHelper.getTasksByMilestoneId('ms_1');
    expect(tasks.length, equals(2));

    final milestoneWithTasks = MilestoneWithTasks(
      milestone: milestones.first,
      tasks: tasks,
    );
    expect(milestoneWithTasks.progress, equals(0.5)); // 1 of 2 tasks isDone

    final state = GoalDetailState(
      goal: goal,
      milestonesWithTasks: [milestoneWithTasks],
    );
    expect(state.totalTasks, equals(2));
    expect(state.completedTasks, equals(1));
    expect(state.overallProgress, equals(0.5));

    // Toggle task2 to done: progress should become 100%
    final updatedTask2 = Task(
      id: task2.id,
      milestoneId: task2.milestoneId,
      title: task2.title,
      estimatedMinutes: task2.estimatedMinutes,
      isDone: true,
    );
    await dbHelper.updateTask(updatedTask2);
    final updatedTasks = await dbHelper.getTasksByMilestoneId('ms_1');
    final updatedState = GoalDetailState(
      goal: goal,
      milestonesWithTasks: [
        MilestoneWithTasks(milestone: milestone1, tasks: updatedTasks),
      ],
    );
    expect(updatedState.completedTasks, equals(2));
    expect(updatedState.overallProgress, equals(1.0));

    // Cleanup
    await dbHelper.deleteGoal('goal_detail_test'); // cascading delete
    expect(await dbHelper.getMilestonesByGoalId('goal_detail_test'), isEmpty);
    expect(await dbHelper.getTasksByMilestoneId('ms_1'), isEmpty);
  });

  test('DBHelper.getPendingTasksForToday queries pending tasks where isDone = 0 with Milestone & Goal context', () async {
    final dbHelper = DBHelper.instance;

    final goalA = Goal(
      id: 'goal_dash_a',
      title: 'VLSI ASIC Design',
      description: 'Synthesis pipeline',
      category: 'VLSI',
      targetDate: DateTime.now().add(const Duration(days: 30)),
      priority: 5.0,
    );
    final goalB = Goal(
      id: 'goal_dash_b',
      title: 'Game Engine Architecture',
      description: 'Vulkan renderer',
      category: 'GameDev',
      targetDate: DateTime.now().add(const Duration(days: 45)),
      priority: 4.0,
    );
    await dbHelper.insertGoal(goalA);
    await dbHelper.insertGoal(goalB);

    final msA = Milestone(
      id: 'ms_dash_a',
      goalId: 'goal_dash_a',
      title: 'Floorplanning & Routing',
      targetDate: DateTime.now().add(const Duration(days: 10)),
    );
    final msB = Milestone(
      id: 'ms_dash_b',
      goalId: 'goal_dash_b',
      title: 'Shader Compilation Subsystem',
      targetDate: DateTime.now().add(const Duration(days: 15)),
    );
    await dbHelper.insertMilestone(msA);
    await dbHelper.insertMilestone(msB);

    final taskA1 = Task(
      id: 't_dash_a1',
      milestoneId: 'ms_dash_a',
      title: 'Run OpenROAD timing analysis',
      estimatedMinutes: 30,
      isDone: false,
    );
    final taskA2 = Task(
      id: 't_dash_a2',
      milestoneId: 'ms_dash_a',
      title: 'Define clock tree constraints',
      estimatedMinutes: 45,
      isDone: true, // Completed - should be filtered out
    );
    final taskB1 = Task(
      id: 't_dash_b1',
      milestoneId: 'ms_dash_b',
      title: 'Write SPIR-V reflection parser',
      estimatedMinutes: 60,
      isDone: false,
    );

    await dbHelper.insertTask(taskA1);
    await dbHelper.insertTask(taskA2);
    await dbHelper.insertTask(taskB1);

    // Call getPendingTasksForToday()
    final pendingTasks = await dbHelper.getPendingTasksForToday();
    expect(pendingTasks.length, equals(2));

    // Verify task A1 and B1 are present and contain goal and milestone metadata
    final titles = pendingTasks.map((t) => t.task.title).toList();
    expect(titles, contains('Run OpenROAD timing analysis'));
    expect(titles, contains('Write SPIR-V reflection parser'));
    expect(titles, isNot(contains('Define clock tree constraints')));

    final itemA1 = pendingTasks.firstWhere((t) => t.task.id == 't_dash_a1');
    expect(itemA1.goalTitle, equals('VLSI ASIC Design'));
    expect(itemA1.goalCategory, equals('VLSI'));
    expect(itemA1.milestoneTitle, equals('Floorplanning & Routing'));
    expect(itemA1.task.estimatedMinutes, equals(30));

    // Cleanup
    await dbHelper.deleteGoal('goal_dash_a');
    await dbHelper.deleteGoal('goal_dash_b');
  });

  test('DashboardNotifier toggleTask removes task from Today\'s Focus and invalidates GoalDetailProvider', () async {
    final container = ProviderContainer();
    final dbHelper = DBHelper.instance;

    final goal = Goal(
      id: 'sync_goal_1',
      title: 'Deep Learning Compiler',
      description: 'Build TVM backend',
      category: 'VLSI',
      targetDate: DateTime.now().add(const Duration(days: 30)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'sync_ms_1',
      goalId: 'sync_goal_1',
      title: 'Graph IR Lowering',
      targetDate: DateTime.now().add(const Duration(days: 7)),
    );
    await dbHelper.insertMilestone(ms);

    final task1 = Task(
      id: 'sync_t_1',
      milestoneId: 'sync_ms_1',
      title: 'Implement Relay to TIR pass',
      estimatedMinutes: 45,
      isDone: false,
    );
    final task2 = Task(
      id: 'sync_t_2',
      milestoneId: 'sync_ms_1',
      title: 'Register CPU target intrinsic',
      estimatedMinutes: 30,
      isDone: false,
    );
    await dbHelper.insertTask(task1);
    await dbHelper.insertTask(task2);

    // Initial Dashboard state
    var dashState = await container.read(dashboardProvider.future);
    expect(dashState.incompleteTasks.length, equals(2));
    expect(dashState.totalEstimatedMinutes, equals(75));

    // Initial GoalDetail state
    var goalDetailState =
        await container.read<Future<GoalDetailState?>>(goalDetailProvider('sync_goal_1').future);
    expect(goalDetailState!.overallProgress, equals(0.0));
    expect(goalDetailState.completedTasks, equals(0));
    expect(goalDetailState.totalTasks, equals(2));

    // Toggle task 1 via DashboardNotifier
    await container.read(dashboardProvider.notifier).toggleTask(task1);

    // Verify Dashboard state auto-updated immediately (task 1 removed from Today's Focus)
    dashState = await container.read(dashboardProvider.future);
    expect(dashState.incompleteTasks.length, equals(1));
    expect(dashState.incompleteTasks.first.task.id, equals('sync_t_2'));
    expect(dashState.totalEstimatedMinutes, equals(30));

    // Verify GoalDetail provider auto-invalidated and calculates 50% progress immediately
    goalDetailState =
        await container.read<Future<GoalDetailState?>>(goalDetailProvider('sync_goal_1').future);
    expect(goalDetailState!.completedTasks, equals(1));
    expect(goalDetailState.overallProgress, equals(0.5));

    container.dispose();
  });

  test('GoalDetailNotifier addTask and toggleTask instantly updates Dashboard without manual reload', () async {
    final container = ProviderContainer();
    final dbHelper = DBHelper.instance;

    final goal = Goal(
      id: 'sync_goal_2',
      title: 'Embedded RTOS Kernel',
      description: 'Context switcher and scheduler in ARM assembly',
      category: 'Cybersecurity',
      targetDate: DateTime.now().add(const Duration(days: 40)),
      priority: 4.5,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'sync_ms_2',
      goalId: 'sync_goal_2',
      title: 'Context Switch & PendSV',
      targetDate: DateTime.now().add(const Duration(days: 10)),
    );
    await dbHelper.insertMilestone(ms);

    // Initial Dashboard is empty
    var dashState = await container.read(dashboardProvider.future);
    expect(dashState.incompleteTasks, isEmpty);

    // Add task via GoalDetailNotifier
    await container.read(goalDetailProvider('sync_goal_2').notifier).addTask(
          milestoneId: 'sync_ms_2',
          title: 'Implement stack frame setup',
          estimatedMinutes: 60,
        );

    // Dashboard automatically has the new task without manual refresh
    dashState = await container.read(dashboardProvider.future);
    expect(dashState.incompleteTasks.length, equals(1));
    expect(dashState.incompleteTasks.first.task.title,
        equals('Implement stack frame setup'));
    expect(dashState.totalEstimatedMinutes, equals(60));

    final insertedTask = dashState.incompleteTasks.first.task;

    // Toggle task in GoalDetailNotifier to complete
    await container
        .read(goalDetailProvider('sync_goal_2').notifier)
        .toggleTask(insertedTask);

    // Goal progress is now 100%
    final goalDetail =
        await container.read<Future<GoalDetailState?>>(goalDetailProvider('sync_goal_2').future);
    expect(goalDetail!.overallProgress, equals(1.0));

    // Dashboard now has 0 incomplete tasks
    dashState = await container.read(dashboardProvider.future);
    expect(dashState.incompleteTasks, isEmpty);
    expect(dashState.totalEstimatedMinutes, equals(0));

    container.dispose();
  });

  test('DBHelper.getAnalyticsData computes weekly stats, consistency ratio, and category distribution', () async {
    final dbHelper = DBHelper.instance;

    final goalVlsi = Goal(
      id: 'g_analytics_vlsi',
      title: 'RISC-V Core in Verilog',
      description: 'Pipeline design',
      category: 'VLSI',
      targetDate: DateTime.now().add(const Duration(days: 30)),
      priority: 5.0,
    );
    final goalSec = Goal(
      id: 'g_analytics_sec',
      title: 'Linux Kernel Exploitation',
      description: 'Heap vulnerabilities',
      category: 'Cybersecurity',
      targetDate: DateTime.now().add(const Duration(days: 45)),
      priority: 4.5,
    );
    await dbHelper.insertGoal(goalVlsi);
    await dbHelper.insertGoal(goalSec);

    final ms1 = Milestone(
      id: 'ms_an_1',
      goalId: 'g_analytics_vlsi',
      title: 'Execution Stage',
      targetDate: DateTime.now().add(const Duration(days: 10)),
    );
    final ms2 = Milestone(
      id: 'ms_an_2',
      goalId: 'g_analytics_sec',
      title: 'Slab Allocator Analysis',
      targetDate: DateTime.now().add(const Duration(days: 12)),
    );
    await dbHelper.insertMilestone(ms1);
    await dbHelper.insertMilestone(ms2);

    final now = DateTime.now();

    // 1 completed task today in VLSI (60 min)
    final tToday = Task(
      id: 't_an_today',
      milestoneId: 'ms_an_1',
      title: 'Implement ALU forwarding unit',
      estimatedMinutes: 60,
      isDone: true,
      completedAt: now,
    );

    // 1 completed task 2 days ago in Cybersecurity (40 min)
    final tPast = Task(
      id: 't_an_past',
      milestoneId: 'ms_an_2',
      title: 'Audit kmalloc slab caches',
      estimatedMinutes: 40,
      isDone: true,
      completedAt: now.subtract(const Duration(days: 2)),
    );

    // 1 incomplete task (should not count in analytics)
    final tIncomplete = Task(
      id: 't_an_inc',
      milestoneId: 'ms_an_1',
      title: 'Hazard detection logic',
      estimatedMinutes: 30,
      isDone: false,
    );

    await dbHelper.insertTask(tToday);
    await dbHelper.insertTask(tPast);
    await dbHelper.insertTask(tIncomplete);

    final analytics = await dbHelper.getAnalyticsData();

    // Verify weekly focus totals
    expect(analytics.totalWeeklyMinutes, equals(100)); // 60 + 40
    expect(analytics.completedTasksCount, equals(2));

    // Verify 7-day stats
    expect(analytics.weeklyFocusStats.length, equals(7));
    final todayStat = analytics.weeklyFocusStats.last;
    expect(todayStat.totalMinutes, equals(60));
    expect(todayStat.taskCount, equals(1));

    // Verify consistency ratio: 2 out of 7 days active
    expect(analytics.activeDaysCount, equals(2));
    expect(analytics.totalDaysCount, equals(7));
    expect(analytics.consistencyRatio, closeTo(2 / 7, 0.01));

    // Verify category effort distribution: VLSI (60%) vs Cybersecurity (40%)
    expect(analytics.categoryEfforts.length, equals(2));
    final vlsiEffort = analytics.categoryEfforts.firstWhere((c) => c.category == 'VLSI');
    final secEffort = analytics.categoryEfforts.firstWhere((c) => c.category == 'Cybersecurity');
    expect(vlsiEffort.totalMinutes, equals(60));
    expect(vlsiEffort.percentage, equals(60.0));
    expect(secEffort.totalMinutes, equals(40));
    expect(secEffort.percentage, equals(40.0));
  });

  testWidgets('AnalyticsSection renders weekly chart, consistency ratio, and category effort distribution', (WidgetTester tester) async {
    final now = DateTime.now();
    final analytics = AnalyticsData(
      weeklyFocusStats: [
        DailyFocusStat(date: now.subtract(const Duration(days: 6)), dayLabel: 'Mon', totalMinutes: 30, taskCount: 1),
        DailyFocusStat(date: now.subtract(const Duration(days: 5)), dayLabel: 'Tue', totalMinutes: 0, taskCount: 0),
        DailyFocusStat(date: now.subtract(const Duration(days: 4)), dayLabel: 'Wed', totalMinutes: 45, taskCount: 1),
        DailyFocusStat(date: now.subtract(const Duration(days: 3)), dayLabel: 'Thu', totalMinutes: 0, taskCount: 0),
        DailyFocusStat(date: now.subtract(const Duration(days: 2)), dayLabel: 'Fri', totalMinutes: 60, taskCount: 2),
        DailyFocusStat(date: now.subtract(const Duration(days: 1)), dayLabel: 'Sat', totalMinutes: 0, taskCount: 0),
        DailyFocusStat(date: now, dayLabel: 'Sun', totalMinutes: 90, taskCount: 2),
      ],
      categoryEfforts: [
        CategoryEffortStat(category: 'VLSI', totalMinutes: 120, taskCount: 3, percentage: 53.3),
        CategoryEffortStat(category: 'Cybersecurity', totalMinutes: 105, taskCount: 3, percentage: 46.7),
      ],
      activeDaysCount: 4,
      totalDaysCount: 7,
      totalWeeklyMinutes: 225,
      completedTasksCount: 6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsSection(analytics: analytics),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Analytics & Momentum'), findsOneWidget);
    expect(find.text('Weekly Focus Time'), findsOneWidget);
    expect(find.text('Consistency Ratio'), findsOneWidget);
    expect(find.text('Goal Effort Distribution'), findsOneWidget);
    expect(find.text('VLSI'), findsOneWidget);
    expect(find.text('Cybersecurity'), findsOneWidget);
    expect(find.text('4/7 days (57%)'), findsOneWidget);
  });

  test('Completing a task dynamically updates analytics in DashboardState', () async {
    final container = ProviderContainer();
    final dbHelper = DBHelper.instance;

    final goal = Goal(
      id: 'g_dyn_an',
      title: 'Real-Time Physics Engine',
      description: 'Verlet integration',
      category: 'GameDev',
      targetDate: DateTime.now().add(const Duration(days: 25)),
      priority: 4.5,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_dyn_an',
      goalId: 'g_dyn_an',
      title: 'Rigid Body Collision',
      targetDate: DateTime.now().add(const Duration(days: 10)),
    );
    await dbHelper.insertMilestone(ms);

    final task = Task(
      id: 't_dyn_an',
      milestoneId: 'ms_dyn_an',
      title: 'Broadphase GJK algorithm',
      estimatedMinutes: 50,
      isDone: false,
    );
    await dbHelper.insertTask(task);

    // Initial Dashboard Analytics has 0 completed minutes
    var dashState = await container.read(dashboardProvider.future);
    expect(dashState.analytics.totalWeeklyMinutes, equals(0));
    expect(dashState.analytics.completedTasksCount, equals(0));
    expect(dashState.analytics.categoryEfforts, isEmpty);

    // Toggle task to completed
    await container.read(dashboardProvider.notifier).toggleTask(task);

    // Dashboard Analytics automatically recalculated dynamically!
    dashState = await container.read(dashboardProvider.future);
    expect(dashState.analytics.totalWeeklyMinutes, equals(50));
    expect(dashState.analytics.completedTasksCount, equals(1));
    expect(dashState.analytics.activeDaysCount, equals(1));
    expect(dashState.analytics.categoryEfforts.length, equals(1));
    expect(dashState.analytics.categoryEfforts.first.category, equals('GameDev'));
    expect(dashState.analytics.categoryEfforts.first.totalMinutes, equals(50));
    expect(dashState.analytics.categoryEfforts.first.percentage, equals(100.0));

    container.dispose();
  });

  test('DBHelper Event CRUD and duration calculation test', () async {
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();

    final event1 = Event(
      id: 'ev_test_1',
      title: 'FPGA Architecture Lab',
      startTime: '09:00',
      endTime: '10:30',
      date: today,
      isFixed: true,
    );

    final event2 = Event(
      id: 'ev_test_2',
      title: 'Kernel Security Reading Group',
      startTime: '14:00',
      endTime: '15:30',
      date: today,
      isFixed: true,
    );

    // Verify duration calculation helper
    expect(event1.durationMinutes, equals(90));
    expect(event1.formattedDuration, equals('1h 30m'));
    expect(event2.durationMinutes, equals(90));

    // Insert
    await dbHelper.insertEvent(event1);
    await dbHelper.insertEvent(event2);

    // Retrieve by date
    final todayEvents = await dbHelper.getEventsForDate(today);
    expect(todayEvents.length, equals(2));
    expect(todayEvents.first.title, equals('FPGA Architecture Lab'));
    expect(todayEvents.last.title, equals('Kernel Security Reading Group'));

    // Retrieve by ID
    final retrieved = await dbHelper.getEventById('ev_test_1');
    expect(retrieved, isNotNull);
    expect(retrieved!.startTime, equals('09:00'));

    // Update
    final updated = retrieved.copyWith(title: 'FPGA Advanced Synthesis Lab');
    await dbHelper.updateEvent(updated);
    final afterUpdate = await dbHelper.getEventById('ev_test_1');
    expect(afterUpdate!.title, equals('FPGA Advanced Synthesis Lab'));

    // Delete
    await dbHelper.deleteEvent('ev_test_2');
    final afterDelete = await dbHelper.getEventsForDate(today);
    expect(afterDelete.length, equals(1));
    expect(afterDelete.first.id, equals('ev_test_1'));
  });

  test('CalendarProvider calculates blocked hours vs focus tasks vs remaining capacity', () async {
    final container = ProviderContainer();
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();

    // 1. Add fixed event: 09:00 to 11:30 (150 minutes = 2.5 hours)
    final event = Event(
      id: 'ev_cal_1',
      title: 'Digital IC Design Lecture',
      startTime: '09:00',
      endTime: '11:30',
      date: today,
      isFixed: true,
    );
    await dbHelper.insertEvent(event);

    // 2. Add goal, milestone, and scheduled focus task (60 minutes)
    final goal = Goal(
      id: 'g_cal_1',
      title: 'Build RISC-V SoC',
      description: 'System on Chip',
      category: 'VLSI',
      targetDate: today.add(const Duration(days: 30)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_cal_1',
      goalId: 'g_cal_1',
      title: 'Instruction Decoder Unit',
      targetDate: today.add(const Duration(days: 7)),
    );
    await dbHelper.insertMilestone(ms);

    final task = Task(
      id: 't_cal_1',
      milestoneId: 'ms_cal_1',
      title: 'Write decode logic for R-type opcodes',
      estimatedMinutes: 60,
      isDone: false,
      scheduledDate: today,
    );
    await dbHelper.insertTask(task);

    // Read Calendar state
    final calState = await container.read(calendarProvider.future);

    // Verify events and scheduled tasks
    expect(calState.events.length, equals(1));
    expect(calState.scheduledTasks.length, equals(1));

    // Verify upgraded 24h capacity math:
    // Total Day = 1440m (24.0h)
    // Sleep Duration = 360m (6.0h, 22:00 -> 04:00)
    // Total Waking Capacity = 1440 - 360 = 1080m (18.0h)
    // Fixed Event minutes = 150m (2h 30m)
    // Focus Capacity = 1080 - 150 = 930m (15h 30m)
    // Scheduled task focus minutes = 60m (1h 00m)
    // Remaining Capacity = 930 - 60 = 870m (14h 30m)
    // Free Buffer = 870m
    expect(calState.sleepDurationMinutes, equals(360));
    expect(calState.totalWakingCapacityMinutes, equals(1080));
    expect(calState.fixedEventMinutes, equals(150));
    expect(calState.focusCapacityMinutes, equals(930));
    expect(calState.totalScheduledTaskMinutes, equals(60));
    expect(calState.remainingCapacityMinutes, equals(870));
    expect(calState.freeBufferMinutes, equals(870));
    expect(calState.isOvercommitted, isFalse);
    expect(calState.formatMinutes(calState.fixedEventMinutes), equals('2h 30m'));
    expect(calState.formatMinutes(calState.remainingCapacityMinutes), equals('14h 30m'));

    // Toggle task in calendarProvider
    await container.read(calendarProvider.notifier).toggleTask(task);
    final calAfterToggle = await container.read(calendarProvider.future);
    expect(calAfterToggle.scheduledTasks.first.task.isDone, isTrue);
    expect(calAfterToggle.completedTaskMinutes, equals(60));

    // Test Overcommitment detection:
    // Insert a massive task that exceeds remaining focus capacity
    final heavyTask = Task(
      id: 't_heavy_cal',
      milestoneId: 'ms_cal_1',
      title: 'Full FPGA formal verification and gate level simulation',
      estimatedMinutes: 1000,
      isDone: false,
      scheduledDate: today,
    );
    await dbHelper.insertTask(heavyTask);
    await container.read(calendarProvider.notifier).refresh();
    final calOvercommitted = await container.read(calendarProvider.future);

    // Total Scheduled Task minutes = 60 + 1000 = 1060m
    // Focus Capacity = 930m
    // Remaining Capacity = 930 - 1060 = -130m
    // Overcommitted deficit = 130m
    expect(calOvercommitted.totalScheduledTaskMinutes, equals(1060));
    expect(calOvercommitted.remainingCapacityMinutes, equals(-130));
    expect(calOvercommitted.isOvercommitted, isTrue);
    expect(calOvercommitted.overcommittedDeficitMinutes, equals(130));
    expect(calOvercommitted.freeBufferMinutes, equals(0));

    container.dispose();
  });

  test('CalendarState merges overlapping event intervals accurately', () {
    final today = DateTime.now();

    final ev1 = Event(
      id: 'ev_merge_1',
      title: 'Meeting Part 1',
      startTime: '09:00',
      endTime: '10:30', // 90 min (09:00 - 10:30)
      date: today,
    );
    final ev2 = Event(
      id: 'ev_merge_2',
      title: 'Meeting Part 2 (Overlapping)',
      startTime: '10:00',
      endTime: '11:30', // Overlaps 10:00 - 10:30, extends to 11:30 (total 09:00 - 11:30 = 150m)
      date: today,
    );
    final ev3 = Event(
      id: 'ev_merge_3',
      title: 'Afternoon Sync',
      startTime: '14:00',
      endTime: '15:00', // 60 min (14:00 - 15:00)
      date: today,
    );

    final totalMinutes =
        CalendarState.calculateNonOverlappingEventMinutes([ev1, ev2, ev3]);
    // 150m (merged 09:00-11:30) + 60m (14:00-15:00) = 210m (3.5h)
    expect(totalMinutes, equals(210));
  });

  testWidgets('CalendarScreen renders standalone smoke test with 24h capacity bar and sleep routine', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify CalendarScreen header & widgets
    expect(find.text('Daily Calendar & Timeline'), findsOneWidget);
    expect(find.text('Capacity Planner'), findsOneWidget);
    expect(find.text('24-Hour Day Allocation'), findsOneWidget);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Tasks'), findsWidgets);
  });

  test('DBHelper queries tasks by scheduledDate and falls back to Milestone.targetDate', () async {
    final dbHelper = DBHelper.instance;
    final targetDate = DateTime(2026, 8, 12);

    final goal = Goal(
      id: 'g_sync_1',
      title: 'Digital Signal Processing FPGA',
      description: 'DSP pipeline',
      category: 'VLSI',
      targetDate: targetDate.add(const Duration(days: 30)),
      priority: 4.5,
    );
    await dbHelper.insertGoal(goal);

    final ms1 = Milestone(
      id: 'ms_sync_1',
      goalId: 'g_sync_1',
      title: 'FIR Filter Core',
      targetDate: targetDate, // Aug 12
    );
    await dbHelper.insertMilestone(ms1);

    // Task 1: Explicitly scheduled on Aug 12
    final t1 = Task(
      id: 't_sync_1',
      milestoneId: 'ms_sync_1',
      title: 'Implement tap multiplier array',
      estimatedMinutes: 45,
      isDone: false,
      scheduledDate: targetDate,
    );
    await dbHelper.insertTask(t1);

    // Task 2: No scheduledDate set (empty), falls back to Milestone targetDate (Aug 12)
    final t2 = Task(
      id: 't_sync_2',
      milestoneId: 'ms_sync_1',
      title: 'Generate filter coefficient ROM',
      estimatedMinutes: 30,
      isDone: false,
      scheduledDate: null,
    );
    await dbHelper.insertTask(t2);

    // Task 3: Scheduled on a different day (Aug 20)
    final t3 = Task(
      id: 't_sync_3',
      milestoneId: 'ms_sync_1',
      title: 'Post-synthesis timing simulation',
      estimatedMinutes: 90,
      isDone: false,
      scheduledDate: DateTime(2026, 8, 20),
    );
    await dbHelper.insertTask(t3);

    final aug12Tasks = await dbHelper.getScheduledTasksForDate(targetDate);
    expect(aug12Tasks.length, equals(2));
    expect(aug12Tasks.map((t) => t.task.id), containsAll(['t_sync_1', 't_sync_2']));
    expect(aug12Tasks.map((t) => t.task.id), isNot(contains('t_sync_3')));

    // Aggregate estimatedMinutes
    final totalMins = aug12Tasks.fold<int>(0, (sum, t) => sum + t.task.estimatedMinutes);
    expect(totalMins, equals(75)); // 45 + 30
  });

  test('Recurring fixed events query matches day of week alongside single-instance events', () async {
    final dbHelper = DBHelper.instance;
    final monday = DateTime(2026, 8, 10); // Monday
    final tuesday = DateTime(2026, 8, 11); // Tuesday
    final wednesday = DateTime(2026, 8, 12); // Wednesday

    // Single-instance event on Monday only
    final singleEvent = Event(
      id: 'ev_single_1',
      title: 'One-off Architecture Review',
      startTime: '10:00',
      endTime: '11:00',
      date: monday,
      isFixed: true,
      isRecurring: false,
    );
    await dbHelper.insertEvent(singleEvent);

    // Recurring weekday standup (Mon,Tue,Wed,Thu,Fri)
    final recurringStandup = Event(
      id: 'ev_rec_standup',
      title: 'Daily Team Standup',
      startTime: '09:00',
      endTime: '09:30',
      date: monday,
      isFixed: true,
      isRecurring: true,
      recurringDays: 'Mon,Tue,Wed,Thu,Fri',
    );
    await dbHelper.insertEvent(recurringStandup);

    // Recurring MWF Lab (Mon,Wed,Fri)
    final mwfLab = Event(
      id: 'ev_rec_lab',
      title: 'Advanced VLSI Lab Session',
      startTime: '14:00',
      endTime: '16:00',
      date: monday,
      isFixed: true,
      isRecurring: true,
      recurringDays: 'Mon,Wed,Fri',
    );
    await dbHelper.insertEvent(mwfLab);

    // Check Monday: should have singleEvent + standup + mwfLab (3 events)
    final monEvents = await dbHelper.getEventsForDate(monday);
    expect(monEvents.length, equals(3));
    expect(monEvents.map((e) => e.id), containsAll(['ev_single_1', 'ev_rec_standup', 'ev_rec_lab']));

    // Check Tuesday: should only have standup (1 event)
    final tueEvents = await dbHelper.getEventsForDate(tuesday);
    expect(tueEvents.length, equals(1));
    expect(tueEvents.first.id, equals('ev_rec_standup'));

    // Check Wednesday: should have standup + mwfLab (2 events)
    final wedEvents = await dbHelper.getEventsForDate(wednesday);
    expect(wedEvents.length, equals(2));
    expect(wedEvents.map((e) => e.id), containsAll(['ev_rec_standup', 'ev_rec_lab']));
  });

  test('Adding task in GoalDetailNotifier automatically refreshes CalendarProvider', () async {
    final container = ProviderContainer();
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();

    final goal = Goal(
      id: 'g_reactive_1',
      title: 'Embedded Linux Kernel Port',
      description: 'Kernel bringup',
      category: 'Firmware',
      targetDate: today.add(const Duration(days: 60)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_reactive_1',
      goalId: 'g_reactive_1',
      title: 'Bootloader Setup',
      targetDate: today,
    );
    await dbHelper.insertMilestone(ms);

    // Initial calendar state
    final initialCal = await container.read(calendarProvider.future);
    expect(initialCal.scheduledTasks.length, equals(0));

    // Add task via GoalDetailNotifier
    await container
        .read(goalDetailProvider('g_reactive_1').notifier)
        .addTask(
          milestoneId: 'ms_reactive_1',
          title: 'Configure U-Boot device tree',
          estimatedMinutes: 50,
          scheduledDate: today,
        );

    // Read CalendarProvider state again (should auto-update!)
    final updatedCal = await container.read(calendarProvider.future);
    expect(updatedCal.scheduledTasks.length, equals(1));
    expect(updatedCal.scheduledTasks.first.task.title, equals('Configure U-Boot device tree'));
    expect(updatedCal.totalScheduledTaskMinutes, equals(50));

    container.dispose();
  });

  test('BackupService.exportToJson exports all goals, milestones, tasks, and events to valid JSON', () async {
    final dbHelper = DBHelper.instance;
    final now = DateTime.now();

    final goal = Goal(
      id: 'g_backup_1',
      title: 'Aerospace Guidance System',
      description: 'Kalman filtering',
      category: 'Robotics',
      targetDate: now.add(const Duration(days: 90)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_backup_1',
      goalId: 'g_backup_1',
      title: 'State Estimation Filter',
      targetDate: now,
    );
    await dbHelper.insertMilestone(ms);

    final task = Task(
      id: 't_backup_1',
      milestoneId: 'ms_backup_1',
      title: 'Tuning Q and R covariance matrices',
      estimatedMinutes: 60,
      isDone: true,
      completedAt: now,
    );
    await dbHelper.insertTask(task);

    final event = Event(
      id: 'ev_backup_1',
      title: 'Simulation Telemetry Review',
      startTime: '11:00',
      endTime: '12:00',
      date: now,
      isFixed: true,
      isRecurring: true,
      recurringDays: 'Mon,Wed,Fri',
    );
    await dbHelper.insertEvent(event);

    final jsonString = await BackupService.instance.exportToJson();
    expect(jsonString, isNotEmpty);

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    expect(decoded['app'], equals('Project Ascend LifeOS'));
    expect(decoded['version'], equals(1));
    expect(decoded['summary']['goalsCount'], equals(1));
    expect(decoded['summary']['milestonesCount'], equals(1));
    expect(decoded['summary']['tasksCount'], equals(1));
    expect(decoded['summary']['eventsCount'], equals(1));

    final data = decoded['data'] as Map<String, dynamic>;
    expect((data['goals'] as List).length, equals(1));
    expect((data['milestones'] as List).length, equals(1));
    expect((data['tasks'] as List).length, equals(1));
    expect((data['events'] as List).length, equals(1));
  });

  test('BackupService.importFromJson safely resets database and restores all records', () async {
    final now = DateTime.now();

    final testBackup = {
      'app': 'Project Ascend LifeOS',
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'data': {
        'goals': [
          {
            'id': 'g_restored_1',
            'title': 'Quantum Computing Simulator',
            'description': 'Qiskit algorithms',
            'category': 'Quantum',
            'targetDate': now.add(const Duration(days: 120)).toIso8601String(),
            'priority': 4.8,
            'createdAt': now.toIso8601String(),
          }
        ],
        'milestones': [
          {
            'id': 'ms_restored_1',
            'goalId': 'g_restored_1',
            'title': 'Grover Algorithm Implementation',
            'targetDate': now.toIso8601String(),
            'isCompleted': 0,
          }
        ],
        'tasks': [
          {
            'id': 't_restored_1',
            'milestoneId': 'ms_restored_1',
            'title': 'Construct Oracle circuit matrix',
            'estimatedMinutes': 75,
            'isDone': 0,
            'scheduledDate': now.toIso8601String(),
            'completedAt': null,
          }
        ],
        'events': [
          {
            'id': 'ev_restored_1',
            'title': 'Quantum Lab Discussion',
            'startTime': '15:00',
            'endTime': '16:00',
            'date': now.toIso8601String(),
            'isFixed': 1,
            'isRecurring': 0,
            'recurringDays': '',
          }
        ],
      }
    };

    final jsonString = jsonEncode(testBackup);
    final result = await BackupService.instance.importFromJson(jsonString);

    expect(result.success, isTrue);
    expect(result.goalsCount, equals(1));
    expect(result.milestonesCount, equals(1));
    expect(result.tasksCount, equals(1));
    expect(result.eventsCount, equals(1));

    // Verify database contents
    final dbHelper = DBHelper.instance;
    final goals = await dbHelper.getAllGoals();
    expect(goals.length, equals(1));
    expect(goals.first.title, equals('Quantum Computing Simulator'));

    final milestones = await dbHelper.getMilestonesByGoalId('g_restored_1');
    expect(milestones.length, equals(1));
    expect(milestones.first.title, equals('Grover Algorithm Implementation'));

    final events = await dbHelper.getEventsForDate(now);
    expect(events.length, equals(1));
    expect(events.first.title, equals('Quantum Lab Discussion'));
  });

  test('BackupService.importFromJson gracefully handles corrupt JSON without crashing', () async {
    final result = await BackupService.instance.importFromJson('Not a valid JSON string');
    expect(result.success, isFalse);
    expect(result.errorMessage, isNotNull);
  });

  testWidgets('DashboardScreen renders Data Management & Offline Backup section', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Data Management & Offline Backup'), findsOneWidget);
    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('Import Data'), findsOneWidget);
    expect(find.byTooltip('Data Management & Backup'), findsOneWidget);
  });

  test('Missed Task Detection flags overdue tasks and isolates them from Today Focus', () async {
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final goal = Goal(
      id: 'g_missed_1',
      title: 'Aerodynamics Simulation',
      description: 'CFD solvers',
      category: 'Physics',
      targetDate: today.add(const Duration(days: 30)),
      priority: 4.5,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_missed_1',
      goalId: 'g_missed_1',
      title: 'Navier Stokes Core',
      targetDate: today,
    );
    await dbHelper.insertMilestone(ms);

    // Overdue incomplete task (yesterday)
    final overdueTask = Task(
      id: 't_overdue_1',
      milestoneId: 'ms_missed_1',
      title: 'Mesh boundary convergence test',
      estimatedMinutes: 45,
      isDone: false,
      scheduledDate: yesterday,
    );
    await dbHelper.insertTask(overdueTask);

    // Today's pending task
    final todayTask = Task(
      id: 't_today_1',
      milestoneId: 'ms_missed_1',
      title: 'Run turbulence model benchmarks',
      estimatedMinutes: 60,
      isDone: false,
      scheduledDate: today,
    );
    await dbHelper.insertTask(todayTask);

    // Completed past task
    final completedPastTask = Task(
      id: 't_done_past',
      milestoneId: 'ms_missed_1',
      title: 'Initial grid setup',
      estimatedMinutes: 30,
      isDone: true,
      scheduledDate: yesterday,
      completedAt: yesterday,
    );
    await dbHelper.insertTask(completedPastTask);

    // Run missed task check
    final markedCount = await dbHelper.checkAndMarkMissedTasks(today);
    expect(markedCount, equals(1));

    // Verify missed tasks list contains overdue task only
    final missedTasks = await dbHelper.getMissedTasks();
    expect(missedTasks.length, equals(1));
    expect(missedTasks.first.task.id, equals('t_overdue_1'));
    expect(missedTasks.first.task.isMissed, isTrue);

    // Verify Today's Focus does NOT contain the missed task
    final todayTasks = await dbHelper.getPendingTasksForToday();
    expect(todayTasks.length, equals(1));
    expect(todayTasks.first.task.id, equals('t_today_1'));

    // Test Rescheduling to Today
    await dbHelper.rescheduleTask('t_overdue_1', today);
    final missedAfterReschedule = await dbHelper.getMissedTasks();
    expect(missedAfterReschedule.length, equals(0));

    final todayTasksAfterReschedule = await dbHelper.getPendingTasksForToday();
    expect(todayTasksAfterReschedule.length, equals(2));
    expect(todayTasksAfterReschedule.map((t) => t.task.id), containsAll(['t_overdue_1', 't_today_1']));
  });

  test('Strict Pause Mode suspends missed task detection and auto-resumes after endDate', () async {
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final goal = Goal(
      id: 'g_pause_1',
      title: 'Compiler Optimization Framework',
      description: 'LLVM passes',
      category: 'Compilers',
      targetDate: today.add(const Duration(days: 45)),
      priority: 5.0,
    );
    await dbHelper.insertGoal(goal);

    final ms = Milestone(
      id: 'ms_pause_1',
      goalId: 'g_pause_1',
      title: 'Loop Unrolling Pass',
      targetDate: today,
    );
    await dbHelper.insertMilestone(ms);

    final pastTask = Task(
      id: 't_past_exam',
      milestoneId: 'ms_pause_1',
      title: 'Vectorization cost analysis',
      estimatedMinutes: 50,
      isDone: false,
      scheduledDate: yesterday,
    );
    await dbHelper.insertTask(pastTask);

    // Activate Exam Pause Mode for 7 days
    final examMode = PauseMode(
      id: 'pause_exam_1',
      title: 'University Final Exams',
      startDate: today,
      endDate: today.add(const Duration(days: 7)),
      activeRoutineTitle: 'Exam Revision & Rest',
      isActive: true,
    );
    await dbHelper.insertPauseMode(examMode);

    // Verify Pause Mode is active
    expect(await dbHelper.isPauseModeActive(today), isTrue);
    final active = await dbHelper.getActivePauseMode(today);
    expect(active, isNotNull);
    expect(active!.title, equals('University Final Exams'));
    expect(active.remainingDays(today), equals(7));

    // Run missed task check while in Pause Mode -> should return 0 (suspended!)
    final markedDuringPause = await dbHelper.checkAndMarkMissedTasks(today);
    expect(markedDuringPause, equals(0));
    final missedDuringPause = await dbHelper.getMissedTasks();
    expect(missedDuringPause.length, equals(0));

    // Test automatic resumption after endDate
    final futureDateAfterPause = today.add(const Duration(days: 8));
    expect(await dbHelper.isPauseModeActive(futureDateAfterPause), isFalse);
    expect(active.hasExpired(futureDateAfterPause), isTrue);

    // Deactivate Pause Mode manually
    await dbHelper.deactivatePauseMode('pause_exam_1');
    expect(await dbHelper.isPauseModeActive(today), isFalse);

    // Missed task check now flags past task
    final markedAfterDeactivate = await dbHelper.checkAndMarkMissedTasks(today);
    expect(markedAfterDeactivate, equals(1));
    final missedAfterDeactivate = await dbHelper.getMissedTasks();
    expect(missedAfterDeactivate.length, equals(1));
    expect(missedAfterDeactivate.first.task.id, equals('t_past_exam'));
  });

  testWidgets('DashboardScreen renders Active Pause Mode banner when PauseMode is active', (WidgetTester tester) async {
    final dbHelper = DBHelper.instance;
    final today = DateTime.now();

    final examMode = PauseMode(
      id: 'pause_ui_test',
      title: 'Final Exams Sprint',
      startDate: today,
      endDate: today.add(const Duration(days: 5)),
      activeRoutineTitle: 'Focused Revision',
      isActive: true,
    );
    await dbHelper.insertPauseMode(examMode);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('STRICT PAUSE MODE ACTIVE'), findsOneWidget);
    expect(find.text('Final Exams Sprint'), findsOneWidget);
    expect(find.text('Resume Now'), findsOneWidget);
    expect(find.byTooltip('Active Pause Mode (Exam / Holiday)'), findsOneWidget);
  });
}

