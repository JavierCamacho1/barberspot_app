import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Para 'es_ES'

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
    // Cargamos el formato español para las fechas
    initializeDateFormatting('es_ES', null).then((_) {
      _loadUserIdAndFetchHistory();
    });
  }

  // --- LÓGICA DE DATOS (SIN CAMBIOS) ---

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

    final String apiUrl = "http://127.0.0.1:8000/usuarios/$_userId/citas/historial";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> citasJson = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error de conexión al cargar historial: $e";
        _isLoading = false;
      });
    }
  }

  // --- UI REDISEÑADA ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa 1: Fondo con Gradiente
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF000000)],
            ),
          ),
        ),
        
        // Capa 2: Contenido de la Pantalla
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true, // El cuerpo pasa por detrás del AppBar
          appBar: AppBar(
            title: const Text('Historial de Citas', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white), // Flecha de regreso blanca
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          body: Padding(
            // Padding para dejar espacio al AppBar de vidrio
            padding: EdgeInsets.fromLTRB(
              16.0,
              kToolbarHeight + MediaQuery.of(context).padding.top, // Altura del AppBar + SafeArea
              16.0,
              0.0 // Sin padding abajo para que la lista llegue al fondo
            ),
            child: _buildHistorialList(),
          ),
        ),
      ],
    );
  }

  // Widget para construir la lista (REDISEÑADO)
  Widget _buildHistorialList() {
    if (_isLoading) {
      // Indicador de carga estilizado
      return const Center(child: CircularProgressIndicator(color: Colors.white));
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
      return RefreshIndicator(
        onRefresh: _fetchCitasHistorial,
        color: Colors.white,
        backgroundColor: Colors.black.withOpacity(0.3),
        child: LayoutBuilder( // Necesario para que el refresh funcione con la lista vacía
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Text(
                  'No tienes citas en tu historial.',
                  style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Si hay citas, las mostramos en una lista de vidrio
    return RefreshIndicator(
      onRefresh: _fetchCitasHistorial,
      color: Colors.white,
      backgroundColor: Colors.black.withOpacity(0.3),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16.0, bottom: 16.0), // Padding interno de la lista
        itemCount: _citasHistorial.length,
        itemBuilder: (context, index) {
          final cita = _citasHistorial[index];
          // Usamos el nuevo helper de tarjeta de vidrio
          return _buildGlassHistoryCard(cita);
        },
      ),
    );
  }

  // --- NUEVO WIDGET HELPER PARA TARJETA DE VIDRIO ---
  Widget _buildGlassHistoryCard(CitaModel cita) {
    final formatoFecha = DateFormat('EEEE d MMMM', 'es_ES');
    final formatoHora = DateFormat('h:mm a', 'es_ES');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              // Usamos el color del estado para un toque sutil
              color: _getStatusColor(cita.estado).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cita.servicioAgendado.servicio.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      backgroundColor: _getStatusColor(cita.estado).withOpacity(0.25),
                      labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Con ${cita.barbero.nombre}',
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${formatoFecha.format(cita.fechaHora)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
                 Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'a las ${formatoHora.format(cita.fechaHora)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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