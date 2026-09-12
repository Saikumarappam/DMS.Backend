import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/pan_input.dart';
import '../../core/utils/validators.dart';
import '../../data/models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _panController = TextEditingController();
  final _businessController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  TextInputType get _panKeyboard =>
      PanInput.keyboardTypeFor(_panController.text);

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _panController.dispose();
    _businessController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final contactName = _nameController.text.trim();
    final pan = _panController.text.trim().toUpperCase();

    final message = await ref.read(authProvider.notifier).register(
          RegisterRequest(
            name: contactName,
            mobileNumber: _mobileController.text.trim(),
            email: _emailController.text.trim(),
            panNumber: pan,
            password: _passwordController.text,
            address: _addressController.text.trim(),
            businessName: _businessController.text.trim(),
            contactPersonName: contactName,
            gstNumber: _gstController.text.trim().isEmpty
                ? null
                : _gstController.text.trim().toUpperCase(),
          ),
        );

    if (!mounted) return;

    if (message != null && !message.toLowerCase().contains('success') &&
        !message.toLowerCase().contains('approval') &&
        !message.toLowerCase().contains('awaiting')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
        ),
        title: const Text('Registration Submitted'),
        content: Text(
          message ??
              'Your account has been submitted. Sign in with your User ID (PAN: $pan) and password after admin approval.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: AuthPrimaryButton(
              label: 'Go to Login',
              onPressed: () {
                Navigator.pop(context);
                context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Create Account',
      subtitle: 'Register your business on ProfitShield',
      footer: AuthLinkRow(
        prompt: 'Already have an account?',
        action: 'Sign In',
        onTap: () => context.go('/login'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your PAN number is your User ID. Use it to sign in after approval.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            AuthTextField(
              controller: _nameController,
              label: 'Contact Person Name',
              hint: 'Saikumar',
              prefixIcon: Icons.badge_outlined,
              validator: Validators.required,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _businessController,
              label: 'Business Name',
              hint: 'SK Traders Limited',
              prefixIcon: Icons.business_outlined,
              validator: Validators.required,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              fieldKey: ValueKey(PanInput.keyboardKeyFor(_panController.text)),
              controller: _panController,
              label: 'User ID (PAN Number)',
              hint: 'JOGPK0219N',
              prefixIcon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.characters,
              keyboardType: _panKeyboard,
              inputFormatters: const [PanInputFormatter()],
              onChanged: (_) => setState(() {}),
              validator: Validators.pan,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _mobileController,
              label: 'Mobile Number',
              hint: '10-digit mobile number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.mobile,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'you@company.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Bapunagar, Hyderabad, Telangana',
              prefixIcon: Icons.location_on_outlined,
              maxLines: 2,
              validator: Validators.required,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _gstController,
              label: 'GSTIN (optional)',
              hint: '07ABCDE1234F2Z5',
              prefixIcon: Icons.receipt_long_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: Validators.gst,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
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
              hint: 'Re-enter your password',
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
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: 'Create Account',
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
