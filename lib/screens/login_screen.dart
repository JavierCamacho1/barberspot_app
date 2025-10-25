import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Import para guardar sesión
import 'client_home_screen.dart';
import 'map_screen.dart'; // Para FASE 2
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para leer el texto de los campos
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Para mostrar un mensaje de carga
  bool _isLoading = false;

  // --- FUNCIÓN PARA EL LOGIN (CON LÓGICA DE REDIRECCIÓN) ---
  Future<void> _login() async {
    // Validar que los campos no estén vacíos
    if (_telefonoController.text.isEmpty || _passwordController.text.isEmpty) {
      print("Error: Los campos no pueden estar vacíos.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String apiUrl = "http://localhost:8000/login";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'telefono': _telefonoController.text,
          'password': _passwordController.text,
        }),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        print("Login exitoso!");

        // --- 1. GUARDAMOS LA SESIÓN ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', responseData['id']);
        await prefs.setString('user_nombre', responseData['nombre']);
        await prefs.setString('user_rol', responseData['rol']);
        
        final String? barberiaIdString = responseData['barberia_id']?.toString();
        await prefs.setString('barberia_id', barberiaIdString ?? 'null');
        
        // --- 2. LÓGICA DE REDIRECCIÓN (IGUAL AL SPLASHSCREEN) ---
        final String userRol = responseData['rol'];

        if (mounted) {
          if (userRol == 'cliente') {
            if (barberiaIdString == null || barberiaIdString == 'null') {
              // 3. Es cliente SIN barbería -> Enviar al MAPA (FASE 2)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            } else {
              // 4. Es cliente CON barbería -> Enviar a Home (FASE 3)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
              );
            }
          } else {
            // 5. Es Barbero o Admin -> Enviar a Home (FASE 4 y 5)
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
            );
          }
        }
        
      } else {
        // Error desde la API (ej. contraseña incorrecta)
        print("Error en el login: ${responseData['detail']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail']}')),
          );
        }
      }
    } catch (e) {
      // Error de conexión
      print("Error de conexión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión. Revisa el servidor.')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
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
              // Título (puedes cambiarlo por tu logo)
              const Text(
                'BarberSpot',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),

              // --- Campo de Teléfono ---
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de Teléfono',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Campo de Contraseña ---
              TextField(
                controller: _passwordController,
                obscureText: true, // Oculta la contraseña
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- Botón de Login ---
              _isLoading
                  ? const CircularProgressIndicator() // Muestra esto si está cargando
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login, // Llama a la función _login
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
              
              const SizedBox(height: 24),

              // --- Botón para ir a Registro ---
                TextButton(
                onPressed: () {
                // --- ¡ LÓGICA DE NAVEGACIÓN! ---
                Navigator.of(context).push(
                MaterialPageRoute(
                builder: (context) => const RegisterScreen(), ),
                );
              },
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
