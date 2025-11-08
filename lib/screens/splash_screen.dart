import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';  // A dónde ir si NO hay sesión
import 'client_home_screen.dart';
import 'map_screen.dart';
import 'barber_home_screen.dart';
import 'admin_home_screen.dart';

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

  await Future.delayed(const Duration(seconds: 1)); // Espera corta
  if (!mounted) return;

  // --- LÓGICA DE REDIRECCIÓN (CORREGIDA) ---
  if (userRol == null) {
    // 1. Sin sesión -> Login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  } else if (userRol == 'cliente') {
    // 2. Es Cliente
    if (barberiaId == null || barberiaId == 'null') {
      // 2a. Sin barbería -> Mapa
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
    } else {
      // 2b. Con barbería -> Home Cliente
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
      );
    }
  } else if (userRol == 'barbero') { // <-- ¡ESTA ES LA LÍNEA CLAVE!
    // 3. Es Barbero -> Home Barbero
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const BarberHomeScreen()), // <-- VA A BARBER HOME
    );
  } else if (userRol == 'admin') { // <-- ¡AQUÍ!
   // 4. Es Admin -> Navegar a AdminHomeScreen
    Navigator.of(context).pushReplacement(
     MaterialPageRoute(builder: (context) => const AdminHomeScreen()), // <-- CORREGIDO
   );
    // 5. Rol desconocido -> Login
     Navigator.of(context).pushReplacement(
       MaterialPageRoute(builder: (context) => const LoginScreen()),
     );
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