import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../components/note_card.dart';
import '../components/state_panel.dart';
import '../design/app_tokens.dart';
import '../note.dart';

class ComponentCatalogPage extends StatefulWidget {
  const ComponentCatalogPage({super.key});

  @override
  State<ComponentCatalogPage> createState() => _ComponentCatalogPageState();
}

class _ComponentCatalogPageState extends State<ComponentCatalogPage> {
  final _sampleController = TextEditingController(text: 'Ejemplo editable');
  final _disabledController = TextEditingController(text: 'No editable');

  @override
  void dispose() {
    _sampleController.dispose();
    _disabledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de componentes')),
      body: SafeArea(
        child: TickerMode(
          enabled: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppTokens.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Sistema Baquero', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Inventario vivo de tokens, interfaz pública y estados. Todos estos componentes se usan en las pantallas reales.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
                      ),
                      const SizedBox(height: AppTokens.space8),
                      _CatalogSection(
                        title: 'Tokens de color',
                        purpose: 'Centralizan las decisiones visuales y evitan colores fijos fuera del tema.',
                        interfaceText: 'AppTokens.of(context): primary, surface, text, textMuted, success, warning y error.',
                        states: 'Un único tema claro; preparado como ThemeExtension para evolucionar sin cambiar componentes.',
                        child: Wrap(
                          spacing: AppTokens.space3,
                          runSpacing: AppTokens.space3,
                          children: <Widget>[
                            _Swatch(label: 'Primario', color: tokens.primary, foreground: tokens.onPrimary),
                            _Swatch(label: 'Superficie', color: tokens.surface, foreground: tokens.text),
                            _Swatch(label: 'Texto', color: tokens.text, foreground: tokens.onPrimary),
                            _Swatch(label: 'Éxito', color: tokens.success, foreground: tokens.onPrimary),
                            _Swatch(label: 'Advertencia', color: tokens.warning, foreground: tokens.onPrimary),
                            _Swatch(label: 'Error', color: tokens.error, foreground: tokens.onPrimary),
                          ],
                        ),
                      ),
                      _CatalogSection(
                        title: 'AppButton',
                        purpose: 'Acción consistente con tamaño táctil, semántica y progreso integrado.',
                        interfaceText: 'label, onPressed, icon, isLoading, variant y expand.',
                        states: 'Primario, secundario, peligro, deshabilitado y cargando.',
                        child: Wrap(
                          spacing: AppTokens.space3,
                          runSpacing: AppTokens.space3,
                          children: <Widget>[
                            AppButton(label: 'Guardar', icon: Icons.save_outlined, onPressed: () {}),
                            AppButton(
                              label: 'Cancelar',
                              variant: AppButtonVariant.secondary,
                              onPressed: () {},
                            ),
                            AppButton(
                              label: 'Eliminar',
                              variant: AppButtonVariant.danger,
                              onPressed: () {},
                            ),
                            const AppButton(label: 'Deshabilitado', onPressed: null),
                            AppButton(label: 'Guardando', isLoading: true, onPressed: () {}),
                          ],
                        ),
                      ),
                      _CatalogSection(
                        title: 'AppTextField',
                        purpose: 'Entrada etiquetada y accesible para formularios de autenticación y notas.',
                        interfaceText: 'controller, label, hint, icon, validator, obscureText, maxLines y enabled.',
                        states: 'Vacío, con valor, error de validación y deshabilitado.',
                        child: LayoutBuilder(
                          builder: (context, inner) => ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: <Widget>[
                                AppTextField(
                                  controller: _sampleController,
                                  label: 'Título de la nota',
                                  icon: Icons.title,
                                ),
                                const SizedBox(height: AppTokens.space4),
                                AppTextField(
                                  controller: _disabledController,
                                  label: 'Campo deshabilitado',
                                  enabled: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _CatalogSection(
                        title: 'NoteCard',
                        purpose: 'Presenta una nota sin conocer navegación, backend ni reglas de persistencia.',
                        interfaceText: 'note, onEdit y onDelete. Las devoluciones de llamada delegan la acción al padre.',
                        states: 'Lectura, editable y eliminable; contenido largo truncado de forma segura.',
                        child: SizedBox(
                          height: 250,
                          child: NoteCard(
                            note: Note(
                              id: 1,
                              title: 'Plan del proyecto',
                              content: 'Validar el inventario de pantallas, revisar accesibilidad y preparar las evidencias del informe.',
                              createdAt: DateTime.now().millisecondsSinceEpoch,
                            ),
                            onEdit: () {},
                            onDelete: () {},
                          ),
                        ),
                      ),
                      _CatalogSection(
                        title: 'StatePanel',
                        purpose: 'Explica el estado de una consulta y ofrece recuperación cuando corresponde.',
                        interfaceText: 'type, title, message, actionLabel y onAction.',
                        states: 'Carga, vacío y error; todos se anuncian como región viva para tecnologías de asistencia.',
                        child: LayoutBuilder(
                          builder: (context, inner) {
                            final wide = inner.maxWidth >= 880;
                            final panels = <Widget>[
                              const TickerMode(
                                enabled: false,
                                child: StatePanel(
                                  type: StatePanelType.loading,
                                  title: 'Cargando',
                                  message: 'Consultando la API.',
                                ),
                              ),
                              StatePanel(
                                type: StatePanelType.empty,
                                title: 'Sin notas',
                                message: 'Crea la primera nota.',
                                actionLabel: 'Crear',
                                onAction: () {},
                              ),
                              StatePanel(
                                type: StatePanelType.error,
                                title: 'Sin conexión',
                                message: 'No fue posible consultar la API.',
                                actionLabel: 'Reintentar',
                                onAction: () {},
                              ),
                            ];
                            if (!wide) {
                              return Column(
                                children: panels
                                    .expand((widget) => <Widget>[widget, const SizedBox(height: AppTokens.space4)])
                                    .toList(),
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: panels
                                  .map((widget) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: AppTokens.space4),
                                          child: widget,
                                        ),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogSection extends StatelessWidget {
  const _CatalogSection({
    required this.title,
    required this.purpose,
    required this.interfaceText,
    required this.states,
    required this.child,
  });

  final String title;
  final String purpose;
  final String interfaceText;
  final String states;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTokens.space6),
      padding: const EdgeInsets.all(AppTokens.space6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: tokens.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTokens.space3),
          _Metadata(label: 'Propósito', value: purpose),
          _Metadata(label: 'Interfaz pública', value: interfaceText),
          _Metadata(label: 'Estados', value: states),
          const SizedBox(height: AppTokens.space6),
          child,
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space2),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color, required this.foreground});

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 72,
      padding: const EdgeInsets.all(AppTokens.space3),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.of(context).outline),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
    );
  }
}
