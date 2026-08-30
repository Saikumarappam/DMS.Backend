import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

/// Prompts the signed-in admin for their password before a sensitive action.
/// Returns `true` when the password is verified, `false` if cancelled.
Future<bool> showAdminPasswordDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  var obscure = true;
  var verifying = false;
  String? errorText;

  try {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final password = passwordController.text;
              if (password.isEmpty) {
                setState(() => errorText = 'Please enter your password.');
                return;
              }

              setState(() {
                verifying = true;
                errorText = null;
              });

              final error = await context.read<AuthProvider>().verifyPassword(password);

              if (!context.mounted) return;

              if (error != null) {
                setState(() {
                  verifying = false;
                  errorText = error;
                });
                return;
              }

              Navigator.pop(dialogContext, true);
            }

            return AlertDialog(
              title: const Text('Confirm Password'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your admin password to continue.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      autofocus: true,
                      enabled: !verifying,
                      textInputAction: TextInputAction.done,
                      onSubmitted: verifying ? null : (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                        suffixIcon: IconButton(
                          onPressed: verifying
                              ? null
                              : () => setState(() => obscure = !obscure),
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verifying ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: verifying ? null : submit,
                  child: verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    return verified == true;
  } finally {
    passwordController.dispose();
  }
}
