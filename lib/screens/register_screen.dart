import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruta_u/main.dart';
import 'package:ruta_u/screens/main_driver_screen.dart';
import 'package:ruta_u/screens/main_passenger_screen.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _selectedRole;

  Future<void> _registerUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    // MANTENIENDO LA FUNCIONALIDAD DE ASIGNAR AMBOS ROLES
    List<String> userRoles = ['conductor', 'pasajero']; 

    // Valida que el rol se haya seleccionado (aunque se asignen ambos) y el resto de campos.
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos y selecciona tu rol inicial')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }
    
    try {
      setState(() => _isLoading = true);

      // 1. Crear usuario en Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. ENVIAR CORREO DE VERIFICACIÓN ✉️
      // Este es el paso clave para que Firebase envíe el correo.
      // La llamada se hace en el objeto 'User' recién creado.
      await userCredential.user!.sendEmailVerification();
      
      // Muestra un mensaje al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso! Se ha enviado un correo de verificación. Por favor, revisa tu bandeja de entrada, en caso de no verlo alli revisa tu carpeta de spam.'),
          duration: Duration(seconds: 5),
        ),
      );

      // 3. Guardar datos en Firestore (mantiene la asignación de ambos roles)
      await _firestore.collection('usuarios').doc(userCredential.user!.uid).set({
        'nombre': name,
        'email': email,
        'rol': userRoles, // Mantiene ambos roles
        'emailVerificado': false, // Añadir este campo es buena práctica
        'creado': FieldValue.serverTimestamp(),
      });
      
      // 4. Cierra la sesión (RECOMENDADO) y redirige
      // Obliga al usuario a iniciar sesión después de verificar el correo.
      await _auth.signOut();

      // Redirige al inicio de sesión (asumiendo que tienes una pantalla de login)
      // Si el objetivo es navegar a una pantalla donde se espera la verificación:
      Navigator.pushReplacementNamed(context, '/login'); 
      // NOTA: Tu código original navegaba directamente. Lo he cambiado a '/login' para forzar la verificación.
      // Si necesitas navegar a las pantallas principales, solo descomenta y usa tu lógica original:
      /*
      if (userRoles.contains('pasajero')) {
        Navigator.pushReplacementNamed(context, '/main_passenger');
      } else if (userRoles.contains('conductor')) {
        Navigator.pushReplacementNamed(context, '/main_driver');
      }
      */


    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'El correo ya está registrado.';
      } else {
        errorMessage = 'Error de autenticación: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      print('Error de Autenticación (FirebaseAuthException): ${e.code} - ${e.message}');
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de Firestore: ${e.message}')),
      );
      print('Error de Firestore (FirebaseException): ${e.code} - ${e.message}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
      print('Error Inesperado (catch all): ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definición de colores para consistencia
    const primaryColor = Color(0xFF6200EE);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Crea una cuenta en Ruta U',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // Mejorar el teclado para correo
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
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¿Cómo quieres usar Ruta U?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedRole = 'conductor';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _selectedRole == 'conductor' ? primaryColor : Colors.grey,
                            width: 2.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.directions_car, color: _selectedRole == 'conductor' ? primaryColor : Colors.grey),
                            const SizedBox(height: 8),
                            const Text('Conductor', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedRole = 'pasajero';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _selectedRole == 'pasajero' ? primaryColor : Colors.grey,
                            width: 2.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person, color: _selectedRole == 'pasajero' ? primaryColor : Colors.grey),
                            const SizedBox(height: 8),
                            const Text('Pasajero', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Registrarme',
                          style: TextStyle(fontSize: 18),
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