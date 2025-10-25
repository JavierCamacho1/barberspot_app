import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Para llamadas API
import 'dart:convert';                   // Para jsonDecode
import 'package:intl/intl.dart';           // Para formatear fechas/horas

// Asegúrate de que la ruta al modelo sea correcta según tu estructura de carpetas
import 'cita_model.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String _userName = '';
  String _barberiaNombre = '';
  int? _userId; // Guardaremos el ID del usuario

  // --- NUEVOS ESTADOS PARA CITAS ---
  List<CitaModel> _citasPendientes = [];
  bool _isLoadingCitas = true;
  String? _citasError;
  // --- FIN NUEVOS ESTADOS ---


  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchCitas(); // Llama a ambas funciones al iniciar
  }

  // Carga datos del usuario Y luego busca las citas
  Future<void> _loadUserDataAndFetchCitas() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id'); // <-- Guardamos el user_id
    if (!mounted) return; // Check if widget is still mounted after async gap
    setState(() {
      _userName = prefs.getString('user_nombre') ?? 'Usuario';
      _barberiaNombre = prefs.getString('barberia_nombre') ?? 'Barbería no asignada';
    });

    // Si tenemos user_id, buscamos sus citas
    if (_userId != null) {
      await _fetchCitasPendientes(); // <--- LLAMAMOS A LA NUEVA FUNCIÓN
    } else {
      // Si no hay user_id (raro), ponemos estado de error
      if (!mounted) return;
      setState(() {
        _isLoadingCitas = false;
        _citasError = "No se pudo identificar al usuario para cargar citas.";
      });
    }
  }

  // --- ¡NUEVA FUNCIÓN PARA OBTENER CITAS PENDIENTES! ---
  Future<void> _fetchCitasPendientes() async {
    if (_userId == null) return; // No hacer nada si no hay user_id

    if (!mounted) return;
    setState(() {
      _isLoadingCitas = true;
      _citasError = null;
    });

    // Usa 10.0.2.2 si es emulador Android, localhost o 127.0.0.1 para web/físico
    final String apiUrl = "http://127.0.0.1:8000/usuarios/$_userId/citas/pendientes";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (!mounted) return; // Check again after the await

      if (response.statusCode == 200) {
        // Decode response body using UTF-8 to handle potential special characters
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _citasPendientes = citasJson
              .map((json) => CitaModel.fromJson(json))
              .toList();
          _isLoadingCitas = false;
        });
      } else {
         if (!mounted) return;
        setState(() {
          _citasError = "Error ${response.statusCode}: No se pudieron cargar las citas.";
          _isLoadingCitas = false;
        });
        print("API Error Citas: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _citasError = "Error de conexión al cargar citas: $e";
        _isLoadingCitas = false;
      });
      print("Fetch Citas Error: $e");
    }
  }
  // --- FIN NUEVA FUNCIÓN ---


  // --- Funciones de Navegación (sin cambios) ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
   }
  void _goToMapScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
   }
  void _goToAgendarCita() {
     print("Navegando a agendar cita...");
     if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pantalla "Agendar Cita" aún no implementada.')),
        );
     }
   }
  void _goToHistorial() {
      // Navega a la pantalla de historial
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenido, $_userName'),
              if (_barberiaNombre.isNotEmpty && _barberiaNombre != 'Barbería no asignada')
                Text(
                  _barberiaNombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                ),
            ],
          ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
           IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Cambiar de Barbería',
            onPressed: _goToMapScreen,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sección Citas Pendientes (ACTUALIZADA) ---
            Row( // Row for title and refresh button
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Próximas Citas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton( // Refresh button
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar citas',
                  onPressed: _fetchCitasPendientes,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCitasList(), // Usamos un widget helper
            ),
            // --- FIN Sección Citas Pendientes ---
            const SizedBox(height: 24),

            // --- Botones de Acción (sin cambios) ---
             SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agendar Nueva Cita'),
                onPressed: _goToAgendarCita,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Ver Historial de Citas'),
                onPressed: _goToHistorial,
                 style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.white,
                   side: BorderSide(color: Colors.grey[700]!),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
                 ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ¡NUEVO WIDGET HELPER PARA MOSTRAR LA LISTA DE CITAS! ---
  Widget _buildCitasList() {
    if (_isLoadingCitas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_citasError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_citasError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchCitasPendientes, // Allows retrying
              child: const Text('Reintentar'),
            )
          ],
        ),
      );
    }
    if (_citasPendientes.isEmpty) {
      return Center(
        child: Text(
          'Aún no tienes citas pendientes.',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
      );
    }

    // Si hay citas, las mostramos en una lista
    return RefreshIndicator( // Added RefreshIndicator
       onRefresh: _fetchCitasPendientes, // Call fetch on pull-to-refresh
       child: ListView.builder(
        itemCount: _citasPendientes.length,
        itemBuilder: (context, index) {
          final cita = _citasPendientes[index];
          // Formateamos la fecha y hora para que sean legibles en español
          final formatoFecha = DateFormat('EEEE d MMM y', 'es_ES'); // ej. martes 5 Nov 2025
          final formatoHora = DateFormat('h:mm a', 'es_ES');    // ej. 3:00 PM

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
             color: Colors.grey[850], // Darker card background
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                 backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                    cita.barbero.nombre.isNotEmpty ? cita.barbero.nombre.substring(0, 1) : '?', // Inicial del barbero
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)
                ),
              ),
              title: Text(
                  cita.servicioAgendado.servicio.nombre,
                   style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                'Con ${cita.barbero.nombre}\n${formatoFecha.format(cita.fechaHora)} a las ${formatoHora.format(cita.fechaHora)}',
                 style: TextStyle(color: Colors.grey[400])
              ),
              trailing: Chip(
                 label: Text(cita.estado, style: TextStyle(fontSize: 12)),
                 backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                 labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                 side: BorderSide.none,
              ),
              isThreeLine: true,
              onTap: () {
                // TODO: Añadir onTap para ver detalles/modificar/cancelar la cita
                print('Tapped cita ID: ${cita.id}');
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Detalles de cita ${cita.id} aún no implementados.')),
                 );
              },
            ),
          );
        },
      ),
    );
  }

   // Helper function to get color based on status
   Color _getStatusColor(String status) {
     switch (status.toLowerCase()) {
       case 'pendiente':
         return Colors.orangeAccent;
       case 'confirmada':
         return Colors.blueAccent;
       case 'completada':
         return Colors.green;
       case 'cancelada':
         return Colors.redAccent;
       default:
         return Colors.grey;
     }
   }
   // --- FIN NUEVO WIDGET HELPER ---
}