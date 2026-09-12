import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/biometric_cold_start_pending_provider.dart';
import '../../presentation/screens/admin_dashboard_screen.dart';
import '../../presentation/screens/alerts_screen.dart';
import '../../presentation/screens/category_management_screen.dart';
import '../../presentation/screens/category_upload_screen.dart';
import '../../presentation/screens/change_password_screen.dart';
import '../../presentation/screens/client_dashboard_screen.dart';
import '../../presentation/screens/client_shell.dart';
import '../../presentation/screens/forgot_password_screen.dart';
import '../../presentation/screens/history_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/register_screen.dart';
import '../../presentation/screens/saved_downloads_screen.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/upload_preview_screen.dart';
import '../../presentation/screens/user_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final isAuthRoute = _publicRoutes.contains(location);
      final isSplash = location == '/splash';
      final isUploadFlow = location.startsWith('/upload/category');

      if (authState.status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }

      if (!authState.isAuthenticated) {
        if (isAuthRoute || location.startsWith('/reset-password')) {
          return null;
        }
        return '/login';
      }

      if (isSplash && ref.read(biometricColdStartPendingProvider)) {
        return null;
      }

      if (isAuthRoute || isSplash) {
        return authState.isSuperAdmin ? '/admin' : '/dashboard';
      }

      if (authState.isSuperAdmin &&
          (location.startsWith('/dashboard') ||
              location.startsWith('/history') ||
              location.startsWith('/alerts') ||
              location == '/profile' ||
              isUploadFlow)) {
        return '/admin';
      }

      if (authState.isClient && location.startsWith('/admin')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        redirect: (context, state) => '/forgot-password',
      ),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const ClientDashboardScreen()),
          GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          GoRoute(path: '/downloads', builder: (context, state) => const SavedDownloadsScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/upload/category/:categoryId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['categoryId']!);
          return CategoryUploadScreen(categoryId: id);
        },
      ),
      GoRoute(
        path: '/upload/category/:categoryId/preview',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['categoryId']!);
          return UploadPreviewScreen(categoryId: id);
        },
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
      GoRoute(path: '/admin/categories', builder: (context, state) => const CategoryManagementScreen()),
    ],
  );
});

const _publicRoutes = {'/login', '/register', '/forgot-password'};

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this.ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.user?.userId != next.user?.userId) {
        notifyListeners();
      }
    });
    ref.listen<bool>(sessionExpiredProvider, (_, expired) {
      if (expired) {
        ref.read(authProvider.notifier).logout();
        ref.read(sessionExpiredProvider.notifier).state = false;
        notifyListeners();
      }
    });
    ref.listen<bool>(biometricColdStartPendingProvider, (previous, next) {
      if (previous != next) {
        notifyListeners();
      }
    });
  }

  final Ref ref;
}
