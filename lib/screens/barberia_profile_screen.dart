import 'dart:ui'; // Necesario para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'client_home_screen.dart';

class BarberiaProfileScreen extends StatefulWidget {
  final int barberiaId;
  final String nombreBarberia;

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

  Future<void> _confirmarAsociacion() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo identificar al usuario.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Usa 10.0.2.2 para emulador Android, localhost para iOS/Web
    final String apiUrl = "http://127.0.0.1:8000/usuarios/asociar_barberia";

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'user_id': userId,
          'barberia_id': widget.barberiaId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await prefs.setString('barberia_id', widget.barberiaId.toString());
        await prefs.setString('barberia_nombre', widget.nombreBarberia);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
          (Route<dynamic> route) => false,
        );

      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['detail']}')),
        );
      }

    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión al confirmar.')),
        );
       }
    }

    if (mounted) {
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un Stack para poner un fondo interesante detrás de todo
    return Stack(
      children: [
        // --- Capa 1: Fondo con Gradiente (para que se note el vidrio) ---
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF000000)], // Azul oscuro a Negro
            ),
          ),
        ),
        
        // --- Capa 2: Contenido de la Pantalla ---
        Scaffold(
          backgroundColor: Colors.transparent, // Hacemos el Scaffold transparente
          extendBodyBehindAppBar: true, // El cuerpo pasa por detrás del AppBar
          appBar: AppBar(
            title: Text(
              widget.nombreBarberia,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.transparent, // AppBar transparente
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white), // Flecha de regreso blanca
            flexibleSpace: ClipRRect( // Efecto vidrio en el AppBar también
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 100.0, 20.0, 20.0), // Padding superior extra por el AppBar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Tarjeta de Detalles con Glassmorphism ---
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalles de la Barbería',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 30),
                      _buildDetailRow(Icons.location_on, 'Dirección', 'Calle Principal #123, Centro'),
                      const SizedBox(height: 20),
                      _buildDetailRow(Icons.access_time_filled, 'Horario', 'Lun - Sab: 10:00 AM - 8:00 PM'),
                      const SizedBox(height: 20),
                      _buildDetailRow(Icons.phone, 'Teléfono', '(687) 123-4567'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // --- Botón de Confirmación ---
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: Colors.white))
                else
                  _buildGlassButton(
                    text: 'Confirmar Asociación',
                    onPressed: _confirmarAsociacion,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper para crear filas de detalle con icono y texto
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper para crear tarjetas con efecto de vidrio (Reutilizable)
  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Un poco más claro que el fondo
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  // Helper para el botón con estilo de vidrio
  Widget _buildGlassButton({required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [Colors.blue.shade800.withOpacity(0.8), Colors.blue.shade500.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}