import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.total,
  });

  final List<CategorySlice> slices;
  final int total;

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final data = widget.slices.isEmpty
        ? const [CategorySlice(name: 'No data', count: 1, percent: 100)]
        : widget.slices.take(6).toList();

    return _ChartCard(
      title: 'Documents by Category',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 300;
          final chartSize = narrow
              ? 150.0
              : (constraints.maxWidth < 380 ? 170.0 : 200.0);
          final chart = SizedBox(
            height: chartSize,
            width: chartSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: chartSize * 0.26,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions) return;
                        setState(() {
                          final section = response?.touchedSection;
                          _touchedIndex = section?.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < data.length; i++)
                        PieChartSectionData(
                          value: data[i].count.toDouble().clamp(0.1, double.infinity),
                          color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                          radius: _touchedIndex == i
                              ? chartSize * 0.19
                              : chartSize * 0.17,
                          showTitle: false,
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 180),
                ),
                if (_touchedIndex != null &&
                    _touchedIndex! >= 0 &&
                    _touchedIndex! < data.length)
                  Positioned(
                    top: -8,
                    child: _CategoryTooltip(
                      slice: data[_touchedIndex!],
                      color: AppColors
                          .chartPalette[_touchedIndex! % AppColors.chartPalette.length],
                    ),
                  ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _format(widget.total),
                        style: TextStyle(
                          fontSize: narrow ? 18 : 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < data.length; i++)
                MouseRegion(
                  onEnter: (_) => setState(() => _touchedIndex = i),
                  onExit: (_) => setState(() => _touchedIndex = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data[i].name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: _touchedIndex == i
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  _touchedIndex == i ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '${data[i].percent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _touchedIndex == i
                                ? AppColors.textPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );

          if (narrow) {
            return Column(
              children: [
                chart,
                const SizedBox(height: 12),
                legend,
              ],
            );
          }

          return Row(
            children: [
              chart,
              const SizedBox(width: 16),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }

  static String _format(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'.replaceAll('.0k', 'k');
    }
    return '$value';
  }
}

class _CategoryTooltip extends StatelessWidget {
  const _CategoryTooltip({
    required this.slice,
    required this.color,
  });

  final CategorySlice slice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slice.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slice.count} docs • ${slice.percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
