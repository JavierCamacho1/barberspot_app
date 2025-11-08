import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para json.encode
import 'package:intl/intl.dart'; // Para formatear

// Modelo simple para representar un rango de tiempo editable
class TimeRange {
  TimeOfDay? inicio;
  TimeOfDay? fin;
  // Usamos un 'key' único para ayudar a Flutter a manejar la lista
  final UniqueKey key = UniqueKey(); 

  TimeRange({this.inicio, this.fin});
}

// Modelo para el Horario Semanal (copiado de availability_screen.dart)
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

class EditScheduleScreen extends StatefulWidget {
  const EditScheduleScreen({super.key});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  int? _barberId;
  bool _isLoading = true; // Para la carga inicial
  bool _isSaving = false; // Para el botón de guardar
  String? _error;

  final List<String> _diasSemanaNombres = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  Map<int, List<TimeRange>> _horarioEditable = {
    0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Carga el ID del barbero y su horario actual
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _barberId = prefs.getInt('user_id');

    if (_barberId == null) {
      if (mounted) setState(() { _isLoading = false; _error = "No se pudo identificar al barbero."; });
      return;
    }
    
    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/disponibilidad";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> dataJson = json.decode(utf8.decode(response.bodyBytes));
        final List<Disponibilidad> horarioActual = dataJson.map((json) => Disponibilidad.fromJson(json)).toList();

        Map<int, List<TimeRange>> horarioTemp = { 0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: [] };
        for (var dispo in horarioActual) {
          horarioTemp[dispo.diaSemana]?.add(TimeRange(
            inicio: dispo.horaInicio,
            fin: dispo.horaFin,
          ));
        }
        
        setState(() {
          _horarioEditable = horarioTemp;
          _isLoading = false;
        });
      } else {
        throw Exception('Error ${response.statusCode} al cargar horario');
      }
    } catch (e) {
      if (mounted) setState(() { _error = "Error cargando horario: $e"; _isLoading = false; });
    }
  }

  // --- Funciones de Acciones (¡IMPLEMENTADAS!) ---

  // Añade un nuevo slot de tiempo (turno) vacío a un día
  void _addTimeSlot(int diaSemana) {
    setState(() {
      _horarioEditable[diaSemana]?.add(TimeRange()); // Añade un turno vacío
    });
  }

  // Elimina un slot de tiempo (turno) de un día
  void _removeTimeSlot(int diaSemana, UniqueKey key) {
    setState(() {
      _horarioEditable[diaSemana]?.removeWhere((range) => range.key == key);
    });
  }
  
  // Muestra el selector de hora (TimePicker)
  Future<void> _selectTime(BuildContext context, TimeRange range, bool isStartTime) async {
     final TimeOfDay? picked = await showTimePicker(
       context: context,
       initialTime: (isStartTime ? range.inicio : range.fin) ?? TimeOfDay.now(),
       builder: (context, child) { // Aplicar tema oscuro
         return Theme(
           data: ThemeData.dark().copyWith(
             colorScheme: const ColorScheme.dark(
               primary: Colors.blueAccent,
             ),
           ),
           child: child!,
         );
       },
     );
     if (picked != null) {
       setState(() {
         if (isStartTime) {
           range.inicio = picked;
         } else {
           range.fin = picked;
         }
       });
     }
  }

  // Función principal para guardar el horario completo
  Future<void> _saveSchedule() async {
    if (_barberId == null) return;
    
    // 1. Validar y construir el JSON
    List<Map<String, dynamic>> payload = []; // Lista de horarios para enviar
    
    for (int dia = 0; dia < 7; dia++) { // Iterar por Lunes (0) a Domingo (6)
      final List<TimeRange> turnos = _horarioEditable[dia] ?? [];
      
      for (var turno in turnos) {
        // Validación A: Asegurarse que ambas horas estén seleccionadas
        if (turno.inicio == null || turno.fin == null) {
          _showError("Por favor, completa todos los campos de hora para el ${_diasSemanaNombres[dia]}.");
          return;
        }

        // Validación B: Asegurarse que la hora de inicio sea ANTES que la hora de fin
        final double inicioDecimal = turno.inicio!.hour + (turno.inicio!.minute / 60.0);
        final double finDecimal = turno.fin!.hour + (turno.fin!.minute / 60.0);

        if (inicioDecimal >= finDecimal) {
           _showError("En ${_diasSemanaNombres[dia]}: La hora de inicio (${turno.inicio!.format(context)}) debe ser anterior a la hora de fin (${turno.fin!.format(context)}).");
           return;
        }

        // Convertir TimeOfDay a string "HH:MM:SS" para la API
        final String horaInicioStr = "${turno.inicio!.hour.toString().padLeft(2, '0')}:${turno.inicio!.minute.toString().padLeft(2, '0')}:00";
        final String horaFinStr = "${turno.fin!.hour.toString().padLeft(2, '0')}:${turno.fin!.minute.toString().padLeft(2, '0')}:00";

        // Añadir el turno válido al payload
        payload.add({
          "dia_semana": dia,
          "hora_inicio": horaInicioStr,
          "hora_fin": horaFinStr
        });
      }
    }

    // 2. Si llegamos aquí, la validación pasó. Mostramos carga y llamamos a la API.
    if (mounted) setState(() => _isSaving = true);

    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/disponibilidad";
    
    try {
        final response = await http.put(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: json.encode(payload), // Enviamos la lista completa de horarios
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (response.statusCode == 200) {
          // ¡Éxito!
          _showSuccess("¡Horario guardado con éxito!");
          Navigator.of(context).pop(true); // Regresamos (true para refrescar)
        } else {
          // Error del backend (ej. 400 Bad Request)
          final Map<String, dynamic> responseData = json.decode(response.body);
          _showError("Error al guardar: ${responseData['detail'] ?? 'Error desconocido'}");
        }

    } catch (e) {
      // Error de conexión
      _showError("Error de conexión: $e");
    } finally {
       if (mounted) {
         setState(() => _isSaving = false); // Ocultar indicador de guardado
       }
    }
  }
  
  // --- Helpers para mostrar SnackBar ---
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }
  void _showSuccess(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  // --- Construcción de la UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Horario Semanal'),
        actions: [
          // Botón de Guardar
          if (_isLoading) // No mostrar botón si está cargando
             Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
             )
          else if (_isSaving) // Mostrar indicador si está guardando
             Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
             )
          else // Mostrar botón de guardar
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Guardar Horario',
              onPressed: _saveSchedule,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!)) // TODO: Mejorar vista de error
              : _buildScheduleEditor(),
    );
  }

  // Construye la lista de los 7 días
  Widget _buildScheduleEditor() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _diasSemanaNombres.length, // 7 días
      itemBuilder: (context, index) {
        final int diaSemana = index; // 0 = Lunes, 1 = Martes...
        final String nombreDia = _diasSemanaNombres[diaSemana];
        final List<TimeRange> turnos = _horarioEditable[diaSemana] ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del Día (Lunes, Martes...)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nombreDia,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_rounded, color: Colors.green),
                      tooltip: 'Añadir turno (ej. para descansos)',
                      onPressed: () => _addTimeSlot(diaSemana),
                    ),
                  ],
                ),
                const Divider(),
                
                // Si no hay turnos (Día libre)
                if (turnos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'Día Libre (No disponible)',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),

                // Lista de turnos (TimeRange) para este día
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: turnos.length,
                  itemBuilder: (context, indexTurno) {
                    final range = turnos[indexTurno];
                    // Usamos la 'key' única para que Flutter identifique la fila
                    return _buildTimeSlotRow(range, diaSemana, range.key); 
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Construye la fila para un solo turno (ej. [ 9:00 AM ] - [ 5:00 PM ] [X] )
  Widget _buildTimeSlotRow(TimeRange range, int diaSemana, UniqueKey key) {
    final format = MaterialLocalizations.of(context);
    
    return Padding(
      // Usamos la 'key' única aquí
      key: key, 
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Hora Inicio
          Expanded( // Damos espacio flexible
            flex: 2,
            child: TextButton(
              onPressed: () => _selectTime(context, range, true),
              child: Text(range.inicio != null ? format.formatTimeOfDay(range.inicio!) : 'Inicio'),
            ),
          ),
          const Text('-'),
          // Botón Hora Fin
          Expanded( // Damos espacio flexible
            flex: 2,
            child: TextButton(
              onPressed: () => _selectTime(context, range, false),
              child: Text(range.fin != null ? format.formatTimeOfDay(range.fin!) : 'Fin'),
            ),
          ),
          // Botón Eliminar Turno
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () => _removeTimeSlot(diaSemana, key),
            tooltip: 'Eliminar este turno',
          ),
        ],
      ),
    );
  }
}