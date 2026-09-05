import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/dashboard_models.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.metric, this.onTap});

  final KpiMetric metric;
  final VoidCallback? onTap;

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
    final scale = AppScale.of(context);
    final iconBox = scale.isMobile ? 32.0 : 36.0;
    final card = Container(
      padding: EdgeInsets.fromLTRB(
        scale.cardPadding,
        scale.cardPadding,
        scale.cardPadding,
        scale.isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scale.radius),
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
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: accent, size: scale.iconMd),
          ),
          SizedBox(height: scale.gap),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: scale.caption,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: TextStyle(
                fontSize: scale.isMobile ? 20 : 24,
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
              fontSize: scale.caption,
              fontWeight: FontWeight.w500,
              color: metric.deltaPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radius),
        child: card,
      ),
    );
  }
}
