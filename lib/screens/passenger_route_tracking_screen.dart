// Archivo completo: screens/passenger_route_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ruta_u/screens/chat_screen.dart';
import 'package:ruta_u/screens/rating_screen.dart'; // ✅ IMPORTACIÓN AÑADIDA

const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

class PassengerRouteTrackingScreen extends StatefulWidget {
  final String rutaId;

  const PassengerRouteTrackingScreen({super.key, required this.rutaId});

  @override
  State<PassengerRouteTrackingScreen> createState() =>
      _PassengerRouteTrackingScreenState();
}

class _PassengerRouteTrackingScreenState
    extends State<PassengerRouteTrackingScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siguiendo la Ruta', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.white),
            onPressed: () {
              if (currentUserId == null) {
                _showError('Debes iniciar sesión para usar el chat.');
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ChatScreen(
                  rutaId: widget.rutaId,
                  userId: currentUserId,
                ),
              ));
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('rutas').doc(widget.rutaId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Si la ruta ya no existe, regresa a la pantalla anterior.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const Center(child: Text('La ruta ha concluido.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // ✅ INICIO DE LA LÓGICA DE NAVEGACIÓN
          final estadoRuta = data['estado'] as String?;
          final conductorId = data['id_conductor'] as String?;

          if (estadoRuta == 'finalizada' && conductorId != null) {
            // Usamos este callback para navegar de forma segura después de que el widget se construya.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => RatingScreen(
                      rutaId: widget.rutaId,
                      conductorId: conductorId,
                    ),
                  ),
                );
              }
            });
            // Muestra un mensaje mientras se realiza la redirección.
            return const Center(child: Text('La ruta ha finalizado. Redirigiendo a la calificación...'));
          }
          // ✅ FIN DE LA LÓGICA DE NAVEGACIÓN

          final Set<Marker> currentMarkers = {};
          LatLng? driverLocation;

          // Obtener ubicación del conductor
          final driverLocationData = data['conductor_ubicacion'] as Map<String, dynamic>?;
          if (driverLocationData != null) {
            driverLocation = LatLng(
              driverLocationData['lat'] as double,
              driverLocationData['lng'] as double,
            );
            currentMarkers.add(Marker(
              markerId: const MarkerId('driver'),
              position: driverLocation,
              infoWindow: const InfoWindow(title: 'Conductor', snippet: 'Ubicación actual del conductor'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ));
          }

          // Obtener marcador de origen
          if (data['origen'] is Map<String, dynamic>) {
            final origenData = data['origen'] as Map<String, dynamic>;
            currentMarkers.add(Marker(
              markerId: const MarkerId('origen'),
              position: LatLng(origenData['lat'], origenData['lng']),
              infoWindow: InfoWindow(title: 'Origen', snippet: origenData['direccion']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ));
          }

          // Obtener marcador de destino
          if (data['destino'] is Map<String, dynamic>) {
            final destinoData = data['destino'] as Map<String, dynamic>;
            currentMarkers.add(Marker(
              markerId: const MarkerId('destino'),
              position: LatLng(destinoData['lat'], destinoData['lng']),
              infoWindow: InfoWindow(title: 'Destino', snippet: destinoData['direccion']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ));
          }

          return GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (driverLocation != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(driverLocation, 15.0));
              }
            },
            initialCameraPosition: CameraPosition(
              target: driverLocation ?? const LatLng(4.60971, -74.08175), // Ubicación por defecto Bogotá
              zoom: 14.0,
            ),
            markers: currentMarkers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}