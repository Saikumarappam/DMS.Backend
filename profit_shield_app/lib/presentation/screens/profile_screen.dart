import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user_models.dart';
import '../providers/auth_provider.dart';
import '../providers/upload_flow_provider.dart';
import '../widgets/profile_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    if (!ref.read(authProvider).isAuthenticated) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final error = await ref.read(authProvider.notifier).refreshProfile();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    if (!auth.isAuthenticated) {
      return const SizedBox.shrink();
    }

    if (_isLoading && user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError ?? 'Profile not available.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadProfile, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.surface,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            children: [
              if (_loadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    friendlyApiError(_loadError!),
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
              _ProfileHeader(user: user),
              const SizedBox(height: 16),
              _AdminNoticeBanner(),
              const SizedBox(height: 16),
              _ProfileDetailsCard(user: user),
              const SizedBox(height: 24),
              _LogoutButton(
                onTap: () async {
                  resetClientSession(ref);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final business = user.businessName ?? user.name;
    final isActive = user.userStatus.toLowerCase() == 'active' ||
        user.userStatus.toLowerCase() == 'approved';

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initialsFromName(user.name),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          business,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.successLight : AppColors.warningLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                size: 16,
                color: isActive ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? 'Active' : user.userStatus,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.info, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Editable only by ProfitShield admin. Contact us to update details.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      ProfileInfoTile(
        icon: Icons.badge_outlined,
        label: 'User ID (PAN)',
        value: user.userLoginId,
        isFirst: true,
      ),
      ProfileInfoTile(
        icon: Icons.business_rounded,
        label: 'Business Name',
        value: user.businessName ?? user.name,
      ),
      if (user.email.isNotEmpty)
        ProfileInfoTile(icon: Icons.email_outlined, label: 'Email', value: user.email),
      if (user.address != null && user.address!.isNotEmpty)
        ProfileInfoTile(icon: Icons.location_on_outlined, label: 'Address', value: user.address!),
      if (user.gstNumber != null && user.gstNumber!.isNotEmpty)
        ProfileInfoTile(icon: Icons.receipt_long_outlined, label: 'GSTIN', value: user.gstNumber!),
      ProfileInfoTile(icon: Icons.person_outline_rounded, label: 'Contact Person', value: user.contactPersonName ?? user.name),
      ProfileInfoTile(icon: Icons.phone_outlined, label: 'Mobile Number', value: '+91 ${user.mobileNumber}', isLast: true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sky),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Column(children: tiles)),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
        label: const Text('Log out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.errorLight.withValues(alpha: 0.5),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
