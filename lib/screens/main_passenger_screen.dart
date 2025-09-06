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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta U - Pasajero', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            const Text(
              'Rutas Publicadas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('rutas').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay rutas publicadas en este momento.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  final rutas = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: rutas.length,
                    itemBuilder: (context, index) {
                      final ruta = rutas[index];
                      final data = ruta.data() as Map<String, dynamic>;
                      final rutaId = ruta.id;
                      final idConductor = data['id_conductor'] as String?;
                      
                      final origen = (data['origen'] is Map) ? data['origen']['direccion'] as String? : (data['origen'] as String?);
                      final destino = (data['destino'] is Map) ? data['destino']['direccion'] as String? : (data['destino'] as String?);
                      final asientosDisponibles = data['asientos_disponibles'] is int ? data['asientos_disponibles'] as int? : null;
                      final horaSalida = (data['hora_salida'] as Timestamp?)?.toDate();
                      
                      final formattedTime = horaSalida != null ? DateFormat.jm().format(horaSalida) : 'Hora no definida';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: const Icon(Icons.drive_eta, color: accentColor),
                          title: Text(
                            'Origen: ${origen ?? 'No especificado'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Destino: ${destino ?? 'No especificado'}\nHora de salida: $formattedTime\nAsientos disponibles: ${asientosDisponibles ?? 0}'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final user = _auth.currentUser;
                              if (user == null || idConductor == null) {
                                return;
                              }
                              
                              // Obtener la información del usuario para la reserva desde la colección 'usuarios'
                              final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
                              final userData = userDoc.data();
                              final nombrePasajero = userData?['nombre'] ?? 'Pasajero Anónimo';

                              // Crea el documento de reserva en la subcolección 'reservas' de la ruta
                              await _firestore
                                  .collection('rutas')
                                  .doc(rutaId)
                                  .collection('reservas')
                                  .add({
                                'pasajero_id': user.uid,
                                'pasajero_nombre': nombrePasajero,
                                'hora_reserva': FieldValue.serverTimestamp(),
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Solicitud de viaje enviada.')),
                              );
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