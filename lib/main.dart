import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PeliculasBuenasApp());
}

class PeliculasBuenasApp extends StatelessWidget {
  const PeliculasBuenasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Películas Buenas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 59, 160, 19),
        ),
      ),
      // Escucha en tiempo real si el usuario ya inicio sesion o esta en la pantalla de inicio
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }
          return const WelcomeScreen();
        },
      ),
    );
  }
}

// 1. PANTALLA DE INICIO (BIENVENIDA, REGISTRO E INICIO DE SESION)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openAuthDialog(BuildContext context, {required bool isLogin}) {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(isLogin: isLogin),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.blueGrey.shade900),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.movie_filter_rounded,
                    size: 90,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bienvenido a Películas Buenas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Explora, administra y descubre tu catálogo cinematográfico.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openAuthDialog(context, isLogin: true),
                        icon: const Icon(Icons.login),
                        label: const Text('Ingresar (Ya tengo cuenta)'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openAuthDialog(context, isLogin: false),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text(
                          'Registrarse como nuevo usuario',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthDialog extends StatefulWidget {
  final bool isLogin;
  const AuthDialog({super.key, required this.isLogin});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      setState(() {
        _errorMessage =
            'Ingresa un correo válido y una contraseña de al menos 6 caracteres.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Guarda el perfil del usuario registrado en Cloud Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(credential.user!.uid)
            .set({
          'email': email,
          'fecha_registro': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Error de autenticación.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isLogin ? 'Iniciar Sesión' : 'Crear Cuenta Nueva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña (mín. 6 caracteres)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: Text(
            _isLoading
                ? 'Procesando...'
                : (widget.isLogin ? 'Ingresar' : 'Registrarse'),
          ),
        ),
      ],
    );
  }
}

// 2. MENU SUPERIOR Y CONTENEDOR PRINCIPAL DE VISTAS
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CatalogScreen(),
    AdminScreen(),
    WeatherScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.movie_filter_rounded),
            SizedBox(width: 8),
            Text('Películas Buenas'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Menu superior para seleccionar Catalogo, AdministraciOn o Clima
          TextButton.icon(
            onPressed: () => setState(() => _currentIndex = 0),
            icon: const Icon(Icons.video_library),
            label: Text(
              'Catálogo',
              style: TextStyle(
                fontWeight:
                    _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _currentIndex = 1),
            icon: const Icon(Icons.admin_panel_settings),
            label: Text(
              'Administración',
              style: TextStyle(
                fontWeight:
                    _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _currentIndex = 2),
            icon: const Icon(Icons.wb_sunny),
            label: Text(
              'Clima (HTTP)',
              style: TextStyle(
                fontWeight:
                    _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_currentIndex],
    );
  }
}

// 3. PANTALLA DE CATALOGO DE PELICULAS
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moviesRef = FirebaseFirestore.instance.collection('peliculas');

    return StreamBuilder<QuerySnapshot>(
      stream: moviesRef.orderBy('fecha_registro', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar catálogo: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay películas en el catálogo.\nVe a "Administración" en el menú superior para agregar una.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            childAspectRatio: 0.68,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final title = data['titulo'] ?? 'Sin título';
            final imageUrl = data['imagen_url'] ?? '';

            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(movieData: data),
                  ),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image, size: 50),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.movie, size: 50),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 4. PANTALLA DE DESCRIPCION DE LA PELICULA
class MovieDetailScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailScreen({super.key, required this.movieData});

  @override
  Widget build(BuildContext context) {
    final title = movieData['titulo'] ?? 'Sin título';
    final year = movieData['anio'] ?? 'Desconocido';
    final director = movieData['director'] ?? 'Desconocido';
    final genre = movieData['genero'] ?? 'Sin género';
    final synopsis = movieData['sinopsis'] ?? 'Sin sinopsis disponible.';
    final imageUrl = movieData['imagen_url'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                height: 340,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 250,
                                  width: 200,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, size: 60),
                                ),
                              )
                            : Container(
                                height: 250,
                                width: 200,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.movie, size: 60),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text('Año: $year'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.person, size: 18),
                          label: Text('Director: $director'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.category, size: 18),
                          label: Text('Género: $genre'),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      'Sinopsis',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      synopsis,
                      style: const TextStyle(fontSize: 16, height: 1.5),
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

