import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/upload_flow_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              currentAccountPicture: CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : 'U')
                      .toUpperCase(),
                  style: TextStyle(color: colorScheme.onPrimary),
                ),
              ),
              accountName: Text(user?.name ?? 'Guest'),
              accountEmail: Text(user?.email ?? ''),
            ),
            if (isAdmin) ...[
              _DrawerTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin');
                },
              ),
              _DrawerTile(
                icon: Icons.people_outline,
                label: 'User Management',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/users');
                },
              ),
              _DrawerTile(
                icon: Icons.category_outlined,
                label: 'Categories',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/categories');
                },
              ),
            ] else ...[
              _DrawerTile(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/dashboard');
                },
              ),
              _DrawerTile(
                icon: Icons.upload_file_outlined,
                label: 'Upload Document',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/upload');
                },
              ),
              _DrawerTile(
                icon: Icons.history,
                label: 'Document History',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/history');
                },
              ),
            ],
            _DrawerTile(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            _DrawerTile(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () {
                Navigator.pop(context);
                context.go('/change-password');
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerTile(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                Navigator.pop(context);
                resetClientSession(ref);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
