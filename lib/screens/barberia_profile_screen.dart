import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para leer el user_id
import 'package:http/http.dart' as http; // Para llamar a la API de confirmar
import 'dart:convert';
import 'home_screen.dart'; // A donde iremos después de confirmar

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

  // --- FUNCIÓN PARA CONFIRMAR ASOCIACIÓN (AÚN NO IMPLEMENTADA) ---
  Future<void> _confirmarAsociacion() async {
    print("Confirmando asociación con barbería ID: ${widget.barberiaId}");
    setState(() => _isLoading = true);

    // TODO: Llamar a la API del backend para asociar
    // TODO: Actualizar SharedPreferences con el nuevo barberia_id
    // TODO: Navegar a HomeScreen

    // Simulación
    await Future.delayed(const Duration(seconds: 2));

    // Ejemplo de navegación (DESPUÉS de confirmar con éxito)
    // if (mounted) {
    //   Navigator.of(context).pushAndRemoveUntil(
    //     MaterialPageRoute(builder: (context) => const HomeScreen()),
    //     (Route<dynamic> route) => false, // Elimina todas las rutas anteriores
    //   );
    // }

    setState(() => _isLoading = false);
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
            // TODO: Mostrar más detalles de la barbería aquí (Dirección, Horario)
            // Podríamos cargarlos con otra llamada a la API usando widget.barberiaId
            // Por ahora, solo mostramos el nombre que ya tenemos.
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
                      onPressed: _confirmarAsociacion,
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
