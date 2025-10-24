import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import para Logout
import 'login_screen.dart'; // Import para Logout
import 'barberia_profile_screen.dart'; // Import para la pantalla de perfil

// --- 1. Modelo de Datos para la Barbería ---
class Barberia {
  final int id;
  final String nombre;
  final String? direccion;
  final double latitud;
  final double longitud;
  final String? horario;

  Barberia({
    required this.id,
    required this.nombre,
    this.direccion,
    required this.latitud,
    required this.longitud,
    this.horario,
  });

  factory Barberia.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse doubles, handling nulls and potential errors
    double _safeParseDouble(String? value) {
      if (value == null) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }

    return Barberia(
      id: json['id'] ?? 0, // Provide default value if id is null
      nombre: json['nombre_barberia'] ?? 'Nombre no disponible', // Provide default
      direccion: json['direccion'],
      latitud: _safeParseDouble(json['latitud']),
      longitud: _safeParseDouble(json['longitud']),
      horario: json['horario'],
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- 2. Variables de Estado ---
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Posición inicial de la cámara (Ahora centrada en Guasave)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(25.5728, -108.4720), // Coordenadas de Guasave
    zoom: 13,
  );

  // --- FUNCIÓN LOGOUT TEMPORAL ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borra todos los datos de sesión

    if (mounted) {
      // Navega de vuelta al Login y REMPLAZA la pantalla actual
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }
  // --- FIN FUNCIÓN LOGOUT ---

  @override
  void initState() {
    super.initState();
    _fetchBarberias();
  }

  // --- 3. Lógica para llamar a la API ---
  Future<void> _fetchBarberias() async {
    // Si pruebas en un EMULADOR de Android, usa 10.0.2.2
    // Si pruebas en Chrome (web) o un teléfono físico, usa localhost
    final String apiUrl = "http://127.0.0.1:8000/barberias"; // Use 127.0.0.1 for web/physical device

    setState(() {
      _isLoading = true; // Start loading indicator
      _errorMessage = null; // Clear previous errors
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (!mounted) return; // Check if the widget is still mounted

      if (response.statusCode == 200) {
        final List<dynamic> barberiasJson = json.decode(response.body);
        final List<Barberia> barberias = barberiasJson
            .map((json) => Barberia.fromJson(json))
            .where((b) => b.latitud != 0.0 && b.longitud != 0.0) // Filter out invalid coordinates
            .toList();

        Set<Marker> tempMarkers = {};
        for (var barberia in barberias) {
          tempMarkers.add(
            Marker(
              markerId: MarkerId(barberia.id.toString()),
              position: LatLng(barberia.latitud, barberia.longitud),
              infoWindow: InfoWindow(
                title: barberia.nombre,
                snippet: barberia.direccion ?? 'Sin dirección',
                // --- ¡AQUÍ ESTÁ LA NAVEGACIÓN CORREGIDA! ---
                onTap: () {
                  // Navega a la pantalla de perfil, pasando los datos
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BarberiaProfileScreen(
                        barberiaId: barberia.id,
                        nombreBarberia: barberia.nombre,
                      ),
                    ),
                  );
                },
                // --- FIN DE LA CORRECCIÓN ---
              ),
            ),
          );
        }

        setState(() {
          _markers = tempMarkers;
          _isLoading = false;
        });

      } else {
        // Handle API errors (e.g., 404, 500)
        setState(() {
          _errorMessage = "Error ${response.statusCode}: Failed to load barber shops.";
          _isLoading = false;
        });
        print("API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      // Handle connection errors or JSON parsing errors
      if (!mounted) return;
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoading = false;
      });
      print("Fetch Error: $e");
    }
  }

  // --- 5. Interfaz de Usuario ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuentra tu Barbería'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        // --- BOTÓN LOGOUT TEMPORAL ---
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout, // Calls the logout function
          ),
        ],
        // --- FIN BOTÓN LOGOUT ---
      ),
      body: _buildBody(), // Use a helper method for the body
    );
  }

  // Helper method to build the body content
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      // Display error message with a retry button
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBarberias, // Retry fetching data
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (_markers.isEmpty) {
        // Handle case where API returns empty list
         return Center(
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Text('No hay barberías disponibles cerca.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _fetchBarberias, // Allow retry
                        child: const Text('Actualizar'),
                    ),
                ],
            ),
        );
    }
    else {
      // Display the map if everything is okay
      return GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        markers: _markers, // Shows the loaded markers
        myLocationButtonEnabled: false, // Optional: disable default location button
        zoomControlsEnabled: true, // Optional: enable zoom controls
      );
    }
  }
}