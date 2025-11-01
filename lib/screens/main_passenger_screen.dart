import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ruta_u/screens/main_driver_screen.dart';
import 'package:ruta_u/screens/passenger_route_tracking_screen.dart';
import 'package:ruta_u/screens/rating_screen.dart';

// Definición de colores para consistencia
const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

class MainPassengerScreen extends StatefulWidget {
  const MainPassengerScreen({super.key});

  @override
  State<MainPassengerScreen> createState() => _MainPassengerScreenState();
}

class _MainPassengerScreenState extends State<MainPassengerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // --- LÓGICA DE PERFIL (Sin cambios) ---
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No se encontraron datos de usuario.'));
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userName = userData['nombre'] ?? 'No disponible';
          final userEmail = userData['email'] ?? 'No disponible';
          final userRoles = (userData['rol'] as List<dynamic>?)?.cast<String>() ?? [];
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.person_pin, size: 100, color: primaryColor)),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileInfoRow(Icons.person_outline, 'Nombre', userName),
                        const Divider(),
                        _buildProfileInfoRow(Icons.email_outlined, 'Email', userEmail),
                        const Divider(),
                        _buildProfileInfoRow(Icons.badge, 'ID de Usuario', userId),
                      ],
                    ),
                  ),
                ),
                if (userRoles.contains('conductor')) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const MainDriverScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        'Cambiar a Perfil Conductor',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE RESERVA Y CANCELACIÓN (Sin cambios) ---
  Future<void> _requestRoute(String rutaId, String idConductor, String puntoRecogida, String metodoPago) async {
        final user = _auth.currentUser;
    final currentUserId = user?.uid;
    if (currentUserId == null || idConductor == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de autenticación.')));
      return;
    }
    if (currentUserId == idConductor) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes reservar tu propia ruta.')));
      return;
    }
    try {
      final userDoc = await _firestore.collection('usuarios').doc(currentUserId).get();
      final nombrePasajero = userDoc.data()?['nombre'] ?? 'Pasajero Anónimo';
      await _firestore.runTransaction((transaction) async {
        final rutaRef = _firestore.collection('rutas').doc(rutaId);
        final rutaDoc = await transaction.get(rutaRef);
        final currentSeats = rutaDoc.data()?['asientos_disponibles'] as int? ?? 0;
        if (currentSeats > 0) {
          transaction.update(rutaRef, {'asientos_disponibles': currentSeats - 1});
          transaction.set(_firestore.collection('rutas').doc(rutaId).collection('reservas').doc(), {
            'pasajero_id': currentUserId,
            'pasajero_nombre': nombrePasajero,
            'punto_recogida': puntoRecogida,
            'hora_reserva': FieldValue.serverTimestamp(),
            'estado_recogido': false,
            'metodo_pago': metodoPago,
          });
        } else {
          throw 'No hay asientos disponibles.';
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Solicitud de viaje enviada. Método de pago: $metodoPago')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al solicitar la ruta: ${e.toString()}')));
    }
  }
  
  Future<void> _showPickupInputDialog(String rutaId, String idConductor, int asientosDisponibles) async {
        final TextEditingController pickupController = TextEditingController();
    String? selectedPaymentMethod;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmar Reserva'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text('1. Especifica tu punto de recogida:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pickupController,
                      decoration: InputDecoration(
                        labelText: 'Dirección de Recogida',
                        hintText: 'Ej: Carrera 7 # 45-10',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.location_on, color: primaryColor),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    const Text('2. Selecciona tu método de pago:'),
                    RadioListTile<String>(
                      title: const Text('Efectivo'),
                      secondary: const Icon(Icons.money),
                      value: 'Efectivo',
                      groupValue: selectedPaymentMethod,
                      onChanged: (value) => setState(() => selectedPaymentMethod = value),
                    ),
                    RadioListTile<String>(
                      title: const Text('Nequi / Daviplata'),
                      secondary: const Icon(Icons.phone_android),
                      value: 'Nequi/Daviplata',
                      groupValue: selectedPaymentMethod,
                      onChanged: (value) => setState(() => selectedPaymentMethod = value),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  onPressed: (pickupController.text.trim().isNotEmpty && selectedPaymentMethod != null)
                      ? () {
                          Navigator.of(context).pop(); 
                          _requestRoute(rutaId, idConductor, pickupController.text.trim(), selectedPaymentMethod!);
                        }
                      : null,
                  child: const Text('Reservar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelReservation(String rutaId, String reservaId) async {
        try {
      await _firestore.runTransaction((transaction) async {
        final rutaRef = _firestore.collection('rutas').doc(rutaId);
        final rutaDoc = await transaction.get(rutaRef);
        final currentSeats = rutaDoc.data()?['asientos_disponibles'] as int? ?? 0;
        transaction.delete(_firestore.collection('rutas').doc(rutaId).collection('reservas').doc(reservaId));
        transaction.update(rutaRef, {'asientos_disponibles': currentSeats + 1});
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Reserva cancelada correctamente.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar la reserva: ${e.toString()}')));
    }
  }

  Future<void> _showCancellationConfirmationDialog(String rutaId, String reservaId) async {
        return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar cancelación'),
          content: const SingleChildScrollView(child: ListBody(children: <Widget>[Text('¿Estás seguro de que deseas cancelar tu reserva para esta ruta?')])),
          actions: <Widget>[
            TextButton(child: const Text('No'), onPressed: () => Navigator.of(context).pop()),
            TextButton(child: const Text('Sí'), onPressed: () { _cancelReservation(rutaId, reservaId); Navigator.of(context).pop(); }),
          ],
        );
      },
    );
  }

  // ✅ BUILD MÉTODO MODIFICADO CON TABCONTROLLER
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final String? currentUserId = user?.uid;

    return DefaultTabController(
      length: 2, // Dos pestañas: "Rutas Disponibles" y "Mi Historial"
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ruta U - Pasajero', style: TextStyle(color: Colors.white)),
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: _showUserProfile,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await _auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
          // ✅ AÑADIDA LA BARRA DE PESTAÑAS
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.explore, color: Colors.white), text: 'Rutas Disponibles'),
              Tab(icon: Icon(Icons.history, color: Colors.white), text: 'Mi Historial'),
            ],
            indicatorColor: accentColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        // ✅ AÑADIDO TABBARVIEW PARA MOSTRAR EL CONTENIDO DE CADA PESTAÑA
        body: TabBarView(
          children: [
            // Pestaña 1: Rutas Disponibles (tu código original)
            _buildAvailableRoutesTab(currentUserId),
            // Pestaña 2: Mi Historial (nuevo widget)
            _buildPassengerHistoryTab(currentUserId),
          ],
        ),
      ),
    );
  }

  // ✅ WIDGET EXTRAÍDO: Esta era tu antigua UI principal
  Widget _buildAvailableRoutesTab(String? currentUserId) {
    return Padding(
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
                    child: Text('No hay rutas publicadas en este momento.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                    final estadoRuta = data['estado'] as String? ?? 'pendiente';
                    final origen = (data['origen'] is Map) ? data['origen']['direccion'] as String? : (data['origen'] as String?);
                    final destino = (data['destino'] is Map) ? data['destino']['direccion'] as String? : (data['destino'] as String?);
                    final asientosDisponibles = (data['asientos_disponibles'] is int ? data['asientos_disponibles'] as int? : null) ?? 0;
                    final horaSalida = (data['hora_salida'] as Timestamp?)?.toDate();
                    final vehicleData = data['vehiculo'] as Map<String, dynamic>?;
                    final vehicleColor = vehicleData?['color'] as String? ?? 'No especificado';
                    final vehiclePlate = vehicleData?['placa'] as String? ?? 'No especificado';
                    final vehicleModel = vehicleData?['modelo'] as String? ?? 'No especificado';
                    final formattedTime = horaSalida != null ? DateFormat.jm().format(horaSalida) : 'Hora no definida';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('rutas').doc(rutaId).collection('reservas').where('pasajero_id', isEqualTo: currentUserId).snapshots(),
                        builder: (context, reservaSnapshot) {
                          bool hasReserved = reservaSnapshot.hasData && reservaSnapshot.data!.docs.isNotEmpty;
                          String? reservaId = hasReserved ? reservaSnapshot.data!.docs.first.id : null;
                          
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.directions_car, color: primaryColor, size: 40),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Origen: ${origen ?? 'No especificado'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Destino: ${destino ?? 'No especificado'}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                      const Divider(height: 10),
                                      Text('Vehículo: $vehicleColor, $vehicleModel', style: const TextStyle(fontSize: 14)),
                                      Text('Placa: $vehiclePlate', style: const TextStyle(fontSize: 14)),
                                      Text('Hora de salida: $formattedTime', style: const TextStyle(fontSize: 14, color: accentColor)),
                                      Text('Asientos disponibles: $asientosDisponibles', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                hasReserved
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (estadoRuta == 'finalizada')
                                            ...[
                                              ElevatedButton(
                                                onPressed: null,
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400),
                                                child: const Text('Ruta Completada', style: TextStyle(color: Colors.white)),
                                              ),
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: () {
                                                   if (idConductor != null) {
                                                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => RatingScreen(rutaId: rutaId, conductorId: idConductor)));
                                                  }
                                                },
                                                style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryColor), foregroundColor: primaryColor),
                                                child: const Text('Calificar'),
                                              ),
                                            ]
                                          else if (estadoRuta == 'en_curso')
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PassengerRouteTrackingScreen(rutaId: rutaId))),
                                              style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black),
                                              child: const Text('Ver Ruta en Vivo'),
                                            )
                                          else 
                                            ...[
                                              ElevatedButton(
                                                onPressed: null,
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400, foregroundColor: Colors.white),
                                                child: const Text('Reservado'),
                                              ),
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: () {
                                                  if (reservaId != null) _showCancellationConfirmationDialog(rutaId, reservaId);
                                                },
                                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                                                child: const Text('Cancelar'),
                                              ),
                                            ],
                                        ],
                                      )
                                    : ElevatedButton(
                                        onPressed: (asientosDisponibles == 0) ? null : () {
                                          if (currentUserId == null || idConductor == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Necesitas iniciar sesión para solicitar una ruta.')));
                                            return;
                                          }
                                          _showPickupInputDialog(rutaId, idConductor, asientosDisponibles);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                                        child: const Text('Solicitar'),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO WIDGET: PESTAÑA DE HISTORIAL DEL PASAJERO
  Widget _buildPassengerHistoryTab(String? currentUserId) {
    if (currentUserId == null) return const Center(child: Text('Inicia sesión para ver tu historial.'));

    return StreamBuilder<QuerySnapshot>(
      // 1. Usamos collectionGroup para buscar en todas las subcolecciones 'reservas'
      //    donde el pasajero_id sea el del usuario actual.
      stream: _firestore.collectionGroup('reservas').where('pasajero_id', isEqualTo: currentUserId).snapshots(),
      builder: (context, reservaSnapshot) {
        if (reservaSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!reservaSnapshot.hasData || reservaSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No has reservado ninguna ruta aún.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final reservas = reservaSnapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: reservas.length,
          itemBuilder: (context, index) {
            final reserva = reservas[index];
            // 2. Obtenemos la referencia al documento de la 'ruta' padre
            final rutaRef = reserva.reference.parent.parent;
            if (rutaRef == null) return const SizedBox.shrink();

            // 3. Para cada reserva, buscamos los detalles de la ruta
            return FutureBuilder<DocumentSnapshot>(
              future: rutaRef.get(),
              builder: (context, rutaSnapshot) {
                if (!rutaSnapshot.hasData || !rutaSnapshot.data!.exists) {
                  return const SizedBox.shrink(); // La ruta pudo haber sido eliminada
                }

                final rutaData = rutaSnapshot.data!.data() as Map<String, dynamic>;
                final origen = (rutaData['origen'] is Map) ? rutaData['origen']['direccion'] : 'No definido';
                final destino = (rutaData['destino'] is Map) ? rutaData['destino']['direccion'] : 'No definido';
                final estado = rutaData['estado'] ?? 'pendiente';
                final conductorId = rutaData['id_conductor'];
                final horaSalida = (rutaData['hora_salida'] as Timestamp?)?.toDate();
                final formattedDate = horaSalida != null ? DateFormat.yMMMd().format(horaSalida) : 'Fecha no definida';

                // 4. Buscamos el nombre del conductor
                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('usuarios').doc(conductorId).get(),
                  builder: (context, conductorSnapshot) {
                    String conductorNombre = 'Cargando...';
                    if (conductorSnapshot.hasData && conductorSnapshot.data!.exists) {
                      conductorNombre = (conductorSnapshot.data!.data() as Map<String, dynamic>)['nombre'] ?? 'Conductor Anónimo';
                    }

                    // 5. Mostramos la tarjeta final
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 3,
                      child: ListTile(
                        leading: Icon(
                          estado == 'finalizada' ? Icons.check_circle : (estado == 'en_curso' ? Icons.route : Icons.watch_later),
                          color: estado == 'finalizada' ? Colors.green : (estado == 'en_curso' ? accentColor : Colors.orange),
                        ),
                        title: Text('Desde: $origen', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Hacia: $destino\nConductor: $conductorNombre\nFecha: $formattedDate'),
                        isThreeLine: true,
                        // Opcional: El pasajero también puede calificar desde aquí
                        trailing: estado == 'finalizada'
                            ? TextButton(
                                child: const Text('Calificar'),
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => RatingScreen(rutaId: rutaRef.id, conductorId: conductorId),
                                  ));
                                },
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

