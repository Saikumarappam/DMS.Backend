import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthProvider({
    required AuthRepository repository,
    required ApiClient apiClient,
  })  : _repository = repository,
        _api = apiClient {
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  final AuthRepository _repository;
  final ApiClient _api;

  AppUser? user;
  bool isLoading = false;
  bool isBootstrapping = true;
  String? errorMessage;

  Timer? _idleTimer;
  DateTime? _lastActivityPersist;
  bool _keyHandlerAttached = false;

  bool get isAuthenticated => user != null && _api.accessToken != null;

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();
    try {
      if (kIsWeb && await _api.isIdleExpired(AppConfig.idleTimeout)) {
        await _repository.logout();
        user = null;
      } else {
        user = await _repository.restoreSession();
        if (user != null) _startIdleWatch();
      }
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
      _startIdleWatch();
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
    _stopIdleWatch();
    await _repository.logout();
    user = null;
    notifyListeners();
  }

  /// Call on pointer / keyboard activity. Web-only idle logout.
  void onUserActivity({bool forcePersist = false}) {
    if (!kIsWeb || !isAuthenticated) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConfig.idleTimeout, () {
      logout();
    });
    final now = DateTime.now();
    if (forcePersist ||
        _lastActivityPersist == null ||
        now.difference(_lastActivityPersist!) >= const Duration(seconds: 30)) {
      _lastActivityPersist = now;
      unawaited(_api.touchActivity());
    }
  }

  void _startIdleWatch() {
    if (!kIsWeb) return;
    if (!_keyHandlerAttached) {
      HardwareKeyboard.instance.addHandler(_onKeyActivity);
      _keyHandlerAttached = true;
    }
    onUserActivity(forcePersist: true);
  }

  void _stopIdleWatch() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _lastActivityPersist = null;
    if (_keyHandlerAttached) {
      HardwareKeyboard.instance.removeHandler(_onKeyActivity);
      _keyHandlerAttached = false;
    }
  }

  bool _onKeyActivity(KeyEvent event) {
    onUserActivity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb || !isAuthenticated) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_logoutIfIdle());
    }
  }

  Future<void> _logoutIfIdle() async {
    if (await _api.isIdleExpired(AppConfig.idleTimeout)) {
      await logout();
      return;
    }
    onUserActivity();
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

  @override
  void dispose() {
    _stopIdleWatch();
    if (kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
