import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Asegúrate que la ruta sea correcta
import 'cita_model.dart';

class BarberHistoryScreen extends StatefulWidget {
  const BarberHistoryScreen({super.key});

  @override
  State<BarberHistoryScreen> createState() => _BarberHistoryScreenState();
}

class _BarberHistoryScreenState extends State<BarberHistoryScreen> {
  int? _barberId;
  List<CitaModel> _citasHistorial = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBarberIdAndFetchHistory();
  }

  Future<void> _loadBarberIdAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id'); // El ID del barbero logueado
    if (_barberId != null) {
      await _fetchCitasHistorial();
    } else {
       if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "No se pudo identificar al barbero.";
      });
    }
  }

  Future<void> _fetchCitasHistorial() async {
    if (_barberId == null) return;

     if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // ¡Endpoint del Barbero!
    // Usa 10.0.2.2 si es emulador Android, localhost o 127.0.0.1 para web/físico
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/citas/historial";

    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          // Guardamos en la lista _citasHistorial
          _citasHistorial = citasJson
              .map((json) => CitaModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Error ${response.statusCode}: No se pudo cargar el historial.";
          _isLoading = false;
        });
        print("API Error Historial Barbero: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error de conexión al cargar historial: $e";
        _isLoading = false;
      });
      print("Fetch Historial Barbero Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial de Atenciones'),
        // El botón de atrás aparece automáticamente
      ),
      body: _buildHistorialList(), // Usamos un widget helper
    );
  }

  // Widget para construir la lista (similar al de ClientHomeScreen)
  Widget _buildHistorialList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchCitasHistorial,
              child: const Text('Reintentar'),
            )
          ],
        ),
      );
    }
    if (_citasHistorial.isEmpty) {
       // Envuelto en RefreshIndicator para consistencia
       return RefreshIndicator(
         onRefresh: _fetchCitasHistorial,
         child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(
                    child: Text(
                      'No tienes citas en tu historial.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
       );
    }

    // Si hay citas, las mostramos en una lista
    return RefreshIndicator(
      onRefresh: _fetchCitasHistorial,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0), // Padding alrededor de la lista
        itemCount: _citasHistorial.length,
        itemBuilder: (context, index) {
          final cita = _citasHistorial[index];
          final formatoFecha = DateFormat('EEEE d MMM y', 'es_ES');
          final formatoHora = DateFormat('h:mm a', 'es_ES');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.grey[850],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              // Mostramos la inicial del CLIENTE
              leading: CircleAvatar(
                 backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                    cita.cliente.nombre.isNotEmpty ? cita.cliente.nombre.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)
                ),
              ),
              title: Text(
                  cita.servicioAgendado.servicio.nombre,
                   style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                'Cliente: ${cita.cliente.nombre}\n${formatoFecha.format(cita.fechaHora.toLocal())} a las ${formatoHora.format(cita.fechaHora.toLocal())}',
                 style: TextStyle(color: Colors.grey[400])
              ),
              trailing: Chip(
                 label: Text(cita.estado, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                 backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                 labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: BorderSide.none,
              ),
              isThreeLine: true,
              onTap: () {
                 print('Tapped cita histórica barbero ID: ${cita.id}');
                 // Aquí podríamos mostrar el motivo de cancelación si existe
                 if (cita.cancelacion_motivo != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Motivo: ${cita.cancelacion_motivo!}')),
                   );
                 }
              },
            ),
          );
        },
      ),
    );
  }

   // Helper function to get color based on status (igual que en ClientHomeScreen)
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