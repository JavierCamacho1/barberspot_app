import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
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

    // Espera un poco más para que se vea el logo (opcional)
    await Future.delayed(const Duration(seconds: 2)); 
    if (!mounted) return;

    if (userRol == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else if (userRol == 'cliente') {
      if (barberiaId == null || barberiaId == 'null') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
        );
      }
    } else if (userRol == 'barbero') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BarberHomeScreen()),
      );
    } else if (userRol == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
      );
    } else {
       Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // --- NUEVO DISEÑO ---
  @override
  Widget build(BuildContext context) {
    // Usamos el mismo color de fondo que en Login/Registro
    const Color kDarkBlue = Color(0xFF0a192f); 
    const Color kLightBlue = Color(0xFF4FC3F7); // Para el loader

    return Scaffold(
      backgroundColor: kDarkBlue, // Fondo oscuro uniforme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- TU LOGO ---
            Image.asset(
              'assets/images/BarberSpot1.png', // Ruta correcta
              height: 200, // Un poco más grande para el Splash
            ),
            const SizedBox(height: 48),
            
            // --- INDICADOR DE CARGA ---
            CircularProgressIndicator(
              color: kLightBlue, // Color de acento de tu paleta
            ),
          ],
        ),
      ),
    );
  }
}