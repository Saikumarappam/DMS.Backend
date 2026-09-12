import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_models.dart';
import '../../data/repositories/category_repository.dart';

class CategoryState {
  const CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  CategoryNotifier(this._repository) : super(const CategoryState());

  final CategoryRepository _repository;

  Future<void> load({bool includeInactive = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getAll(includeInactive: includeInactive);
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return;
    }
    state = state.copyWith(
      isLoading: false,
      categories: result.data ?? [],
    );
  }

  Future<String?> create(String name, String? description) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.create(
      CreateCategoryRequest(categoryName: name, description: description),
    );
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return result.errorMessage;
    }
    await load(includeInactive: true);
    return null;
  }

  Future<String?> update(int id, String name, String? description) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.update(
      id,
      UpdateCategoryRequest(categoryName: name, description: description),
    );
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return result.errorMessage;
    }
    await load(includeInactive: true);
    return null;
  }

  Future<String?> delete(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.delete(id);
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return result.errorMessage;
    }
    await load(includeInactive: true);
    return null;
  }
}

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  return CategoryNotifier(ref.read(categoryRepositoryProvider));
});
