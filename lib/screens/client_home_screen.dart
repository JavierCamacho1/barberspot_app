import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para 'es_ES'

// Modelos y Pantallas
import 'cita_model.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'agendar_cita_screen.dart';
import 'history_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String _userName = '';
  String _barberiaNombre = '';
  int? _userId;

  List<CitaModel> _citasPendientes = [];
  bool _isLoadingCitas = true;
  String? _citasError;

  @override
  void initState() {
    super.initState();
    // Asegura que los formatos de fecha en español estén cargados
    initializeDateFormatting('es_ES', null).then((_) {
      _loadUserDataAndFetchCitas();
    });
  }

  // --- LÓGICA DE DATOS (SIN CAMBIOS) ---

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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _citasError = "Error de conexión al cargar citas: $e";
        _isLoadingCitas = false;
      });
    }
  }

  // --- FUNCIÓN PARA CANCELAR CITA (LÓGICA IGUAL, DIÁLOGO REDISEÑADO) ---
  Future<void> _cancelarCita(int citaId) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      // Hacemos que el fondo del diálogo sea borroso también
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        // Usamos el BackdropFilter para aplicar el desenfoque detrás del diálogo
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            // Estilo del Diálogo
            backgroundColor: Colors.grey[900]?.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            title: const Text(
              'Confirmar Cancelación',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              '¿Estás seguro de que deseas cancelar esta cita?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('No', style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                ),
                child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    final String apiUrl = "http://127.0.0.1:8000/citas/$citaId/cancelar";
    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada con éxito.'), backgroundColor: Colors.green),
        );
        _fetchCitasPendientes();
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cancelar: ${responseData['detail'] ?? 'Error desconocido'}')),
         );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al cancelar.')),
      );
    }
  }
  
  // --- Funciones de Navegación (LÓGICA SIN CAMBIOS) ---
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

  void _goToAgendarCita() async {
     final result = await Navigator.of(context).push(
       MaterialPageRoute(builder: (context) => const AgendarCitaScreen()),
     );
     if ((result == true || result == null) && mounted) {
       _fetchCitasPendientes();
     }
  }

   void _goToHistorial() {
     Navigator.of(context).push(
       MaterialPageRoute(builder: (context) => const HistoryScreen()),
     );
   }

  // --- UI REDISEÑADA ---

  @override
  Widget build(BuildContext context) {
    // Usamos el Stack para el fondo
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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, $_userName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (_barberiaNombre.isNotEmpty && _barberiaNombre != 'Barbería no asignada')
                  Text(
                    _barberiaNombre,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
              ],
            ),
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
            // Efecto Glassmorphism para el AppBar
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          body: Padding(
            // Padding ajustado para el AppBar transparente
            padding: EdgeInsets.fromLTRB(
              16.0,
              kToolbarHeight + MediaQuery.of(context).padding.top + 16.0, // Altura del AppBar + SafeArea
              16.0,
              16.0
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximas Citas',
                  style: TextStyle(
                    fontSize: 28, // Más grande
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildCitasList(), // Helper widget para la lista
                ),
                const SizedBox(height: 24),

                // --- Botones de Acción Rediseñados ---
                _buildGlassButtonPrimary(
                  text: 'Agendar Nueva Cita',
                  icon: Icons.add_circle_outline,
                  onPressed: _goToAgendarCita,
                ),
                const SizedBox(height: 12),
                _buildGlassButtonSecondary(
                  text: 'Ver Historial de Citas',
                  icon: Icons.history,
                  onPressed: _goToHistorial,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPER PARA LISTA DE CITAS (REDISEÑADO) ---
  Widget _buildCitasList() {
    if (_isLoadingCitas && _citasPendientes.isEmpty && _citasError == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    if (_citasError != null && _citasPendientes.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Text(_citasError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
             const SizedBox(height: 10),
             ElevatedButton(
               onPressed: _fetchCitasPendientes,
               child: const Text('Reintentar'),
             )
           ],
         ),
       );
    }
    
    if (_citasPendientes.isEmpty && !_isLoadingCitas) {
       return RefreshIndicator(
         onRefresh: _fetchCitasPendientes,
         color: Colors.white, // Color del spinner de refresh
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
                     'Aún no tienes citas pendientes.\n¡Agenda una!',
                       style: TextStyle(fontSize: 18, color: Colors.grey[400], height: 1.5),
                       textAlign: TextAlign.center,
                   ),
                 ),
               ),
             ),
           ),
         ),
       );
    }

    // Lista principal con RefreshIndicator
    return RefreshIndicator(
       onRefresh: _fetchCitasPendientes,
       color: Colors.white,
       backgroundColor: Colors.black.withOpacity(0.3),
       child: ListView.builder(
         physics: const AlwaysScrollableScrollPhysics(),
         itemCount: _citasPendientes.length,
         itemBuilder: (context, index) {
           final cita = _citasPendientes[index];
           return _buildGlassAppointmentCard(cita); // Usamos el helper de tarjeta de vidrio
         },
       ),
    );
  }
  
  // --- NUEVOS WIDGETS HELPER PARA ESTILO GLASSMORPHISM ---

  /// Tarjeta de Cita con estilo Glassmorphism
  Widget _buildGlassAppointmentCard(CitaModel cita) {
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Título del Servicio
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
                    // Chip de Estado
                    Chip(
                      label: Text(cita.estado, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      backgroundColor: _getStatusColor(cita.estado).withOpacity(0.2),
                      labelStyle: TextStyle(color: _getStatusColor(cita.estado)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                // Detalle: Barbero
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
                // Detalle: Fecha y Hora
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
                // Botón de Cancelar (si aplica)
                if (cita.estado == 'pendiente' || cita.estado == 'confirmada')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: TextButton.icon(
                      icon: Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancelar Cita', style: TextStyle(fontSize: 14)),
                      onPressed: () => _cancelarCita(cita.id),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent[100],
                        backgroundColor: Colors.red.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón principal (con gradiente azul)
  Widget _buildGlassButtonPrimary({required String text, required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [Colors.blue.shade800.withOpacity(0.8), Colors.blue.shade500.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  /// Botón secundario (borde de vidrio)
  Widget _buildGlassButtonSecondary({required String text, required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // Menos blur para un botón
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.0),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white70),
              label: Text(
                text,
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ),
      ),
    );
  }
   
  // Helper de color (SIN CAMBIOS)
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