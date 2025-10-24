import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // Para navegar al Login después de cerrar sesión

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nombreUsuario = "Usuario";

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  // Lee el nombre del usuario desde la sesión guardada
  Future<void> _cargarNombre() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = prefs.getString('user_nombre') ?? "Usuario";
    });
  }

  // Borra la sesión y vuelve al Login
  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borra todos los datos de la sesión

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BarberSpot Home'),
        actions: [
          // Botón de Cerrar Sesión
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Center(
        child: Text(
          '¡Bienvenido, $_nombreUsuario!',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }
}