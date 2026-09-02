import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_service.dart';
import 'design/app_theme.dart';
import 'screens/login_page.dart';
import 'screens/notes_page.dart';
import 'session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(MyApp(apiService: ApiService()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baquero Notes',
      theme: AppTheme.light(),
      home: SessionGate(apiService: apiService),
    );
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.apiService});

  final ApiService apiService;

  Future<Widget> _initialPage() async {
    try {
      final session = await SessionStorage().read();
      if (session != null) {
        return NotesPage(apiService: apiService, session: session);
      }
    } on Object {
      return LoginPage(apiService: apiService);
    }
    return LoginPage(apiService: apiService);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialPage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoginPage(apiService: apiService);
        return snapshot.data!;
      },
    );
  }
}
