import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';  // A dónde ir si NO hay sesión
import 'home_screen.dart';   // A dónde ir si SÍ hay sesión
import 'map_screen.dart'; // <--- ¡ASEGÚRATE DE TENER ESTO!

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
  final prefs = await SharedPreferences.getInstance();
  final String? userRol = prefs.getString('user_rol');
  final String? barberiaId = prefs.getString('barberia_id');

  await Future.delayed(const Duration(seconds: 2));
  if (!mounted) return;

  // --- LÓGICA DE REDIRECCIÓN (FASE 2) ---
  if (userRol == null) {
    // 1. No hay sesión -> Enviar a Login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  } else {
    // 2. Hay sesión, revisamos el rol
    if (userRol == 'cliente') {
      if (barberiaId == null || barberiaId == 'null') {
        // 3. Es cliente SIN barbería -> Enviar al MAPA (FASE 2)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      } else {
        // 4. Es cliente CON barbería -> Enviar a Home (FASE 3)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // 5. Es Barbero o Admin -> Enviar a Home (FASE 4 y 5)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // backgroundColor: Color(0xFF1A1A1A), // Para que coincida con el tema
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BarberSpot',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}