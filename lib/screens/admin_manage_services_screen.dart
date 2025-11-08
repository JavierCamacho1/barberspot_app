import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- MODELOS DE DATOS ---
// Modelo Maestro: El servicio del catálogo (ej. "Corte de Cabello")
class Servicio {
  final int id;
  final String nombre;
  final int? duracion;

  Servicio({required this.id, required this.nombre, this.duracion});

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      duracion: json['duracion_estimada_minutos'],
    );
  }
}

// Modelo Ofrecido: El servicio que la barbería ofrece (ej. "Corte de Cabello" a $20)
class BarberiaServicio {
  final int id; // Este es el ID de la oferta (barberia_servicios.id)
  final double precio;
  final bool activo;
  final Servicio servicio; // Objeto anidado

  BarberiaServicio({
    required this.id,
    required this.precio,
    required this.activo,
    required this.servicio,
  });

  factory BarberiaServicio.fromJson(Map<String, dynamic> json) {
    return BarberiaServicio(
      id: json['id'],
      precio: (json['precio'] as num).toDouble(),
      activo: json['activo'] ?? false,
      servicio: Servicio.fromJson(json['servicio']),
    );
  }
}

// --- WIDGET PRINCIPAL ---
class AdminManageServicesScreen extends StatefulWidget {
  const AdminManageServicesScreen({super.key});

  @override
  State<AdminManageServicesScreen> createState() =>
      _AdminManageServicesScreenState();
}

class _AdminManageServicesScreenState extends State<AdminManageServicesScreen> {
  // Lista de servicios que la barbería YA ofrece
  List<BarberiaServicio> _serviciosOfrecidos = [];
  // Lista de TODOS los servicios del catálogo maestro (para el Dropdown)
  List<Servicio> _catalogoMaestro = [];

  bool _isLoading = true;
  int? _barberiaId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    
    final prefs = await SharedPreferences.getInstance();
    final String? barberiaIdStr = prefs.getString('barberia_id');

    if (barberiaIdStr == null || barberiaIdStr == 'null') {
      if (mounted) setState(() { _isLoading = false; _error = "No se pudo identificar la barbería."; });
      return;
    }
    _barberiaId = int.parse(barberiaIdStr);

    try {
      // Cargamos ambas listas en paralelo
      await Future.wait([
        _fetchServiciosOfrecidos(),
        _fetchCatalogoMaestro(),
      ]);
    } catch (e) {
      if (mounted) setState(() { _error = "Error al cargar datos: $e"; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // --- CRUD: LEER (Servicios Ofrecidos por esta barbería) ---
  Future<void> _fetchServiciosOfrecidos() async {
    if (_barberiaId == null) return;
    
    final String apiUrl = "http://127.0.0.1:8000/barberias/$_barberiaId/servicios";
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

    if (!mounted) return;
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        _serviciosOfrecidos = data.map((json) => BarberiaServicio.fromJson(json)).toList();
      });
    } else {
      throw Exception('Error al cargar servicios ofrecidos (${response.statusCode})');
    }
  }

