import 'package:flutter/material.dart';

import '../api_service.dart';
import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../design/app_tokens.dart';
import 'notes_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.apiService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => NotesPage(apiService: widget.apiService, session: session),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space6),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.all(AppTokens.space8),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: tokens.outline),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Empieza a organizar tus ideas', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      'La contraseña debe tener 8 caracteres, mayúscula, minúscula, número y símbolo.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
                    ),
                    const SizedBox(height: AppTokens.space6),
                    AppTextField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) return 'Ingresa un correo válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTokens.space4),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Contraseña segura',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.length < 8) return 'Usa al menos 8 caracteres';
                        if (!RegExp(r'[A-Z]').hasMatch(password) ||
                            !RegExp(r'[a-z]').hasMatch(password) ||
                            !RegExp(r'[0-9]').hasMatch(password) ||
                            !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                          return 'Incluye mayúscula, minúscula, número y símbolo';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppTokens.space4),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.error)),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space6),
                    AppButton(
                      label: 'Crear cuenta',
                      icon: Icons.person_add_alt,
                      onPressed: _register,
                      isLoading: _loading,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
