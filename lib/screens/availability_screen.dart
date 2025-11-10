import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ¡IMPORTANTE!
import 'edit_schedule_screen.dart';

// --- MODELOS DE DATOS (Sin cambios) ---
class Disponibilidad {
  final int id;
  final int diaSemana; // 0=Lunes, 6=Domingo
  final TimeOfDay horaInicio;
  final TimeOfDay horaFin;

  Disponibilidad({
    required this.id,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
  });

  factory Disponibilidad.fromJson(Map<String, dynamic> json) {
    TimeOfDay _timeFromString(String timeStr) {
      try {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        print("Error parseando hora: $timeStr, $e");
        return TimeOfDay(hour: 0, minute: 0);
      }
    }
    return Disponibilidad(
      id: json['id'],
      diaSemana: json['dia_semana'],
      horaInicio: _timeFromString(json['hora_inicio']),
      horaFin: _timeFromString(json['hora_fin']),
    );
  }
}

class Excepcion {
  final int id;
  final DateTime fecha;
  final bool estaDisponible;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFin;

  Excepcion({
    required this.id,
    required this.fecha,
    required this.estaDisponible,
    this.horaInicio,
    this.horaFin,
  });

  factory Excepcion.fromJson(Map<String, dynamic> json) {
    TimeOfDay? _timeFromStringNullable(String? timeStr) {
      if (timeStr == null) return null;
      try {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        print("Error parseando hora: $timeStr, $e");
        return null;
      }
    }
    
    return Excepcion(
      id: json['id'],
      fecha: DateTime.tryParse(json['fecha']) ?? DateTime.now(),
      estaDisponible: json['esta_disponible'],
      horaInicio: _timeFromStringNullable(json['hora_inicio']),
      horaFin: _timeFromStringNullable(json['hora_fin']),
    );
  }
}

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  int? _barberId;
  bool _isLoading = true;
  String? _error;
  
  List<Disponibilidad> _horarioSemanal = [];
  List<Excepcion> _excepciones = [];

  final List<String> _diasSemanaNombres = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'es_ES');


  @override
  void initState() {
    super.initState();
    // ¡AÑADIDO! Asegura que el formato 'es_ES' esté cargado
    initializeDateFormatting('es_ES', null).then((_) {
      _loadInitialData();
    });
  }

  // --- LÓGICA DE DATOS (Sin cambios) ---
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id');

    if (_barberId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "No se pudo identificar al barbero.";
        });
      }
      return;
    }
    
    // Reseteamos el error al recargar
    setState(() {
      _error = null;
    });

    await Future.wait([
      _fetchDisponibilidad(),
      _fetchExcepciones(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDisponibilidad() async {
    // ... (Tu lógica de fetch no cambia) ...
    if (_barberId == null) return;
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/disponibilidad";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> dataJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _horarioSemanal = dataJson.map((json) => Disponibilidad.fromJson(json)).toList();
        });
      } else {
        throw Exception('Error ${response.statusCode} al cargar horario');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = (_error ?? '') + "\nError cargando horario: $e";
        });
      }
    }
  }

  Future<void> _fetchExcepciones() async {
    // ... (Tu lógica de fetch no cambia) ...
    if (_barberId == null) return;
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/excepciones";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> dataJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _excepciones = dataJson.map((json) => Excepcion.fromJson(json)).toList();
        });
      } else {
        throw Exception('Error ${response.statusCode} al cargar excepciones');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = (_error ?? '') + "\nError cargando excepciones: $e";
        });
      }
    }
  }
  
  // --- Funciones de Acciones (¡MEJORADAS!) ---
  
  // Navegación (Sin cambios, solo la usamos)
  void _editarHorarioSemanal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditScheduleScreen(),
      ),
    ).then((_) {
      setState(() => _isLoading = true);
      _loadInitialData();
    });
  }

  // ¡MEJORADA! Ahora pregunta qué tipo de excepción
  void _anadirExcepcion() async {
    if (_barberId == null) return;

    // 1. Mostrar Calendario
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) { // Estilo de Vidrio
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF2C2C2C),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada == null || !mounted) return;

    // 2. Preguntar qué hacer (Día Libre o Horario Especial)
    final String? tipoExcepcion = await _showGlassModalSheet(
      context: context,
      title: 'Añadir Excepción - ${_dateFormat.format(fechaSeleccionada.toLocal())}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.block, color: Colors.redAccent[100]),
            title: Text('Marcar como Día Libre', style: TextStyle(color: Colors.white)),
            subtitle: Text('No estarás disponible en todo el día.', style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.of(context).pop('dia_libre'),
          ),
          ListTile(
            leading: Icon(Icons.edit_calendar_outlined, color: Colors.blueAccent[100]),
            title: Text('Establecer Horario Especial', style: TextStyle(color: Colors.white)),
            subtitle: Text('Define un horario solo para este día.', style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.of(context).pop('horario_especial'),
          ),
        ],
      )
    );

    if (tipoExcepcion == null || !mounted) return;

    if (tipoExcepcion == 'dia_libre') {
      // Llamamos a la API para "Día Libre"
      await _llamarApiExcepcion(
        fecha: fechaSeleccionada,
        estaDisponible: false,
      );
    } 
    else if (tipoExcepcion == 'horario_especial') {
      // 3. Pedir Hora Inicio y Fin
      final TimeOfDay? horaInicio = await _showGlassTimePicker(context, 'Seleccionar Hora de Inicio');
      if (horaInicio == null || !mounted) return;
      
      final TimeOfDay? horaFin = await _showGlassTimePicker(context, 'Seleccionar Hora de Fin');
      if (horaFin == null || !mounted) return;
      
      // Llamamos a la API para "Horario Especial"
      await _llamarApiExcepcion(
        fecha: fechaSeleccionada,
        estaDisponible: true,
        horaInicio: horaInicio,
        horaFin: horaFin,
      );
    }
  }

  // ¡NUEVA FUNCIÓN! Refactorizamos la llamada a la API
  Future<void> _llamarApiExcepcion({
    required DateTime fecha,
    required bool estaDisponible,
    TimeOfDay? horaInicio,
    TimeOfDay? horaFin,
  }) async {
    if (_barberId == null) return;

    setState(() => _isLoading = true);

    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/excepciones";
    final String fechaISO = fecha.toIso8601String().split('T')[0];

    // Helper para convertir TimeOfDay a "HH:mm"
    String? _timeToApiString(TimeOfDay? time) {
      if (time == null) return null;
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'fecha': fechaISO,
          'esta_disponible': estaDisponible,
          'hora_inicio': _timeToApiString(horaInicio),
          'hora_fin': _timeToApiString(horaFin)
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excepción añadida con éxito.'), backgroundColor: Colors.green),
        );
        await _fetchExcepciones();
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['detail'] ?? 'Error desconocido'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ¡MEJORADA! Con diálogo de vidrio
  Future<void> _eliminarExcepcion(int excepcionId) async {
    final bool? confirmar = await _showGlassConfirmationDialog(
      title: 'Eliminar Excepción',
      content: '¿Estás seguro de que deseas eliminar este día de excepción?',
    );

    if (confirmar != true || !mounted) return;
    setState(() => _isLoading = true);

    // El resto de tu lógica de API no cambia...
    final String apiUrl = "http://127.0.0.1:8000/excepciones/$excepcionId";
    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Día de excepción eliminado.'), backgroundColor: Colors.green),
        );
        await _fetchExcepciones(); // Solo refrescamos excepciones
      } else {
        final Map<String, dynamic>? responseData = response.body.isNotEmpty ? json.decode(response.body) : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${responseData?['detail'] ?? 'Error desconocido'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Construcción de la UI (REDISEÑADA) ---
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
            title: const Text('Gestionar Disponibilidad', style: TextStyle(color: Colors.white)),
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? _buildErrorView()
                  : _buildAvailabilityView(),
          floatingActionButton: FloatingActionButton(
            onPressed: _anadirExcepcion,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Añadir Excepción',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      // ... (Tu widget de error no cambia, está bien) ...
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadInitialData();
              },
              child: const Text('Reintentar'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityView() {
    _horarioSemanal.sort((a, b) => a.diaSemana.compareTo(b.diaSemana));

    // Obtenemos el padding superior para el AppBar
    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: Colors.white,
      backgroundColor: Colors.black.withOpacity(0.3),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.0, topPadding + 16.0, 16.0, 80.0), // Padding para FAB
        children: [
          // --- Sección 1: Horario Semanal ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mi Horario Semanal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
                style: TextButton.styleFrom(foregroundColor: Colors.blueAccent[100]),
                onPressed: _editarHorarioSemanal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _horarioSemanal.isEmpty
              ? const Text('Aún no has configurado tu horario semanal.', style: TextStyle(color: Colors.grey))
              : _buildHorarioSemanalList(),
          
          const Divider(height: 40, color: Colors.white24),

          // --- Sección 2: Excepciones (Días Libres) ---
            const Text('Excepciones (Días Libres / Especiales)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
           _excepciones.isEmpty
              ? const Text('No tienes días de excepción programados.', style: TextStyle(color: Colors.grey))
              : _buildExcepcionesList(),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS (REDISEÑADOS) ---

  // Helper para construir la lista de horario semanal (CON VIDRIO)
  Widget _buildHorarioSemanalList() {
    // Creamos un mapa de los horarios que SÍ tenemos
    final Map<int, Disponibilidad> horarioMap = {
      for (var h in _horarioSemanal) h.diaSemana: h
    };

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _diasSemanaNombres.length, // Siempre mostramos los 7 días
      itemBuilder: (context, index) {
        final String dia = _diasSemanaNombres[index];
        final Disponibilidad? horario = horarioMap[index]; // Buscamos el horario para este día (index)

        String subtitulo;
        if (horario != null) {
          final String horaInicioStr = MaterialLocalizations.of(context).formatTimeOfDay(horario.horaInicio, alwaysUse24HourFormat: false);
          final String horaFinStr = MaterialLocalizations.of(context).formatTimeOfDay(horario.horaFin, alwaysUse24HourFormat: false);
          subtitulo = '$horaInicioStr - $horaFinStr';
        } else {
          subtitulo = 'No disponible';
        }
        
        return _buildGlassCard(
          title: dia,
          subtitle: subtitulo,
          isAvailable: horario != null,
        );
      },
    );
  }

  // Helper para construir la lista de excepciones (CON VIDRIO)
  Widget _buildExcepcionesList() {
    // Ordenamos por fecha
    _excepciones.sort((a, b) => a.fecha.compareTo(b.fecha));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _excepciones.length,
      itemBuilder: (context, index) {
        final excepcion = _excepciones[index];
        final String fechaStr = _dateFormat.format(excepcion.fecha.toLocal());
        String subtitulo;
        
        if (!excepcion.estaDisponible) {
           subtitulo = 'Día Libre (No disponible)';
        } else if (excepcion.horaInicio != null && excepcion.horaFin != null) {
           final String hInicio = MaterialLocalizations.of(context).formatTimeOfDay(excepcion.horaInicio!, alwaysUse24HourFormat: false);
           final String hFin = MaterialLocalizations.of(context).formatTimeOfDay(excepcion.horaFin!, alwaysUse24HourFormat: false);
           subtitulo = 'Horario especial: $hInicio - $hFin';
        } else {
           subtitulo = 'Disponible (Horario normal aplicado)';
        }

        return _buildGlassCard(
          title: fechaStr,
          subtitle: subtitulo,
          isAvailable: excepcion.estaDisponible,
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
            tooltip: 'Eliminar excepción',
            onPressed: () => _eliminarExcepcion(excepcion.id),
          ),
        );
      },
    );
  }

  /// Helper genérico para las tarjetas de vidrio
  Widget _buildGlassCard({
    required String title,
    required String subtitle,
    required bool isAvailable,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              color: isAvailable ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }

  /// Helper para TimePicker de vidrio
  Future<TimeOfDay?> _showGlassTimePicker(BuildContext context, String title) {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: title,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
             colorScheme: const ColorScheme.dark(
               primary: Colors.blueAccent,
               onPrimary: Colors.white,
               surface: Color(0xFF2C2C2C),
               onSurface: Colors.white,
             ),
             dialogBackgroundColor: const Color(0xFF2C2C2C).withOpacity(0.8),
          ),
          child: child!,
        );
      },
    );
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper para Diálogo de Confirmación de Vidrio
  Future<bool?> _showGlassConfirmationDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.grey[900]?.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Text(content, style: const TextStyle(color: Colors.white70)),
            actions: <Widget>[
              TextButton(
                child: const Text('No', style: TextStyle(color: Colors.white70)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
                child: const Text('Sí, Eliminar', style: TextStyle(color: Colors.redAccent)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );
  }
}