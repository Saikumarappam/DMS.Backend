class KpiMetric {
  const KpiMetric({
    required this.title,
    required this.value,
    required this.delta,
    required this.deltaPositive,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String delta;
  final bool deltaPositive;
  final String icon; // material icon name key
  final int accent; // ARGB
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.count,
    required this.percent,
  });

  final String name;
  final int count;
  final double percent;
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.received,
    required this.processed,
  });

  final String label;
  final int received;
  final int processed;
}

class ClientPendingRow {
  const ClientPendingRow({
    required this.rank,
    required this.clientName,
    required this.pendingTasks,
    required this.documentsPending,
    required this.overdueTasks,
  });

  final int rank;
  final String clientName;
  final int pendingTasks;
  final int documentsPending;
  final int overdueTasks;
}

class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.categories,
    required this.trend,
    required this.topClients,
    required this.pendingApprovals,
    required this.pendingTasksBadge,
    required this.documentsTotal,
  });

  final List<KpiMetric> kpis;
  final List<CategorySlice> categories;
  final List<TrendPoint> trend;
  final List<ClientPendingRow> topClients;
  final int pendingApprovals;
  final int pendingTasksBadge;
  final int documentsTotal;

  factory DashboardData.empty() => const DashboardData(
        kpis: [],
        categories: [],
        trend: [],
        topClients: [],
        pendingApprovals: 0,
        pendingTasksBadge: 0,
        documentsTotal: 0,
      );
}
