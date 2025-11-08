import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_home_screen.dart'; // Pantalla principal del cliente
import 'register_screen.dart';
import 'map_screen.dart'; // Pantalla del mapa
// --- ¡IMPORTACIONES PARA ROLES Y RESET! ---
import 'request_reset_screen.dart'; // Pantalla para solicitar reseteo
import 'barber_home_screen.dart'; // <-- Pantalla principal del barbero
import 'admin_home_screen.dart';
// --- FIN IMPORTACIONES ---

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
    // Validación de campos vacíos
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

    // Usa 10.0.2.2 para emulador Android, localhost o 127.0.0.1 para web/físico
    final String apiUrl = "http://127.0.0.1:8000/login";

    try {
      // Usamos los datos reales en el body de la petición POST
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
        // Guardar datos en SharedPreferences
        await prefs.setInt('user_id', responseData['id']);
        await prefs.setString('user_nombre', responseData['nombre']);
        await prefs.setString('user_rol', responseData['rol']);
        final String? barberiaIdStr = responseData['barberia_id']?.toString();
        await prefs.setString('barberia_id', barberiaIdStr ?? 'null');
        // Opcional: guardar nombre barberia si viene del login o hacer otra llamada
        // await prefs.setString('barberia_nombre', responseData['barberia_nombre'] ?? '');


        // --- Lógica de Redirección Inteligente (¡CORREGIDA!) ---
        final String userRol = responseData['rol'];
        final bool tieneBarberia = barberiaIdStr != null && barberiaIdStr != 'null';

        if (!mounted) return; // Verificar antes de navegar

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
        } else if (userRol == 'barbero') { // <-- ¡ESTA ES LA CORRECCIÓN!
           Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const BarberHomeScreen()), // <-- VA A BARBER HOME
           );
        } else if (userRol == 'admin') {
       Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()), // <-- CORREGIDO
       );
    } else {
           // Rol desconocido -> Login
            Navigator.of(context).pushReplacement(
             MaterialPageRoute(builder: (context) => const LoginScreen()),
           );
        }
        // --- Fin Lógica Redirección ---

      } else {
         // Manejo de errores de login
         print("Error en el login: ${responseData['detail']}");
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${responseData['detail']}')),
          );
         }
      }

    } catch (e) {
       // Manejo de errores de conexión
       print("Error de conexión: $e");
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión. Revisa el servidor.')),
        );
       }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    // El resto del build sigue igual: TextFields, Botones, Enlaces
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
              const SizedBox(height: 10),
              TextButton(
                 onPressed: () {
                   Navigator.of(context).push(
                     MaterialPageRoute(
                       builder: (context) => const RequestResetScreen(),
                     ),
                   );
                 },
                 style: TextButton.styleFrom(padding: EdgeInsets.zero),
                 child: Text(
                   '¿Olvidaste tu contraseña?',
                   style: TextStyle(color: Colors.grey[400], fontSize: 14),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}

