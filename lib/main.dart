import 'dart:io';

import 'package:flutter/material.dart';
import 'screens/scanner_screen.dart';
import 'screens/listener_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the home screen based on platform
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final Widget homeScreen = isMobile
        ? const ScannerScreen()
        : const ListenerScreen();

    return MaterialApp(
      title: 'Network QR Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: homeScreen,
    );
  }
}
