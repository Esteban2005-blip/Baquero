import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'db_helper.dart';
import 'note.dart';
import 'user.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baquero',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _message = '';
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Escribe correo y contraseña';
        _isLoading = false;
      });
      return;
    }

    final user = await DBHelper.instance.authenticateUser(email, password);

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      setState(() {
        _message = 'Correo o contraseña incorrectos';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.8),
              const Color(0xFF8B5CF6),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.note_alt_rounded, size: 60, color: const Color(0xFF6366F1)),
                ),
                const SizedBox(height: 30),
                Text(
                  'Baquero',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tus notas, tu mundo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(_emailController, 'Correo electrónico', Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Contraseña', Icons.lock_outline, obscure: true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                            ),
                          )
                        : const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: Colors.white30)),
                    const SizedBox(width: 12),
                    Text('¿No tienes cuenta?', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 1, color: Colors.white30)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Crear cuenta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_message, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: label.contains('Correo') ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Usuario';
  String _message = '';
  bool _isRegistering = false;

  Future<void> _register() async {
    setState(() {
      _message = '';
      _isRegistering = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Completa todos los campos';
        _isRegistering = false;
      });
      return;
    }

    final existingUser = await DBHelper.instance.getUserByEmail(email);
    if (existingUser != null) {
      setState(() {
        _message = 'Ya existe una cuenta con ese correo';
        _isRegistering = false;
      });
      return;
    }

    final newUser = User(
      name: name,
      email: email,
      password: password,
      role: _selectedRole,
    );

    await DBHelper.instance.insertUser(newUser);

    setState(() {
      _isRegistering = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Cuenta creada correctamente!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.8),
              const Color(0xFF8B5CF6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Crea tu cuenta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a Baquero hoy',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(_nameController, 'Nombre completo', Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Correo electrónico', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildTextField(_passwordController, 'Contraseña', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      items: const [
                        DropdownMenuItem(value: 'Usuario', child: Text('Usuario')),
                        DropdownMenuItem(value: 'Emprendedor', child: Text('Emprendedor')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Soy un',
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF6366F1)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                              ),
                            )
                          : const Text('Crear cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_message, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: label.contains('Correo') ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final User user;

  const HomePage({required this.user, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Note>> _notesFuture;
  final List<Color> _noteColors = [
    const Color(0xFFFFE5B4),
    const Color(0xFFB4E5FF),
    const Color(0xFFD4FFB4),
    const Color(0xFFFFB4E5),
    const Color(0xFFFFD4B4),
    const Color(0xFFB4D4FF),
  ];

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  void _refreshNotes() {
    setState(() {
      _notesFuture = DBHelper.instance.getNotes();
    });
  }

  Future<void> _showNoteDialog([Note? note]) async {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note == null ? 'Nueva nota' : 'Editar nota',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Título',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    hintText: 'Contenido',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        if (title.isEmpty || content.isEmpty) return;

                        final newNote = Note(
                          id: note?.id,
                          title: title,
                          content: content,
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                        );

                        if (note == null) {
                          await DBHelper.instance.insertNote(newNote);
                        } else {
                          await DBHelper.instance.updateNote(newNote);
                        }

                        Navigator.of(context).pop();
                        _refreshNotes();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteNote(int id) async {
    await DBHelper.instance.deleteNote(id);
    _refreshNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.user.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6366F1).withOpacity(0.1), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '👤 ${widget.user.role}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Sin notas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Presiona + para crear una nueva nota',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final bgColor = _noteColors[index % _noteColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _showNoteDialog(note),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: bgColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3748),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showNoteDialog(note);
                                        } else if (value == 'delete') {
                                          _deleteNote(note.id!);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  note.content,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4A5568),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
