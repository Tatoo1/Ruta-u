import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart'; // ✅ IMPORTACIÓN AÑADIDA para enlaces en texto

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
  bool _termsAccepted = false; // ✅ NUEVA VARIABLE DE ESTADO

  // ✅ NUEVA FUNCIÓN: Muestra el diálogo con los términos y condiciones.
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Términos y Política de Datos'),
        content: const SingleChildScrollView(
          child: Text(
              'AVISO IMPORTANTE: Este es un texto genérico de ejemplo. NO constituye asesoría legal. Debes consultar con un abogado para redactar una política que se ajuste a tu aplicación y cumpla con toda la legislación colombiana vigente.\n\n'
              '--- TÉRMINOS Y CONDICIONES DE USO DE RUTA U ---\n\n'
              'Al registrarse, usted acepta y se compromete a cumplir los siguientes Términos y Condiciones...\n\n'
              '--- POLÍTICA DE TRATAMIENTO DE DATOS PERSONALES (HABEAS DATA) ---\n\n'
              'De conformidad con la Ley 1581 de 2012, al marcar la casilla de aceptación, usted autoriza de manera libre, previa, expresa e informada a Ruta U para realizar el tratamiento de sus datos personales...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    List<String> userRoles = ['conductor', 'pasajero'];

    // ✅ NUEVA VALIDACIÓN: Verifica si los términos fueron aceptados.
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Debes aceptar los términos y condiciones para continuar.')),
      );
      return;
    }

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor, completa todos los campos y selecciona tu rol inicial')),
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

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '¡Registro exitoso! Se ha enviado un correo de verificación.'),
          duration: Duration(seconds: 5),
        ),
      );

      // ✅ CAMBIO: Se añaden los campos de aceptación de términos al guardar el usuario.
      await _firestore.collection('usuarios').doc(userCredential.user!.uid).set({
        'nombre': name,
        'email': email,
        'rol': userRoles,
        'emailVerificado': false,
        'creado': FieldValue.serverTimestamp(),
        'terminos_aceptados': true,
        'fecha_aceptacion': FieldValue.serverTimestamp(),
      });

      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
      
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
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
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Institucional',
                    prefixIcon:
                        Icon(Icons.email_outlined, color: primaryColor),
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
                  // ... (Tu widget de selección de rol no tiene cambios)
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
                
                // ✅ NUEVO WIDGET: CHECKBOX PARA TÉRMINOS Y CONDICIONES
                CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (newValue) {
                    setState(() {
                      _termsAccepted = newValue ?? false;
                    });
                  },
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                      children: [
                        const TextSpan(text: 'He leído y acepto los '),
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: const TextStyle(
                              color: primaryColor,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = _showTermsDialog,
                        ),
                        const TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política de Datos (Habeas Data).',
                          style: const TextStyle(
                              color: primaryColor,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = _showTermsDialog,
                        ),
                      ],
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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
