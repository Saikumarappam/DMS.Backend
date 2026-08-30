import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_model.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> load(AppUser user) async {
    if (user.isSuperAdmin) {
      return _loadAdmin();
    }
    return _loadClient();
  }

  Future<DashboardData> _loadAdmin() async {
    final response = await _api.get('/reports/admin-dashboard');
    final kpiRows = response.array0;
    final categoryRows = response.array1;
    final trendRows = response.array2;
    final clientRows = response.array3;
    final summary = kpiRows.isNotEmpty ? kpiRows.first : <String, dynamic>{};

    final kpis = _mapKpis(kpiRows);
    final categories = _mapCategories(categoryRows);
    final trend = _mapTrend(trendRows);
    final topClients = _mapTopClients(clientRows);

    return DashboardData(
      kpis: kpis,
      categories: categories,
      trend: trend,
      topClients: topClients,
      pendingApprovals: _asInt(
        summary['ClientsAddedThisMonth'] ?? summary['clientsAddedThisMonth'],
      ),
      pendingTasksBadge: _asInt(summary['PendingTasks'] ?? summary['pendingTasks']),
      documentsTotal: _asInt(
        summary['TotalDocumentsReceived'] ?? summary['totalDocumentsReceived'],
      ),
    );
  }

  List<KpiMetric> _mapKpis(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];

    if (_hasAnyKey(rows.first, ['Title', 'title'])) {
      return rows.map((row) {
        return KpiMetric(
          title: _str(row, 'Title', 'title'),
          value: _str(row, 'Value', 'value'),
          delta: _str(row, 'Delta', 'delta'),
          deltaPositive: _bool(row, 'DeltaPositive', 'deltaPositive', defaultValue: true),
          icon: _str(row, 'Icon', 'icon', fallback: 'analytics'),
          accent: _asInt(row['Accent'] ?? row['accent'], fallback: AppColors.info.toARGB32()),
        );
      }).toList();
    }

    final row = rows.first;
    final totalClients = _asInt(row['TotalClients'] ?? row['totalClients']);
    final clientsAddedThisMonth =
        _asInt(row['ClientsAddedThisMonth'] ?? row['clientsAddedThisMonth']);
    final documentsReceived =
        _asInt(row['TotalDocumentsReceived'] ?? row['totalDocumentsReceived']);
    final weekDocuments =
        _asInt(row['DocumentsReceivedThisWeek'] ?? row['documentsReceivedThisWeek']);
    final pendingTasks = _asInt(row['PendingTasks'] ?? row['pendingTasks']);
    final completedTasks = _asInt(row['CompletedTasks'] ?? row['completedTasks']);
    final completedThisWeek =
        _asInt(row['CompletedThisWeek'] ?? row['completedThisWeek']);
    final overdueTasks = _asInt(row['OverdueTasks'] ?? row['overdueTasks']);

    return [
      KpiMetric(
        title: 'Total Clients',
        value: _formatNumber(totalClients),
        delta: '+$clientsAddedThisMonth this month',
        deltaPositive: clientsAddedThisMonth >= 0,
        icon: 'people',
        accent: AppColors.info.toARGB32(),
      ),
      KpiMetric(
        title: 'Documents Received',
        value: _formatNumber(documentsReceived),
        delta: '+$weekDocuments this week',
        deltaPositive: weekDocuments >= 0,
        icon: 'description',
        accent: AppColors.success.toARGB32(),
      ),
      KpiMetric(
        title: 'Pending Tasks',
        value: _formatNumber(pendingTasks),
        delta: '+$pendingTasks open',
        deltaPositive: true,
        icon: 'pending_actions',
        accent: AppColors.warning.toARGB32(),
      ),
      KpiMetric(
        title: 'Tasks Completed',
        value: _formatNumber(completedTasks),
        delta: '+$completedThisWeek this week',
        deltaPositive: completedThisWeek >= 0,
        icon: 'task_alt',
        accent: AppColors.purple.toARGB32(),
      ),
      KpiMetric(
        title: 'Overdue Tasks',
        value: _formatNumber(overdueTasks),
        delta: '$overdueTasks overdue',
        deltaPositive: false,
        icon: 'error_outline',
        accent: AppColors.danger.toARGB32(),
      ),
    ];
  }

  List<CategorySlice> _mapCategories(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];

    final slices = rows
        .map((row) {
          final count = _asInt(row['DocumentCount'] ?? row['documentCount']);
          final name = _str(row, 'CategoryName', 'categoryName', fallback: 'Others');
          final percent = _asDouble(
            row['Percentage'] ?? row['percentage'],
            fallback: 0,
          );
          return CategorySlice(
            name: name,
            count: count,
            percent: percent,
          );
        })
        .where((slice) => slice.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return slices;
  }

  List<TrendPoint> _mapTrend(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];

    return rows.map((row) {
      final rawDay = _str(
        row,
        'ReportDate',
        'reportDate',
        extraKeys: ['UploadDay', 'uploadDay'],
      );
      final day = DateTime.tryParse(rawDay);
      final label = day != null ? DateFormat('MMM d').format(day) : rawDay;
      final received = _asInt(
        row['Received'] ?? row['received'],
        fallback: _asInt(row['DocumentCount'] ?? row['documentCount']),
      );
      final processed = _asInt(
        row['Processed'] ?? row['processed'],
        fallback: _asInt(row['ProcessedCount'] ?? row['processedCount']),
      );

      return TrendPoint(
        label: label,
        received: received,
        processed: processed,
      );
    }).toList();
  }

  List<ClientPendingRow> _mapTopClients(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];

    return rows.asMap().entries.map((entry) {
      final row = entry.value;
      final rank = _asInt(row['Rank'] ?? row['rank'], fallback: entry.key + 1);
      final businessName = _str(row, 'BusinessName', 'businessName');
      final clientName = _str(row, 'ClientName', 'clientName');
      final name = businessName.isNotEmpty
          ? businessName
          : (clientName.isNotEmpty ? clientName : 'Client');
      final pending = _asInt(row['PendingTasks'] ?? row['pendingTasks']);
      final docsPending = _asInt(
        row['DocumentsPending'] ?? row['documentsPending'],
        fallback: pending,
      );
      final overdue = _asInt(row['OverdueTasks'] ?? row['overdueTasks']);

      return ClientPendingRow(
        rank: rank,
        clientName: name,
        pendingTasks: pending,
        documentsPending: docsPending,
        overdueTasks: overdue,
      );
    }).toList();
  }

  Future<DashboardData> _loadClient() async {
    final response = await _api.get('/documents/dashboard');
    final stats = response.array1.isNotEmpty ? response.array1.first : <String, dynamic>{};
    final recent = response.array2;

    final total = _asInt(stats['TotalDocuments'] ?? stats['totalDocuments']);
    final pending = _asInt(stats['PendingDocuments'] ?? stats['pendingDocuments']);
    final approved = _asInt(stats['ApprovedDocuments'] ?? stats['approvedDocuments']);

    final kpis = [
      KpiMetric(
        title: 'Total Documents',
        value: _formatNumber(total),
        delta: 'Your uploads',
        deltaPositive: true,
        icon: 'description',
        accent: AppColors.info.toARGB32(),
      ),
      KpiMetric(
        title: 'Pending',
        value: _formatNumber(pending),
        delta: 'Awaiting review',
        deltaPositive: true,
        icon: 'pending_actions',
        accent: AppColors.warning.toARGB32(),
      ),
      KpiMetric(
        title: 'Approved',
        value: _formatNumber(approved),
        delta: 'Completed',
        deltaPositive: true,
        icon: 'task_alt',
        accent: AppColors.success.toARGB32(),
      ),
      KpiMetric(
        title: 'Recent Uploads',
        value: _formatNumber(recent.length),
        delta: 'Latest activity',
        deltaPositive: true,
        icon: 'cloud_upload',
        accent: AppColors.purple.toARGB32(),
      ),
      KpiMetric(
        title: 'In Process',
        value: _formatNumber((total - pending - approved).clamp(0, total)),
        delta: 'Being processed',
        deltaPositive: true,
        icon: 'hourglass_empty',
        accent: AppColors.danger.toARGB32(),
      ),
    ];

    final byCategory = <String, int>{};
    for (final doc in recent) {
      final name = _str(doc, 'CategoryName', 'categoryName', fallback: 'Others');
      byCategory[name] = (byCategory[name] ?? 0) + 1;
    }
    final catTotal = byCategory.values.fold<int>(0, (a, b) => a + b);
    final categories = byCategory.entries.map((e) {
      return CategorySlice(
        name: e.key,
        count: e.value,
        percent: catTotal == 0 ? 0 : (e.value / catTotal) * 100,
      );
    }).toList();

    final now = DateTime.now();
    final trend = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final count = recent.where((d) {
        final uploaded = DateTime.tryParse(_str(d, 'UploadDate', 'uploadDate'));
        if (uploaded == null) return false;
        return uploaded.year == day.year &&
            uploaded.month == day.month &&
            uploaded.day == day.day;
      }).length;
      return TrendPoint(
        label: DateFormat('MMM d').format(day),
        received: count,
        processed: (count * 0.8).round(),
      );
    });

    final topClients = recent.take(5).toList().asMap().entries.map((entry) {
      final doc = entry.value;
      return ClientPendingRow(
        rank: entry.key + 1,
        clientName: _str(doc, 'OriginalFileName', 'originalFileName', fallback: 'Document'),
        pendingTasks: 1,
        documentsPending: 1,
        overdueTasks: 0,
      );
    }).toList();

    return DashboardData(
      kpis: kpis,
      categories: categories,
      trend: trend,
      topClients: topClients,
      pendingApprovals: 0,
      pendingTasksBadge: pending,
      documentsTotal: total,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value'.replaceAll(',', '')) ?? fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '')) ?? fallback;
  }

  static bool _hasAnyKey(Map<String, dynamic> row, List<String> keys) {
    return keys.any(row.containsKey);
  }

  static String _str(
    Map<String, dynamic> row,
    String primary,
    String secondary, {
    List<String> extraKeys = const [],
    String fallback = '',
  }) {
    for (final key in [primary, secondary, ...extraKeys]) {
      final value = row[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
    }
    return fallback;
  }

  static bool _bool(
    Map<String, dynamic> row,
    String primary,
    String secondary, {
    required bool defaultValue,
  }) {
    final value = row[primary] ?? row[secondary];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return defaultValue;
  }

  static String _formatNumber(int value) {
    return NumberFormat('#,###').format(value);
  }
}
