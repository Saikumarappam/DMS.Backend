import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/stat_card.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(dashboardProvider.notifier).loadAdminDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final totalDocs = state.dailyReports.fold<int>(
      0,
      (sum, item) => sum + item.documentCount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: const AppDrawer(isAdmin: true),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).loadAdminDashboard(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.6,
                    children: [
                      StatCard(
                        title: 'Documents (30 days)',
                        value: '$totalDocs',
                        icon: Icons.description_outlined,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: 'Report Days',
                        value: '${state.dailyReports.length}',
                        icon: Icons.calendar_today_outlined,
                        color: Colors.teal,
                      ),
                      StatCard(
                        title: 'Audit Logs',
                        value: '${state.auditLogs.length}',
                        icon: Icons.history_toggle_off,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.people_outline),
                        label: const Text('Manage Users'),
                        onPressed: () => context.push('/admin/users'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.category_outlined),
                        label: const Text('Manage Categories'),
                        onPressed: () => context.push('/admin/categories'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Daily Reports (Last 30 Days)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.dailyReports.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No report data available.'),
                      ),
                    )
                  else
                    ...state.dailyReports.map(
                      (item) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.bar_chart),
                          title: Text(item.label),
                          subtitle: Text('Total size: ${_formatSize(item.totalSize)}'),
                          trailing: Text('${item.documentCount} docs'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Audit Logs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.auditLogs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No audit logs found.'),
                      ),
                    )
                  else
                    ...state.auditLogs.take(10).map(
                          (log) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.security),
                              title: Text('${log.action} • ${log.entityName}'),
                              subtitle: Text(
                                '${log.userName ?? 'System'} • ${dateFormat.format(log.createdDate)}',
                              ),
                            ),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
