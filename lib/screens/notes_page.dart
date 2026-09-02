import 'package:flutter/material.dart';

import '../api_service.dart';
import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../components/note_card.dart';
import '../components/state_panel.dart';
import '../design/app_tokens.dart';
import '../note.dart';
import '../session.dart';
import 'component_catalog_page.dart';
import 'login_page.dart';

enum NotesViewState { loading, ready, empty, error }

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.apiService,
    required this.session,
  });

  final ApiService apiService;
  final Session session;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  NotesViewState _state = NotesViewState.loading;
  List<Note> _notes = <Note>[];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _state = NotesViewState.loading);
    try {
      final notes = await widget.apiService.getNotes(widget.session.accessToken);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _state = notes.isEmpty ? NotesViewState.empty : NotesViewState.ready;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _state = NotesViewState.error;
      });
    }
  }

  Future<void> _openEditor([Note? note]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => NoteEditorDialog(
        apiService: widget.apiService,
        accessToken: widget.session.accessToken,
        note: note,
      ),
    );
    if (changed == true) await _loadNotes();
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text('¿Quieres eliminar “${note.title}”? Esta acción no se puede deshacer.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppTokens.of(context).error)),
          ),
        ],
      ),
    );
    if (confirmed != true || note.id == null) return;
    try {
      await widget.apiService.deleteNote(widget.session.accessToken, note.id!);
      await _loadNotes();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _logout() async {
    try {
      await widget.apiService.logout(widget.session.accessToken);
    } catch (_) {
      // El cierre local continúa aunque la API ya no esté disponible.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => LoginPage(apiService: widget.apiService)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis notas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Catálogo de componentes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ComponentCatalogPage()),
            ),
            icon: const Icon(Icons.widgets_outlined),
          ),
          IconButton(tooltip: 'Actualizar notas', onPressed: _loadNotes, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Cerrar sesión', onPressed: _logout, icon: const Icon(Icons.logout)),
          const SizedBox(width: AppTokens.space2),
        ],
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'Crear una nota',
        child: FloatingActionButton.extended(
          onPressed: _openEditor,
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text('Nueva nota'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotes,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space6,
              AppTokens.space4,
              AppTokens.space6,
              96,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppTokens.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppTokens.space4,
                        runSpacing: AppTokens.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text('Hola, ${widget.session.email}', style: Theme.of(context).textTheme.headlineSmall),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.space3,
                              vertical: AppTokens.space1,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.primarySoft,
                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            ),
                            child: Text(widget.session.role, style: Theme.of(context).textTheme.labelMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Crea, consulta y administra el contenido asociado a tu cuenta.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
                      ),
                      const SizedBox(height: AppTokens.space6),
                      _buildContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case NotesViewState.loading:
        return const StatePanel(
          type: StatePanelType.loading,
          title: 'Cargando tus notas',
          message: 'Estamos consultando la información más reciente.',
        );
      case NotesViewState.empty:
        return StatePanel(
          type: StatePanelType.empty,
          title: 'Aún no tienes notas',
          message: 'Crea la primera para comenzar a organizar tus ideas.',
          actionLabel: 'Crear primera nota',
          onAction: _openEditor,
        );
      case NotesViewState.error:
        return StatePanel(
          type: StatePanelType.error,
          title: 'No pudimos cargar las notas',
          message: _errorMessage,
          actionLabel: 'Reintentar',
          onAction: _loadNotes,
        );
      case NotesViewState.ready:
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppTokens.space4,
                mainAxisSpacing: AppTokens.space4,
                mainAxisExtent: 250,
              ),
              itemBuilder: (context, index) {
                final note = _notes[index];
                return NoteCard(
                  note: note,
                  onEdit: () => _openEditor(note),
                  onDelete: () => _confirmDelete(note),
                );
              },
            );
          },
        );
    }
  }
}

class NoteEditorDialog extends StatefulWidget {
  const NoteEditorDialog({
    super.key,
    required this.apiService,
    required this.accessToken,
    this.note,
  });

  final ApiService apiService;
  final String accessToken;
  final Note? note;

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.note?.id == null) {
        await widget.apiService.createNote(
          widget.accessToken,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
      } else {
        await widget.apiService.updateNote(
          widget.accessToken,
          widget.note!.id!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AlertDialog(
      title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppTextField(
                  controller: _titleController,
                  label: 'Título',
                  icon: Icons.title,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 3 || length > 100) return 'Usa entre 3 y 100 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  controller: _contentController,
                  label: 'Contenido',
                  icon: Icons.notes,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length == 0 || length > 5000) return 'Escribe entre 1 y 5000 caracteres';
                    return null;
                  },
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppTokens.space4),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: tokens.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        AppButton(
          label: widget.note == null ? 'Crear nota' : 'Guardar cambios',
          onPressed: _save,
          isLoading: _saving,
        ),
      ],
    );
  }
}
