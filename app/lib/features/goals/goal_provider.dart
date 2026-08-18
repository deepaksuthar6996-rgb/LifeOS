import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_helper.dart';
import '../../models/goal.dart';
import '../calendar/calendar_provider.dart';
import '../dashboard/dashboard_provider.dart';
import 'goal_detail_provider.dart';

class GoalNotifier extends AsyncNotifier<List<Goal>> {
  @override
  Future<List<Goal>> build() async {
    return _fetchGoals();
  }

  Future<List<Goal>> _fetchGoals() async {
    return await DBHelper.instance.getAllGoals();
  }

  Future<void> refreshGoals() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchGoals());
  }

  Future<void> addGoal(Goal goal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DBHelper.instance.insertGoal(goal);
      return _fetchGoals();
    });
    ref.invalidate(dashboardProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> updateGoal(Goal goal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DBHelper.instance.updateGoal(goal);
      return _fetchGoals();
    });
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalDetailProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DBHelper.instance.deleteGoal(id);
      return _fetchGoals();
    });
    ref.invalidate(dashboardProvider);
    ref.invalidate(goalDetailProvider);
    ref.invalidate(calendarProvider);
  }
}

final goalProvider = AsyncNotifierProvider<GoalNotifier, List<Goal>>(() {
  return GoalNotifier();
});

