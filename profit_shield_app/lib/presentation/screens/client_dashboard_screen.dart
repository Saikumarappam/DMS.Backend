import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_upload_stats.dart';
import '../../data/mock/mock_category_data.dart';
import '../providers/category_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/upload_flow_provider.dart';
import '../widgets/dashboard_hero_header.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDashboard);
  }

  Future<void> _loadDashboard() async {
    await Future.wait([
      ref.read(dashboardProvider.notifier).loadClientDashboard(),
      ref.read(categoryProvider.notifier).load(),
    ]);
    ref.invalidate(documentFullHistoryProvider);
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(dashboardProvider.notifier).loadClientDashboard(),
      ref.read(categoryProvider.notifier).load(),
    ]);
    ref.invalidate(documentFullHistoryProvider);
    ref.invalidate(documentHistoryProvider);
    ref.invalidate(documentInvoiceNumbersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final categoryState = ref.watch(categoryProvider);
    final historyAsync = ref.watch(documentFullHistoryProvider);
    final dashboard = dashState.dashboard;
    final categories = categoryState.categories.where((c) => c.isActive).toList();
    final history = historyAsync.valueOrNull ?? const [];
    final dayFormat = DateFormat('dd MMM yyyy');

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardHeroHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                const Text(
                  'Upload documents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: const Text(
                    'Choose a category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldDark,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: dashState.isLoading && dashboard == null && categories.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : dashState.error != null && dashboard == null && categories.isEmpty
                    ? _DashboardError(
                        message: dashState.error!,
                        onRetry: _refresh,
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _refresh,
                        child: categories.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'No categories available',
                                      style: TextStyle(color: AppColors.textMuted),
                                    ),
                                  ),
                                ],
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                                physics: const AlwaysScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.12,
                                ),
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final latestUpload =
                                      CategoryUploadStats.latestUploadDateForCategory(
                                    category.categoryId,
                                    history,
                                  );
                                  final docCount =
                                      CategoryUploadStats.invoiceCountForCategory(
                                    category.categoryId,
                                    history,
                                  );
                                  final accent = MockCategoryData.accentFor(index);

                                  return _CategoryCard(
                                    title: category.categoryName,
                                    latestUploadLabel: latestUpload != null
                                        ? dayFormat.format(latestUpload)
                                        : 'No uploads yet',
                                    docCount: docCount,
                                    icon: MockCategoryData.iconFor(category.categoryName),
                                    accent: accent,
                                    onTap: () => context.push(
                                      '/upload/category/${category.categoryId}',
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.latestUploadLabel,
    required this.docCount,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String latestUploadLabel;
  final int docCount;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final docLabel = '$docCount doc${docCount == 1 ? '' : 's'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 14,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latestUploadLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          docLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withValues(alpha: 0.35)),
                            color: accent.withValues(alpha: 0.06),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
