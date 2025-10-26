import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_home_screen.dart';
import 'register_screen.dart';
import 'map_screen.dart'; // Para la lógica de redirección
// --- ¡IMPORTACIÓN PARA RESET! ---
import 'request_reset_screen.dart';
// --- FIN IMPORTACIÓN ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_telefonoController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa teléfono y contraseña.')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String apiUrl = "http://127.0.0.1:8000/login"; // Usa 10.0.2.2 para emulador Android

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'telefono': _telefonoController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10)); // Timeout añadido

      if (!mounted) return; // Verificar después del await

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        print("Login exitoso!");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', responseData['id']);
        await prefs.setString('user_nombre', responseData['nombre']);
        await prefs.setString('user_rol', responseData['rol']);
        final String? barberiaIdStr = responseData['barberia_id']?.toString();
        await prefs.setString('barberia_id', barberiaIdStr ?? 'null');

        // --- Lógica de Redirección Inteligente ---
        final String userRol = responseData['rol'];
        final bool tieneBarberia = barberiaIdStr != null && barberiaIdStr != 'null';

        if (!mounted) return; // Verificar antes de navegar

        if (userRol == 'cliente') {
          if (tieneBarberia) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ClientHomeScreen()), // Ir a Home Cliente
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MapScreen()), // Ir al Mapa
            );
          }
        } else {
          // TODO: Redirigir a pantalla de Barbero/Admin (FASE 4/5)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ClientHomeScreen()), // Temporalmente a Home Cliente
          );
        }
        // --- Fin Lógica Redirección ---

      } else {
        print("Error en el login: ${responseData['detail']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail']}')),
          );
        }
      }

    } catch (e) {
      print("Error de conexión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Revisa el servidor.')),
        );
      }
    } finally {
       if (mounted) { // Ensure widget is still mounted before calling setState
         setState(() {
           _isLoading = false;
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'BarberSpot',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de Teléfono',
                  prefixIcon: const Icon(Icons.phone),
                  // Usar tema definido en main.dart
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                   // Usar tema definido en main.dart
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        // Estilo tomado del tema en main.dart
                        child: const Text('Iniciar Sesión'),
                      ),
                    ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),

              // --- ¡NUEVO ENLACE AÑADIDO! ---
              const SizedBox(height: 10), // Espacio
              TextButton(
                onPressed: () {
                  // Navega a la pantalla para solicitar el reseteo
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // Asegúrate de crear este archivo: request_reset_screen.dart
                      builder: (context) => const RequestResetScreen(),
                    ),
                  );
                },
                 style: TextButton.styleFrom(padding: EdgeInsets.zero), // Reduce padding
                child: Text(
                  '¿Olvidaste tu contraseña?',
                   style: TextStyle(color: Colors.grey[400], fontSize: 14), // Estilo sutil
                ),
              ),
              // --- FIN ENLACE AÑADIDO ---
            ],
          ),
        ),
      ),
    );
  }
}