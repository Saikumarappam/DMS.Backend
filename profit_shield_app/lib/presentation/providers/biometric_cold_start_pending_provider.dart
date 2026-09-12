import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the app on splash until cold-start fingerprint unlock finishes.
final biometricColdStartPendingProvider = StateProvider<bool>((ref) => true);