  // --- CRUD: LEER (Catálogo Maestro de TODOS los servicios) ---
  Future<void> _fetchCatalogoMaestro() async {
    const String apiUrl = "http://127.0.0.1:8000/servicios";
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

    if (!mounted) return;
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        _catalogoMaestro = data.map((json) => Servicio.fromJson(json)).toList();
      });
    } else {
      throw Exception('Error al cargar catálogo maestro (${response.statusCode})');
    }
  }

  // --- CRUD: DESACTIVAR (DELETE Lógico) ---
  Future<void> _desactivarServicio(int servicioOfrecidoId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Acción'),
        content: const Text('¿Seguro que quieres quitar este servicio? Ya no aparecerá para agendar nuevas citas. Podrás reactivarlo editándolo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Quitar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Usamos el endpoint de soft-delete que creamos
    final String apiUrl = "http://127.0.0.1:8000/barberia-servicios/$servicioOfrecidoId";
    try {
      final response = await http.delete(Uri.parse(apiUrl));
      if (!mounted) return;

      // ¡Importante! Nuestro backend devuelve 200 (no 204) porque es un soft-delete
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio desactivado'), backgroundColor: Colors.green));
        _loadInitialData(); // Recargar ambas listas
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['detail']}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  // --- CRUD: CREAR/ACTUALIZAR (POST/PUT) - Diálogo ---
  void _showServiceDialog({BarberiaServicio? servicio}) {
    final isEditing = servicio != null;
    final formKey = GlobalKey<FormState>();

    // Controladores
    final priceController = TextEditingController(
      text: isEditing ? servicio.precio.toStringAsFixed(0) : ''
    );
    // Estado para el Dropdown (al crear)
    Servicio? _servicioSeleccionado;
    // Estado para el Switch (al editar)
    bool _estaActivo = isEditing ? servicio.activo : true;

    // Para el Dropdown: Filtramos los servicios que YA están siendo ofrecidos
    final serviciosDisponibles = _catalogoMaestro.where((catalogoSvc) {
      // Si está editando, no filtramos nada (no se muestra el dropdown)
      if(isEditing) return true;
      // Si está creando, filtramos los que ya están en la lista
      return !_serviciosOfrecidos.any((ofrecidoSvc) => ofrecidoSvc.servicio.id == catalogoSvc.id);
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Usamos StatefulBuilder para manejar el estado del Switch
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Servicio' : 'Añadir Servicio'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- CAMPO: SELECCIÓN DE SERVICIO (SOLO AL CREAR) ---
                      if (!isEditing)
                        DropdownButtonFormField<Servicio>(
                          decoration: const InputDecoration(labelText: 'Servicio'),
                          hint: const Text('Selecciona un servicio'),
                          isExpanded: true,
                          value: _servicioSeleccionado,
                          items: serviciosDisponibles.map((Servicio svc) {
                            return DropdownMenuItem<Servicio>(
                              value: svc,
                              child: Text(svc.nombre),
                            );
                          }).toList(),
                          onChanged: (Servicio? newValue) {
                            _servicioSeleccionado = newValue;
                          },
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      
                      // --- CAMPO: NOMBRE (SOLO AL EDITAR, SOLO LECTURA) ---
                      if (isEditing)
                        TextFormField(
                          initialValue: servicio.servicio.nombre,
                          decoration: const InputDecoration(labelText: 'Servicio'),
                          readOnly: true, // No se puede cambiar el servicio
                        ),

                      const SizedBox(height: 10),

                      // --- CAMPO: PRECIO (CREAR Y EDITAR) ---
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Precio',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (double.tryParse(v) == null) return 'Número inválido';
                          return null;
                        },
                      ),

                      // --- CAMPO: ACTIVO (SOLO AL EDITAR) ---
                      if (isEditing)
                        SwitchListTile(
                          title: const Text('Activo'),
                          subtitle: const Text('Permitir agendar este servicio'),
                          value: _estaActivo,
                          onChanged: (bool newValue) {
                            setDialogState(() { // Actualiza el estado del diálogo
                              _estaActivo = newValue;
                            });
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
                      _saveServicio(
                        isEditing: isEditing,
                        servicioOfrecidoId: servicio?.id,
                        servicioMaestroId: _servicioSeleccionado?.id,
                        precio: double.parse(priceController.text),
                        activo: _estaActivo,
                      );
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Añadir Servicio'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Lógica para guardar
  Future<void> _saveServicio({
    required bool isEditing,
    int? servicioOfrecidoId, // ID de la oferta (para PUT)
    int? servicioMaestroId,  // ID del catálogo (para POST)
    required double precio,
    required bool activo,
  }) async {
    if (_barberiaId == null) return;
    setState(() => _isLoading = true);

    final String apiUrl = isEditing
        ? "http://127.0.0.1:8000/barberia-servicios/$servicioOfrecidoId" // PUT
        : "http://127.0.0.1:8000/barberias/$_barberiaId/servicios";    // POST

    try {
      // El body es diferente para crear que para editar
      Map<String, dynamic> bodyData;
      if (isEditing) {
        // Schema: BarberiaServicioUpdate
        bodyData = {
          'precio': precio,
          'activo': activo,
        };
      } else {
        // Schema: BarberiaServicioCreate
        bodyData = {
          'servicio_id': servicioMaestroId,
          'precio': precio,
          'activo': true, // Siempre se crea como activo
        };
      }

      final response = isEditing
          ? await http.put(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(bodyData))
          : await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(bodyData));

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Servicio actualizado' : 'Servicio añadido'), backgroundColor: Colors.green));
        _loadInitialData(); // Recargamos todo
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['detail']}')));
        setState(() => _isLoading = false);
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
    // Filtramos la lista para mostrar activos e inactivos por separado
    final serviciosActivos = _serviciosOfrecidos.where((s) => s.activo).toList();
    final serviciosInactivos = _serviciosOfrecidos.where((s) => !s.activo).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Servicios')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(), // Abrir diálogo para CREAR
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: TextStyle(color: Colors.red[300])), ElevatedButton(onPressed: _loadInitialData, child: const Text('Reintentar'))]))
              : _serviciosOfrecidos.isEmpty && _catalogoMaestro.isEmpty
                  ? const Center(child: Text('No hay servicios en el catálogo.', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (serviciosActivos.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('No hay servicios activos. Añade uno.', style: TextStyle(color: Colors.grey)),
                            )),
                          
                          ...serviciosActivos.map((servicio) {
                            return _buildServiceCard(servicio, isActive: true);
                          }),

                          if (serviciosInactivos.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 24.0, bottom: 8.0, left: 8.0),
                              child: Text(
                                'SERVICIOS INACTIVOS',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          
                          ...serviciosInactivos.map((servicio) {
                            return _buildServiceCard(servicio, isActive: false);
                          }),
                        ],
                      ),
                    ),
    );
  }

  // Widget para la tarjeta de servicio
  Widget _buildServiceCard(BarberiaServicio servicio, {required bool isActive}) {
    // Este estilo de Card es para que coincida con el de 'Gestionar Barberos'
    return Card(
      color: isActive ? Colors.grey[850] : Colors.grey[900], // Color atenuado si está inactivo
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[700],
          child: const Icon(Icons.content_cut, color: Colors.white),
        ),
        title: Text(
          servicio.servicio.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey[500],
            decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '\$${servicio.precio.toStringAsFixed(0)}', // Mostramos precio sin decimales
          style: TextStyle(color: isActive ? Colors.grey[300] : Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: isActive ? Colors.blueAccent : Colors.grey[600]),
              onPressed: () => _showServiceDialog(servicio: servicio), // Editar
            ),
            // El botón de "desactivar" solo tiene sentido si está activo
            if (isActive)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _desactivarServicio(servicio.id), // Desactivar
              ),
          ],
        ),
      ),
    );
  }
}