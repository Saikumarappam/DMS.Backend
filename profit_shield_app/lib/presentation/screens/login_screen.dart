import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/biometric_auth_service.dart';
import '../../core/auth/biometric_login_helper.dart';
import '../../core/storage/remember_me_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/pan_input.dart';
import '../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _isSubmitting = false;
  bool _rememberMe = false;
  bool _prefsLoaded = false;
  bool _biometricAvailable = false;
  bool _showUsernameHint = false;
  bool _showPasswordHint = false;
  String? _savedUserId;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_onUsernameFocusChanged);
    _passwordFocus.addListener(_onPasswordFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRememberMe();
    });
  }

  Future<void> _loadRememberMe() async {
    final prefs = await ref.read(rememberMeStorageProvider).load();
    final biometricAvailable =
        await ref.read(biometricAuthServiceProvider).hasEnrolledBiometrics();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.enabled;
      _savedUserId = prefs.userId;
      _savedPassword = prefs.password;
      _biometricAvailable = biometricAvailable;
      _prefsLoaded = true;
    });

    if (BiometricLoginHelper.shouldAutoLogin(
      prefs: prefs,
      biometricAvailable: biometricAvailable,
    )) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _loginWithBiometric(autoPrompt: true);
    }
  }

  void _onUsernameFocusChanged() {
    if (_usernameFocus.hasFocus) _revealUsernameHint();
  }

  void _onPasswordFocusChanged() {
    if (_passwordFocus.hasFocus) _revealPasswordHint();
  }

  void _revealUsernameHint() {
    if (!_prefsLoaded || _savedUserId == null || _usernameController.text.isNotEmpty) {
      return;
    }
    setState(() => _showUsernameHint = true);
  }

  void _revealPasswordHint() {
    if (!_prefsLoaded ||
        _savedPassword == null ||
        _savedPassword!.isEmpty ||
        _passwordController.text.isNotEmpty) {
      return;
    }
    setState(() => _showPasswordHint = true);
  }

  void _applySavedUsername() {
    if (_savedUserId == null) return;
    setState(() {
      _usernameController.text = _savedUserId!;
      _showUsernameHint = false;
    });
  }

  void _applySavedPassword() {
    if (_savedPassword == null || _savedPassword!.isEmpty) return;
    setState(() {
      _passwordController.text = _savedPassword!;
      _showPasswordHint = false;
    });
  }

  void _onUsernameChanged(String _) {
    setState(() {
      if (_usernameController.text.isNotEmpty) {
        _showUsernameHint = false;
      }
    });
  }

  void _onPasswordChanged(String _) {
    setState(() {
      if (_passwordController.text.isNotEmpty) {
        _showPasswordHint = false;
      }
    });
  }

  String _maskUserId(String userId) {
    final value = userId.trim();
    if (value.length <= 2) return '••••';
    if (value.length <= 4) {
      return '${value[0]}${'•' * (value.length - 1)}';
    }
    return '${value.substring(0, 2)}${'•' * (value.length - 4)}${value.substring(value.length - 2)}';
  }

  String _maskPassword(String password) {
    final length = password.length.clamp(6, 12);
    return '•' * length;
  }

  Future<void> _persistRememberMe(String userId, String password) async {
    final biometricAvailable = _biometricAvailable ||
        await ref.read(biometricAuthServiceProvider).hasEnrolledBiometrics();
    await ref.read(rememberMeStorageProvider).save(
          enabled: _rememberMe,
          userId: _rememberMe ? userId : null,
          password: _rememberMe ? password : null,
          biometricEnabled: _rememberMe && biometricAvailable,
        );
  }

  Future<void> _loginWithBiometric({bool autoPrompt = false}) async {
    if (_isSubmitting) return;
    if (_savedUserId == null || _savedPassword == null || _savedPassword!.isEmpty) {
      if (!autoPrompt && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save login with Remember me first.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final authenticated = await ref.read(biometricAuthServiceProvider).authenticate(
          reason: BiometricLoginHelper.signInReason,
        );
    if (!authenticated || !mounted) return;

    setState(() => _isSubmitting = true);
    final success = await ref.read(authProvider.notifier).login(
          _savedUserId!,
          _savedPassword!,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      await _persistRememberMe(_savedUserId!, _savedPassword!);
      if (!mounted) return;
      // Router redirect runs when auth state becomes authenticated.
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Fingerprint sign-in failed.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final userId = _usernameController.text.trim().toUpperCase();
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);

    final success = await ref.read(authProvider.notifier).login(userId, password);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      await _persistRememberMe(userId, password);
      if (!mounted) return;
      // Router redirect runs when auth state becomes authenticated.
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Invalid user name or password'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showUsernameSuggestion =
        _showUsernameHint && _savedUserId != null && _usernameController.text.isEmpty;
    final showPasswordSuggestion = _showPasswordHint &&
        _savedPassword != null &&
        _savedPassword!.isNotEmpty &&
        _passwordController.text.isEmpty;

    return AuthScaffold(
      style: AuthScaffoldStyle.wave,
      title: 'Welcome Back!',
      subtitle: 'Sign in to continue to ProfitShield',
      footer: AuthLinkRow(
        prompt: "Don't have an account?",
        action: 'Create Account',
        onTap: _isSubmitting ? () {} : () => context.push('/register'),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(
                ignoring: _isSubmitting || !_prefsLoaded,
                child: AuthTextField(
                  fieldKey: ValueKey(PanInput.keyboardKeyFor(_usernameController.text)),
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  autofillHints: const [AutofillHints.username],
                  label: 'User Name',
                  hint: 'Enter your PAN Number',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: PanInput.keyboardTypeFor(_usernameController.text),
                  inputFormatters: const [PanInputFormatter()],
                  onTap: _revealUsernameHint,
                  onChanged: _onUsernameChanged,
                  validator: Validators.pan,
                ),
              ),
              if (showUsernameSuggestion) ...[
                const SizedBox(height: 8),
                _SavedFieldSuggestion(
                  icon: Icons.badge_outlined,
                  title: 'Saved user name',
                  value: _maskUserId(_savedUserId!),
                  onTap: _isSubmitting ? null : _applySavedUsername,
                ),
              ],
              const SizedBox(height: 20),
              IgnorePointer(
                ignoring: _isSubmitting,
                child: AuthTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  autofillHints: const [AutofillHints.password],
                  label: 'Password',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  onTap: _revealPasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: _isSubmitting ? null : () => setState(() => _obscure = !_obscure),
                  ),
                  onChanged: _onPasswordChanged,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Password is required' : null,
                ),
              ),
              if (showPasswordSuggestion) ...[
                const SizedBox(height: 8),
                _SavedFieldSuggestion(
                  icon: Icons.lock_outline_rounded,
                  title: 'Saved password',
                  value: _maskPassword(_savedPassword!),
                  onTap: _isSubmitting ? null : _applySavedPassword,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.darkBlue,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                                _rememberMe = value ?? false;
                              }),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() {
                                _rememberMe = !_rememberMe;
                              }),
                      child: const Text(
                        'Remember me',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => context.push('/forgot-password'),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: 'Sign In',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedFieldSuggestion extends StatelessWidget {
  const _SavedFieldSuggestion({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Use',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
