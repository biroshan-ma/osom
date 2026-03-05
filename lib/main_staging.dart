import 'package:flutter/material.dart';
import 'core/env/app_config.dart';
import 'app_entry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.staging();
  runApp(AppEntry(config: config));
}
