import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruta_u/screens/main_passenger_screen.dart';
import 'package:ruta_u/screens/main_driver_screen.dart';

// Definición de colores para consistencia
const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetPassword() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo Electrónico'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) return;
              try {
                await _auth.sendPasswordResetEmail(
                    email: emailController.text.trim());
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Correo de restablecimiento enviado. Revisa tu bandeja de entrada.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Error al enviar el correo. Verifica que esté bien escrito.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  // ✅ FUNCIÓN DE LOGIN ACTUALIZADA CON VERIFICACIÓN DE CORREO
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Intenta iniciar sesión
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        // MUY IMPORTANTE: Recarga el estado del usuario para obtener el emailVerified más reciente.
        await user.reload();
        
        // Verifica si el correo ha sido verificado en Firebase Authentication.
        if (!user.emailVerified) {
          // Si no está verificado, muestra un mensaje y cierra sesión.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, verifica tu correo electrónico para poder iniciar sesión. Revisa tu bandeja de entrada o spam.'),
              backgroundColor: Colors.orange,
            ),
          );
          await _auth.signOut(); // Cierra la sesión
          return; // Detiene el proceso de login
        }

        // Si el correo está verificado en Firebase Auth, procede a Firestore.
        final userDocRef = _firestore.collection('usuarios').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No se encontraron datos del usuario en la base de datos.')),
          );
           await _auth.signOut();
           return;
        }

        final userData = userDoc.data();
        final firestoreVerified = userData?['emailVerificado'] ?? false;

        // Si Firestore dice 'false' pero Auth dice 'true', actualiza Firestore.
        if (!firestoreVerified) {
          await userDocRef.update({'emailVerificado': true});
        }
        
        // Procede con la navegación basada en roles.
        final dynamic rolData = userData?['rol'];
        final List<String> userRoles;

        if (rolData is String) {
          userRoles = [rolData];
        } else if (rolData is List) {
          userRoles = rolData.cast<String>();
        } else {
          userRoles = [];
        }

        if (userRoles.contains('conductor')) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainDriverScreen()));
        } else if (userRoles.contains('pasajero')) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => const MainPassengerScreen()));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error: El rol del usuario no está definido.')),
          );
           await _auth.signOut(); // Cierra sesión si no hay rol válido
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'too-many-requests') {
        errorMessage = 'Acceso bloqueado por demasiados intentos. Inténtalo más tarde.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No existe un usuario con ese correo.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      } else {
        // Captura otros errores de Auth
        errorMessage = "Error de inicio de sesión: ${e.message ?? e.code}";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
       // Captura errores generales (ej. problemas de red, Firestore)
       if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ocurrió un error inesperado: ${e.toString()}"), backgroundColor: Colors.red),
        );
    } finally {
      if(mounted){
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (El resto del widget build se queda exactamente igual)
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.school, size: 100, color: primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido a Ruta U',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
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
                  keyboardType: TextInputType.emailAddress,
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
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
                        )
                      : const Text('Iniciar Sesión',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        '¿No tienes cuenta? Regístrate',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        'Olvidé mi contraseña',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

