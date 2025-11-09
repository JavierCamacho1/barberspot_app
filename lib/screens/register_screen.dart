// Importa este nuevo paquete para el efecto de desenfoque
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para leer el texto de los campos
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  
  // --- ¡NUEVO! Variable de estado para ver/ocultar contraseña ---
  bool _isPasswordObscured = true;

  // --- LÓGICA DE REGISTRO (Sin cambios) ---
  Future<void> _register() async {
    if (_nombreController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Todos los campos son obligatorios.')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() { _isLoading = true; });

    final String apiUrl = "http://127.0.0.1:8000/registro";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'nombre': _nombreController.text,
          'telefono': _telefonoController.text,
          'password': _passwordController.text,
        }),
      );

      if (!mounted) return;
      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Registro exitoso! Ya puedes iniciar sesión.')),
          );
        }
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });

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
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    }

    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  // --- NUEVO DISEÑO ---
  @override
  Widget build(BuildContext context) {
    // Definimos la paleta del logo
    const Color kDarkBlue = Color(0xFF0a192f); // Azul oscuro de fondo
    const Color kLightBlue = Color(0xFF4FC3F7); // Azul claro para botones
    const Color kGreyText = Colors.white70;

    return Scaffold(
      // La AppBar se integra con el fondo
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: Colors.transparent, // Fondo transparente
        elevation: 0, // Sin sombra
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // Ícono más estilizado
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Extendemos el body detrás de la AppBar
      extendBodyBehindAppBar: true, 
      
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- 1. FONDO (Igual que en Login) ---
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
                    height: 200, // Un poco más pequeño que en el login
                  ),
                  const SizedBox(height: 24),

                  // --- 4. CONTENEDOR DE VIDRIO ---
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        // --- 5. CAMPOS DE TEXTO ---
                        _buildTextField(
                          controller: _nombreController,
                          label: 'Nombre Completo',
                          icon: Icons.person,
                          keyboard: TextInputType.name,
                        ),
                        const SizedBox(height: 20),
                        
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- 6. BOTÓN DE REGISTRO ---
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
                                  onPressed: _register,
                                  child: const Text(
                                    'Registrarse',
                                    style: TextStyle(fontSize: 16, color: kDarkBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),

                        // --- 7. BOTÓN DE TEXTO ---
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('¿Ya tienes cuenta? Inicia sesión', style: TextStyle(color: kGreyText)),
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

  // --- WIDGET HELPER para el campo de texto ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        // Estilo del "vidrio" para el campo
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
          // Aquí usamos la paleta de colores del logo
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