import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para groupBy

// Asegúrate que la ruta sea correcta
import 'cita_model.dart';
import 'login_screen.dart';       // Para cerrar sesión

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  String _barberName = '';
  int? _barberId;

  // Estados para las citas de la SEMANA
  List<CitaModel> _citasSemana = []; // <-- Renombrado
  bool _isLoadingCitas = true;
  String? _citasError;

  // Formateadores de fecha/hora
  final DateFormat _headerDateFormat = DateFormat('EEEE d MMM y', 'es_ES'); // Para encabezados de día
  final DateFormat _timeFormat = DateFormat('h:mm a', 'es_ES');       // Para la hora de la cita

  @override
  void initState() {
    super.initState();
    _loadBarberDataAndFetchCitas();
  }

  Future<void> _loadBarberDataAndFetchCitas() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id'); // El ID del barbero logueado
    if (!mounted) return;
    setState(() {
      _barberName = prefs.getString('user_nombre') ?? 'Barbero';
      // No necesitamos el nombre de la barbería aquí, pero podríamos cargarlo si quisiéramos
    });

    if (_barberId != null) {
      await _fetchCitasSemana(); // <-- Llamamos a la nueva función
    } else {
      if (!mounted) return;
      setState(() {
        _isLoadingCitas = false;
        _citasError = "No se pudo identificar al barbero.";
      });
    }
  }

  // --- FUNCIÓN ACTUALIZADA PARA OBTENER CITAS DE LA SEMANA ---
  Future<void> _fetchCitasSemana() async { // <-- Renombrado
    if (_barberId == null) return;

    if (!mounted) return;
    // Mostrar indicador solo si la lista está vacía o hubo error previo
    if (_citasSemana.isEmpty || _citasError != null) {
        setState(() {
        _isLoadingCitas = true;
        _citasError = null;
        });
    }

    // ¡NUEVO ENDPOINT!
    // Usa 10.0.2.2 si es emulador Android, localhost o 127.0.0.1 para web/físico
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/citas/semana";

    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _citasSemana = citasJson // <-- Guardamos en la nueva lista
              .map((json) => CitaModel.fromJson(json))
              .toList();
          _isLoadingCitas = false;
          _citasError = null;
        });
      } else {
         if (!mounted) return;
        setState(() {
          _citasError = "Error ${response.statusCode}: No se pudieron cargar las citas.";
          _isLoadingCitas = false;
        });
        print("API Error Citas Semana: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _citasError = "Error de conexión al cargar citas: $e";
        _isLoadingCitas = false;
      });
      print("Fetch Citas Semana Error: $e");
    }
  }
  // --- FIN FUNCIÓN ACTUALIZADA ---

  // --- Funciones de Navegación ---
  Future<void> _logout() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
     if (mounted) {
       Navigator.of(context).pushReplacement(
         MaterialPageRoute(builder: (context) => const LoginScreen()),
       );
     }
   }

   void _goToHistorialBarbero() {
     // TODO: Navegar a la pantalla de historial del barbero (FASE 4)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pantalla "Historial Barbero" aún no implementada.')),
        );
      }
   }

   void _goToDisponibilidad() {
      // TODO: Navegar a la pantalla de disponibilidad (FASE 4)
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pantalla "Disponibilidad" aún no implementada.')),
        );
       }
   }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agenda Semanal - $_barberName'), // Título cambiado
        actions: [
           IconButton( // Botón Logout añadido aquí
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Lista de Citas de la Semana ---
          Expanded(
            child: _buildCitasSemanaList(), // <-- Llamamos a la nueva función de build
          ),
          // --- Botones de Acción para Barbero ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Espaciado entre botones
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Disponibilidad'),
                  onPressed: _goToDisponibilidad,
                  // Estilo puede venir del tema global en main.dart
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Mi Historial'),
                  onPressed: _goToHistorialBarbero,
                   // Estilo puede venir del tema global en main.dart
                ),
              ],
             ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ACTUALIZADO PARA MOSTRAR LA LISTA AGRUPADA POR DÍA ---
  Widget _buildCitasSemanaList() { // <-- Renombrado
    // Estado de carga inicial
    if (_isLoadingCitas && _citasSemana.isEmpty && _citasError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Estado de error inicial
    if (_citasError != null && _citasSemana.isEmpty) {
      return Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(_citasError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
               const SizedBox(height: 10),
               ElevatedButton(
                 onPressed: _fetchCitasSemana, // Llama a la función correcta
                 child: const Text('Reintentar'),
               )
             ],
           ),
         );
    }
     // Estado vacío después de cargar
    if (_citasSemana.isEmpty && !_isLoadingCitas) {
       return RefreshIndicator(
         onRefresh: _fetchCitasSemana, // Llama a la función correcta
         child: LayoutBuilder( // Necesario para que RefreshIndicator funcione con lista vacía
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Permite scroll para refrescar
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight), // Ocupa toda la altura
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No tienes citas programadas para esta semana.',
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

    // --- LÓGICA DE AGRUPACIÓN ---
    // Agrupamos las citas por día (ignorando la hora)
    final Map<DateTime, List<CitaModel>> citasAgrupadas = groupBy(
      _citasSemana,
      // Usamos toLocal() para agrupar por fecha local, no UTC
      (CitaModel cita) {
          final localDate = cita.fechaHora.toLocal();
          return DateTime(localDate.year, localDate.month, localDate.day);
      }
    );
    // Ordenamos los días
    final List<DateTime> diasOrdenados = citasAgrupadas.keys.toList()..sort();
    // --- FIN LÓGICA DE AGRUPACIÓN ---

    // Mostramos la lista agrupada
    return RefreshIndicator(
       onRefresh: _fetchCitasSemana, // Llama a la función correcta
       child: ListView.builder(
         padding: const EdgeInsets.all(8.0), // Padding exterior
        // La cantidad de items ahora es la cantidad de DÍAS con citas
        itemCount: diasOrdenados.length,
        itemBuilder: (context, indexDia) {
          final dia = diasOrdenados[indexDia];
          // Ordenamos las citas de ese día por hora
          final citasDelDia = citasAgrupadas[dia]!..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

          // Creamos una columna para cada día
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del Día
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Text(
                    // Formateamos usando la fecha local
                    _headerDateFormat.format(dia.toLocal()),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent[100]),
                  ),
                ),
                // Lista de Citas para ese Día
                ListView.builder(
                  shrinkWrap: true, // Para que funcione dentro de la Column
                  physics: const NeverScrollableScrollPhysics(), // Deshabilita scroll interno
                  itemCount: citasDelDia.length,
                  itemBuilder: (context, indexCita) {
                    final cita = citasDelDia[indexCita];
                    // Formateamos la hora usando toLocal()
                    final horaFormateada = _timeFormat.format(cita.fechaHora.toLocal());

                    return Card(
                       margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                       color: Colors.grey[850],
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          cita.servicioAgendado.servicio.nombre, // Servicio
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Subtítulo: Hora y Nombre del Cliente
                        subtitle: Text(
                          '$horaFormateada - ${cita.cliente.nombre}', // Hora local formateada
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                         // Estado de la cita
                        trailing: Chip(
                           label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                           backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                           labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                           side: BorderSide.none,
                         ),
                        onTap: () {
                          // TODO: Ir a detalles de la cita (marcar como completada?)
                           print('Tapped cita barbero ID: ${cita.id}');
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Acciones para cita ${cita.id} aún no implementadas.')),
                             );
                           }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
   // --- FIN WIDGET HELPER ACTUALIZADO ---

   // Helper para color de estado (igual que en ClientHomeScreen)
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



