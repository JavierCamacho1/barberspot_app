// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const BarberSpotApp());
}

class BarberSpotApp extends StatelessWidget {
  const BarberSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberSpot',
      debugShowCheckedModeBanner: false, // Quita la cinta de "Debug"
      theme: ThemeData.dark().copyWith(
        // Define un color de acento que usaremos
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Fondo gris oscuro
      ),
      home: const SplashScreen(), // Antes era LoginScreen()
    );
  }
}