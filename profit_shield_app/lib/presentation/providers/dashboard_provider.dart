import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_models.dart';
import '../../data/repositories/document_repository.dart';

class DashboardState {
  const DashboardState({
    this.dashboard,
    this.dailyReports = const [],
    this.auditLogs = const [],
    this.isLoading = false,
    this.error,
  });

  final DashboardModel? dashboard;
  final List<ReportItemModel> dailyReports;
  final List<AuditLogModel> auditLogs;
  final bool isLoading;
  final String? error;

  DashboardState copyWith({
    DashboardModel? dashboard,
    List<ReportItemModel>? dailyReports,
    List<AuditLogModel>? auditLogs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      dashboard: dashboard ?? this.dashboard,
      dailyReports: dailyReports ?? this.dailyReports,
      auditLogs: auditLogs ?? this.auditLogs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository) : super(const DashboardState());

  final DocumentRepository _repository;

  Future<void> loadClientDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getDashboard();
    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return;
    }
    state = state.copyWith(
      isLoading: false,
      dashboard: result.data,
    );
  }

  void reset() => state = const DashboardState();

  Future<void> loadAdminDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final daily = await _repository.getDailyReport(from: from, to: now);
    final audit = await _repository.getAuditLogs(from: from, to: now);

    if (!daily.success) {
      state = state.copyWith(isLoading: false, error: daily.errorMessage);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      dailyReports: daily.data ?? [],
      auditLogs: audit.data ?? [],
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.read(documentRepositoryProvider));
});
