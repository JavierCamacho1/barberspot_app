import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para json.encode
import 'package:intl/intl.dart'; // Para formatear

// --- MODELOS DE DATOS ---
class TimeRange {
  TimeOfDay? inicio;
  TimeOfDay? fin;
  final UniqueKey key = UniqueKey();

  TimeRange({this.inicio, this.fin});
}

class Disponibilidad {
  final int id;
  final int diaSemana;
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
// --- FIN MODELOS ---

class EditScheduleScreen extends StatefulWidget {
  const EditScheduleScreen({super.key});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  int? _barberId;
  bool _isLoading = true;
  bool _isSaving = false;
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

  // --- LÓGICA DE DATOS Y API ---
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

  void _addTimeSlot(int diaSemana) {
    setState(() {
      _horarioEditable[diaSemana]?.add(TimeRange());
    });
  }

  void _removeTimeSlot(int diaSemana, UniqueKey key) {
    setState(() {
      _horarioEditable[diaSemana]?.removeWhere((range) => range.key == key);
    });
  }
  
  Future<void> _selectTime(BuildContext context, TimeRange range, bool isStartTime) async {
      final TimeOfDay? picked = await _showGlassTimePicker(
        context,
        (isStartTime ? range.inicio : range.fin) ?? TimeOfDay.now()
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

  Future<void> _saveSchedule() async {
    if (_barberId == null) return;
    
    List<Map<String, dynamic>> payload = [];
    
    for (int dia = 0; dia < 7; dia++) {
      final List<TimeRange> turnos = _horarioEditable[dia] ?? [];
      
      for (var turno in turnos) {
        if (turno.inicio == null || turno.fin == null) {
          _showError("Por favor, completa todos los campos de hora para el ${_diasSemanaNombres[dia]}.");
          return;
        }

        final double inicioDecimal = turno.inicio!.hour + (turno.inicio!.minute / 60.0);
        final double finDecimal = turno.fin!.hour + (turno.fin!.minute / 60.0);

        if (inicioDecimal >= finDecimal) {
           _showError("En ${_diasSemanaNombres[dia]}: La hora de inicio (${turno.inicio!.format(context)}) debe ser anterior a la hora de fin (${turno.fin!.format(context)}).");
           return;
        }

        final String horaInicioStr = "${turno.inicio!.hour.toString().padLeft(2, '0')}:${turno.inicio!.minute.toString().padLeft(2, '0')}:00";
        final String horaFinStr = "${turno.fin!.hour.toString().padLeft(2, '0')}:${turno.fin!.minute.toString().padLeft(2, '0')}:00";

        payload.add({
          "dia_semana": dia,
          "hora_inicio": horaInicioStr,
          "hora_fin": horaFinStr
        });
      }
    }

    if (mounted) setState(() => _isSaving = true);

    final String apiUrl = "http://127.0.0.1:8000/barberos/$_barberId/disponibilidad";
    
    try {
        final response = await http.put(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (response.statusCode == 200) {
          _showSuccess("¡Horario guardado con éxito!");
          Navigator.of(context).pop(true);
        } else {
          final Map<String, dynamic> responseData = json.decode(response.body);
          _showError("Error al guardar: ${responseData['detail'] ?? 'Error desconocido'}");
        }

    } catch (e) {
      _showError("Error de conexión: $e");
    } finally {
       if (mounted) {
         setState(() => _isSaving = false);
       }
    }
  }
  
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
            title: const Text('Editar Horario Semanal', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                )
              else if (_isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: 'Guardar Horario',
                  onPressed: _saveSchedule,
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: Colors.red[300])))
                  : _buildScheduleEditor(),
        ),
      ],
    );
  }

  Widget _buildScheduleEditor() {
    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;
    
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.0, topPadding + 12.0, 12.0, 12.0),
      itemCount: _diasSemanaNombres.length,
      itemBuilder: (context, index) {
        final int diaSemana = index;
        final String nombreDia = _diasSemanaNombres[diaSemana];
        final List<TimeRange> turnos = _horarioEditable[diaSemana] ?? [];

        return _buildGlassDayCard(nombreDia, turnos, diaSemana);
      },
    );
  }

  // --- WIDGETS HELPER DE VIDRIO ---

  Widget _buildGlassDayCard(String nombreDia, List<TimeRange> turnos, int diaSemana) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
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
                    Text(
                      nombreDia,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_rounded, color: Colors.greenAccent),
                      tooltip: 'Añadir turno',
                      onPressed: () => _addTimeSlot(diaSemana),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                
                if (turnos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'Día Libre (No disponible)',
                        style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: turnos.length,
                  itemBuilder: (context, indexTurno) {
                    final range = turnos[indexTurno];
                    return _buildTimeSlotRow(range, diaSemana, range.key); 
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotRow(TimeRange range, int diaSemana, UniqueKey key) {
    final format = MaterialLocalizations.of(context);
    
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: _buildTimeButton(
              time: range.inicio,
              label: 'Inicio',
              onPressed: () => _selectTime(context, range, true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          Expanded(
            flex: 2,
            child: _buildTimeButton(
              time: range.fin,
              label: 'Fin',
              onPressed: () => _selectTime(context, range, false),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () => _removeTimeSlot(diaSemana, key),
            tooltip: 'Eliminar este turno',
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton({
    required TimeOfDay? time,
    required String label,
    required VoidCallback onPressed,
  }) {
    final format = MaterialLocalizations.of(context);
    final bool hasTime = time != null;
    
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: hasTime ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: hasTime ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.2)
          ),
        ),
      ),
      child: Text(
        time != null ? format.formatTimeOfDay(time) : label,
        style: TextStyle(
          fontWeight: hasTime ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
  
  Future<TimeOfDay?> _showGlassTimePicker(BuildContext context, TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
             colorScheme: const ColorScheme.dark(
               primary: Colors.blueAccent,
               onPrimary: Colors.white,
               surface: Color(0xFF2C2C2C),
               onSurface: Colors.white,
             ),
             dialogBackgroundColor: const Color(0xFF2C2C2C).withOpacity(0.85),
          ),
          child: child!,
        );
      },
    );
  }
}