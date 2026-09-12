import '../../core/utils/json_utils.dart';

class CategoryModel {
  const CategoryModel({
    required this.categoryId,
    required this.categoryName,
    required this.isActive,
    this.description,
  });

  final int categoryId;
  final String categoryName;
  final bool isActive;
  final String? description;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryId: (JsonUtils.pick(json, 'categoryId') as num).toInt(),
      categoryName: JsonUtils.pick(json, 'categoryName') as String? ?? '',
      isActive: JsonUtils.pick(json, 'isActive') as bool? ?? true,
      description: JsonUtils.pick(json, 'description') as String?,
    );
  }
}

class CreateCategoryRequest {
  const CreateCategoryRequest({required this.categoryName, this.description});

  final String categoryName;
  final String? description;

  Map<String, dynamic> toJson() => {
        'categoryName': categoryName,
        if (description != null) 'description': description,
      };
}

class UpdateCategoryRequest {
  const UpdateCategoryRequest({required this.categoryName, this.description});

  final String categoryName;
  final String? description;

  Map<String, dynamic> toJson() => {
        'categoryName': categoryName,
        if (description != null) 'description': description,
      };
}
