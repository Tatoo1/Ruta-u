import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Definición de colores para consistencia
const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

// Pantalla principal del pasajero para ver rutas
class MainPassengerScreen extends StatefulWidget {
  const MainPassengerScreen({super.key});

  @override
  State<MainPassengerScreen> createState() => _MainPassengerScreenState();
}

class _MainPassengerScreenState extends State<MainPassengerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  void _showUserProfile() {
    final user = _auth.currentUser;
    if (user != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _buildUserProfileScreen(user.uid),
        ),
      );
    }
  }

  Widget _buildUserProfileScreen(String userId) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('usuarios').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar el perfil: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Usuario no encontrado.'));
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nombre: ${userData['nombre']}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Email: ${userData['email']}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Rol: ${userData['rol']}', style: const TextStyle(fontSize: 18)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Método para manejar el cierre de sesión
  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas Disponibles', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: _showUserProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sección para filtrar rutas (puedes agregar filtros aquí)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar rutas...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('rutas').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar las rutas: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay rutas disponibles en este momento.'));
                  }

                  final rutas = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: rutas.length,
                    itemBuilder: (context, index) {
                      final ruta = rutas[index].data() as Map<String, dynamic>;
                      final origen = ruta['origen_nombre'] ?? 'Ubicación Desconocida';
                      final destino = ruta['destino_nombre'] ?? 'Destino Desconocido';
                      final conductor = ruta['conductor_nombre'] ?? 'Conductor Desconocido';
                      final hora = ruta['hora_salida'] != null
                          ? DateFormat.Hm().format((ruta['hora_salida'] as Timestamp).toDate())
                          : 'Hora Desconocida';
                      final asientos = ruta['asientos_disponibles'] ?? 'N/A';
                      final precio = ruta['precio'] ?? 'N/A';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: ListTile(
                          title: Text('$origen a $destino'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Conductor: $conductor'),
                              Text('Hora: $hora'),
                              Text('Asientos disponibles: $asientos'),
                              Text('Precio: $precio'),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              final user = _auth.currentUser;
                              if (user == null) {
                                // Muestra un mensaje de error si el usuario no está autenticado
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ Error: Debes iniciar sesión para solicitar una ruta.')),
                                );
                                return;
                              }

                              try {
                                // Aquí se crea la solicitud de viaje
                                _firestore.collection('solicitudes_viaje').add({
                                  'id_ruta': rutas[index].id,
                                  'id_conductor': ruta['id_conductor'],
                                  'id_pasajero': user.uid, // Aseguramos que el ID del usuario esté presente
                                  'estado': 'pendiente',
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // Muestra un mensaje de éxito
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Solicitud de viaje enviada.')),
                                );
                              } on FirebaseException catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al solicitar la ruta: ${e.message}')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ocurrió un error inesperado: $e')),
                                );
                              }
                            },
                            child: const Text('Solicitar'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
