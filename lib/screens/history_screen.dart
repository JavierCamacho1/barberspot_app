import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Asegúrate que la ruta sea correcta
import 'cita_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _userId;
  List<CitaModel> _citasHistorial = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetchHistory();
  }

  Future<void> _loadUserIdAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    if (_userId != null) {
      await _fetchCitasHistorial();
    } else {
       if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "No se pudo identificar al usuario.";
      });
    }
  }

  Future<void> _fetchCitasHistorial() async {
    if (_userId == null) return;

     if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // ¡Endpoint diferente!
    final String apiUrl = "http://127.0.0.1:8000/usuarios/$_userId/citas/historial";

    try {
      final response = await http.get(Uri.parse(apiUrl));

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
        print("API Error Historial: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error de conexión al cargar historial: $e";
        _isLoading = false;
      });
      print("Fetch Historial Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Citas'),
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
      return const Center(
        child: Text(
          'No tienes citas en tu historial.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
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
              leading: CircleAvatar(
                 backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                    cita.barbero.nombre.isNotEmpty ? cita.barbero.nombre.substring(0, 1) : '?',
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
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: BorderSide.none,
              ),
              isThreeLine: true,
              onTap: () {
                // TODO: Mostrar detalles de la cita histórica (quizás no editable)
                print('Tapped cita histórica ID: ${cita.id}');
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