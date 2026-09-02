import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_service.dart';
import 'design/app_theme.dart';
import 'screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  ApiService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.apiService});

  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baquero Notes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: LoginPage(apiService: apiService ?? ApiService.instance),
    );
  }
}
