// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
// ¡Importante! Añadiremos estas librerías para la conexión
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart'; // <--- ¡AÑADE ESTA LÍNEA!

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

  // --- FUNCIÓN PARA EL LOGIN (CONECTADA A LA API) ---
  Future<void> _login() async {
    // Validar que los campos no estén vacíos
    if (_telefonoController.text.isEmpty || _passwordController.text.isEmpty) {
      // Opcional: Mostrar un mensaje de error
      print("Error: Los campos no pueden estar vacíos.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // La URL de tu API de FastAPI. 
    // Usamos localhost porque el backend corre en tu misma máquina.
    final String apiUrl = "http://localhost:8000/login";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        // Convertimos los datos de Dart a un string JSON
        body: json.encode({
          'telefono': _telefonoController.text,
          'password': _passwordController.text,
        }),
      );

      // Decodificamos la respuesta JSON
      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // ¡Éxito!
        print("Login exitoso!");
        print("Datos del usuario: $responseData");
        // Aquí es donde guardaremos la sesión y navegaremos a la
        // pantalla de inicio (Fase 2)
        // Por ahora, solo imprimimos el rol:
        print("Rol del usuario: ${responseData['rol']}");
        
      } else {
        // Error desde la API (ej. contraseña incorrecta)
        print("Error en el login: ${responseData['detail']}");
      }

    } catch (e) {
      // Error de conexión (ej. el servidor FastAPI no está corriendo)
      print("Error de conexión: $e");
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