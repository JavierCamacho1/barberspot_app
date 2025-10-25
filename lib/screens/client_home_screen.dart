import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // Para cerrar sesión
import 'map_screen.dart';   // Para cambiar de barbería

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String _userName = ''; // Para mostrar el nombre del usuario
  String _barberiaNombre = ''; // <-- VARIABLE NUEVA para el nombre de la barbería

  @override
  void initState() {
    super.initState();
    _loadUserData(); // <--- NOMBRE CAMBIADO
    // TODO: Cargar las citas pendientes aquí
  }

  // --- FUNCIÓN ACTUALIZADA ---
  // Carga los datos del usuario y la barbería desde SharedPreferences
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_nombre') ?? 'Usuario';
      // Leemos el nombre de la barbería guardado
      _barberiaNombre = prefs.getString('barberia_nombre') ?? 'Barbería no asignada'; // <-- LÍNEA NUEVA
    });
  }
  // --- FIN FUNCIÓN ACTUALIZADA ---

  // --- Funciones de Navegación ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _goToMapScreen() {
     // Navega al mapa PERO permite regresar (no reemplaza)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  void _goToAgendarCita() {
    // TODO: Navegar a la pantalla de agendar cita (FASE 3)
    print("Navegando a agendar cita...");
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pantalla "Agendar Cita" aún no implementada.')),
    );
  }

  void _goToHistorial() {
    // TODO: Navegar a la pantalla de historial (FASE 3)
    print("Navegando a historial...");
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pantalla "Historial" aún no implementada.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         // --- ¡APPBAR MODIFICADO! ---
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido, $_userName'),
            // Solo muestra el nombre de la barbería si existe y no es el valor por defecto
            if (_barberiaNombre.isNotEmpty && _barberiaNombre != 'Barbería no asignada')
              Text(
                _barberiaNombre,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey), // Estilo más sutil
              ),
          ],
        ),
        // --- FIN APPBAR MODIFICADO ---
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          // Botón para Cambiar Barbería (Ir al Mapa)
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Cambiar de Barbería',
            onPressed: _goToMapScreen,
          ),
          // Botón para Cerrar Sesión
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sección Citas Pendientes ---
            const Text(
              'Próximas Citas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              // Usamos Expanded para que la lista ocupe el espacio disponible
              child: Center(
                // TODO: Reemplazar esto con la lista real de citas pendientes
                child: Text(
                  'Aún no tienes citas pendientes.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Botones de Acción ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agendar Nueva Cita'),
                onPressed: _goToAgendarCita,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon( // Usamos OutlinedButton para diferenciar
                icon: const Icon(Icons.history),
                label: const Text('Ver Historial de Citas'),
                onPressed: _goToHistorial,
                 style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.white, // Color del texto e icono
                   side: BorderSide(color: Colors.grey[700]!), // Borde gris
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
                 ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
