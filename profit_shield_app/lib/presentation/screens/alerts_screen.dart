import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stay updated on your document status',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: const [
                  _AlertCard(
                    icon: Icons.check_circle_outline,
                    title: 'Document Approved',
                    message: 'Your Sales invoice was marked as Completed.',
                    time: '2 hours ago',
                    color: AppColors.success,
                    bg: AppColors.successLight,
                  ),
                  SizedBox(height: 8),
                  _AlertCard(
                    icon: Icons.info_outline,
                    title: 'Upload Reminder',
                    message: 'Upload your monthly Purchases documents.',
                    time: 'Yesterday',
                    color: AppColors.info,
                    bg: AppColors.infoLight,
                  ),
                  SizedBox(height: 8),
                  _AlertCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Welcome to ProfitShield',
                    message: 'Your account is active. Start uploading documents.',
                    time: 'Just now',
                    color: AppColors.primary,
                    bg: AppColors.sky,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sky),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
