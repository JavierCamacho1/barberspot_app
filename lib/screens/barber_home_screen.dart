import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ¡IMPORTANTE!
import 'package:collection/collection.dart'; // Para groupBy

import 'cita_model.dart';
import 'login_screen.dart';
import 'barber_history_screen.dart';
import 'availability_screen.dart';

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

  final DateFormat _headerDateFormat = DateFormat('EEEE d MMMM y', 'es_ES');
  final DateFormat _timeFormat = DateFormat('h:mm a', 'es_ES');
  
  final TextEditingController _cancelReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ¡AÑADIDO! Asegura que el formato 'es_ES' esté cargado
    initializeDateFormatting('es_ES', null).then((_) {
      _loadBarberDataAndFetchCitas();
    });
  }
  
  @override
  void dispose() {
    _cancelReasonController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE DATOS (SIN CAMBIOS) ---
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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _citasError = "Error de conexión al cargar citas: $e";
        _isLoadingCitas = false;
      });
    }
  }

  // --- LÓGICA DE ACCIONES (SIN CAMBIOS, EXCEPTO MODALES) ---
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
        _fetchCitasSemana();
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

  // --- ¡REDISEÑADO CON DIÁLOGO DE VIDRIO! ---
  Future<void> _cancelarCitaBarbero(int citaId) async {
    _cancelReasonController.clear();

    final String? motivo = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        // Usamos el BackdropFilter para aplicar el desenfoque detrás del diálogo
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.grey[900]?.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            title: const Text('Cancelar Cita', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: _cancelReasonController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Motivo (ej. cliente no asistió)",
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
                child: const Text('Confirmar Cancelación', style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  if (_cancelReasonController.text.trim().length < 5) {
                    // Aquí podrías manejar un error visual si quieres
                  } else {
                    Navigator.of(context).pop(_cancelReasonController.text);
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    if (motivo == null || motivo.trim().isEmpty || !mounted) {
      return;
    }

    // El resto de la lógica de API no cambia...
    final String apiUrl = "http://127.0.0.1:8000/barberos/citas/$citaId/cancelar";

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'motivo': motivo}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada por el barbero.'), backgroundColor: Colors.orange),
        );
        _fetchCitasSemana();
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


  // --- ¡REDISEÑADO CON MODAL DE VIDRIO! ---
  void _mostrarAccionesCita(CitaModel cita) {
    if (cita.estado != 'pendiente' && cita.estado != 'confirmada') {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Esta cita ya está ${cita.estado}.')),
        );
       }
      return;
    }

    // Usamos el helper de modal de vidrio
    _showGlassModalSheet(
      context: context,
      title: cita.cliente.nombre, // Título principal
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Subtítulo con el servicio y estado
          ListTile(
            dense: true,
            title: Text(cita.servicioAgendado.servicio.nombre, style: TextStyle(color: Colors.white70)),
            trailing: Chip(
              label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
              labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
            ),
          ),
          const Divider(color: Colors.white24),
          // Opciones con estilo oscuro
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Marcar como Completada', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pop();
              _marcarCitaCompletada(cita.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel, color: Colors.redAccent),
            title: const Text('Marcar como No Asistió / Cancelar', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pop();
              _cancelarCitaBarbero(cita.id);
            },
          ),
        ],
      ),
    );
  }

  // --- Funciones de Navegación (SIN CAMBIOS) ---
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AvailabilityScreen()),
    );
  }

  // --- UI REDISEÑADA ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa 1: Fondo Gradiente
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF000000)],
            ),
          ),
        ),
        
        // Capa 2: Contenido
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text('Agenda - $_barberName', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar Sesión',
                onPressed: _logout,
              ),
            ],
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          // Usamos un Column para la lista y la barra de navegación fija
          body: Column(
            children: [
              // La lista ocupa todo el espacio disponible
              Expanded(
                child: _buildCitasSemanaList(),
              ),
              // La barra de navegación se queda fija abajo
              _buildBottomNavBar(),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPER (REDISEÑADO) ---
  Widget _buildCitasSemanaList() {
    if (_isLoadingCitas && _citasSemana.isEmpty && _citasError == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
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
     
    if (_citasSemana.isEmpty && !_isLoadingCitas) { 
       return RefreshIndicator(
         onRefresh: _fetchCitasSemana,
         color: Colors.white,
         backgroundColor: Colors.black.withOpacity(0.3),
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

    // --- LÓGICA DE AGRUPACIÓN (SIN CAMBIOS) ---
    final Map<DateTime, List<CitaModel>> citasAgrupadas = groupBy(
      _citasSemana,
      (CitaModel cita) {
         final localDate = cita.fechaHora.toLocal();
         return DateTime(localDate.year, localDate.month, localDate.day);
      }
    );
    final List<DateTime> diasOrdenados = citasAgrupadas.keys.toList()..sort();
    
    // Obtenemos el padding superior para el AppBar
    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;

    return RefreshIndicator(
       onRefresh: _fetchCitasSemana,
       color: Colors.white,
       backgroundColor: Colors.black.withOpacity(0.3),
       child: ListView.builder(
         // Añadimos padding para el AppBar y para la barra inferior
         padding: EdgeInsets.fromLTRB(8.0, topPadding + 8.0, 8.0, 8.0),
         itemCount: diasOrdenados.length,
         itemBuilder: (context, indexDia) {
           final dia = diasOrdenados[indexDia];
           final citasDelDia = citasAgrupadas[dia]!..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

           return Padding(
             padding: const EdgeInsets.only(bottom: 16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Encabezado del Día (Estilizado)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                   child: Text(
                     _headerDateFormat.format(dia.toLocal()),
                     style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                 ),
                 // Lista de Citas para ese Día
                 ListView.builder(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: citasDelDia.length,
                   itemBuilder: (context, indexCita) {
                     final cita = citasDelDia[indexCita];
                     // Usamos el nuevo helper de tarjeta de vidrio
                     return _buildGlassBarberCard(cita);
                   },
                 ),
               ],
             ),
           );
         },
       ),
    );
  }
  
  // --- NUEVOS WIDGETS HELPER DE VIDRIO ---
  
  /// Construye la tarjeta de cita para el barbero
  Widget _buildGlassBarberCard(CitaModel cita) {
    final horaFormateada = _timeFormat.format(cita.fechaHora.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                child: Text(
                  cita.cliente.nombre.isNotEmpty ? cita.cliente.nombre.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(color: _getStatusColor(cita.estado), fontWeight: FontWeight.bold)
                ),
              ),
              title: Text(
                cita.servicioAgendado.servicio.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                '$horaFormateada - ${cita.cliente.nombre}',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: Chip(
                label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                side: BorderSide.none,
              ),
              onTap: () {
                _mostrarAccionesCita(cita); 
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la barra de navegación inferior de vidrio
  Widget _buildBottomNavBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
          child: SafeArea( // SafeArea para evitar el "home bar" de iOS/Android
            top: false, // Solo nos importa la parte de abajo
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGlassNavButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Disponibilidad',
                  onPressed: _goToDisponibilidad,
                  isPrimary: true, // Botón principal
                ),
                _buildGlassNavButton(
                  icon: Icons.history,
                  label: 'Mi Historial',
                  onPressed: _goToHistorialBarbero,
                  isPrimary: false, // Botón secundario
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper para los botones de la barra de navegación
  Widget _buildGlassNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      // Botón principal (con gradiente)
      return Expanded(
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [Colors.blue.shade800.withOpacity(0.8), Colors.blue.shade500.withOpacity(0.8)],
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 20),
            label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      );
    }
    // Botón secundario (solo texto e icono)
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white70, size: 20),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Helper para el modal de vidrio (copiado de agendar_cita_screen)
  void _showGlassModalSheet({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // El child (que ya tiene subtítulo)
                child, 
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper para color de estado (SIN CAMBIOS)
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