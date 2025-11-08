import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'edit_schedule_screen.dart';

// Definimos los modelos de datos aquí mismo por simplicidad
// (Podríamos moverlos a un archivo 'disponibilidad_model.dart' más tarde)

// Modelo para el Horario Semanal
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
    // Helper para convertir "HH:MM:SS" string a TimeOfDay
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

// Modelo para Excepciones (Días Libres)
class Excepcion {
  final int id;
  final DateTime fecha;
  final bool estaDisponible;
  final TimeOfDay? horaInicio; // Opcional
  final TimeOfDay? horaFin; // Opcional

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
  final DateFormat _dateFormat = DateFormat('EEEE d MMM y', 'es_ES');


  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

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

    // Cargamos ambos en paralelo
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

  // --- Llamadas a la API ---
  Future<void> _fetchDisponibilidad() async {
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
  
  // --- Funciones de Acciones (TODO) ---
 void _editarHorarioSemanal() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const EditScheduleScreen(),
    ),
  ).then((_) {
    // Cuando regresemos de la pantalla de edición,
    // volvemos a cargar los datos para mostrar los cambios.
    setState(() => _isLoading = true);
    _loadInitialData();
  });
}
// --- FIN FUNCIÓN

 void _anadirExcepcion() async {
  if (_barberId == null) return;

  // 1. Mostrar Calendario para seleccionar la fecha
  final DateTime? fechaSeleccionada = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(), // Solo fechas futuras
    lastDate: DateTime.now().add(const Duration(days: 365)), // 1 año
    locale: const Locale('es', 'ES'),
  );

  if (fechaSeleccionada == null || !mounted) {
    return; // Usuario canceló el calendario
  }

  // 2. Preguntar al usuario si es un día libre (o horario especial)
  //    (Por ahora, implementaremos la lógica más simple: marcar como "Día Libre")
  final bool? esDiaLibre = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar Día: ${DateFormat('d MMM y', 'es_ES').format(fechaSeleccionada)}'),
        content: const Text('¿Deseas marcar esta fecha como un día "No Disponible" (Día Libre)?\n\n(La edición de horarios especiales se añadirá pronto).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Devuelve true (marcar como libre)
            child: const Text('Marcar como Día Libre'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
  );

  if (esDiaLibre != true || !mounted) {
    return; // Usuario canceló el diálogo
  }

  // 3. Llamar a la API (POST)
  setState(() => _isLoading = true);

  final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/excepciones";

  // Formato YYYY-MM-DD
  final String fechaISO = fechaSeleccionada.toIso8601String().split('T')[0]; 

  try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'fecha': fechaISO,
          'esta_disponible': false, // Marcamos como NO disponible
          'hora_inicio': null, // Sin horario especial
          'hora_fin': null
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) { // 201 Created
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Día libre añadido con éxito.'), backgroundColor: Colors.green),
        );
        // Refrescamos solo las excepciones
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
// --- FIN FUNCIÓN

  Future<void> _eliminarExcepcion(int excepcionId) async {
  // Mostrar confirmación
  final bool? confirmar = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Eliminar Excepción'),
        content: const Text('¿Estás seguro de que deseas eliminar este día de excepción?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Sí, Eliminar'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );

  if (confirmar != true || !mounted) {
    return;
  }

  // Mostrar un indicador de carga (opcional, pero bueno)
  setState(() => _isLoading = true);

  final String apiUrl = "http://127.0.0.1:8000/excepciones/$excepcionId";

  try {
    final response = await http.delete(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
    ).timeout(const Duration(seconds: 10));

    if (!mounted) return;

    if (response.statusCode == 204) { // 204 No Content (Éxito)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Día de excepción eliminado.'), backgroundColor: Colors.green),
      );
      // Refrescar ambas listas (solo excepciones en realidad)
      // Usamos _loadInitialData para recargar todo por si acaso
      await _loadInitialData(); 
    } else {
      // Si la API devuelve un error (ej. 404)
      final Map<String, dynamic>? responseData = json.decode(response.body);
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
      setState(() => _isLoading = false); // Ocultar indicador de carga
    }
  }
}
// --- FIN FUNCIÓN

  // --- Construcción de la UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Disponibilidad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildAvailabilityView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
    // Ordenamos el horario semanal por dia_semana
    _horarioSemanal.sort((a, b) => a.diaSemana.compareTo(b.diaSemana));

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Sección 1: Horario Semanal ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mi Horario Semanal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                tooltip: 'Editar horario semanal',
                onPressed: _editarHorarioSemanal,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _horarioSemanal.isEmpty
              ? const Text('Aún no has configurado tu horario semanal.', style: TextStyle(color: Colors.grey))
              : _buildHorarioSemanalList(),
          
          const Divider(height: 40, thickness: 1),

          // --- Sección 2: Excepciones (Días Libres) ---
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Días Libres / Especiales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                tooltip: 'Añadir día libre o especial',
                onPressed: _anadirExcepcion,
              ),
            ],
          ),
          const SizedBox(height: 8),
           _excepciones.isEmpty
              ? const Text('No tienes días de excepción programados.', style: TextStyle(color: Colors.grey))
              : _buildExcepcionesList(),

        ],
      ),
    );
  }

  // Helper para construir la lista de horario semanal
  Widget _buildHorarioSemanalList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _horarioSemanal.length,
      itemBuilder: (context, index) {
        final horario = _horarioSemanal[index];
        final String dia = _diasSemanaNombres[horario.diaSemana]; // Convierte 0 a Lunes
        final String horaInicioStr = MaterialLocalizations.of(context).formatTimeOfDay(horario.horaInicio, alwaysUse24HourFormat: false);
        final String horaFinStr = MaterialLocalizations.of(context).formatTimeOfDay(horario.horaFin, alwaysUse24HourFormat: false);

        return Card(
          color: Colors.grey[850],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(dia, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$horaInicioStr - $horaFinStr'),
          ),
        );
      },
    );
  }

  // Helper para construir la lista de excepciones
   Widget _buildExcepcionesList() {
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

        return Card(
          color: excepcion.estaDisponible ? Colors.grey[850] : Colors.red[900]?.withOpacity(0.5), // Resalta días libres
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitulo),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
              tooltip: 'Eliminar excepción',
              onPressed: () => _eliminarExcepcion(excepcion.id),
            ),
          ),
        );
      },
    );
   }

}