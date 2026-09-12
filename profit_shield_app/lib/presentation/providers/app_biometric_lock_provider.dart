import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blocks the UI until fingerprint unlock succeeds after returning to the app.
final appBiometricLockProvider = StateProvider<bool>((ref) => false);
