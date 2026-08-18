import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/database/db_helper.dart';
import 'package:app/core/services/analytics_service.dart';
import 'package:app/models/goal.dart';
import 'package:app/models/milestone.dart';
import 'package:app/models/task.dart';

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

  test('AnalyticsService Weak Point Identification - Rule 1 (Zero Activity)', () async {
    final now = DateTime.now();

    // Create a Goal
    final goal = Goal(
      id: 'g1',
      title: 'Learn Flutter',
      description: 'Master Dart and Flutter',
      category: 'MobileDev',
      targetDate: now.add(const Duration(days: 30)),
    );
    await DBHelper.instance.insertGoal(goal);

    // Create a Milestone
    final milestone = Milestone(
      id: 'm1',
      goalId: 'g1',
      title: 'Milestone 1',
      targetDate: now.add(const Duration(days: 30)),
    );
    await DBHelper.instance.insertMilestone(milestone);

    // Create a Task (incomplete)
    final task = Task(
      id: 't1',
      milestoneId: 'm1',
      title: 'Read Dart docs',
      estimatedMinutes: 30,
      isDone: false,
    );
    await DBHelper.instance.insertTask(task);

    // Get insights
    final insights = await AnalyticsService.instance.getSystemInsights(now);

    // Verify Rule 1 flags it (0 completed tasks in past 14 days)
    expect(insights.weakPoints.length, 1);
    expect(insights.weakPoints.first.goal.id, 'g1');
    expect(insights.weakPoints.first.reason, contains('0 completed tasks'));
  });

  test('AnalyticsService Weak Point Identification - Rule 2 (Low Focus <10%)', () async {
    final now = DateTime.now();

    // Goal 1: High focus (MobileDev)
    final goal1 = Goal(
      id: 'g1',
      title: 'Learn Flutter',
      description: 'Master Dart and Flutter',
      category: 'MobileDev',
      targetDate: now.add(const Duration(days: 30)),
    );
    await DBHelper.instance.insertGoal(goal1);

    final m1 = Milestone(id: 'm1', goalId: 'g1', title: 'Milestone 1', targetDate: now.add(const Duration(days: 30)));
    await DBHelper.instance.insertMilestone(m1);

    // Goal 2: Low focus (Cybersecurity)
    final goal2 = Goal(
      id: 'g2',
      title: 'Ethical Hacking',
      description: 'Learn Kali Linux',
      category: 'Cyber',
      targetDate: now.add(const Duration(days: 30)),
    );
    await DBHelper.instance.insertGoal(goal2);

    final m2 = Milestone(id: 'm2', goalId: 'g2', title: 'Milestone 2', targetDate: now.add(const Duration(days: 30)));
    await DBHelper.instance.insertMilestone(m2);

    // Log 90 mins for Goal 1 (completed 3 tasks)
    for (int i = 0; i < 3; i++) {
      final t = Task(
        id: 't_g1_$i',
        milestoneId: 'm1',
        title: 'Task $i',
        estimatedMinutes: 30,
        isDone: true,
        completedAt: now.subtract(const Duration(days: 1)),
      );
      await DBHelper.instance.insertTask(t);
    }

    // Log 8 mins for Goal 2 (completed 1 task, total 8 mins, which is 8/98 = 8.1% focus time, under 10%)
    final t2 = Task(
      id: 't_g2',
      milestoneId: 'm2',
      title: 'Hack a server',
      estimatedMinutes: 8,
      isDone: true,
      completedAt: now.subtract(const Duration(days: 1)),
    );
    await DBHelper.instance.insertTask(t2);

    final t2Incomplete = Task(
      id: 't_g2_inc',
      milestoneId: 'm2',
      title: 'Study encryption algorithms',
      estimatedMinutes: 30,
      isDone: false,
    );
    await DBHelper.instance.insertTask(t2Incomplete);

    // Get insights
    final insights = await AnalyticsService.instance.getSystemInsights(now);

    // Verify Rule 2 flags goal2
    final weakGoal2 = insights.weakPoints.firstWhere((wp) => wp.goal.id == 'g2');
    expect(weakGoal2.reason, contains('Low focus'));
  });

  test('AnalyticsService Weak Point Identification - Rule 3 (Approaching Deadline & Under-Executed)', () async {
    final now = DateTime.now();

    // Goal approaching in 5 days with 0% progress
    final goal = Goal(
      id: 'g1',
      title: 'Approaching Deadline Goal',
      description: 'Must do soon',
      category: 'VLSI',
      targetDate: now.add(const Duration(days: 5)),
    );
    await DBHelper.instance.insertGoal(goal);

    final milestone = Milestone(
      id: 'm1',
      goalId: 'g1',
      title: 'M1',
      targetDate: now.add(const Duration(days: 5)),
    );
    await DBHelper.instance.insertMilestone(milestone);

    final task = Task(
      id: 't1',
      milestoneId: 'm1',
      title: 'T1',
      estimatedMinutes: 30,
      isDone: false,
    );
    await DBHelper.instance.insertTask(task);

    // Get insights
    final insights = await AnalyticsService.instance.getSystemInsights(now);

    // Rule 3 flags approaching target date
    final wp = insights.weakPoints.firstWhere((w) => w.goal.id == 'g1');
    expect(wp.isCriticallyOverdue, true);
    expect(wp.reason, contains('Target date is approaching'));
  });
}
