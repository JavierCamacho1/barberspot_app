import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

// --- IMPORTACIONES DE PANTALLAS DE GESTIÓN ---
// Asegúrate de que estos 3 archivos existan en tu carpeta 'screens':

// 1. La pantalla para gestionar barberos
import 'admin_manage_barbers_screen.dart'; 

// 2. La pantalla para gestionar servicios (que te di antes)
import 'admin_manage_services_screen.dart';

// 3. La pantalla para configuración (que te di antes)
import 'admin_config_screen.dart';      

import 'admin_view_clients_screen.dart';


// Modelo para las métricas del Dashboard
class DashboardMetrics {
  final int citasHoy;
  final int totalClientes;
  final int totalBarberos;

  DashboardMetrics({
    required this.citasHoy,
    required this.totalClientes,
    required this.totalBarberos,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      citasHoy: json['citas_hoy'] ?? 0,
      totalClientes: json['total_clientes'] ?? 0,
      totalBarberos: json['total_barberos'] ?? 0,
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _adminName = '';
  int? _barberiaId;
  DashboardMetrics? _metrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdminDataAndFetchMetrics();
  }

  Future<void> _loadAdminDataAndFetchMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final String? barberiaIdStr = prefs.getString('barberia_id');
    
    if (!mounted) return;
    setState(() {
      _adminName = prefs.getString('user_nombre') ?? 'Administrador';
      if (barberiaIdStr != null && barberiaIdStr != 'null') {
         _barberiaId = int.tryParse(barberiaIdStr);
      }
    });

    if (_barberiaId != null) {
      await _fetchDashboardMetrics();
    } else {
       if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "No se pudo identificar la barbería del administrador.";
      });
    }
  }

  Future<void> _fetchDashboardMetrics() async {
    if (_barberiaId == null) return;
    
     if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final String apiUrl = "http://127.0.0.1:8000/administrador/$_barberiaId/dashboard";

    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _metrics = DashboardMetrics.fromJson(dataJson);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Error ${response.statusCode} al cargar dashboard.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error de conexión: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
     if (mounted) {
       Navigator.of(context).pushReplacement(
         MaterialPageRoute(builder: (context) => const LoginScreen()),
       );
     }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $_adminName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red[300])))
              : RefreshIndicator(
                  onRefresh: _fetchDashboardMetrics,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Resumen de tu Barbería',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      // --- Tarjetas de Métricas ---
                      Row(
                        children: [
                          _buildMetricCard('Citas Hoy', _metrics?.citasHoy.toString() ?? '-', Icons.calendar_today, Colors.blueAccent),
                          const SizedBox(width: 16),
                          _buildMetricCard('Barberos', _metrics?.totalBarberos.toString() ?? '-', Icons.content_cut, Colors.orangeAccent),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMetricCard('Total Clientes', _metrics?.totalClientes.toString() ?? '-', Icons.people, Colors.greenAccent, fullWidth: true),

                      const SizedBox(height: 40),
                      const Text(
                        'Gestión',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // --- MENÚ DE GESTIÓN (CORREGIDO) ---
                      
                      _buildManagementButton(
                        Icons.people_outline, // Icono de barberos
                        'Gestionar Barberos',  // Label de barberos
                        () {
                          Navigator.of(context).push(
                            // Esta llamada es la que da error
                            MaterialPageRoute(builder: (context) => const AdminManageBarbersScreen()),
                          );
                        }
                      ),
                      
                      _buildManagementButton(Icons.list_alt, 'Gestionar Servicios', () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AdminManageServicesScreen()),
                        );
                      }),

                      _buildManagementButton(
                       Icons.people, // Icono de clientes
                       'Ver Clientes',  // Label
                       () {
                          Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AdminViewClientsScreen()),
                         );
                       }),
                      
                      _buildManagementButton(Icons.settings, 'Configuración', () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AdminConfigScreen()),
                        );
                      }),

                    ],
                  ),
                ),
    );
  }

  // --- WIDGETS HELPER (copiados de tu código) ---

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Expanded(
      flex: fullWidth ? 0 : 1,
      child: SizedBox( // Si es fullWidth, Expanded no funciona bien solo, necesita SizedBox
        width: fullWidth ? double.infinity : null,
        child: Card(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                 Text(
                  title,
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementButton(IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[800]!)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent[100]),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}