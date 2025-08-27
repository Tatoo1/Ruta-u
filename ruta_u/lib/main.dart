// Archivo: lib/main.dart

import 'package:flutter/material.dart';
import 'package:ruta_u/screens/login_screen.dart';
import 'package:ruta_u/screens/register_screen.dart';
import 'package:ruta_u/screens/main_driver_screen.dart';
import 'package:ruta_u/screens/main_passenger_screen.dart';
import 'package:ruta_u/screens/role_selection_screen.dart';

// Definición de las constantes de color para un diseño consistente
const Color primaryColor = Color(0xFF673AB7);
const Color accentColor = Color(0xFFE91E63);
const Color backgroundColor = Color(0xFFF5F5F5);

// Punto de entrada de la aplicación Flutter
void main() {
  runApp(const RutaUApp());
}

// Clase principal de la aplicación, utiliza un MaterialApp para la estructura
class RutaUApp extends StatelessWidget {
  const RutaUApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruta U',
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          color: primaryColor,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/main_passenger': (context) => const MainPassengerScreen(),
        '/main_driver': (context) => const MainDriverScreen(),
      },
    );
  }
}