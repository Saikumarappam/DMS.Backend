import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_store_plus/media_store_plus.dart';

import 'core/config/env_config.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();

  if (Platform.isAndroid) {
    MediaStore.appFolder = 'ProfitShield';
    await MediaStore.ensureInitialized();
  }

  runApp(
    const ProviderScope(
      child: DmsApp(),
    ),
  );
}
