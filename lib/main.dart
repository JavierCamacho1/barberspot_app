import 'package:flutter/material.dart';
// --- ¡IMPORTACIONES PARA LOCALIZACIÓN! ---
// Asegúrate de que esta línea NO esté marcada como error después de reiniciar VS Code
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
// --- FIN IMPORTACIONES ---

import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa los datos de formato para español
  await initializeDateFormatting('es_ES', null);
  runApp(const BarberSpotApp());
}

class BarberSpotApp extends StatelessWidget {
  const BarberSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberSpot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
         cardTheme: CardThemeData( // <-- ¡LA CLAVE ES USAR CardThemeData!
          color: Colors.grey[850],
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
         elevatedButtonTheme: ElevatedButtonThemeData( // Estilo botones principales
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.blueAccent,
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(12),
             ),
             textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
           )
         ),
          outlinedButtonTheme: OutlinedButtonThemeData( // Estilo botones secundarios
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 16)
            )
          ),
          inputDecorationTheme: InputDecorationTheme( // Estilo campos de texto
             border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!)
             ),
             focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blueAccent) // Corregido: Quitado const innecesario
             ),
             labelStyle: TextStyle(color: Colors.grey[400]),
             prefixIconColor: Colors.grey[400],
          ),
          appBarTheme: AppBarTheme( // Estilo AppBar
             backgroundColor: const Color(0xFF1A1A1A),
             elevation: 0,
             titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
             iconTheme: const IconThemeData(color: Colors.white)
          ),
      ),

      // --- CONFIGURACIÓN DE LOCALIZACIÓN ---
      // Quitamos 'const' aquí temporalmente, aunque debería funcionar con él
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      locale: const Locale('es', 'ES'),
      // --- FIN CONFIGURACIÓN ---

      home: const SplashScreen(),
    );
  }
}