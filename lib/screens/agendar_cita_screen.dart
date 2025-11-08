import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Para formatear fechas

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

  bool _isConfirming = false;

  final DateFormat _dateFormat = DateFormat('EEEE d MMM y', 'es_ES');
  // Ya no necesitamos _timeFormat aquí, lo usaremos en la función helper

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // --- ¡NUEVA FUNCIÓN HELPER PARA FORZAR AM/PM! ---
  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    // Creamos un DateTime temporal (con fecha de hoy) solo para poder usar el formateador intl
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    // Usamos el formateador 'h:mm a' (que incluye am/pm)
    return DateFormat('h:mm a', 'es_ES').format(dt);
  }
  // --- FIN FUNCIÓN HELPER ---

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

   Future<void> _selectTime(BuildContext context) async {
     final TimeOfDay? picked = await showTimePicker(
       context: context,
       initialTime: _selectedTime ?? TimeOfDay.now(),
       builder: (context, child) {
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
     if (picked != null && picked != _selectedTime) {
       setState(() {
         _selectedTime = picked;
       });
     }
  }

  Future<void> _confirmarCita() async {
    if (_selectedDate == null || _selectedTime == null || _selectedBarbero == null || _selectedServicio == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona fecha, hora, barbero y servicio.')),
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

    // --- LÓGICA CON CONVERSIÓN A UTC ---
    final DateTime fechaHoraLocal = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final DateTime fechaHoraCita = fechaHoraLocal.toUtc();
    // --- FIN LÓGICA UTC ---

    final String apiUrl = "http://127.0.0.1:8000/citas";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'fecha_hora': fechaHoraCita.toIso8601String(), // Enviamos en UTC
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
         // Regresamos a la pantalla anterior (ClientHomeScreen)
         // Pasamos 'true' para indicar que se refresque la lista
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Nueva Cita'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorData != null
              ? Center(child: Text(_errorData!, style: TextStyle(color: Colors.red[300])))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Selector de Fecha ---
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          _selectedDate == null
                              ? 'Seleccionar Fecha'
                              : _dateFormat.format(_selectedDate!),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectDate(context),
                        shape: RoundedRectangleBorder(
                           side: BorderSide(color: Colors.grey[700]!),
                           borderRadius: BorderRadius.circular(12)
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Selector de Hora (CORREGIDO) ---
                       ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text(
                          _selectedTime == null
                              ? 'Seleccionar Hora'
                              // ¡LÓGICA CORREGIDA para forzar a.m./p.m.!
                              : _formatTimeOfDay(_selectedTime!),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        enabled: _selectedDate != null,
                        onTap: _selectedDate == null ? null : () => _selectTime(context),
                         shape: RoundedRectangleBorder(
                           side: BorderSide(color: _selectedDate == null ? Colors.grey[800]! : Colors.grey[700]!),
                           borderRadius: BorderRadius.circular(12)
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Selector de Barbero ---
                      DropdownButtonFormField<UsuarioSimple>(
                        value: _selectedBarbero,
                        hint: const Text('Seleccionar Barbero'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _barberos.map((barbero) {
                          return DropdownMenuItem<UsuarioSimple>(
                            value: barbero,
                            child: Text(barbero.nombre),
                          );
                        }).toList(),
                        onChanged: (UsuarioSimple? newValue) {
                          setState(() {
                            _selectedBarbero = newValue;
                             _selectedTime = null;
                          });
                        },
                         validator: (value) => value == null ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 20),

                      // --- Selector de Servicio ---
                      DropdownButtonFormField<BarberiaServicioSimple>(
                        value: _selectedServicio,
                        hint: const Text('Seleccionar Servicio'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.content_cut),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _servicios.map((servicioOferta) {
                          return DropdownMenuItem<BarberiaServicioSimple>(
                            value: servicioOferta,
                            child: Text('${servicioOferta.servicio.nombre} (\$${servicioOferta.precio.toStringAsFixed(2)})'),
                          );
                        }).toList(),
                        onChanged: (BarberiaServicioSimple? newValue) {
                          setState(() {
                            _selectedServicio = newValue;
                          });
                        },
                         validator: (value) => value == null ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 40),

                      // --- Botón Confirmar Cita ---
                      _isConfirming
                       ? const Center(child: CircularProgressIndicator())
                       : ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar Cita'),
                          onPressed: _confirmarCita,
                        )
                    ],
                  ),
                ),
    );
  }
}