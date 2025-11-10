import 'dart:ui'; // Para ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart'; // ¡NUEVA IMPORTACIÓN!

// Importamos los modelos que podríamos necesitar
import 'cita_model.dart';

class AgendarCitaScreen extends StatefulWidget {
  const AgendarCitaScreen({super.key});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  // Estados para guardar selecciones
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  UsuarioSimple? _selectedBarbero;
  BarberiaServicioSimple? _selectedServicio;

  // Estados para cargar datos de la API
  List<UsuarioSimple> _barberos = [];
  List<BarberiaServicioSimple> _servicios = [];
  bool _isLoadingData = true;
  String? _errorData;
  int? _barberiaId;

  // --- ¡NUEVOS ESTADOS PARA HORARIOS! ---
  List<TimeOfDay> _horariosDisponibles = [];
  bool _isLoadingHorarios = false;
  String? _errorHorarios;
  
  // Para TableCalendar
  DateTime _focusedDay = DateTime.now();


  bool _isConfirming = false;

  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'es_ES');
  
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _selectedDate = _focusedDay; // Selecciona hoy por defecto
      _loadInitialData();
    });
  }
  
  // --- LÓGICA DE DATOS Y API (MODIFICADA) ---

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('h:mm a', 'es_ES').format(dt);
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? barberiaIdString = prefs.getString('barberia_id');
    if (barberiaIdString != null && barberiaIdString != 'null') {
      _barberiaId = int.tryParse(barberiaIdString);
    }

    if (_barberiaId != null) {
      await Future.wait([
        _fetchBarberos(),
        _fetchServicios(),
      ]);
    } else {
       if (!mounted) return;
      setState(() {
        _errorData = "No se pudo identificar tu barbería.";
        _isLoadingData = false;
      });
    }
     if (!mounted) return;
     setState(() {
       _isLoadingData = false;
     });
  }

  Future<void> _fetchBarberos() async {
    // ... (Tu código de _fetchBarberos no cambia)
    if (_barberiaId == null) return;
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId/barberos";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> barberosJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _barberos = barberosJson.map((json) => UsuarioSimple.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _errorData = (_errorData ?? '') + "\nError al cargar barberos.";
        });
      }
    } catch (e) {
       if (!mounted) return;
       setState(() {
         _errorData = (_errorData ?? '') + "\nError de conexión (barberos).";
       });
    }
  }

  Future<void> _fetchServicios() async {
    // ... (Tu código de _fetchServicios no cambia)
    if (_barberiaId == null) return;
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId/servicios";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> serviciosJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _servicios = serviciosJson.map((json) => BarberiaServicioSimple.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _errorData = (_errorData ?? '') + "\nError al cargar servicios.";
        });
      }
    } catch (e) {
       if (!mounted) return;
       setState(() {
         _errorData = (_errorData ?? '') + "\nError de conexión (servicios).";
       });
    }
  }

  // --- ¡NUEVA FUNCIÓN PARA OBTENER HORARIOS! ---
  Future<void> _fetchDisponibilidad() async {
    if (_selectedBarbero == null || _selectedDate == null) return;

    if (!mounted) return;
    setState(() {
      _isLoadingHorarios = true;
      _horariosDisponibles = [];
      _errorHorarios = null;
      _selectedTime = null; // Reinicia la hora seleccionada
    });

    // ¡¡¡IMPORTANTE!!!
    // Este es el NUEVO ENDPOINT que necesitas crear en tu backend (FastAPI)
    // Debe devolver una lista de strings con las horas disponibles, ej: ["09:00", "10:30", "14:00"]
    final String fechaISO = _selectedDate!.toIso8601String().split('T').first;
    final String apiUrl = "http://127.0.0.1:8000/barberos/${_selectedBarbero!.id}/disponibilidad?fecha=$fechaISO";
    
    print("Llamando a API de disponibilidad: $apiUrl"); // Para debug

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> horariosJson = json.decode(utf8.decode(response.bodyBytes));
        
        List<TimeOfDay> horarios = [];
        for (String horaString in horariosJson.cast<String>()) {
          // Asumimos formato "HH:mm" (ej. "09:00" o "14:30")
          try {
            final parts = horaString.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            horarios.add(TimeOfDay(hour: hour, minute: minute));
          } catch (e) {
            print("Error al parsear hora: $horaString");
          }
        }

        setState(() {
          _horariosDisponibles = horarios;
          _isLoadingHorarios = false;
        });

      } else {
        setState(() {
          _errorHorarios = "No se pudo cargar la disponibilidad.";
          _isLoadingHorarios = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorHorarios = "Error de conexión (horarios).";
        _isLoadingHorarios = false;
      });
    }
  }

  // --- LÓGICA DE CONFIRMACIÓN (SIN CAMBIOS) ---
  Future<void> _confirmarCita() async {
    // ... (Tu código de _confirmarCita no cambia en absoluto)
    if (_selectedDate == null || _selectedTime == null || _selectedBarbero == null || _selectedServicio == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona fecha, hora, barbero y servicio.'),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isConfirming = true);

    final prefs = await SharedPreferences.getInstance();
    final int? clienteId = prefs.getInt('user_id');

    if (clienteId == null) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo identificar al cliente.')),
        );
       }
      setState(() => _isConfirming = false);
      return;
    }

    final DateTime fechaHoraLocal = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final DateTime fechaHoraCita = fechaHoraLocal.toUtc();
    final String apiUrl = "http://127.0.0.1:8000/citas";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'fecha_hora': fechaHoraCita.toIso8601String(),
          'cliente_id': clienteId,
          'barbero_id': _selectedBarbero!.id,
          'barberia_id': _barberiaId!,
          'barberia_servicio_id': _selectedServicio!.id,
        }),
      );

       if (!mounted) return;

      if (response.statusCode == 201) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('¡Cita agendada con éxito!'), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop(true);

      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al agendar: ${responseData['detail'] ?? 'Error desconocido'}')),
         );
      }
    } catch(e) {
       if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Error de conexión al agendar la cita.')),
       );
    }

    if (mounted) {
       setState(() => _isConfirming = false);
    }
  }


  // --- FUNCIONES DE SELECCIÓN (REDISEÑADAS) ---

  // ¡YA NO NECESITAMOS _selectDate() NI _selectTime()! Los reemplazamos.
  
  /// NUEVA: Muestra un modal de vidrio para seleccionar barbero
  void _showBarberoPicker() {
    _showGlassModalSheet(
      context: context,
      title: 'Seleccionar Barbero',
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _barberos.length,
        itemBuilder: (context, index) {
          final barbero = _barberos[index];
          final bool isSelected = _selectedBarbero?.id == barbero.id;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.person_outline,
              color: isSelected ? Colors.blueAccent : Colors.white70,
            ),
            title: Text(barbero.nombre, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            onTap: () {
              setState(() {
                _selectedBarbero = barbero;
              });
              // ¡Al seleccionar barbero, llamamos a la API de horarios!
              _fetchDisponibilidad(); 
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  /// Muestra un modal de vidrio para seleccionar servicio
  void _showServicioPicker() {
    _showGlassModalSheet(
      context: context,
      title: 'Seleccionar Servicio',
      child: ListView.builder(
        // ... (Este código no cambia)
        shrinkWrap: true,
        itemCount: _servicios.length,
        itemBuilder: (context, index) {
          final servicio = _servicios[index];
          final bool isSelected = _selectedServicio?.id == servicio.id;
          final String displayText = '${servicio.servicio.nombre} (\$${servicio.precio.toStringAsFixed(2)})';
          return ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.content_cut,
              color: isSelected ? Colors.blueAccent : Colors.white70,
            ),
            title: Text(displayText, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            onTap: () {
              setState(() {
                _selectedServicio = servicio;
              });
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  // --- UI REDISEÑADA ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa 1: Fondo
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
            // ... (AppBar de vidrio no cambia)
            title: const Text('Agendar Nueva Cita', style: TextStyle(color: Colors.white)),
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
          body: _isLoadingData
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _errorData != null
                  ? Center(child: Text(_errorData!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center,))
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20.0,
                        kToolbarHeight + MediaQuery.of(context).padding.top + 20.0,
                        20.0,
                        20.0
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- 1. Calendario Incrustado ---
                          _buildInlineCalendar(),
                          const SizedBox(height: 20),

                          // --- 2. Selector de Barbero ---
                          _buildGlassPicker(
                            icon: Icons.person_outline,
                            text: _selectedBarbero == null ? 'Seleccionar Barbero' : _selectedBarbero!.nombre,
                            onTap: _barberos.isEmpty ? null : _showBarberoPicker,
                            enabled: _barberos.isNotEmpty,
                          ),
                          const SizedBox(height: 20),

                          // --- 3. Grid de Horarios Disponibles ---
                          _buildHorariosGrid(),
                          const SizedBox(height: 20),

                          // --- 4. Selector de Servicio ---
                          _buildGlassPicker(
                            icon: Icons.content_cut_outlined,
                            text: _selectedServicio == null 
                                ? 'Seleccionar Servicio' 
                                : '${_selectedServicio!.servicio.nombre} (\$${_selectedServicio!.precio.toStringAsFixed(2)})',
                            onTap: _servicios.isEmpty ? null : _showServicioPicker,
                            enabled: _servicios.isNotEmpty,
                          ),
                          const SizedBox(height: 40),

                          // --- 5. Botón Confirmar Cita ---
                          _isConfirming
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : _buildGlassButtonPrimary(
                                text: 'Confirmar Cita',
                                icon: Icons.check_circle_outline,
                                onPressed: _confirmarCita,
                              )
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // --- NUEVOS WIDGETS HELPER PARA ESTILO ---

  /// NUEVO: Construye el calendario de vidrio
  Widget _buildInlineCalendar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TableCalendar(
            locale: 'es_ES',
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18.0),
              leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
            ),
            calendarStyle: CalendarStyle(
              // Estilos de texto
              defaultTextStyle: const TextStyle(color: Colors.white70),
              weekendTextStyle: const TextStyle(color: Colors.white),
              outsideTextStyle: const TextStyle(color: Colors.white30),
              // Día de hoy
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              // Día seleccionado
              selectedDecoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(color: Colors.white54),
              weekendStyle: const TextStyle(color: Colors.white70),
            ),
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
              // ¡Al seleccionar fecha, llamamos a la API de horarios!
              _fetchDisponibilidad();
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        ),
      ),
    );
  }

  /// NUEVO: Construye el grid de horarios
  Widget _buildHorariosGrid() {
    // 1. Si no se ha seleccionado barbero o fecha, no mostrar nada o un mensaje
    if (_selectedBarbero == null || _selectedDate == null) {
      return _buildGlassPicker(
        icon: Icons.access_time_outlined,
        text: 'Selecciona barbero y fecha',
        onTap: null, // Deshabilitado
        enabled: false,
      );
    }
    
    // 2. Si está cargando horarios
    if (_isLoadingHorarios) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(color: Colors.white),
      ));
    }

    // 3. Si hubo un error al cargar
    if (_errorHorarios != null) {
      return Center(child: Text(_errorHorarios!, style: TextStyle(color: Colors.red[300])));
    }

    // 4. Si no hay horarios disponibles
    if (_horariosDisponibles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No hay horarios disponibles para este día.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    // 5. Mostrar el Grid de horarios
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona una Hora',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 columnas
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.0, // Más anchos que altos
          ),
          itemCount: _horariosDisponibles.length,
          itemBuilder: (context, index) {
            final time = _horariosDisponibles[index];
            final isSelected = _selectedTime == time;
            
            return _buildTimeSlotChip(
              time: time,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedTime = time;
                });
              },
            );
          },
        ),
      ],
    );
  }

  /// NUEVO: Helper para el chip de la hora
  Widget _buildTimeSlotChip({
    required TimeOfDay time,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent.withOpacity(0.7) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                _formatTimeOfDay(time).replaceAll(' ', '\n'), // Pone AM/PM abajo si hay espacio
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  /// Helper para crear los campos de selección de vidrio (Barbero y Servicio)
  Widget _buildGlassPicker({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    // ... (Este helper no cambia)
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: Icon(icon, color: enabled ? Colors.white : Colors.white38),
            title: Text(
              text,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: enabled ? Colors.white70 : Colors.white38),
            onTap: enabled ? onTap : null,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  /// Helper para el modal de vidrio (no cambia)
  void _showGlassModalSheet({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    // ... (Este helper no cambia)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Fondo del modal transparente
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Helper para el botón principal (no cambia)
  Widget _buildGlassButtonPrimary({required String text, required IconData icon, required VoidCallback onPressed}) {
    // ... (Este helper no cambia)
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
}