// 5. PANTALLA DE ADMINISTRACION (ALTA Y BAJA DE PELICULAS EN FIRESTORE)
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _directorController = TextEditingController();
  final _genreController = TextEditingController();
  final _synopsisController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isSaving = false;

  final CollectionReference _moviesCollection =
      FirebaseFirestore.instance.collection('peliculas');

  Future<void> _addMovie() async {
    final title = _titleController.text.trim();
    final year = _yearController.text.trim();
    final director = _directorController.text.trim();
    final genre = _genreController.text.trim();
    final synopsis = _synopsisController.text.trim();
    final imageUrl = _imageUrlController.text.trim();

    if (title.isEmpty ||
        year.isEmpty ||
        director.isEmpty ||
        genre.isEmpty ||
        synopsis.isEmpty ||
        imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos para dar de alta.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _moviesCollection.add({
        'titulo': title,
        'anio': year,
        'director': director,
        'genero': genre,
        'sinopsis': synopsis,
        'imagen_url': imageUrl,
        'fecha_registro': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _yearController.clear();
      _directorController.clear();
      _genreController.clear();
      _synopsisController.clear();
      _imageUrlController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Película agregada al catálogo en Firebase.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteMovie(String docId, String title) async {
    try {
      await _moviesCollection.doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Película "$title" eliminada de Firebase.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _directorController.dispose();
    _genreController.dispose();
    _synopsisController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Formulario de Alta
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Alta de Nueva Película',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título de la película',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Año de estreno',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _genreController,
                              decoration: const InputDecoration(
                                labelText: 'Género cinematográfico',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _directorController,
                        decoration: const InputDecoration(
                          labelText: 'Director',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de la imagen / póster (https://...)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _synopsisController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Sinopsis',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _addMovie,
                        icon: const Icon(Icons.add_circle),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Dar de Alta en Catálogo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Lista de Baja
              Text(
                'Películas Registradas (Baja del Catálogo)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: _moviesCollection
                    .orderBy('fecha_registro', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text('No hay películas registradas actualmente.');
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['titulo'] ?? 'Sin título';
                      final year = data['anio'] ?? '';
                      final director = data['director'] ?? '';

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.movie),
                          title: Text('$title ($year)'),
                          subtitle: Text('Director: $director'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Dar de baja',
                            onPressed: () => _deleteMovie(doc.id, title),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 6. PANTALLA DE PRONOSTICO DEL CLIMA (PETICION HTTP OFICIAL)
class WeatherInfo {
  final String city;
  final double temp;
  final String description;

  WeatherInfo({
    required this.city,
    required this.temp,
    required this.description,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      city: json['name'] ?? '',
      temp: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
    );
  }
}

Future<WeatherInfo> fetchWeather() async {
  const apiKey = 'a4d1212b0dd6d5fde6f3b4f4a9b5f1d5';
  const city = 'Guadalajara';
  final url = Uri.parse(
    'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric&lang=es',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    return WeatherInfo.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Error al cargar clima (${response.statusCode})');
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<WeatherInfo> futureWeather;

  @override
  void initState() {
    super.initState();
    futureWeather = fetchWeather();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FutureBuilder<WeatherInfo>(
              future: futureWeather,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Consultando clima local...'),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            futureWeather = fetchWeather();
                          });
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                } else if (snapshot.hasData) {
                  final weather = snapshot.data!;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud, size: 64, color: Colors.lightBlue),
                      const SizedBox(height: 12),
                      Text(
                        weather.city,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${weather.temp.toStringAsFixed(1)} °C',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weather.description.toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                  );
                }
                return const Text('Sin datos');
              },
            ),
          ),
        ),
      ),
    );
  }
}