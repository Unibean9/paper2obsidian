import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'screens/main_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseService.initializeFfi();
  await EnvConfig.load();
  runApp(const PaperToObsidianApp());
}

class PaperToObsidianApp extends StatelessWidget {
  const PaperToObsidianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyperdatalab - P2O',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainScreen(),
    );
  }
}
