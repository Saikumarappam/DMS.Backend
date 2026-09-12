import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../providers/password_recovery_provider.dart';
import '../widgets/auth/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(passwordRecoveryProvider.notifier);
    final step = ref.read(passwordRecoveryProvider).step;
    String? error;

    switch (step) {
      case RecoveryStep.requestOtp:
        final message = await notifier.requestOtp(_emailController.text);
        if (!mounted) return;
        if (message != null && ref.read(passwordRecoveryProvider).step == RecoveryStep.requestOtp) {
          _showError(message);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'OTP sent to your email.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;

      case RecoveryStep.verifyOtp:
        error = await notifier.verifyOtp(_otpController.text);
        if (!mounted) return;
        if (error != null) {
          _showError(error);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified. Set your new password.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;

      case RecoveryStep.resetPassword:
        error = await notifier.resetPassword(
          newPassword: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
        if (!mounted) return;
        if (error != null) {
          _showError(error);
          return;
        }
        notifier.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully. Please sign in.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/login');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _handleBack(PasswordRecoveryState recovery) {
    if (recovery.step == RecoveryStep.requestOtp) {
      ref.read(passwordRecoveryProvider.notifier).reset();
      context.go('/login');
      return;
    }
    ref.read(passwordRecoveryProvider.notifier).goBack();
  }

  @override
  Widget build(BuildContext context) {
    final recovery = ref.watch(passwordRecoveryProvider);

    if (recovery.email.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = recovery.email;
    }

    return AuthScaffold(
      showBack: true,
      title: _titleFor(recovery.step),
      subtitle: _subtitleFor(recovery.step),
      footer: AuthLinkRow(
        prompt: 'Remember your password?',
        action: 'Sign In',
        onTap: () {
          ref.read(passwordRecoveryProvider.notifier).reset();
          context.go('/login');
        },
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicator(current: recovery.step),
            const SizedBox(height: 24),
            ..._fieldsFor(recovery.step),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: _buttonLabel(recovery.step),
              isLoading: recovery.isLoading,
              onPressed: recovery.isLoading ? null : _submit,
            ),
            if (recovery.step != RecoveryStep.requestOtp) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: recovery.isLoading ? null : () => _handleBack(recovery),
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titleFor(RecoveryStep step) => switch (step) {
        RecoveryStep.requestOtp => 'Forgot Password',
        RecoveryStep.verifyOtp => 'Verify OTP',
        RecoveryStep.resetPassword => 'Reset Password',
      };

  String _subtitleFor(RecoveryStep step) => switch (step) {
        RecoveryStep.requestOtp =>
          'Enter your registered email. We will send an OTP to reset your password.',
        RecoveryStep.verifyOtp =>
          'Enter the OTP sent to your email address.',
        RecoveryStep.resetPassword =>
          'Create a new strong password for your account.',
      };

  String _buttonLabel(RecoveryStep step) => switch (step) {
        RecoveryStep.requestOtp => 'Send OTP',
        RecoveryStep.verifyOtp => 'Verify OTP',
        RecoveryStep.resetPassword => 'Update Password',
      };

  List<Widget> _fieldsFor(RecoveryStep step) {
    switch (step) {
      case RecoveryStep.requestOtp:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.mail_outline_rounded, color: AppColors.info),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use the same email you registered with on ProfitShield.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'you@company.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
        ];

      case RecoveryStep.verifyOtp:
        return [
          AuthTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'you@company.com',
            prefixIcon: Icons.email_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 18),
          AuthTextField(
            controller: _otpController,
            label: 'OTP Code',
            hint: 'Enter 6-digit OTP',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            validator: Validators.otp,
          ),
        ];

      case RecoveryStep.resetPassword:
        return [
          AuthTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'you@company.com',
            prefixIcon: Icons.email_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 18),
          AuthTextField(
            controller: _passwordController,
            label: 'New Password',
            hint: 'Min 8 chars: upper, lower, digit, special',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 18),
          AuthTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter new password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (value) =>
                Validators.confirmPassword(value, _passwordController.text),
          ),
        ];
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final RecoveryStep current;

  @override
  Widget build(BuildContext context) {
    final steps = RecoveryStep.values;
    final index = steps.indexOf(current);

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= index ? AppColors.primary : AppColors.sky,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
