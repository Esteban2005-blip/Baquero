import 'package:flutter/material.dart';

import 'api_service.dart';
import 'design/app_theme.dart';
import 'screens/login_page.dart';
import 'screens/notes_page.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Session?> _session = widget.apiService.storage.read();
  @override
  Widget build(BuildContext context) => FutureBuilder<Session?>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final session = snapshot.data;
      return session == null
          ? LoginPage(apiService: widget.apiService)
          : NotesPage(apiService: widget.apiService, session: session);
    },
  );
}
