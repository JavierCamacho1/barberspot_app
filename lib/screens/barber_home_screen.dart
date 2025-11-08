import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para groupBy

import 'cita_model.dart';
import 'login_screen.dart';
import 'barber_history_screen.dart'; // Para navegar al historial

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  String _barberName = '';
  int? _barberId;

  List<CitaModel> _citasSemana = [];
  bool _isLoadingCitas = true;
  String? _citasError;

  final DateFormat _headerDateFormat = DateFormat('EEEE d MMM y', 'es_ES');
  final DateFormat _timeFormat = DateFormat('h:mm a', 'es_ES');
  
  // Controlador para el motivo de cancelación
  final TextEditingController _cancelReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBarberDataAndFetchCitas();
  }
  
  @override
  void dispose() {
    // Limpiamos el controlador
    _cancelReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBarberDataAndFetchCitas() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id');
    if (!mounted) return;
    setState(() {
      _barberName = prefs.getString('user_nombre') ?? 'Barbero';
    });
    if (_barberId != null) {
      await _fetchCitasSemana();
    } else {
      if (!mounted) return;
      setState(() {
        _isLoadingCitas = false;
        _citasError = "No se pudo identificar al barbero.";
      });
    }
  }

  Future<void> _fetchCitasSemana() async {
     if (_barberId == null) return;
    if (!mounted) return;
    // Mostrar indicador solo si la lista está vacía o hubo error previo
    if (_citasSemana.isEmpty || _citasError != null) {
        setState(() {
        _isLoadingCitas = true;
        _citasError = null;
        });
    }
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/citas/semana";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _citasSemana = citasJson.map((json) => CitaModel.fromJson(json)).toList();
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

  // --- FUNCIÓN PARA MARCAR CITA COMPLETADA ---
  Future<void> _marcarCitaCompletada(int citaId) async {
    final String apiUrl = "http://127.0.0.1:8000/citas/$citaId/completar";
    
    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita marcada como completada.'), backgroundColor: Colors.green),
        );
        _fetchCitasSemana(); // Refresca la lista (la cita desaparecerá de aquí)
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al completar la cita.')),
      );
    }
  }

  // --- FUNCIÓN PARA CANCELAR CITA (BARBERO) CON MOTIVO ---
  Future<void> _cancelarCitaBarbero(int citaId) async {
    // 1. Limpiar el controlador del diálogo anterior
    _cancelReasonController.clear();

    // 2. Preguntar por el motivo
    final String? motivo = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancelar Cita'),
          content: TextField(
            controller: _cancelReasonController,
            decoration: const InputDecoration(
              hintText: "Motivo de la cancelación (ej. cliente no asistió)",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(), // Cierra sin devolver nada
            ),
            TextButton(
              child: const Text('Confirmar Cancelación'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () {
                // Validación simple para que el motivo no esté vacío
                if (_cancelReasonController.text.trim().length < 5) {
                   // Opcional: mostrar un mini error dentro del diálogo
                   print("El motivo debe tener al menos 5 caracteres");
                   // Podríamos añadir un validador visual aquí
                } else {
                  Navigator.of(context).pop(_cancelReasonController.text); // Devuelve el motivo
                }
              },
            ),
          ],
        );
      },
    );

    // 3. Si el usuario no escribió un motivo o cerró el diálogo, no hacemos nada
    if (motivo == null || motivo.trim().isEmpty || !mounted) {
      return;
    }

    // 4. Si hay motivo, llamar a la API
    final String apiUrl = "http://127.0.0.1:8000/barberos/citas/$citaId/cancelar";

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'motivo': motivo}), // <-- Enviamos el motivo
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada por el barbero.'), backgroundColor: Colors.orange),
        );
        _fetchCitasSemana(); // Refresca la lista
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al cancelar la cita.')),
      );
    }
  }


  // --- FUNCIÓN PARA MOSTRAR OPCIONES DE CITA ---
  void _mostrarAccionesCita(CitaModel cita) {
    // Solo muestra opciones si la cita está 'pendiente' o 'confirmada'
    if (cita.estado != 'pendiente' && cita.estado != 'confirmada') {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Esta cita ya está ${cita.estado}.')),
        );
       }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              // Título del Modal (Cliente y Servicio)
               ListTile(
                title: Text(cita.cliente.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(cita.servicioAgendado.servicio.nombre),
                trailing: Chip(
                   label: Text(cita.estado, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                   backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                   labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                ),
              ),
               const Divider(height: 1),
              // Opción 1: Marcar como Completada
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Marcar como Completada'),
                onTap: () {
                  Navigator.of(context).pop(); // Cierra el modal
                  _marcarCitaCompletada(cita.id); // Llama a la función
                },
              ),
              // Opción 2: Marcar como No Asistió / Cancelar
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.redAccent),
                title: const Text('Marcar como No Asistió / Cancelar'),
                onTap: () {
                  Navigator.of(context).pop(); // Cierra el modal
                  _cancelarCitaBarbero(cita.id); // Llama a la función con motivo
                },
              ),
              // Opción 3: Cerrar
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cerrar'),
                onTap: () {
                  Navigator.of(context).pop(); // Solo cierra el modal
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // --- FIN NUEVAS FUNCIONES ---


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
     Navigator.of(context).push(
       MaterialPageRoute(builder: (context) => const BarberHistoryScreen()),
     );
   }
  void _goToDisponibilidad() {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pantalla "Disponibilidad" aún no implementada.')),
      );
     }
   }
  // --- FIN Funciones de Navegación ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agenda Semanal - $_barberName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout, // Llama a la función
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCitasSemanaList(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Disponibilidad'),
                  onPressed: _goToDisponibilidad, // Llama a la función
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Mi Historial'),
                  onPressed: _goToHistorialBarbero, // Llama a la función
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER (ACTUALIZADO CON onTap) ---
  Widget _buildCitasSemanaList() {
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
               onPressed: _fetchCitasSemana,
               child: const Text('Reintentar'),
             )
           ],
         ),
       );
     }
     // Estado vacío después de cargar
    if (_citasSemana.isEmpty && !_isLoadingCitas) { 
       return RefreshIndicator(
         onRefresh: _fetchCitasSemana,
         child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
    final Map<DateTime, List<CitaModel>> citasAgrupadas = groupBy(
      _citasSemana,
      (CitaModel cita) {
          final localDate = cita.fechaHora.toLocal();
          return DateTime(localDate.year, localDate.month, localDate.day);
      }
    );
    final List<DateTime> diasOrdenados = citasAgrupadas.keys.toList()..sort();
    // --- FIN LÓGICA DE AGRUPACIÓN ---

    return RefreshIndicator(
       onRefresh: _fetchCitasSemana,
       child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: diasOrdenados.length,
        itemBuilder: (context, indexDia) {
          final dia = diasOrdenados[indexDia];
          final citasDelDia = citasAgrupadas[dia]!..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del Día
                Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                   child: Text(
                     _headerDateFormat.format(dia.toLocal()),
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent[100]),
                   ),
                 ),
                 // Lista de Citas para ese Día
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: citasDelDia.length,
                  itemBuilder: (context, indexCita) {
                    final cita = citasDelDia[indexCita];
                    final horaFormateada = _timeFormat.format(cita.fechaHora.toLocal());

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                           backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            child: Text(
                                cita.cliente.nombre.isNotEmpty ? cita.cliente.nombre.substring(0, 1).toUpperCase() : '?',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)
                            ),
                         ),
                        title: Text(
                           cita.servicioAgendado.servicio.nombre,
                           style: const TextStyle(fontWeight: FontWeight.bold),
                         ),
                        subtitle: Text(
                           '$horaFormateada - ${cita.cliente.nombre}',
                           style: TextStyle(color: Colors.grey[400]),
                         ),
                        trailing: Chip(
                           label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                           backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                           labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                           side: BorderSide.none,
                         ),
                        
                        // --- ¡onTap ACTUALIZADO! ---
                        onTap: () {
                          // Llama a la función que muestra el modal de acciones
                          _mostrarAccionesCita(cita); 
                        },
                        // --- FIN onTap ACTUALIZADO ---
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
   // --- FIN WIDGET HELPER ---

   // Helper para color de estado
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