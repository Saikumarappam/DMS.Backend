import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/client_bottom_nav.dart';
import '../widgets/client_header.dart';

class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(authProvider.notifier).refreshProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = bottomNavIndexForLocation(location);
    final isDashboard = location.startsWith('/dashboard');
    final isHistory = location.startsWith('/history');
    final hideShellHeader = isDashboard || isHistory;

    return Scaffold(
      body: Column(
        children: [
          if (!hideShellHeader) SafeArea(bottom: false, child: const ClientHeader()),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: ClientBottomNav(
        currentIndex: index,
        onTap: (_) {},
      ),
    );
  }
}
