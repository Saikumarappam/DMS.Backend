import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/browser_title.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_splash_loader.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../documents/providers/documents_provider.dart';
import '../../../user_approvals/providers/user_approvals_provider.dart';
import '../../providers/dashboard_provider.dart';
import 'app_sidebar.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.selectedLabel,
    required this.title,
    required this.child,
    this.onRefresh,
    this.isLoading = false,
  });

  final String selectedLabel;
  final String title;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final bool isLoading;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DocumentsProvider>().ensurePendingCount();
    });
  }

  List<SidebarItem> _items(
    DashboardProvider dash,
    UserApprovalsProvider approvals,
    DocumentsProvider documents,
  ) {
    final pendingBadge = approvals.counts.pending > 0
        ? approvals.counts.pending
        : dash.data.pendingApprovals;
    return [
      const SidebarItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
      const SidebarItem(label: 'Clients', icon: Icons.people_outline, route: '/clients'),
      SidebarItem(
        label: 'User Approvals',
        icon: Icons.how_to_reg_outlined,
        badge: pendingBadge > 0 ? pendingBadge : null,
        route: '/user-approvals',
      ),
      SidebarItem(
        label: 'Documents',
        icon: Icons.folder_outlined,
        badge: documents.pendingCount > 0 ? documents.pendingCount : null,
        route: '/documents',
      ),
      SidebarItem(
        label: 'Tasks',
        icon: Icons.checklist_outlined,
        badge: dash.data.pendingTasksBadge > 0 ? dash.data.pendingTasksBadge : null,
        route: '/dashboard',
      ),
      const SidebarItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/dashboard'),
      const SidebarItem(label: 'Categories', icon: Icons.category_outlined, route: '/categories'),
      const SidebarItem(label: 'Team Members', icon: Icons.groups_outlined, route: '/dashboard'),
      const SidebarItem(label: 'Settings', icon: Icons.settings_outlined, route: '/dashboard'),
      const SidebarItem(label: 'Activity Log', icon: Icons.history, route: '/dashboard'),
      const SidebarItem(label: 'Backup & Export', icon: Icons.cloud_download_outlined, route: '/dashboard'),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  void _onSelectSidebar(BuildContext context, SidebarItem item) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (item.label == widget.selectedLabel) {
      if (item.route == '/documents') context.go('/documents');
      if (item.route == '/categories') context.go('/categories');
      return;
    }
    if (item.route == '/dashboard' && item.label != 'Dashboard') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.label} coming soon')),
      );
      return;
    }
    context.go(item.route);
  }

  void _toggleSidebar() => setState(() => _sidebarCollapsed = !_sidebarCollapsed);

  @override
  Widget build(BuildContext context) {
    setBrowserTitle(widget.title);

    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final approvals = context.watch<UserApprovalsProvider>();
    final documents = context.watch<DocumentsProvider>();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final useDrawer = viewportWidth < Breakpoints.tablet;
    final user = auth.user;

    Widget buildSidebar({required bool collapsed}) {
      return AppSidebar(
        items: _items(dash, approvals, documents),
        selectedLabel: widget.selectedLabel,
        userName: user?.name ?? 'User',
        userRole: user?.roleName ?? '',
        collapsed: collapsed,
        width: collapsed ? SidebarDims.collapsed(viewportWidth) : SidebarDims.expanded(viewportWidth),
        onSelect: (item) => _onSelectSidebar(context, item),
        onLogout: () => _logout(context),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: useDrawer
          ? Drawer(
              width: SidebarDims.expanded(viewportWidth).clamp(220, 280),
              child: buildSidebar(collapsed: false),
            )
          : null,
      body: Row(
        children: [
          if (!useDrawer) buildSidebar(collapsed: _sidebarCollapsed),
          Expanded(
            child: Column(
              children: [
                AdminTopBar(
                  title: widget.title,
                  showMenu: useDrawer,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  sidebarCollapsed: _sidebarCollapsed,
                  onToggleSidebar: useDrawer ? null : _toggleSidebar,
                  onRefresh: widget.onRefresh,
                  userName: user?.name ?? 'Admin',
                  userRole: user?.roleName ?? 'Super Admin',
                ),
                Expanded(
                  child: Stack(
                    children: [
                      widget.child,
                      if (widget.isLoading)
                        const Positioned.fill(child: AppLoadingOverlay()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.title,
    required this.showMenu,
    required this.onMenu,
    required this.sidebarCollapsed,
    required this.userName,
    required this.userRole,
    this.onToggleSidebar,
    this.onRefresh,
  });

  final String title;
  final bool showMenu;
  final VoidCallback onMenu;
  final bool sidebarCollapsed;
  final VoidCallback? onToggleSidebar;
  final Future<void> Function()? onRefresh;
  final String userName;
  final String userRole;

  String get _displayRole {
    if (userRole.toLowerCase() == 'superadmin') return 'Super Admin';
    return userRole;
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactHeader = viewportWidth < Breakpoints.tablet;

    return Container(
      height: AppScale.of(context).topBarHeight,
      padding: EdgeInsets.symmetric(horizontal: compactHeader ? 8 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu))
          else if (onToggleSidebar != null)
            IconButton(
              tooltip: sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onPressed: onToggleSidebar,
              icon: Icon(sidebarCollapsed ? Icons.menu_open : Icons.menu),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fontSize = _titleFontSize(constraints.maxWidth, viewportWidth);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => onRefresh!(),
                  icon: Icon(Icons.refresh, size: compactHeader ? AppScale.of(context).iconMd : 22),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
              icon: Icon(
                Icons.notifications_none_outlined,
                size: compactHeader ? AppScale.of(context).iconMd : 22,
              ),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(width: compactHeader ? 4 : 12),
              _HeaderAccount(
                name: userName,
                role: _displayRole,
                compact: compactHeader || viewportWidth < 1100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _titleFontSize(double availableWidth, double viewportWidth) {
    if (availableWidth < 180) return 13;
    if (availableWidth < 260) return 14;
    if (viewportWidth < Breakpoints.mobile) return 15;
    if (viewportWidth < Breakpoints.tablet) return 16;
    if (viewportWidth < Breakpoints.desktop) return 17;
    return 18;
  }
}

class _HeaderAccount extends StatelessWidget {
  const _HeaderAccount({
    required this.name,
    required this.role,
    this.compact = false,
  });

  final String name;
  final String role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 13 : 14,
          backgroundColor: AppColors.gold.withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'A',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
