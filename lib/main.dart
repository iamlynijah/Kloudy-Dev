import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'theme/kloudy_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KloudyApp());
}

class KloudyApp extends StatelessWidget {
  const KloudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kloudy',
      theme: originalThemeData,
      home: const AuthGate(),
    );
  }
}
