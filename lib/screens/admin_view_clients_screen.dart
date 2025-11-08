import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo simple para Cliente (es idéntico al de Barbero)
class Cliente {
  final int id;
  final String nombre;
  final String telefono;

  Cliente({required this.id, required this.nombre, required this.telefono});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      telefono: json['telefono'] ?? '',
    );
  }
}

// --- WIDGET PRINCIPAL ---
class AdminViewClientsScreen extends StatefulWidget {
  const AdminViewClientsScreen({super.key});

  @override
  State<AdminViewClientsScreen> createState() => _AdminViewClientsScreenState();
}

class _AdminViewClientsScreenState extends State<AdminViewClientsScreen> {
  List<Cliente> _clientes = [];
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
    final String? barberiaIdStr = prefs.getString('barberia_id'); 
    
    if (barberiaIdStr != null && barberiaIdStr != 'null') {
      _barberiaId = int.tryParse(barberiaIdStr);
      if (_barberiaId != null) {
         _fetchClientes();
      } else {
         if (mounted) setState(() { _isLoading = false; _error = "ID de barbería inválido."; });
      }
    } else {
      if (mounted) setState(() { _isLoading = false; _error = "No se pudo identificar la barbería."; });
    }
  }

  // --- CRUD: LEER (GET) ---
  Future<void> _fetchClientes() async {
    if (_barberiaId == null) return;
    if (mounted) setState(() { _isLoading = true; _error = null; });

    // Este es el endpoint que creamos para ver clientes
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId/clientes";
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _clientes = data.map((json) => Cliente.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = "Error al cargar clientes: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes de la Barbería')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: TextStyle(color: Colors.red[300])), ElevatedButton(onPressed: _fetchClientes, child: const Text('Reintentar'))]))
              : _clientes.isEmpty
                  ? const Center(child: Text('No hay clientes asociados.', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _fetchClientes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = _clientes[index];
                          return Card(
                            color: Colors.grey[850], // Estilo de AdminHome
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(child: Text(cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?')),
                              title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(cliente.telefono),
                              // No hay 'trailing' porque es de solo lectura
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}