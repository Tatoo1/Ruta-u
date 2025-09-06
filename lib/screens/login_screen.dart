import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

// Pantalla de inicio de sesión
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static final TextEditingController _emailController = TextEditingController();
  static final TextEditingController _passwordController = TextEditingController();

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
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Institucional',
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 24),

ElevatedButton(
  onPressed: () async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user != null) {
        // Obtenemos una referencia a la instancia de Firestore
        final firestore = FirebaseFirestore.instance;

        // Consultamos el documento del usuario usando su UID
        final userDoc = await firestore
            .collection('usuarios')
            .doc(credential.user!.uid)
            .get();

        // Leemos el rol del documento
        final userRole = userDoc.data()?['rol'];

        // Redireccionamos según el rol
        if (userRole == 'pasajero') {
          // CORRECCIÓN: Se cambia el nombre de la ruta a '/main_passenger'
          // para que coincida con la definición en main.dart.
          Navigator.pushReplacementNamed(context, '/main_passenger');
        } else if (userRole == 'conductor') {
          Navigator.pushReplacementNamed(context, '/main_driver');
        } else {
          // Manejar caso de rol no definido
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: El rol del usuario no está definido.')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensajeError = "Error desconocido";
      if (e.code == 'user-not-found') {
        mensajeError = "No existe un usuario con ese correo.";
      } else if (e.code == 'wrong-password') {
        mensajeError = "Contraseña incorrecta.";
      } else if (e.code == 'invalid-email') {
        mensajeError = "El formato del correo no es válido.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeError)),
      );
    }
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
