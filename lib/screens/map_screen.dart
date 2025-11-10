import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'barberia_profile_screen.dart';

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
    double _safeParseDouble(String? value) {
      if (value == null) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }

    return Barberia(
      id: json['id'] ?? 0,
      nombre: json['nombre_barberia'] ?? 'Nombre no disponible',
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
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  GoogleMapController? _mapController;
  Barberia? _selectedBarberia;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(25.5728, -108.4720),
    zoom: 13,
  );

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBarberias();
  }

  Future<void> _fetchBarberias() async {
    // Si pruebas en un EMULADOR de Android, usa 10.0.2.2
    // Si pruebas en Chrome (web) o un teléfono físico, usa localhost o 127.0.0.1
    final String apiUrl = "http://127.0.0.1:8000/barberias";

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> barberiasJson = json.decode(response.body);
        final List<Barberia> barberias = barberiasJson
            .map((json) => Barberia.fromJson(json))
            .where((b) => b.latitud != 0.0 && b.longitud != 0.0)
            .toList();

        Set<Marker> tempMarkers = {};
        for (var barberia in barberias) {
          tempMarkers.add(
            Marker(
              markerId: MarkerId(barberia.id.toString()),
              position: LatLng(barberia.latitud, barberia.longitud),
              onTap: () {
                _onMarkerTapped(barberia);
              },
            ),
          );
        }

        setState(() {
          _markers = tempMarkers;
          _isLoading = false;
        });

      } else {
        setState(() {
          _errorMessage = "Error ${response.statusCode}: No se pudieron cargar las barberías.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Error de conexión: $e";
        _isLoading = false;
      });
    }
  }

  void _onMarkerTapped(Barberia barberia) {
    setState(() {
      _selectedBarberia = barberia;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(barberia.latitud, barberia.longitud),
      ),
    );
  }

  void _onMapTapped() {
    setState(() {
      _selectedBarberia = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: null, 
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCameraPosition,
          markers: _markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          onTap: (_) => _onMapTapped(),
        ),

        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        
        if (_errorMessage != null)
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchBarberias,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildGlassAppBar(context),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _selectedBarberia != null ? 20 : -250,
          left: 20,
          right: 20,
          child: _buildBarberiaDetailsPanel(_selectedBarberia),
        )
      ],
    );
  }

  Widget _buildGlassAppBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: kToolbarHeight,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Encuentra tu Barbería',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Cerrar Sesión',
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarberiaDetailsPanel(Barberia? barberia) {
    if (barberia == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                barberia.nombre,
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8.0),
              if (barberia.direccion != null)
                Text(
                  barberia.direccion!,
                  style: TextStyle(fontSize: 16.0, color: Colors.white.withOpacity(0.9)),
                ),
              if (barberia.horario != null) ...[
                const SizedBox(height: 4.0),
                Text(
                  barberia.horario!,
                  style: TextStyle(fontSize: 14.0, color: Colors.white.withOpacity(0.7)),
                ),
              ],
              const SizedBox(height: 16.0),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: Size(double.infinity, 48) // Hace que el botón ocupe todo el ancho
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BarberiaProfileScreen(
                        barberiaId: barberia.id,
                        nombreBarberia: barberia.nombre,
                      ),
                    ),
                  );
                },
                child: const Text('Ver Perfil y Agendar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}