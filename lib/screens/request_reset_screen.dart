// Importa este nuevo paquete para el efecto de desenfoque
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Asegúrate de que este archivo exista o créalo más tarde
import 'confirm_reset_screen.dart';

class RequestResetScreen extends StatefulWidget {
  const RequestResetScreen({super.key});

  @override
  State<RequestResetScreen> createState() => _RequestResetScreenState();
}

class _RequestResetScreenState extends State<RequestResetScreen> {
  final TextEditingController _telefonoController = TextEditingController();
  bool _isLoading = false;

  Future<void> _solicitarCodigo() async {
    if (_telefonoController.text.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa tu número de teléfono.')),
        );
       }
      return;
    }

     if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String apiUrl = "http://127.0.0.1:8000/password/solicitar-reset"; 

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'telefono': _telefonoController.text}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return; 

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final String message = responseData['message'];
        final String? resetCode = responseData['reset_code']; // SOLO DESARROLLO
        print("Código de reseteo (temporal): $resetCode");

         if (!mounted) return;

         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message)),
         );

        if (resetCode != null) {
          Navigator.of(context).pushReplacement( 
            MaterialPageRoute(
              builder: (context) => ConfirmResetScreen(
                telefono: _telefonoController.text, 
              ),
            ),
          );
        } else {
           setState(() => _isLoading = false);
        }

      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
          );
           setState(() => _isLoading = false);
         }
      }

    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
        );
         setState(() => _isLoading = false);
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
        title: const Text('Recuperar Contraseña'),
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
          // Image.asset('assets/images/barber_bg.jpg', fit: BoxFit.cover),

          // --- 2. CONTENIDO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono grande de candado o similar
                  Icon(Icons.lock_reset, size: 80, color: kLightBlue.withOpacity(0.8)),
                  const SizedBox(height: 32),

                  // --- 3. CONTENEDOR DE VIDRIO ---
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kWhiteText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ingresa tu número de teléfono y te enviaremos un código para restablecerla.',
                          style: TextStyle(fontSize: 16, color: kGreyText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // --- CAMPO DE TELÉFONO ---
                        _buildTextField(
                          controller: _telefonoController,
                          label: 'Número de Teléfono',
                          icon: Icons.phone,
                          keyboard: TextInputType.phone,
                        ),
                        const SizedBox(height: 32),

                        // --- BOTÓN DE ENVIAR ---
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
                                  onPressed: _solicitarCodigo,
                                  child: const Text(
                                    'Enviar Código',
                                    style: TextStyle(fontSize: 16, color: kDarkBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
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

  // --- WIDGETS HELPER (Idénticos a los de Login/Registro) ---
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.lightBlue[300]!, width: 1.5)),
      ),
    );
  }

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