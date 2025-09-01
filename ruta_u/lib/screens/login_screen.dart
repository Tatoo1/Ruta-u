import 'package:flutter/material.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

// Pantalla de inicio de sesión
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Logo de la Universidad Central
                const Image(
                  image: AssetImage('assets/logo.png'), // Agrega el logo de la universidad
                  height: 150,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido a Ruta U',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'El transporte colaborativo para estudiantes',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Correo Institucional',
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Añadir lógica de autenticación de Firebase aquí.
                    // Navegar a la pantalla principal del usuario después de la autenticación exitosa.
                    // Por ahora, solo navegamos a la pantalla del conductor como ejemplo.
                    Navigator.pushReplacementNamed(context, '/main_driver');
                  },
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    '¿No tienes una cuenta? Regístrate',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}