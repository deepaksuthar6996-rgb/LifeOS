import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class ImportResult {
  final bool success;
  final String? errorMessage;
  final int goalsCount;
  final int milestonesCount;
  final int tasksCount;
  final int eventsCount;

  const ImportResult({
    required this.success,
    this.errorMessage,
    this.goalsCount = 0,
    this.milestonesCount = 0,
    this.tasksCount = 0,
    this.eventsCount = 0,
  });

  String get summaryMessage =>
      'Restored $goalsCount goals, $milestonesCount milestones, $tasksCount tasks, and $eventsCount events.';
}

class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  /// Converts all database tables (goals, milestones, tasks, events, pause_modes) into a single structured JSON string
  Future<String> exportToJson() async {
    final db = await DBHelper.instance.database;

    final goals = await db.query(DBHelper.tableGoals);
    final milestones = await db.query(DBHelper.tableMilestones);
    final tasks = await db.query(DBHelper.tableTasks);
    final events = await db.query(DBHelper.tableEvents);
    final pauseModes = await db.query(DBHelper.tablePauseModes);

    final backupMap = {
      'app': 'Project Ascend LifeOS',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'summary': {
        'goalsCount': goals.length,
        'milestonesCount': milestones.length,
        'tasksCount': tasks.length,
        'eventsCount': events.length,
        'pauseModesCount': pauseModes.length,
      },
      'data': {
        'goals': goals,
        'milestones': milestones,
        'tasks': tasks,
        'events': events,
        'pauseModes': pauseModes,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Parses JSON content, resets the SQLite database safely, and bulk inserts all records in dependency order
  Future<ImportResult> importFromJson(String jsonContent) async {
    try {
      final dynamic decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult(
          success: false,
          errorMessage: 'Invalid backup file format: Root is not a JSON object.',
        );
      }

      final Map<String, dynamic> dataMap = decoded.containsKey('data') &&
              decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      final goalsList = dataMap['goals'];
      final rawGoals = goalsList is List ? goalsList : [];

      final milestonesList = dataMap['milestones'];
      final rawMilestones = milestonesList is List ? milestonesList : [];

      final tasksList = dataMap['tasks'];
      final rawTasks = tasksList is List ? tasksList : [];

      final eventsList = dataMap['events'];
      final rawEvents = eventsList is List ? eventsList : [];

      final pauseModesList = dataMap['pauseModes'];
      final rawPauseModes = pauseModesList is List ? pauseModesList : [];

      final goals = <Map<String, dynamic>>[];
      for (final e in rawGoals) {
        if (e is Map) {
          goals.add(Map<String, dynamic>.from(e));
        }
      }

      final milestones = <Map<String, dynamic>>[];
      for (final e in rawMilestones) {
        if (e is Map) {
          milestones.add(Map<String, dynamic>.from(e));
        }
      }

      final tasks = <Map<String, dynamic>>[];
      for (final e in rawTasks) {
        if (e is Map) {
          tasks.add(Map<String, dynamic>.from(e));
        }
      }

      final events = <Map<String, dynamic>>[];
      for (final e in rawEvents) {
        if (e is Map) {
          events.add(Map<String, dynamic>.from(e));
        }
      }

      final pauseModes = <Map<String, dynamic>>[];
      for (final e in rawPauseModes) {
        if (e is Map) {
          pauseModes.add(Map<String, dynamic>.from(e));
        }
      }

      const goalColumns = {'id', 'title', 'description', 'category', 'targetDate', 'priority'};
      const milestoneColumns = {'id', 'goalId', 'title', 'targetDate', 'isCompleted'};
      const taskColumns = {'id', 'milestoneId', 'title', 'estimatedMinutes', 'isDone', 'isMissed', 'scheduledDate', 'completedAt'};
      const eventColumns = {'id', 'title', 'startTime', 'endTime', 'date', 'isFixed', 'isRecurring', 'recurringDays'};
      const pauseModeColumns = {'id', 'title', 'startDate', 'endDate', 'activeRoutineTitle', 'isActive'};

      final db = await DBHelper.instance.database;

      await db.transaction((txn) async {
        // Clear all tables safely
        await txn.delete(DBHelper.tablePauseModes);
        await txn.delete(DBHelper.tableEvents);
        await txn.delete(DBHelper.tableTasks);
        await txn.delete(DBHelper.tableMilestones);
        await txn.delete(DBHelper.tableGoals);
        await txn.delete(DBHelper.tableCategories);

        // Re-seed default categories
        final defaults = ['Career', 'Health', 'Skill Development', 'Personal'];
        for (final name in defaults) {
          await txn.insert(
            DBHelper.tableCategories,
            {
              'id': name.toLowerCase().replaceAll(' ', '_'),
              'name': name,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // Bulk insert in dependency order: Goals -> Milestones -> Tasks -> Events -> Pause Modes
        for (final rawGoal in goals) {
          final sanitized = Map<String, dynamic>.from(rawGoal)
            ..removeWhere((key, _) => !goalColumns.contains(key));
          if (sanitized.containsKey('id') && sanitized.containsKey('title')) {
            await txn.insert(
              DBHelper.tableGoals,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Register category dynamically
            final cat = sanitized['category'] as String?;
            if (cat != null && cat.trim().isNotEmpty) {
              final trimmed = cat.trim();
              await txn.insert(
                DBHelper.tableCategories,
                {
                  'id': trimmed.toLowerCase().replaceAll(' ', '_'),
                  'name': trimmed,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }

        for (final rawMs in milestones) {
          final sanitized = Map<String, dynamic>.from(rawMs)
            ..removeWhere((key, _) => !milestoneColumns.contains(key));
          if (sanitized.containsKey('id') && sanitized.containsKey('goalId')) {
            await txn.insert(
              DBHelper.tableMilestones,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        for (final rawTask in tasks) {
          final sanitized = Map<String, dynamic>.from(rawTask)
            ..removeWhere((key, _) => !taskColumns.contains(key));
          if (sanitized.containsKey('id') && sanitized.containsKey('milestoneId')) {
            await txn.insert(
              DBHelper.tableTasks,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        for (final rawEvent in events) {
          final sanitized = Map<String, dynamic>.from(rawEvent)
            ..removeWhere((key, _) => !eventColumns.contains(key));
          if (sanitized.containsKey('id') && sanitized.containsKey('title')) {
            await txn.insert(
              DBHelper.tableEvents,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        for (final rawPause in pauseModes) {
          final sanitized = Map<String, dynamic>.from(rawPause)
            ..removeWhere((key, _) => !pauseModeColumns.contains(key));
          if (sanitized.containsKey('id') && sanitized.containsKey('title')) {
            await txn.insert(
              DBHelper.tablePauseModes,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return ImportResult(
        success: true,
        goalsCount: goals.length,
        milestonesCount: milestones.length,
        tasksCount: tasks.length,
        eventsCount: events.length,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: 'Failed to import backup: $e',
      );
    }
  }

  /// Prompts user to select save location and exports ascend_backup_[timestamp].json
  Future<String?> exportBackupFile() async {
    final jsonString = await exportToJson();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final defaultFileName = 'ascend_backup_$timestamp.json';

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Ascend LifeOS Backup',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (savePath == null) {
      return null; // User cancelled
    }

    final file = File(savePath);
    await file.writeAsString(jsonString, flush: true);
    return savePath;
  }

  /// Prompts user to pick a JSON backup file and restores the SQLite database
  Future<ImportResult?> importBackupFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Ascend LifeOS JSON Backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null; // User cancelled
    }

    final pickedFile = result.files.first;
    String jsonString = '';

    if (pickedFile.bytes != null) {
      jsonString = utf8.decode(pickedFile.bytes!);
    } else if (pickedFile.path != null) {
      final file = File(pickedFile.path!);
      jsonString = await file.readAsString();
    }

    if (jsonString.trim().isEmpty) {
      return const ImportResult(
        success: false,
        errorMessage: 'Selected backup file is empty.',
      );
    }

    return await importFromJson(jsonString);
  }
}
