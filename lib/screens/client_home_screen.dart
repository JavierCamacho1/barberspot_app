import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Para llamadas API
import 'dart:convert';                   // Para jsonDecode
import 'package:intl/intl.dart';           // Para formatear fechas/horas

// Asegúrate de que la ruta al modelo sea correcta según tu estructura de carpetas
import 'cita_model.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'agendar_cita_screen.dart'; // Importar pantalla de agendar
import 'history_screen.dart';    // Importar pantalla de historial

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String _userName = '';
  String _barberiaNombre = '';
  int? _userId;

  // Estados para citas
  List<CitaModel> _citasPendientes = [];
  bool _isLoadingCitas = true;
  String? _citasError;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchCitas();
  }

  Future<void> _loadUserDataAndFetchCitas() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_nombre') ?? 'Usuario';
      _barberiaNombre = prefs.getString('barberia_nombre') ?? 'Barbería no asignada';
    });
    if (_userId != null) {
      await _fetchCitasPendientes();
    } else {
      if (!mounted) return;
      setState(() {
        _isLoadingCitas = false;
        _citasError = "No se pudo identificar al usuario para cargar citas.";
      });
    }
  }

  Future<void> _fetchCitasPendientes() async {
    if (_userId == null) return;
    if (!mounted) return;
    // Show loading only on initial load or if there was a previous error
    if (_citasPendientes.isEmpty || _citasError != null) {
      setState(() {
        _isLoadingCitas = true;
        _citasError = null;
      });
    }
    final String apiUrl = "http://127.0.0.1:8000/usuarios/$_userId/citas/pendientes";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _citasPendientes = citasJson.map((json) => CitaModel.fromJson(json)).toList();
          _isLoadingCitas = false;
          _citasError = null;
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

  // --- FUNCIÓN PARA CANCELAR CITA ---
  Future<void> _cancelarCita(int citaId) async {
    // Show confirmation dialog
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cancelación'),
          content: const Text('¿Estás seguro de que deseas cancelar esta cita?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false); // Do not confirm
              },
            ),
            TextButton(
              child: const Text('Sí, Cancelar'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm
              },
            ),
          ],
        );
      },
    );

    // If user didn't confirm, do nothing
    if (confirmar != true || !mounted) {
      return;
    }

    // Call API if confirmed
    final String apiUrl = "http://127.0.0.1:8000/citas/$citaId/cancelar";
    // Optional: Add a specific loading indicator for the card being cancelled

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada con éxito.'), backgroundColor: Colors.green),
        );
        // Refresh the list so the cancelled appointment disappears
        _fetchCitasPendientes();
      } else {
        // API error (e.g., 400 if already cancelled, 404 if not found)
        final Map<String, dynamic> responseData = json.decode(response.body);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cancelar: ${responseData['detail'] ?? 'Error desconocido'}')),
         );
      }
    } catch (e) {
      // Connection error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al cancelar.')),
      );
      print("Cancel Cita Error: $e");
    }
    // Optional: Remove specific loading indicator here
  }
  // --- FIN FUNCIÓN CANCELAR CITA ---


  // --- Funciones de Navegación ---
  Future<void> _logout() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
     if (mounted) {
       // Use pushReplacement to prevent going back to home screen after logout
       Navigator.of(context).pushReplacement(
         MaterialPageRoute(builder: (context) => const LoginScreen()),
       );
     }
   }
  void _goToMapScreen() {
     // Use push to allow going back from map screen
     Navigator.of(context).push(
       MaterialPageRoute(builder: (context) => const MapScreen()),
     );
   }

  // Navigate to Agendar Cita and refresh list on return
  void _goToAgendarCita() async {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AgendarCitaScreen()),
      );
      // Refresh if we returned (result can be null if back button used, true if confirmed)
      if ((result == true || result == null) && mounted) {
          print("Regresando de Agendar Cita, refrescando...");
          _fetchCitasPendientes(); // Reload appointments
      }
  }

   void _goToHistorial() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Próximas Citas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                // Removed manual refresh button, using pull-to-refresh
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCitasList(), // Helper widget for the list
            ),
            const SizedBox(height: 24),

            // --- Action Buttons ---
             SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agendar Nueva Cita'),
                onPressed: _goToAgendarCita, // Calls updated function
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

  // --- WIDGET HELPER FOR APPOINTMENT LIST (UPDATED WITH CANCEL BUTTON) ---
  Widget _buildCitasList() {
    // Initial loading state
    if (_isLoadingCitas && _citasPendientes.isEmpty && _citasError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Error state when initially loading and list is empty
    if (_citasError != null && _citasPendientes.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Text(_citasError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
             const SizedBox(height: 10),
             ElevatedButton(
               onPressed: _fetchCitasPendientes, // Allow retry
               child: const Text('Reintentar'),
             )
           ],
         ),
       );
    }
    // Empty state after loading successfully
    if (_citasPendientes.isEmpty && !_isLoadingCitas) {
       // Wrap the empty message in RefreshIndicator as well
       return RefreshIndicator(
         onRefresh: _fetchCitasPendientes,
         child: LayoutBuilder( // Needed so ListView works inside RefreshIndicator when empty
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling even when empty
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Aún no tienes citas pendientes.',
                         style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                         textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
       );
    }

    // If there are appointments, display them in the RefreshIndicator list
    return RefreshIndicator(
       onRefresh: _fetchCitasPendientes, // The key for pull-to-refresh
       child: ListView.builder(
         physics: const AlwaysScrollableScrollPhysics(), // Ensure scrolling for refresh
        itemCount: _citasPendientes.length,
        itemBuilder: (context, index) {
          final cita = _citasPendientes[index];
          final formatoFecha = DateFormat('EEEE d MMM y', 'es_ES');
          final formatoHora = DateFormat('h:mm a', 'es_ES');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.grey[850],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                 backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                    cita.barbero.nombre.isNotEmpty ? cita.barbero.nombre.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)
                ),
              ),
              title: Text(
                  cita.servicioAgendado.servicio.nombre,
                   style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              // --- SUBTITLE MODIFIED WITH CANCEL BUTTON ---
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Con ${cita.barbero.nombre}\n${formatoFecha.format(cita.fechaHora)} a las ${formatoHora.format(cita.fechaHora)}',
                       style: TextStyle(color: Colors.grey[400], height: 1.4)
                    ),
                    // Show button only if pending or confirmed
                    if (cita.estado == 'pendiente' || cita.estado == 'confirmada')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0), // Space above button
                        child: TextButton(
                           onPressed: () => _cancelarCita(cita.id), // Call the cancel function
                           style: TextButton.styleFrom(
                             foregroundColor: Colors.redAccent[100], // Softer red for dark theme
                             padding: EdgeInsets.zero, // Remove extra padding
                             tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Adjust tap area
                             minimumSize: const Size(0, 30), // Reduce minimum height
                             alignment: Alignment.centerLeft // Align to the left
                           ),
                           child: const Text('Cancelar Cita', style: TextStyle(fontSize: 13)), // Smaller text
                         ),
                      ),
                  ],
                ),
              // --- END SUBTITLE MODIFIED ---
              trailing: Chip(
                 label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                 backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                 labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                 side: BorderSide.none,
              ),
              // Adjust isThreeLine based on whether the button is shown
              isThreeLine: cita.estado == 'pendiente' || cita.estado == 'confirmada',
              onTap: () {
                // TODO: Navigate to appointment details/modify screen
                print('Tapped cita ID: ${cita.id}');
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Detalles de cita ${cita.id} aún no implementados.')),
                   );
                 }
              },
            ),
          );
        },
      ),
    );
  }
   // --- FIN WIDGET HELPER ---

   // Helper function to get color based on status
   Color _getStatusColor(String status) {
     switch (status.toLowerCase()) {
       case 'pendiente': return Colors.orangeAccent;
       case 'confirmada': return Colors.blueAccent;
       case 'completada': return Colors.green;
       case 'cancelada': return Colors.redAccent;
       default: return Colors.grey;
     }
   }
}