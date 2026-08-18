import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/goal.dart';
import '../../models/milestone.dart';
import '../../models/task.dart';
import '../../models/dashboard_task_item.dart';
import '../../models/analytics_data.dart';
import '../../models/event.dart';
import '../../models/pause_mode.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  // Table Names
  static const String tableGoals = 'goals';
  static const String tableMilestones = 'milestones';
  static const String tableTasks = 'tasks';
  static const String tableEvents = 'events';
  static const String tablePauseModes = 'pause_modes';
  static const String tableCategories = 'categories';

  // Database Info
  static String databaseName = 'ascend_lifeos.db';
  static const int _databaseVersion = 7;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (filePath == inMemoryDatabasePath) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: _databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableTasks ADD COLUMN completedAt TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableEvents (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          date TEXT NOT NULL,
          isFixed INTEGER NOT NULL DEFAULT 1,
          isRecurring INTEGER NOT NULL DEFAULT 0,
          recurringDays TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE $tableEvents ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE $tableEvents ADD COLUMN recurringDays TEXT NOT NULL DEFAULT \'\'');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE $tableTasks ADD COLUMN isMissed INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tablePauseModes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          activeRoutineTitle TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCategories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      final defaults = ['Career', 'Health', 'Skill Development', 'Personal'];
      for (final name in defaults) {
        await db.insert(
          tableCategories,
          {
            'id': name.toLowerCase().replaceAll(' ', '_'),
            'name': name,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      try {
        final List<Map<String, dynamic>> existingGoals = await db.query(tableGoals);
        for (final row in existingGoals) {
          final cat = row['category'] as String?;
          if (cat != null && cat.trim().isNotEmpty) {
            final trimmed = cat.trim();
            await db.insert(
              tableCategories,
              {
                'id': trimmed.toLowerCase().replaceAll(' ', '_'),
                'name': trimmed,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      try {
        await db.execute('ALTER TABLE $tableTasks ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableTasks ADD COLUMN recurringDays TEXT NOT NULL DEFAULT \'\'');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_completions (
          id TEXT PRIMARY KEY,
          task_id TEXT,
          completed_date TEXT,
          focus_minutes INTEGER
        )
      ''');

      // Migrate existing completed tasks
      try {
        final List<Map<String, dynamic>> existingCompleted = await db.query(
          tableTasks,
          where: 'isDone = 1',
        );
        for (final row in existingCompleted) {
          final taskId = row['id'] as String;
          final completedAt = row['completedAt'] as String? ?? row['scheduledDate'] as String? ?? DateTime.now().toIso8601String();
          final dateStr = completedAt.substring(0, 10);
          final estMins = row['estimatedMinutes'] as int? ?? 30;
          
          await db.insert(
            'task_completions',
            {
              'id': 'tc_mig_${taskId}_${DateTime.now().millisecondsSinceEpoch}',
              'task_id': taskId,
              'completed_date': dateStr,
              'focus_minutes': estMins,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Categories Table
    await db.execute('''
      CREATE TABLE $tableCategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    final defaults = ['Career', 'Health', 'Skill Development', 'Personal'];
    for (final name in defaults) {
      await db.insert(
        tableCategories,
        {
          'id': name.toLowerCase().replaceAll(' ', '_'),
          'name': name,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Create Goals Table
    await db.execute('''
      CREATE TABLE $tableGoals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        targetDate TEXT NOT NULL,
        priority REAL NOT NULL
      )
    ''');

    // Create Milestones Table
    await db.execute('''
      CREATE TABLE $tableMilestones (
        id TEXT PRIMARY KEY,
        goalId TEXT NOT NULL,
        title TEXT NOT NULL,
        targetDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (goalId) REFERENCES $tableGoals (id) ON DELETE CASCADE
      )
    ''');

    // Create Tasks Table
    await db.execute('''
      CREATE TABLE $tableTasks (
        id TEXT PRIMARY KEY,
        milestoneId TEXT NOT NULL,
        title TEXT NOT NULL,
        estimatedMinutes INTEGER NOT NULL DEFAULT 30,
        isDone INTEGER NOT NULL DEFAULT 0,
        isMissed INTEGER NOT NULL DEFAULT 0,
        scheduledDate TEXT,
        completedAt TEXT,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurringDays TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (milestoneId) REFERENCES $tableMilestones (id) ON DELETE CASCADE
      )
    ''');

    // Create Events Table
    await db.execute('''
      CREATE TABLE $tableEvents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        date TEXT NOT NULL,
        isFixed INTEGER NOT NULL DEFAULT 1,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurringDays TEXT NOT NULL DEFAULT ''
      )
    ''');

    // Create Pause Modes Table
    await db.execute('''
      CREATE TABLE $tablePauseModes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        activeRoutineTitle TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Create Task Completions Table
    await db.execute('''
      CREATE TABLE task_completions (
        id TEXT PRIMARY KEY,
        task_id TEXT,
        completed_date TEXT,
        focus_minutes INTEGER
      )
    ''');
  }

  // ==========================================
  // GOAL CRUD OPERATIONS
  // ==========================================

  Future<int> insertGoal(Goal goal) async {
    final db = await instance.database;
    return await db.insert(
      tableGoals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Goal>> getAllGoals() async {
    final db = await instance.database;
    final result = await db.query(
      tableGoals,
      orderBy: 'priority DESC, targetDate ASC',
    );
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  Future<Goal?> getGoalById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableGoals,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Goal.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Goal>> getGoalsByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      tableGoals,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'priority DESC, targetDate ASC',
    );
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await instance.database;
    return await db.update(
      tableGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(String id) async {
    final db = await instance.database;
    return await db.delete(
      tableGoals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // MILESTONE CRUD OPERATIONS
  // ==========================================

  Future<int> insertMilestone(Milestone milestone) async {
    final db = await instance.database;
    return await db.insert(
      tableMilestones,
      milestone.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Milestone>> getAllMilestones() async {
    final db = await instance.database;
    final result = await db.query(
      tableMilestones,
      orderBy: 'targetDate ASC',
    );
    return result.map((json) => Milestone.fromMap(json)).toList();
  }

  Future<List<Milestone>> getMilestonesByGoalId(String goalId) async {
    final db = await instance.database;
    final result = await db.query(
      tableMilestones,
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'targetDate ASC',
    );
    return result.map((json) => Milestone.fromMap(json)).toList();
  }

  Future<Milestone?> getMilestoneById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableMilestones,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Milestone.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateMilestone(Milestone milestone) async {
    final db = await instance.database;
    return await db.update(
      tableMilestones,
      milestone.toMap(),
      where: 'id = ?',
      whereArgs: [milestone.id],
    );
  }

  Future<int> deleteMilestone(String id) async {
    final db = await instance.database;
    return await db.delete(
      tableMilestones,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // TASK CRUD OPERATIONS
  // ==========================================

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    return await db.insert(
      tableTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query(
      tableTasks,
      orderBy: 'isDone ASC, scheduledDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksByMilestoneId(String milestoneId) async {
    final db = await instance.database;
    final result = await db.query(
      tableTasks,
      where: 'milestoneId = ?',
      whereArgs: [milestoneId],
      orderBy: 'isDone ASC, scheduledDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Task?> getTaskById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableTasks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    final int rows = await db.update(
      tableTasks,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    if (rows > 0) {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (task.isDone) {
        final List<Map<String, dynamic>> existing = await db.query(
          'task_completions',
          where: 'task_id = ? AND completed_date = ?',
          whereArgs: [task.id, todayStr],
        );
        if (existing.isEmpty) {
          await db.insert('task_completions', {
            'id': 'tc_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
            'task_id': task.id,
            'completed_date': todayStr,
            'focus_minutes': task.estimatedMinutes,
          });
        }
      } else {
        await db.delete(
          'task_completions',
          where: 'task_id = ? AND completed_date = ?',
          whereArgs: [task.id, todayStr],
        );
      }
    }
    return rows;
  }

  Future<List<Task>> getIncompleteTasks() async {
    final db = await instance.database;
    final result = await db.query(
      tableTasks,
      where: 'isDone = 0',
      orderBy: 'scheduledDate ASC, title ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<DashboardTaskItem>> getIncompleteDashboardTasks() async {
    return getPendingTasksForToday();
  }

  /// Queries all pending tasks where isDone = 0 joined with parent Milestone and Goal titles
  Future<List<DashboardTaskItem>> getPendingTasksForToday([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayLabel = dayLabels[now.weekday - 1];

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        t.id,
        t.milestoneId,
        t.title,
        t.estimatedMinutes,
        t.isDone,
        t.isMissed,
        t.scheduledDate,
        t.isRecurring,
        t.recurringDays,
        m.title AS milestoneTitle,
        g.id AS goalId,
        g.title AS goalTitle,
        g.category AS goalCategory,
        g.priority AS goalPriority
      FROM $tableTasks t
      INNER JOIN $tableMilestones m ON t.milestoneId = m.id
      INNER JOIN $tableGoals g ON m.goalId = g.id
      WHERE t.isDone = 0 AND (t.isMissed IS NULL OR t.isMissed = 0)
      ORDER BY 
        CASE WHEN t.scheduledDate IS NULL THEN 1 ELSE 0 END,
        t.scheduledDate ASC,
        g.priority DESC,
        t.title ASC
    ''');

    final list = result.map((row) => DashboardTaskItem.fromMap(row)).toList();
    return list.where((item) {
      if (item.task.isRecurring) {
        if (item.task.recurringDays.isEmpty) return true;
        final days = item.task.recurringDays.split(',').map((s) => s.trim());
        return days.contains(todayLabel);
      }
      return true;
    }).toList();
  }

  // ==========================================
  // MISSED TASK DETECTION & RECOVERY
  // ==========================================

  /// Checks for any incomplete task whose scheduledDate < today and marks it as missed.
  /// Automatically disabled if the system is in an active PauseMode.
  Future<int> checkAndMarkMissedTasks([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();

    // If Strict Pause or Exam Mode is active, skip marking missed tasks
    if (await isPauseModeActive(now)) {
      return 0;
    }

    final db = await instance.database;
    final todayPrefix =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final count = await db.rawUpdate('''
      UPDATE $tableTasks
      SET isMissed = 1
      WHERE isDone = 0
        AND (isMissed IS NULL OR isMissed = 0)
        AND (isRecurring IS NULL OR isRecurring = 0)
        AND scheduledDate IS NOT NULL
        AND TRIM(scheduledDate) != ''
        AND substr(scheduledDate, 1, 10) < ?
    ''', [todayPrefix]);

    return count;
  }

  /// Retrieves all incomplete tasks flagged as missed
  Future<List<DashboardTaskItem>> getMissedTasks() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        t.id,
        t.milestoneId,
        t.title,
        t.estimatedMinutes,
        t.isDone,
        t.isMissed,
        t.scheduledDate,
        m.title AS milestoneTitle,
        g.id AS goalId,
        g.title AS goalTitle,
        g.category AS goalCategory,
        g.priority AS goalPriority
      FROM $tableTasks t
      INNER JOIN $tableMilestones m ON t.milestoneId = m.id
      INNER JOIN $tableGoals g ON m.goalId = g.id
      WHERE t.isDone = 0 AND t.isMissed = 1
      ORDER BY t.scheduledDate DESC, g.priority DESC, t.title ASC
    ''');

    return result.map((row) => DashboardTaskItem.fromMap(row)).toList();
  }

  /// Reschedules a missed or scheduled task to a new date and clears its missed status
  Future<int> rescheduleTask(String taskId, DateTime newDate) async {
    final db = await instance.database;
    return await db.update(
      tableTasks,
      {
        'scheduledDate': newDate.toIso8601String(),
        'isMissed': 0,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<DashboardTaskItem>> getCompletedTasks() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        t.id,
        t.milestoneId,
        t.title,
        tc.focus_minutes AS estimatedMinutes,
        1 AS isDone,
        t.scheduledDate,
        tc.completed_date AS completedAt,
        m.title AS milestoneTitle,
        g.id AS goalId,
        g.title AS goalTitle,
        g.category AS goalCategory,
        g.priority AS goalPriority
      FROM task_completions tc
      INNER JOIN $tableTasks t ON tc.task_id = t.id
      INNER JOIN $tableMilestones m ON t.milestoneId = m.id
      INNER JOIN $tableGoals g ON m.goalId = g.id
      ORDER BY tc.completed_date DESC, t.scheduledDate DESC
    ''');

    return result.map((row) => DashboardTaskItem.fromMap(row)).toList();
  }

  Future<AnalyticsData> getAnalyticsData() async {
    final db = await instance.database;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build the 7 day window from (today - 6 days) to today
    final List<DateTime> last7Days = List.generate(7, (i) {
      return today.subtract(Duration(days: 6 - i));
    });

    final weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Query all completed tasks joined with milestone & goal
    final result = await db.rawQuery('''
      SELECT 
        t.id,
        t.milestoneId,
        t.title,
        tc.focus_minutes AS estimatedMinutes,
        1 AS isDone,
        t.scheduledDate,
        tc.completed_date AS completedAt,
        m.title AS milestoneTitle,
        g.id AS goalId,
        g.title AS goalTitle,
        g.category AS goalCategory,
        g.priority AS goalPriority
      FROM task_completions tc
      INNER JOIN $tableTasks t ON tc.task_id = t.id
      INNER JOIN $tableMilestones m ON t.milestoneId = m.id
      INNER JOIN $tableGoals g ON m.goalId = g.id
    ''');

    final completedItems =
        result.map((r) => DashboardTaskItem.fromMap(r)).toList();

    // Group completed items by day in the last 7 days window
    final Map<int, List<DashboardTaskItem>> tasksByDayIndex = {};
    for (int i = 0; i < 7; i++) {
      tasksByDayIndex[i] = [];
    }

    final Map<String, int> categoryMinutes = {};
    final Map<String, int> categoryTaskCounts = {};
    int totalWeeklyMinutes = 0;
    int totalCompletedInWindow = 0;

    final windowStart = last7Days.first; // 00:00:00 of day 0
    final windowEnd =
        today.add(const Duration(days: 1)); // 00:00:00 of tomorrow

    for (final item in completedItems) {
      final completedDate =
          item.task.completedAt ?? item.task.scheduledDate ?? now;
      final completedDay = DateTime(
          completedDate.year, completedDate.month, completedDate.day);

      // Check if it falls within the 7-day window
      if (!completedDay.isBefore(windowStart) &&
          completedDay.isBefore(windowEnd)) {
        final dayIndex = last7Days.indexWhere((d) =>
            d.year == completedDay.year &&
            d.month == completedDay.month &&
            d.day == completedDay.day);

        if (dayIndex != -1) {
          tasksByDayIndex[dayIndex]!.add(item);
          totalWeeklyMinutes += item.task.estimatedMinutes;
          totalCompletedInWindow++;
        }
      }

      // Tally category distribution for all completed tasks
      final category = item.goalCategory.trim().isNotEmpty
          ? item.goalCategory.trim()
          : 'General';
      categoryMinutes[category] =
          (categoryMinutes[category] ?? 0) + item.task.estimatedMinutes;
      categoryTaskCounts[category] = (categoryTaskCounts[category] ?? 0) + 1;
    }

    // Build DailyFocusStat list
    int activeDays = 0;
    final List<DailyFocusStat> dailyStats = [];
    for (int i = 0; i < 7; i++) {
      final day = last7Days[i];
      final dayTasks = tasksByDayIndex[i] ?? [];
      final dayMinutes =
          dayTasks.fold<int>(0, (sum, t) => sum + t.task.estimatedMinutes);
      if (dayTasks.isNotEmpty) {
        activeDays++;
      }
      dailyStats.add(
        DailyFocusStat(
          date: day,
          dayLabel: weekdayLabels[day.weekday - 1],
          totalMinutes: dayMinutes,
          taskCount: dayTasks.length,
        ),
      );
    }

    // Build CategoryEffortStat list
    final int overallCategoryMinutes =
        categoryMinutes.values.fold<int>(0, (sum, m) => sum + m);
    final List<CategoryEffortStat> categoryEfforts = [];
    categoryMinutes.forEach((category, minutes) {
      final percentage = overallCategoryMinutes > 0
          ? (minutes / overallCategoryMinutes) * 100.0
          : 0.0;
      categoryEfforts.add(
        CategoryEffortStat(
          category: category,
          totalMinutes: minutes,
          taskCount: categoryTaskCounts[category] ?? 0,
          percentage: percentage,
        ),
      );
    });

    // Sort categories by totalMinutes descending
    categoryEfforts.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    return AnalyticsData(
      weeklyFocusStats: dailyStats,
      categoryEfforts: categoryEfforts,
      activeDaysCount: activeDays,
      totalDaysCount: 7,
      totalWeeklyMinutes: totalWeeklyMinutes,
      completedTasksCount: totalCompletedInWindow,
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await instance.database;
    return await db.delete(
      tableTasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // EVENT CRUD OPERATIONS
  // ==========================================

  Future<int> insertEvent(Event event) async {
    final db = await instance.database;
    return await db.insert(
      tableEvents,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Event>> getEventsForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final prefix = dateStr.substring(0, 10);

    // Query single-instance events for this date OR any recurring events
    final result = await db.rawQuery('''
      SELECT * FROM $tableEvents
      WHERE (isRecurring = 0 AND date LIKE ?)
         OR (isRecurring = 1)
      ORDER BY startTime ASC, title ASC
    ''', ['$prefix%']);

    final allEvents = result.map((json) => Event.fromMap(json)).toList();
    // Filter to only events that actually occur on the specified date
    return allEvents.where((e) => e.occursOnDay(date)).toList();
  }

  Future<List<Event>> getAllEvents() async {
    final db = await instance.database;
    final result = await db.query(
      tableEvents,
      orderBy: 'date ASC, startTime ASC',
    );
    return result.map((json) => Event.fromMap(json)).toList();
  }

  Future<Event?> getEventById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableEvents,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateEvent(Event event) async {
    final db = await instance.database;
    return await db.update(
      tableEvents,
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(String id) async {
    final db = await instance.database;
    return await db.delete(
      tableEvents,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Queries all tasks scheduled for a specific date (joined with goal and milestone metadata).
  /// Falls back to Milestone.targetDate if task.scheduledDate is unset/empty.
  Future<List<DashboardTaskItem>> getScheduledTasksForDate(DateTime date) async {
    final db = await instance.database;
    final datePrefix =
        DateTime(date.year, date.month, date.day).toIso8601String().substring(0, 10);
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final targetLabel = dayLabels[date.weekday - 1];

    final result = await db.rawQuery('''
      SELECT 
        t.id,
        t.milestoneId,
        t.title,
        t.estimatedMinutes,
        t.isDone,
        t.scheduledDate,
        t.completedAt,
        t.isRecurring,
        t.recurringDays,
        m.title AS milestoneTitle,
        g.id AS goalId,
        g.title AS goalTitle,
        g.category AS goalCategory,
        g.priority AS goalPriority
      FROM $tableTasks t
      INNER JOIN $tableMilestones m ON t.milestoneId = m.id
      INNER JOIN $tableGoals g ON m.goalId = g.id
      WHERE (
        t.scheduledDate LIKE ?
        OR (
          (t.scheduledDate IS NULL OR TRIM(t.scheduledDate) = '')
          AND m.targetDate LIKE ?
        )
        OR (t.isRecurring = 1)
      )
      ORDER BY t.isDone ASC, g.priority DESC, t.title ASC
    ''', ['$datePrefix%', '$datePrefix%']);

    final list = result.map((row) => DashboardTaskItem.fromMap(row)).toList();
    return list.where((item) {
      if (item.task.isRecurring) {
        if (item.task.recurringDays.isEmpty) return true;
        final days = item.task.recurringDays.split(',').map((s) => s.trim());
        return days.contains(targetLabel);
      }
      return true;
    }).toList();
  }

  // ==========================================
  // PAUSE MODE & EXAM MODE CRUD OPERATIONS
  // ==========================================

  Future<int> insertPauseMode(PauseMode mode) async {
    final db = await instance.database;
    return await db.insert(
      tablePauseModes,
      mode.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PauseMode?> getActivePauseMode([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();
    final db = await instance.database;
    final result = await db.query(
      tablePauseModes,
      where: 'isActive = 1',
      orderBy: 'startDate DESC',
    );

    for (final row in result) {
      final mode = PauseMode.fromMap(row);
      if (mode.isCurrentActive(now)) {
        return mode;
      }
    }
    return null;
  }

  Future<List<PauseMode>> getAllPauseModes() async {
    final db = await instance.database;
    final result = await db.query(
      tablePauseModes,
      orderBy: 'startDate DESC',
    );
    return result.map((row) => PauseMode.fromMap(row)).toList();
  }

  Future<int> deactivatePauseMode(String id) async {
    final db = await instance.database;
    return await db.update(
      tablePauseModes,
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePauseMode(String id) async {
    final db = await instance.database;
    return await db.delete(
      tablePauseModes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isPauseModeActive([DateTime? customNow]) async {
    final activeMode = await getActivePauseMode(customNow);
    return activeMode != null;
  }

  // ==========================================
  // CONVENIENCE & MAINTENANCE METHODS
  // ==========================================

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(tablePauseModes);
      await txn.delete(tableEvents);
      await txn.delete(tableTasks);
      await txn.delete(tableMilestones);
      await txn.delete(tableGoals);
      await txn.delete(tableCategories);
      final defaults = ['Career', 'Health', 'Skill Development', 'Personal'];
      for (final name in defaults) {
        await txn.insert(
          tableCategories,
          {
            'id': name.toLowerCase().replaceAll(' ', '_'),
            'name': name,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // ==========================================
  // CATEGORY OPERATIONS
  // ==========================================

  Future<List<String>> getAllCategoryNames() async {
    final db = await instance.database;
    final result = await db.query(tableCategories);
    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> insertCategory(String name) async {
    final db = await instance.database;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await db.insert(
      tableCategories,
      {
        'id': trimmed.toLowerCase().replaceAll(' ', '_'),
        'name': trimmed,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  // ==========================================
  // SETTINGS & ROLLOVER METHODS
  // ==========================================

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await instance.database;
    final result = await db.query('settings');
    return {for (final row in result) row['key'] as String: row['value'] as String};
  }

  Future<void> rolloverRecurringTasks([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();
    final db = await instance.database;
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final lastRollover = await getSetting('last_rollover_date');
    if (lastRollover != todayStr) {
      await db.update(
        tableTasks,
        {
          'isDone': 0,
          'completedAt': null,
          'scheduledDate': now.toIso8601String(),
        },
        where: 'isRecurring = 1',
      );
      await saveSetting('last_rollover_date', todayStr);
    }
  }
}
