import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required ApiClient apiClient,
  })  : _repository = repository,
        _api = apiClient;

  final AuthRepository _repository;
  final ApiClient _api;

  AppUser? user;
  bool isLoading = false;
  bool isBootstrapping = true;
  String? errorMessage;

  bool get isAuthenticated => user != null && _api.accessToken != null;

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();
    try {
      user = await _repository.restoreSession();
    } catch (_) {
      user = null;
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      user = result.user;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      print("Login error: $errorMessage");
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<String?> forgotPassword(String email) async {
    try {
      await _repository.forgotPassword(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> verifyPassword(String password) async {
    try {
      await _repository.verifyPassword(password);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
