import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo para los datos de la barbería
class BarberiaConfig {
  final String nombre;
  final String? direccion;
  final String? horario;
  final String? latitud;
  final String? longitud;

  BarberiaConfig({
    required this.nombre,
    this.direccion,
    this.horario,
    this.latitud,
    this.longitud,
  });

  factory BarberiaConfig.fromJson(Map<String, dynamic> json) {
    return BarberiaConfig(
      nombre: json['nombre_barberia'] ?? 'Mi Barbería',
      direccion: json['direccion'],
      horario: json['horario'],
      latitud: json['latitud'],
      longitud: json['longitud'],
    );
  }
}

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _barberiaId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Controladores para los campos de texto
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _horarioController = TextEditingController();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBarberiaIdAndFetchData();
  }

  Future<void> _loadBarberiaIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? barberiaIdStr = prefs.getString('barberia_id');

    if (barberiaIdStr == null || barberiaIdStr == 'null') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "No se pudo identificar la barbería.";
        });
      }
      return;
    }
    _barberiaId = int.parse(barberiaIdStr);
    _fetchBarberiaData();
  }

  // --- LEER (GET) ---
  Future<void> _fetchBarberiaData() async {
    if (_barberiaId == null) return;
    if (mounted) setState(() { _isLoading = true; _error = null; });

    // Este es el endpoint GET que creamos
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final barberia = BarberiaConfig.fromJson(data);
        
        // Llenamos los controladores con los datos actuales
        _nombreController.text = barberia.nombre;
        _direccionController.text = barberia.direccion ?? '';
        _horarioController.text = barberia.horario ?? '';
        _latitudController.text = barberia.latitud ?? '';
        _longitudController.text = barberia.longitud ?? '';

        setState(() { _isLoading = false; });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error al cargar datos: $e";
        });
      }
    }
  }

  // --- ACTUALIZAR (PUT) ---
  Future<void> _saveBarberiaData() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return; // No hacer nada si el formulario no es válido
    }
    if (_barberiaId == null || _isSaving) return;

    setState(() { _isSaving = true; });

    // Este es el endpoint PUT que ya teníamos
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId";
    
    // Usamos el schema BarberiaUpdate
    final Map<String, dynamic> bodyData = {
      'nombre_barberia': _nombreController.text,
      'direccion': _direccionController.text,
      'horario': _horarioController.text,
      'latitud': _latitudController.text.isNotEmpty ? _latitudController.text : null,
      'longitud': _longitudController.text.isNotEmpty ? _longitudController.text : null,
    };

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada'), backgroundColor: Colors.green),
        );
        // Actualizar SharedPreferences si el nombre cambió
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('barberia_nombre', _nombreController.text);
        
        Navigator.pop(context, true); // Regresar (true indica que se guardó)
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['detail']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _horarioController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: TextStyle(color: Colors.red[300])), ElevatedButton(onPressed: _fetchBarberiaData, child: const Text('Reintentar'))]))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre de la Barbería',
                        icon: Icons.store,
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _direccionController,
                        label: 'Dirección',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _horarioController,
                        label: 'Horario (Texto)',
                        icon: Icons.access_time,
                        hint: 'Ej: L-V 9am-7pm, S 9am-2pm',
                      ),
                      const SizedBox(height: 24),
                      Text('Ubicación en el Mapa (Opcional)', style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _latitudController,
                              label: 'Latitud',
                              icon: Icons.map,
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _longitudController,
                              label: 'Longitud',
                              icon: Icons.map,
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blueAccent,
                        ),
                        onPressed: _isSaving ? null : _saveBarberiaData,
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : const Text('Guardar Cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Widget helper para los campos de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[850], // Coincide con el estilo de AdminHome
      ),
      keyboardType: keyboard,
      validator: validator,
    );
  }
}