import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.metric});

  final KpiMetric metric;

  IconData get _icon {
    switch (metric.icon) {
      case 'people':
        return Icons.people_alt_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'pending_actions':
        return Icons.pending_actions_outlined;
      case 'task_alt':
        return Icons.task_alt;
      case 'error_outline':
        return Icons.error_outline;
      case 'cloud_upload':
        return Icons.cloud_upload_outlined;
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      default:
        return Icons.analytics_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(metric.accent);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.delta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: metric.deltaPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
