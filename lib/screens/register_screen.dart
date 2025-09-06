import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

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
  String? _selectedRole; // Variable para almacenar el rol seleccionado

  Future<void> _registerUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Valida que el rol se haya seleccionado
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos y selecciona tu rol')),
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

      // Crear usuario en Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardar el rol seleccionado en Firestore
      // Esta es la parte que intentamos depurar si no se guarda el documento
      await _firestore.collection('usuarios').doc(userCredential.user!.uid).set({
        'nombre': name,
        'email': email,
        'rol': _selectedRole, // Usa la variable de rol seleccionada
        'creado': FieldValue.serverTimestamp(),
      });

      // Navegar a la pantalla principal según el rol
      if (_selectedRole == 'pasajero') {
        Navigator.pushReplacementNamed(context, '/main_passenger');
      } else if (_selectedRole == 'conductor') {
        Navigator.pushReplacementNamed(context, '/main_driver');
      }

    } on FirebaseAuthException catch (e) {
      // Este bloque captura errores específicos de autenticación (ej: email ya en uso, contraseña débil)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de autenticación: ${e.message}')),
      );
      // Imprime el error en la consola para una depuración más detallada
      print('Error de Autenticación (FirebaseAuthException): ${e.code} - ${e.message}');
    } on FirebaseException catch (e) { // <-- ¡ESTE ES EL BLOQUE AÑADIDO/CORREGIDO!
      // Este bloque captura errores que vienen de servicios de Firebase como Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de Firestore: ${e.message}')),
      );
      // Imprime el error en la consola para una depuración más detallada
      print('Error de Firestore (FirebaseException): ${e.code} - ${e.message}');
    } catch (e) {
      // Este bloque captura cualquier otro tipo de error inesperado que no sea de Firebase
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
      // Imprime el error en la consola para una depuración más detallada
      print('Error Inesperado (catch all): ${e.toString()}');
    } finally {
      // Siempre oculta el indicador de carga, sin importar si hubo un error o no
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
