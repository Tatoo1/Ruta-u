import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';

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
  bool _termsAccepted = false;

  // ✅ FUNCIÓN MODIFICADA: Ahora muestra un texto más detallado y con formato.
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Términos y Política de Datos'),
        content: SingleChildScrollView(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 14, height: 1.5),
              children: const [
                TextSpan(
                  text: 'AVISO IMPORTANTE:\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: 'Se genera un texto de T&C pero se debe consultar con profesionales legales para ajustarlo conforme a las leyes actuales\n\n',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
                TextSpan(
                  text: 'Términos y Condiciones de Uso\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text: '1. Objeto: Ruta U es una plataforma tecnológica que actúa como intermediaria para conectar a miembros de la comunidad universitaria que deseen compartir un viaje en vehículo particular.\n'
                        '2. Responsabilidades del Usuario: Usted se compromete a proporcionar información veraz y actualizada, a mantener un comportamiento respetuoso y a cumplir con las normas de seguridad vial.\n'
                        '3. Limitación de Responsabilidad: Ruta U no provee servicios de transporte y no se hace responsable por incidentes, accidentes, o cualquier disputa que pueda surgir entre los usuarios durante un viaje.\n\n',
                ),
                TextSpan(
                  text: 'Política de Tratamiento de Datos (Habeas Data)\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text: 'De conformidad con la Ley 1581 de 2012, al aceptar estos términos, usted autoriza a Ruta U para el tratamiento de sus datos personales con las siguientes finalidades:\n\n'
                        'a) Datos Recopilados: Nombre, correo electrónico, rol (conductor/pasajero), ubicación en tiempo real durante las rutas activas, y datos del vehículo (para conductores).\n'
                        'b) Finalidad: Conectar usuarios, facilitar la comunicación, mejorar la seguridad, procesar calificaciones y gestionar el servicio.\n'
                        'c) Derechos del Titular: Usted tiene derecho a conocer, actualizar, rectificar y solicitar la supresión de sus datos personales escribiendo a [Correo de Soporte de la App].\n\n'
                        'Al marcar la casilla, usted declara que ha leído y acepta de manera libre, previa, expresa e informada los términos y la política de tratamiento de datos de Ruta U.',
                ),
              ],
            ),
          ),
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

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones para continuar.')),
      );
      return;
    }

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

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Registro exitoso! Se ha enviado un correo de verificación.'), duration: Duration(seconds: 5)),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: ${e.toString()}')));
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person_outline, color: primaryColor)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Institucional', prefixIcon: Icon(Icons.email_outlined, color: primaryColor)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline, color: primaryColor)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña', prefixIcon: Icon(Icons.lock_outline, color: primaryColor)),
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
                        onPressed: () => setState(() => _selectedRole = 'conductor'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _selectedRole == 'conductor' ? primaryColor : Colors.grey, width: 2.0),
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
                        onPressed: () => setState(() => _selectedRole = 'pasajero'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _selectedRole == 'pasajero' ? primaryColor : Colors.grey, width: 2.0),
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
                
                CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (newValue) => setState(() => _termsAccepted = newValue ?? false),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                      children: [
                        const TextSpan(text: 'He leído y acepto los '),
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: const TextStyle(color: primaryColor, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                        ),
                        const TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política de Datos (Habeas Data).',
                          style: const TextStyle(color: primaryColor, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
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
                      : const Text('Registrarme', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
