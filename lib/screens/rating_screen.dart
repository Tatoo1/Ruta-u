// Archivo corregido: screens/rating_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const primaryColor = Color(0xFF6200EE);

class RatingScreen extends StatefulWidget {
  final String rutaId;
  final String conductorId;

  const RatingScreen({
    super.key,
    required this.rutaId,
    required this.conductorId,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0.0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  // Función para construir los íconos de estrellas (sin cambios)
  Widget _buildStar(int index) {
    Icon icon;
    if (index >= _rating) {
      icon = const Icon(Icons.star_border, color: Colors.grey, size: 40);
    } else {
      icon = const Icon(Icons.star, color: Colors.amber, size: 40);
    }
    return IconButton(
      icon: icon,
      onPressed: () => setState(() {
        _rating = index + 1.0;
      }),
    );
  }

  // ✅ FUNCIÓN MODIFICADA PARA EVITAR CALIFICACIONES MÚLTIPLES
  Future<void> _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona al menos una estrella.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // VERIFICACIÓN PREVIA: Comprobar si el usuario ya ha calificado esta ruta.
      final existingRatingQuery = await FirebaseFirestore.instance
          .collection('calificaciones')
          .where('ruta_id', isEqualTo: widget.rutaId)
          .where('pasajero_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingRatingQuery.docs.isNotEmpty) {
        // Si la consulta devuelve algún documento, significa que ya existe una calificación.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya has calificado esta ruta anteriormente.')),
        );
        Navigator.of(context).pop(); // Cierra la pantalla de calificación
        return; // Detiene la ejecución de la función
      }

      // Si no hay calificación previa, procede a guardarla.
      await FirebaseFirestore.instance.collection('calificaciones').add({
        'ruta_id': widget.rutaId,
        'conductor_id': widget.conductorId,
        'pasajero_id': user.uid,
        'calificacion': _rating,
        'comentario': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu calificación!')),
      );

      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la calificación: $e')),
      );
    } finally {
       if(mounted) {
         setState(() => _isLoading = false);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Califica tu Viaje', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        // ✅ CAMBIO: Se eliminó 'automaticallyImplyLeading: false' para mostrar el botón de regreso.
        // Ahora Flutter añadirá automáticamente la flecha para volver a la pantalla anterior.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.drive_eta, size: 80, color: primaryColor),
            const SizedBox(height: 16),
            const Text(
              '¿Qué tal estuvo tu ruta?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu opinión nos ayuda a mejorar.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => _buildStar(index)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Enviar Calificación',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}