import 'package:flutter/material.dart';

import '../models/category_models.dart';
import 'mock_auth_data.dart';

class MockCategoryData {
  MockCategoryData._();

  static bool isLocalToken(String? token) => MockAuthData.isMockToken(token);

  static List<CategoryModel> categories = const [
    CategoryModel(categoryId: 1, categoryName: 'Sales', isActive: true),
    CategoryModel(categoryId: 2, categoryName: 'Purchases', isActive: true),
    CategoryModel(categoryId: 3, categoryName: 'Sales Returns', isActive: true),
    CategoryModel(categoryId: 4, categoryName: 'Purchase Returns', isActive: true),
    CategoryModel(categoryId: 5, categoryName: 'Expenses', isActive: true),
    CategoryModel(categoryId: 6, categoryName: 'Reports', isActive: true),
  ];

  static IconData iconFor(String name) {
    switch (name.toLowerCase()) {
      case 'sales':
      case 'sales documents':
        return Icons.receipt_long_outlined;
      case 'purchases':
      case 'purchase documents':
        return Icons.shopping_cart_outlined;
      case 'sales returns':
        return Icons.keyboard_return_rounded;
      case 'purchase returns':
        return Icons.undo_rounded;
      case 'expenses':
        return Icons.payments_outlined;
      case 'reports':
        return Icons.trending_up_rounded;
      case 'bank statements':
        return Icons.account_balance_outlined;
      case 'gst':
      case 'gst documents':
        return Icons.description_outlined;
      case 'other documents':
        return Icons.folder_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  static Color accentFor(int index) {
    const accents = [
      Color(0xFF2563EB),
      Color(0xFF16A34A),
      Color(0xFFC9A84C),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF0B1F3A),
    ];
    return accents[index % accents.length];
  }

  static String nameForId(int id) {
    return categories
        .firstWhere((c) => c.categoryId == id, orElse: () => categories.first)
        .categoryName;
  }
}
