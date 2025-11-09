// Importa este nuevo paquete para el efecto de desenfoque
import 'dart:ui'; 

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_home_screen.dart'; 
import 'register_screen.dart';
import 'map_screen.dart'; 
import 'request_reset_screen.dart'; 
import 'barber_home_screen.dart'; 
import 'admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  
  // --- ¡NUEVO! Variable de estado para ver/ocultar contraseña ---
  bool _isPasswordObscured = true;

  // --- LÓGICA DE LOGIN (Sin cambios) ---
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
    setState(() { _isLoading = true; });

    final String apiUrl = "http://127.0.0.1:8000/login";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'telefono': _telefonoController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', responseData['id']);
        await prefs.setString('user_nombre', responseData['nombre']);
        await prefs.setString('user_rol', responseData['rol']);
        final String? barberiaIdStr = responseData['barberia_id']?.toString();
        await prefs.setString('barberia_id', barberiaIdStr ?? 'null');

        if (!mounted) return;
        final String userRol = responseData['rol'];
        final bool tieneBarberia = barberiaIdStr != null && barberiaIdStr != 'null';

        if (userRol == 'cliente') {
          if (tieneBarberia) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MapScreen()),
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Revisa el servidor.')),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- NUEVO DISEÑO ---
  @override
  Widget build(BuildContext context) {
    // Definimos la paleta del logo
    const Color kDarkBlue = Color(0xFF0a192f); // Azul oscuro de fondo
    const Color kLightBlue = Color(0xFF4FC3F7); // Azul claro para botones
    const Color kWhiteText = Colors.white;
    const Color kGreyText = Colors.white70;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- 1. FONDO ---
          Container(
            color: kDarkBlue,
          ),
          // (Si tienes una imagen de fondo, ponla aquí)
          // Image.asset(
          //   'assets/images/barber_bg.jpg', 
          //   fit: BoxFit.cover,
          // ),

          // --- 2. CONTENIDO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 3. TU LOGO ---
                  Image.asset(
                    'assets/images/BarberSpot1.png', // Ruta de tu logo
                    height: 200,
                  ),
                  const Text(
                'BarberSpot',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),

                  // --- 4. CONTENEDOR DE VIDRIO ---
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        // --- CAMPO DE TELÉFONO ---
                        _buildTextField(
                          controller: _telefonoController,
                          label: 'Número de Teléfono',
                          icon: Icons.phone,
                          keyboard: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        // --- ¡NUEVO! CAMPO DE CONTRASEÑA CON VISIBILIDAD ---
                        TextField(
                          controller: _passwordController,
                          // Usa la variable de estado
                          obscureText: _isPasswordObscured, 
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock, color: Colors.white70),
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.lightBlue[300]!, width: 1.5),
                            ),
                            // --- ¡NUEVO! Botón para ver/ocultar ---
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                // Cambia el estado
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- 6. BOTÓN DE LOGIN ---
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kLightBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  onPressed: _login,
                                  child: const Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(fontSize: 16, color: kDarkBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),

                        // --- 7. BOTONES DE TEXTO ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ));
                              },
                              child: const Text('Regístrate aqui', style: TextStyle(color: kGreyText)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => const RequestResetScreen(),
                                ));
                              },
                              child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: kGreyText)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER (Solo para el campo de teléfono ahora) ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.lightBlue[300]!, width: 1.5),
        ),
      ),
    );
  }

  // --- WIDGET HELPER para el contenedor Glassmorphic ---
  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        // Este es el filtro de desenfoque
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // El color del "vidrio"
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            // El borde sutil del "vidrio"
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}