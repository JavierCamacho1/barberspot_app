import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para leer el user_id y actualizar barberia_id
import 'package:http/http.dart' as http; // Para llamar a la API de confirmar
import 'dart:convert';
import 'client_home_screen.dart';

class BarberiaProfileScreen extends StatefulWidget {
  final int barberiaId; // Recibe el ID desde el mapa
  final String nombreBarberia; // Recibe el nombre para mostrarlo rápido

  const BarberiaProfileScreen({
    super.key,
    required this.barberiaId,
    required this.nombreBarberia,
  });

  @override
  State<BarberiaProfileScreen> createState() => _BarberiaProfileScreenState();
}

class _BarberiaProfileScreenState extends State<BarberiaProfileScreen> {
  bool _isLoading = false;
  // TODO: Añadir variables para guardar más detalles (dirección, horario) si los cargamos

  // --- FUNCIÓN PARA CONFIRMAR ASOCIACIÓN (IMPLEMENTADA) ---
  Future<void> _confirmarAsociacion() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id'); // Leemos el ID del usuario logueado

    if (userId == null) {
      // Si no encontramos el ID (algo raro), mostramos error
      print("Error: No se pudo obtener el ID del usuario.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo identificar al usuario.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final String apiUrl = "http://127.0.0.1:8000/usuarios/asociar_barberia"; // Endpoint del backend

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'user_id': userId,
          'barberia_id': widget.barberiaId, // El ID de la barbería de esta pantalla
        }),
      );

      if (!mounted) return; // Verificar si el widget sigue montado

      if (response.statusCode == 200) {
        // ¡Éxito en el backend!
        print("Asociación exitosa en backend.");

        // Ahora actualizamos la sesión local
        await prefs.setString('barberia_id', widget.barberiaId.toString());
        print("SharedPreferences actualizado con barberia_id: ${widget.barberiaId}");

        // --- ¡AÑADE ESTA LÍNEA PARA GUARDAR EL NOMBRE! ---
        await prefs.setString('barberia_nombre', widget.nombreBarberia); 

        print("SharedPreferences actualizado con barberia_id: ${widget.barberiaId} y nombre: ${widget.nombreBarberia}");

        // Navegamos al HomeScreen y eliminamos todas las pantallas anteriores
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
          (Route<dynamic> route) => false, // Elimina Login, Splash, Mapa, Perfil
        );

      } else {
        // Error desde la API
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("Error al asociar: ${responseData['detail']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['detail']}')),
        );
      }

    } catch (e) {
      // Error de conexión
      print("Error de conexión al asociar: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión al confirmar.')),
        );
       }
    }

    // Solo ponemos isLoading a false si hubo un error (si tuvo éxito, ya navegó)
    if (mounted) {
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreBarberia), // Muestra el nombre recibido
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO: Mostrar más detalles de la barbería aquí
            Text(
              'Dirección: [Dirección de la barbería aquí]', // Placeholder
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Horario: [Horario de la barbería aquí]', // Placeholder
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            const SizedBox(height: 40),

            // --- Botón de Confirmar ---
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmarAsociacion, // Llama a la nueva función
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirmar Asociación',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}