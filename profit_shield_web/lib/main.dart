import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/api_logger.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/clients/data/clients_repository.dart';
import 'features/clients/presentation/clients_screen.dart';
import 'features/clients/providers/clients_provider.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/user_approvals/data/user_approvals_repository.dart';
import 'features/user_approvals/presentation/user_approvals_screen.dart';
import 'features/user_approvals/providers/user_approvals_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Use /clients instead of /#/clients on web.
  usePathUrlStrategy();
  ApiLogger.logStartup();
  if (kDebugMode) {
    debugPrint('API base URL: ${AppConfig.apiBaseUrl}');
  }
  runApp(const ProfitShieldApp());
}

class ProfitShieldApp extends StatefulWidget {
  const ProfitShieldApp({super.key});

  @override
  State<ProfitShieldApp> createState() => _ProfitShieldAppState();
}

class _ProfitShieldAppState extends State<ProfitShieldApp> {
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final DashboardRepository _dashboardRepository;
  late final UserApprovalsRepository _userApprovalsRepository;
  late final ClientsRepository _clientsRepository;
  late final AuthProvider _authProvider;
  late final DashboardProvider _dashboardProvider;
  late final UserApprovalsProvider _userApprovalsProvider;
  late final ClientsProvider _clientsProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authRepository = AuthRepository(_apiClient);
    _dashboardRepository = DashboardRepository(_apiClient);
    _userApprovalsRepository = UserApprovalsRepository(_apiClient);
    _clientsRepository = ClientsRepository(_apiClient);
    _authProvider = AuthProvider(repository: _authRepository, apiClient: _apiClient);
    _dashboardProvider = DashboardProvider(_dashboardRepository);
    _userApprovalsProvider = UserApprovalsProvider(_userApprovalsRepository);
    _clientsProvider = ClientsProvider(_clientsRepository);

    _apiClient.onSessionExpired = () {
      _authProvider.logout();
    };

    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _authProvider,
      redirect: (context, state) {
        if (_authProvider.isBootstrapping) return null;
        final loggedIn = _authProvider.isAuthenticated;
        final onLogin = state.matchedLocation == '/login';
        if (!loggedIn && !onLogin) return '/login';
        if (loggedIn && onLogin) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/user-approvals',
          builder: (context, state) => const UserApprovalsScreen(),
        ),
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientsScreen(),
        ),
      ],
    );

    _authProvider.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _dashboardProvider),
        ChangeNotifierProvider.value(value: _userApprovalsProvider),
        ChangeNotifierProvider.value(value: _clientsProvider),
        Provider.value(value: _apiClient),
      ],
      child: MaterialApp.router(
        title: 'ProfitShield',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
