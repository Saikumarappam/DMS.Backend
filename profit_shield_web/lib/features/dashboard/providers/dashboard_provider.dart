import 'package:flutter/foundation.dart';

import '../../auth/models/user_model.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository);

  final DashboardRepository _repository;

  DashboardData data = DashboardData.empty();
  bool isLoading = false;
  String? errorMessage;

  Future<void> load(AppUser user) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      data = await _repository.load(user);
    } catch (e) {
      errorMessage = e.toString();
      data = DashboardData.empty();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
