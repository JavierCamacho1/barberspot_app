// Importa este nuevo paquete para el efecto de desenfoque
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart'; // A donde regresar después del éxito

class ConfirmResetScreen extends StatefulWidget {
  final String telefono; // Recibe el teléfono de la pantalla anterior

  const ConfirmResetScreen({super.key, required this.telefono});

  @override
  State<ConfirmResetScreen> createState() => _ConfirmResetScreenState();
}

class _ConfirmResetScreenState extends State<ConfirmResetScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _confirmarReseteo() async {
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String apiUrl = "http://127.0.0.1:8000/password/confirmar-reset"; 

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'telefono': widget.telefono, 
          'code': _codeController.text, 
          'new_password': _newPasswordController.text, 
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message']), backgroundColor: Colors.green),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const LoginScreen()),
             (Route<dynamic> route) => false, 
           );
        }

      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
        );
      }
    } finally {
       if (mounted) {
         setState(() {
           _isLoading = false;
         });
       }
    }
  }
  
  // --- NUEVO DISEÑO ---
  @override
  Widget build(BuildContext context) {
    // Definimos la paleta del logo
    const Color kDarkBlue = Color(0xFF0a192f); 
    const Color kLightBlue = Color(0xFF4FC3F7); 
    const Color kGreyText = Colors.white70;
    const Color kWhiteText = Colors.white;

    return Scaffold(
      // AppBar integrada
      appBar: AppBar(
        title: const Text('Confirmar Código'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,

      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- 1. FONDO ---
          Container(
            color: kDarkBlue,
          ),
          // (Si tienes una imagen de fondo, ponla aquí)
          // Image.asset('assets/images/barber_bg.jpg', fit: BoxFit.cover),

          // --- 2. CONTENIDO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // --- 3. CONTENEDOR DE VIDRIO ---
                  _buildGlassContainer(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            'Ingresa el código y tu nueva contraseña',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kWhiteText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // --- CAMPO CÓDIGO ---
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, letterSpacing: 8, color: kWhiteText),
                            decoration: _glassInputDecoration(
                              label: 'Código de Verificación',
                              icon: Icons.pin,
                            ).copyWith(counterText: ""), // Oculta el contador
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Ingresa el código';
                              if (value.length != 6) return 'El código debe tener 6 dígitos';
                              return null; 
                            },
                          ),
                          const SizedBox(height: 20),

                          // --- CAMPO NUEVA CONTRASEÑA ---
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscurePassword,
                            decoration: _glassInputDecoration(
                              label: 'Nueva Contraseña',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: kGreyText),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                              if (value.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // --- CAMPO CONFIRMAR CONTRASEÑA ---
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: _glassInputDecoration(
                              label: 'Confirmar Contraseña',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: kGreyText),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Confirma la contraseña';
                              if (value != _newPasswordController.text) return 'Las contraseñas no coinciden';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // --- BOTÓN RESTABLECER ---
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
                                    onPressed: _confirmarReseteo,
                                    child: const Text(
                                      'Restablecer Contraseña',
                                      style: TextStyle(fontSize: 16, color: kDarkBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                        ],
                      ),
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

  // --- WIDGET HELPER para el estilo de los Inputs ---
  InputDecoration _glassInputDecoration({required String label, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.lightBlue[300]!, width: 1.5)),
    );
  }

  // --- WIDGET HELPER para el contenedor Glassmorphic ---
  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}