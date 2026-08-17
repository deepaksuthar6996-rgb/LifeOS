import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_helper.dart';

class CategoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return _fetchCategories();
  }

  Future<List<String>> _fetchCategories() async {
    return await DBHelper.instance.getAllCategoryNames();
  }

  Future<void> refreshCategories() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCategories());
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;
    await DBHelper.instance.insertCategory(trimmed);
    await refreshCategories();
  }
}

final categoryProvider = AsyncNotifierProvider<CategoryNotifier, List<String>>(() {
  return CategoryNotifier();
});
