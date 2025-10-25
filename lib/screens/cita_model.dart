// Modelo para representar los datos de una cita recibidos de la API

// Clases auxiliares para datos anidados
class UsuarioSimple {
  final int id;
  final String nombre;
  final String telefono;

  UsuarioSimple({required this.id, required this.nombre, required this.telefono});

  factory UsuarioSimple.fromJson(Map<String, dynamic> json) {
    return UsuarioSimple(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'N/A',
      telefono: json['telefono'] ?? 'N/A',
    );
  }
}

class ServicioSimple {
   final int id;
   final String nombre;
   final String? descripcion;
   final int? duracionEstimadaMinutos;

   ServicioSimple({
     required this.id,
     required this.nombre,
     this.descripcion,
     this.duracionEstimadaMinutos,
   });

   factory ServicioSimple.fromJson(Map<String, dynamic> json) {
     return ServicioSimple(
       id: json['id'] ?? 0,
       nombre: json['nombre'] ?? 'N/A',
       descripcion: json['descripcion'],
       duracionEstimadaMinutos: json['duracion_estimada_minutos'],
     );
   }
}

class BarberiaServicioSimple {
  final int id;
  final double precio;
  final bool activo;
  final int barberiaId;
  final int servicioId;
  final ServicioSimple servicio; // Objeto Servicio anidado

  BarberiaServicioSimple({
    required this.id,
    required this.precio,
    required this.activo,
    required this.barberiaId,
    required this.servicioId,
    required this.servicio,
  });

 factory BarberiaServicioSimple.fromJson(Map<String, dynamic> json) {
   return BarberiaServicioSimple(
     id: json['id'] ?? 0,
     precio: (json['precio'] as num?)?.toDouble() ?? 0.0, // Conversión segura a double
     activo: json['activo'] ?? false,
     barberiaId: json['barberia_id'] ?? 0,
     servicioId: json['servicio_id'] ?? 0,
     // Parseamos el objeto 'servicio' anidado
     servicio: ServicioSimple.fromJson(json['servicio'] ?? {}),
   );
 }
}


// Clase principal para la Cita
class CitaModel {
  final int id;
  final DateTime fechaHora;
  final int clienteId;
  final int barberoId;
  final int barberiaId;
  final int barberiaServicioId;
  final String estado;
  final UsuarioSimple cliente; // Objeto Usuario anidado
  final UsuarioSimple barbero; // Objeto Usuario anidado
  final BarberiaServicioSimple servicioAgendado; // Objeto BarberiaServicio anidado

  CitaModel({
    required this.id,
    required this.fechaHora,
    required this.clienteId,
    required this.barberoId,
    required this.barberiaId,
    required this.barberiaServicioId,
    required this.estado,
    required this.cliente,
    required this.barbero,
    required this.servicioAgendado,
  });

  factory CitaModel.fromJson(Map<String, dynamic> json) {
    return CitaModel(
      id: json['id'] ?? 0,
      // Parseamos la fecha ISO 8601 que viene de la API
      fechaHora: DateTime.tryParse(json['fecha_hora'] ?? '') ?? DateTime.now(),
      clienteId: json['cliente_id'] ?? 0,
      barberoId: json['barbero_id'] ?? 0,
      barberiaId: json['barberia_id'] ?? 0,
      barberiaServicioId: json['barberia_servicio_id'] ?? 0,
      estado: json['estado'] ?? 'desconocido',
      // Parseamos los objetos anidados
      cliente: UsuarioSimple.fromJson(json['cliente'] ?? {}),
      barbero: UsuarioSimple.fromJson(json['barbero'] ?? {}),
      servicioAgendado: BarberiaServicioSimple.fromJson(json['servicio_agendado'] ?? {}),
    );
  }
}
