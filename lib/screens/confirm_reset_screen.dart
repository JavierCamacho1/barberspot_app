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
  // GlobalKey para validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _confirmarReseteo() async {
    // Primero, valida el formulario
    if (!_formKey.currentState!.validate()) {
      return; // Si no es válido, no hace nada
    }

    // Si es válido, procede con la llamada a la API
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String apiUrl = "http://127.0.0.1:8000/password/confirmar-reset"; // Usa 10.0.2.2 para emulador Android

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'telefono': widget.telefono, // Teléfono recibido
          'code': _codeController.text, // Código ingresado
          'new_password': _newPasswordController.text, // Nueva contraseña
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return; // Verificar después del await

      if (response.statusCode == 200) {
        // ¡Éxito!
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("Mensaje de confirmación: ${responseData['message']}");

        // Muestra mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message']), backgroundColor: Colors.green),
        );

        // Espera un poquito para que el usuario vea el mensaje y navega al Login
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
           // Usamos pushAndRemoveUntil para limpiar el stack de navegación
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const LoginScreen()),
             (Route<dynamic> route) => false, // Elimina todas las rutas anteriores
           );
        }

      } else {
        // Error de la API (código incorrecto, expirado, etc.)
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("Error al confirmar reseteo: ${responseData['detail']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
          );
        }
      }

    } catch (e) {
      print("Error de conexión al confirmar reseteo: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar Código'),
      ),
      body: Center( // Centra el contenido verticalmente
        child: SingleChildScrollView( // Permite scroll si el teclado aparece
          padding: const EdgeInsets.all(20.0),
          child: Form( // Usamos un Form para validaciones
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centra los elementos
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ingresa el código de 6 dígitos que recibiste (simulado en consola) y tu nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
                const SizedBox(height: 30),

                // --- Campo Código ---
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6, // Limita a 6 dígitos
                  textAlign: TextAlign.center, // Centra el texto del código
                  style: const TextStyle(fontSize: 24, letterSpacing: 8), // Estilo más grande para el código
                  decoration: InputDecoration(
                    labelText: 'Código de Verificación',
                    counterText: "", // Oculta el contador de caracteres
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el código';
                    }
                    if (value.length != 6) {
                      return 'El código debe tener 6 dígitos';
                    }
                    return null; // Válido
                  },
                ),
                const SizedBox(height: 20),

                // --- Campo Nueva Contraseña ---
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                       icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                       onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una contraseña';
                    }
                    if (value.length < 6) { // Ejemplo: mínimo 6 caracteres
                       return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // --- Campo Confirmar Contraseña ---
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Nueva Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                     suffixIcon: IconButton(
                       icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                       onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirma la contraseña';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // --- Botón Restablecer ---
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _confirmarReseteo,
                        child: const Text('Restablecer Contraseña'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
