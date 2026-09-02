import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:profit_shield_web/core/error/app_error_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/browser_title.dart';
import '../../../core/widgets/app_splash_loader.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      username: _usernameController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    if (ok) context.go('/dashboard');
  }

  Future<void> _showForgotPassword() async {
    final emailController = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot Password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter registered email',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    final error = await context.read<AuthProvider>().forgotPassword(
      emailController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'If the email exists, an OTP has been sent.'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    setBrowserTitle('Login');
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 480 ? width - 32 : 420.0;

    return Scaffold(
      body: Stack(
        children: [
          const _LoginBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'User Name',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your PAN Number',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your PAN or username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Password',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.textMuted,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Please enter your password';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Remember me',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _showForgotPassword,
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.link,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (auth.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    AppErrorHandler.getErrorMessage(
                                      auth.errorMessage!,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],

                              // if (auth.errorMessage != null) ...[
                              //   const SizedBox(height: 12),
                              //   Container(
                              //     padding: const EdgeInsets.all(12),
                              //     decoration: BoxDecoration(
                              //       color: AppColors.danger.withValues(
                              //         alpha: 0.08,
                              //       ),
                              //       borderRadius: BorderRadius.circular(8),
                              //       border: Border.all(
                              //         color: AppColors.danger.withValues(
                              //           alpha: 0.3,
                              //         ),
                              //       ),
                              //     ),
                              //     child: Text(
                              //       auth.errorMessage!,
                              //       style: const TextStyle(color: AppColors.danger, fontSize: 13),
                              //     ),
                              //   ),
                              // ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: auth.isLoading ? null : _submit,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign In'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (auth.isLoading)
            const Positioned.fill(child: AppLoadingOverlay()),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(AppAssets.logoFull2, height: 120, fit: BoxFit.contain),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.navy),
        CustomPaint(painter: _DotsPainter()),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.28,
            width: double.infinity,
            child: CustomPaint(painter: _WavePainter()),
          ),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = AppColors.gold.withValues(alpha: 0.25);
    final silver = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final positions = [
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.85, size.height * 0.12),
      Offset(size.width * 0.2, size.height * 0.55),
      Offset(size.width * 0.9, size.height * 0.48),
      Offset(size.width * 0.08, size.height * 0.75),
      Offset(size.width * 0.75, size.height * 0.7),
    ];
    for (var i = 0; i < positions.length; i++) {
      canvas.drawCircle(
        positions[i],
        i.isEven ? 3 : 2.5,
        i.isEven ? gold : silver,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: positions[i] + const Offset(18, -10),
          width: 6,
          height: 6,
        ),
        i.isEven ? silver : gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final goldLine = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.58,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, fill);

    final line = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.58,
        size.width,
        size.height * 0.28,
      );
    canvas.drawPath(line, goldLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
