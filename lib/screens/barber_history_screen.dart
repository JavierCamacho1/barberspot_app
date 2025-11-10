import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Para 'es_ES'

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
    // ¡AÑADIDO! Asegura que el formato 'es_ES' esté cargado
    initializeDateFormatting('es_ES', null).then((_) {
      _loadBarberIdAndFetchHistory();
    });
  }

  // --- LÓGICA DE DATOS (Sin cambios) ---
  Future<void> _loadBarberIdAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id');
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
    
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/citas/historial";

    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

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
            title: const Text('Mi Historial de Atenciones', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          body: _buildHistorialList(),
        ),
      ],
    );
  }

  // Widget para construir la lista (REDISEÑADO)
  Widget _buildHistorialList() {
    if (_isLoading) {
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
    
    // Obtenemos el padding superior para el AppBar
    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;
    
    if (_citasHistorial.isEmpty) {
       return RefreshIndicator(
         onRefresh: _fetchCitasHistorial,
         color: Colors.white,
         backgroundColor: Colors.black.withOpacity(0.3),
         child: LayoutBuilder(
           builder: (context, constraints) => SingleChildScrollView(
             physics: const AlwaysScrollableScrollPhysics(),
             child: ConstrainedBox(
               constraints: BoxConstraints(minHeight: constraints.maxHeight),
               child: Center(
                 child: Padding(
                   padding: const EdgeInsets.only(top: 80.0), // Padding extra
                   child: Text(
                     'No tienes citas en tu historial.',
                     style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                     textAlign: TextAlign.center,
                   ),
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
      color: Colors.white,
      backgroundColor: Colors.black.withOpacity(0.3),
      child: ListView.builder(
        // Padding para AppBar y para el fondo
        padding: EdgeInsets.fromLTRB(16.0, topPadding + 16.0, 16.0, 16.0),
        itemCount: _citasHistorial.length,
        itemBuilder: (context, index) {
          final cita = _citasHistorial[index];
          // Usamos el helper de tarjeta de vidrio
          return _buildGlassHistoryCard(cita);
        },
      ),
    );
  }

  // --- NUEVO WIDGET HELPER PARA TARJETA DE VIDRIO ---
  Widget _buildGlassHistoryCard(CitaModel cita) {
    final formatoFecha = DateFormat('EEEE d MMMM y', 'es_ES');
    final formatoHora = DateFormat('h:mm a', 'es_ES');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              color: _getStatusColor(cita.estado).withOpacity(0.1),
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
                'Cliente: ${cita.cliente.nombre}\n${formatoFecha.format(cita.fechaHora.toLocal())} a las ${formatoHora.format(cita.fechaHora.toLocal())}',
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              trailing: Chip(
                label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                backgroundColor: _getStatusColor(cita.estado).withOpacity(0.25),
                labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                side: BorderSide.none,
              ),
              isThreeLine: true,
              onTap: () {
                 // ¡MEJORADO! Muestra el motivo en un modal de vidrio
                 _showCancelReasonModal(cita);
              },
            ),
          ),
        ),
      ),
    );
  }
  
  /// ¡NUEVO! Muestra el motivo de cancelación en un modal
  void _showCancelReasonModal(CitaModel cita) {
    // Solo muestra el modal si la cita fue cancelada Y hay un motivo
    if (cita.estado == 'cancelada' && cita.cancelacion_motivo != null && cita.cancelacion_motivo!.isNotEmpty) {
      _showGlassModalSheet(
        context: context,
        title: 'Motivo de Cancelación',
        child: Text(
          cita.cancelacion_motivo!,
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
      );
    }
    // Opcional: podrías mostrar un SnackBar si se toca una cita "Completada"
    // else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Cita ${cita.estado}.')),
    //   );
    // }
  }

  /// Helper para Modal de Vidrio
  Future<T?> _showGlassModalSheet<T>({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
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
                const Divider(color: Colors.white24, height: 24),
                child,
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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