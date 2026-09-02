import 'package:flutter/material.dart';

import '../api_service.dart';
import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../design/app_tokens.dart';
import 'component_catalog_page.dart';
import 'notes_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session = await widget.apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NotesPage(apiService: widget.apiService, session: session),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final form = Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(AppTokens.space8),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: tokens.outline),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Inicia sesión', style: textTheme.headlineMedium),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      'Accede a tus notas seguras desde la API.',
                      style: textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
                    ),
                    const SizedBox(height: AppTokens.space6),
                    AppTextField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      hint: 'nombre@ejemplo.com',
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
                      label: 'Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      validator: (value) => (value ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppTokens.space4),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTokens.space3),
                          decoration: BoxDecoration(
                            color: tokens.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            border: Border.all(color: tokens.error),
                          ),
                          child: Text(_error!, style: textTheme.bodyMedium?.copyWith(color: tokens.error)),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space6),
                    AppButton(
                      label: 'Iniciar sesión',
                      icon: Icons.login,
                      isLoading: _isLoading,
                      onPressed: _login,
                      expand: true,
                    ),
                    const SizedBox(height: AppTokens.space3),
                    AppButton(
                      label: 'Crear una cuenta',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RegisterPage(apiService: widget.apiService),
                        ),
                      ),
                      expand: true,
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ComponentCatalogPage()),
                        ),
                        icon: const Icon(Icons.widgets_outlined),
                        label: const Text('Ver catálogo de componentes'),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final hero = Semantics(
              header: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Icon(Icons.note_alt_outlined, color: tokens.onPrimary, size: AppTokens.space12),
                  ),
                  const SizedBox(height: AppTokens.space6),
                  Text('Baquero Notes', style: textTheme.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppTokens.space3),
                  Text(
                    'Tus ideas organizadas, accesibles y protegidas.',
                    style: textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
                    textAlign: wide ? TextAlign.start : TextAlign.center,
                  ),
                ],
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - AppTokens.space12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppTokens.contentMaxWidth),
                    child: wide
                        ? Row(
                            children: <Widget>[
                              Expanded(child: hero),
                              const SizedBox(width: AppTokens.space12),
                              Expanded(child: form),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              hero,
                              const SizedBox(height: AppTokens.space8),
                              form,
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
