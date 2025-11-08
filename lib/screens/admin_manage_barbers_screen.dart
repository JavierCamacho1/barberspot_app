import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo simple para Barbero en esta pantalla
class Barbero {
  final int id;
  final String nombre;
  final String telefono;

  Barbero({required this.id, required this.nombre, required this.telefono});

  factory Barbero.fromJson(Map<String, dynamic> json) {
    return Barbero(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      telefono: json['telefono'] ?? '',
    );
  }
}

// --- WIDGET PRINCIPAL ---
// Esta es la clase que 'admin_home_screen' necesita importar
class AdminManageBarbersScreen extends StatefulWidget {
  const AdminManageBarbersScreen({super.key});

  @override
  State<AdminManageBarbersScreen> createState() => _AdminManageBarbersScreenState();
}

class _AdminManageBarbersScreenState extends State<AdminManageBarbersScreen> {
  List<Barbero> _barberos = [];
  bool _isLoading = true;
  int? _barberiaId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBarberiaIdAndFetch();
  }

  Future<void> _loadBarberiaIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    // Asegúrate de que la key 'barberia_id' se guarda en SharedPreferences
    final String? barberiaIdStr = prefs.getString('barberia_id'); 
    
    if (barberiaIdStr != null && barberiaIdStr != 'null') {
      _barberiaId = int.tryParse(barberiaIdStr);
      if (_barberiaId != null) {
         _fetchBarberos();
      } else {
         if (mounted) setState(() { _isLoading = false; _error = "ID de barbería inválido."; });
      }
    } else {
      if (mounted) setState(() { _isLoading = false; _error = "No se pudo identificar la barbería."; });
    }
  }

  // --- CRUD: LEER (GET) ---
  Future<void> _fetchBarberos() async {
    if (_barberiaId == null) return;
    if (mounted) setState(() { _isLoading = true; _error = null; });

    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId/barberos";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _barberos = data.map((json) => Barbero.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = "Error al cargar barberos: $e"; });
    }
  }

  // --- CRUD: ELIMINAR (DELETE) ---
  Future<void> _deleteBarbero(int barberoId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Seguro que quieres eliminar a este barbero? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final String apiUrl = "http://127.0.0.1:8000/barberos/$barberoId";
    try {
      final response = await http.delete(Uri.parse(apiUrl));
      if (!mounted) return;
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barbero eliminado'), backgroundColor: Colors.green));
        _fetchBarberos(); // Recargar lista
      } else {
         final data = json.decode(response.body);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['detail']}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  // --- CRUD: CREAR/ACTUALIZAR (POST/PUT) - Diálogo ---
  void _showBarberDialog({Barbero? barbero}) {
    final isEditing = barbero != null;
    final nameController = TextEditingController(text: barbero?.nombre);
    final phoneController = TextEditingController(text: barbero?.telefono);
    final passController = TextEditingController(); // Siempre vacía al inicio
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Barbero' : 'Nuevo Barbero'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passController,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Nueva Contraseña (Opcional)' : 'Contraseña',
                    helperText: isEditing ? 'Deja vacío para no cambiarla' : null,
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (!isEditing && (v == null || v.length < 6)) return 'Mínimo 6 caracteres';
                    // Si está editando y el campo no está vacío, también valida
                    if (isEditing && v != null && v.isNotEmpty && v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx); // Cerrar diálogo
                _saveBarber(
                  id: barbero?.id,
                  nombre: nameController.text,
                  telefono: phoneController.text,
                  password: passController.text.isEmpty ? null : passController.text,
                );
              }
            },
            child: Text(isEditing ? 'Guardar Cambios' : 'Crear Barbero'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBarber({int? id, required String nombre, required String telefono, String? password}) async {
    if (_barberiaId == null) return;
    final isEditing = id != null;
    setState(() => _isLoading = true);

    final String apiUrl = isEditing
        ? "http://127.0.0.1:8000/barberos/$id"       // PUT
        : "http://127.0.0.1:8000/barberias/$_barberiaId/barberos"; // POST

    try {
      final Map<String, dynamic> bodyData = {
        'nombre': nombre,
        'telefono': telefono,
      };
      // Solo añade la contraseña al body si se proporcionó una
      if (password != null && password.isNotEmpty) {
        bodyData['password'] = password;
      }

      final response = isEditing
          ? await http.put(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(bodyData))
          : await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(bodyData));

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Barbero actualizado' : 'Barbero creado'), backgroundColor: Colors.green));
        _fetchBarberos(); // Recargar lista
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['detail']}')));
        setState(() => _isLoading = false); // Solo si falló
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Barberos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBarberDialog(), // Abrir diálogo para CREAR
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: TextStyle(color: Colors.red[300])), ElevatedButton(onPressed: _fetchBarberos, child: const Text('Reintentar'))]))
              : _barberos.isEmpty
                  ? const Center(child: Text('No hay barberos registrados.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _barberos.length,
                      itemBuilder: (context, index) {
                        final barbero = _barberos[index];
                        return Card(
                          color: Colors.grey[850], // Estilo de AdminHome
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(barbero.nombre.isNotEmpty ? barbero.nombre[0].toUpperCase() : '?')),
                            title: Text(barbero.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(barbero.telefono),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () => _showBarberDialog(barbero: barbero), // Editar
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteBarbero(barbero.id), // Eliminar
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}