import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../user_approvals/models/approval_user_model.dart';
import '../../user_approvals/providers/user_approvals_provider.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';
import 'widgets/admin_shell.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/documents_trend_chart.dart';
import 'widgets/kpi_card.dart';
import 'widgets/top_clients_table.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<DashboardProvider>().load(user);
        if (user.isSuperAdmin) {
          context.read<UserApprovalsProvider>().load(status: UserApprovalStatus.pending);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final user = auth.user;

    return AdminShell(
      selectedLabel: 'Dashboard',
      title: 'Dashboard',
      isLoading: dash.isLoading && dash.data.kpis.isEmpty,
      onRefresh: user == null ? null : () async => dash.load(user),
      child: RefreshIndicator(
        onRefresh: () async {
          if (user != null) await dash.load(user);
        },
        child: _DashboardBody(dash: dash),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dash});

  final DashboardProvider dash;

  @override
  Widget build(BuildContext context) {
    if (dash.isLoading && dash.data.kpis.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final mode = contentLayoutMode(contentWidth);
        final padding = mode == ContentLayoutMode.compact ? 12.0 : 16.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (padding * 2),
              maxWidth: contentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dash.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      dash.errorMessage!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                _KpiRow(
                  metrics: dash.data.kpis,
                  contentWidth: contentWidth,
                  mode: mode,
                ),
                const SizedBox(height: 16),
                _ChartsAndTableRow(
                  dash: dash,
                  contentWidth: contentWidth,
                  mode: mode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.metrics,
    required this.contentWidth,
    required this.mode,
  });

  final List<KpiMetric> metrics;
  final double contentWidth;
  final ContentLayoutMode mode;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No KPI data available')),
      );
    }

    final gap = mode == ContentLayoutMode.spacious ? 12.0 : 8.0;
    final minCardWidth = mode == ContentLayoutMode.compact ? 160.0 : 150.0;
    final needed = metrics.length * minCardWidth + (metrics.length - 1) * gap;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: KpiCard(metric: metrics[i])),
        ],
      ],
    );

    if (contentWidth + 0.5 >= needed) {
      return row;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: needed.clamp(needed, contentWidth > needed ? contentWidth : needed),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: needed, maxWidth: needed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                SizedBox(
                  width: minCardWidth,
                  child: KpiCard(metric: metrics[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartsAndTableRow extends StatelessWidget {
  const _ChartsAndTableRow({
    required this.dash,
    required this.contentWidth,
    required this.mode,
  });

  final DashboardProvider dash;
  final double contentWidth;
  final ContentLayoutMode mode;

  @override
  Widget build(BuildContext context) {
    final gap = mode == ContentLayoutMode.spacious ? 12.0 : 8.0;
    final donut = CategoryDonutChart(
      slices: dash.data.categories,
      total: dash.data.documentsTotal,
    );
    final trend = DocumentsTrendChart(points: dash.data.trend);
    final table = TopClientsTable(rows: dash.data.topClients);

    final minRowWidth = mode == ContentLayoutMode.compact ? 960.0 : 1020.0;

    Widget buildRow(double width) {
      return SizedBox(
        width: width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: donut),
            SizedBox(width: gap),
            Expanded(flex: 4, child: trend),
            SizedBox(width: gap),
            Expanded(flex: 4, child: table),
          ],
        ),
      );
    }

    if (contentWidth >= minRowWidth) {
      return buildRow(contentWidth);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: buildRow(minRowWidth),
    );
  }
}
