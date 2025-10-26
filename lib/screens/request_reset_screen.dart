import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Importaremos esta pantalla más tarde cuando la creemos
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

    final String apiUrl = "http://127.0.0.1:8000/password/solicitar-reset"; // Usa 10.0.2.2 para emulador Android

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'telefono': _telefonoController.text}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return; // Verificar después del await

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Éxito (incluso si el teléfono no existe, el backend devuelve 200)
        final String message = responseData['message'];
        // --- ¡SOLO PARA DESARROLLO! ---
        final String? resetCode = responseData['reset_code'];
        print("Mensaje de la API: $message");
        print("Código de reseteo (temporal): $resetCode");
        // --- FIN SOLO PARA DESARROLLO ---

         if (!mounted) return;

         // Mostramos el mensaje de la API al usuario
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message)),
         );

        // Si SÍ obtuvimos un código (o sea, el teléfono sí estaba registrado),
        // navegamos a la siguiente pantalla.
        if (resetCode != null) {
          Navigator.of(context).pushReplacement( // Usamos pushReplacement
            MaterialPageRoute(
              builder: (context) => ConfirmResetScreen(
                telefono: _telefonoController.text, // Pasamos el teléfono
                // No pasamos el código, el usuario debe ingresarlo
              ),
            ),
          );
        } else {
           // Si no hubo código, nos quedamos aquí (teléfono no encontrado)
           setState(() => _isLoading = false);
        }


      } else {
        // Error inesperado del backend (distinto de usuario no encontrado)
        print("Error al solicitar código: ${responseData['detail']}");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
          );
           setState(() => _isLoading = false);
         }
      }

    } catch (e) {
      print("Error de conexión al solicitar código: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
        );
         setState(() => _isLoading = false);
       }
    }
     // No necesitamos setState(isLoading=false) aquí si navegamos
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer Contraseña'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa tu número de teléfono para recibir un código de verificación (simulado).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Teléfono',
                prefixIcon: Icon(Icons.phone),
                // Estilo del tema
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _solicitarCodigo,
                    child: const Text('Enviar Código'),
                  ),
          ],
        ),
      ),
    );
  }
}
