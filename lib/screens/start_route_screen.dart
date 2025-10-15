import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // Para obtener la ubicación en tiempo real
import 'dart:async';
import 'package:ruta_u/screens/chat_screen.dart'; // ¡IMPORTACIÓN AÑADIDA!

const primaryColor = Color(0xFF6200EE); 
const accentColor = Color(0xFF03DAC6); 

class StartRouteScreen extends StatefulWidget {
  final String rutaId;
  
  const StartRouteScreen({super.key, required this.rutaId});

  @override
  State<StartRouteScreen> createState() => _StartRouteScreenState();
}

class _StartRouteScreenState extends State<StartRouteScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  GoogleMapController? _mapController;
  LatLng? _currentDriverLocation;
  final Set<Marker> _markers = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isRouteActive = false; 

  @override
  void initState() {
    super.initState();
    _checkRouteStatus();
  }
  
  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // --- LÓGICA DE INICIO Y FINALIZACIÓN DE RUTA ---

  Future<void> _checkRouteStatus() async {
    try {
      final doc = await _firestore.collection('rutas').doc(widget.rutaId).get();
      final status = doc.data()?['estado'] as String?;
      
      if (status == 'en_curso') {
        setState(() {
          _isRouteActive = true;
        });
        _startLocationTracking();
      }
    } catch (e) {
      print('Error al verificar el estado de la ruta: $e');
    }
  }

  Future<void> _startRoute() async {
    setState(() => _isRouteActive = true);
    await _firestore.collection('rutas').doc(widget.rutaId).update({
      'estado': 'en_curso',
      'hora_inicio_real': FieldValue.serverTimestamp(),
    });
    _startLocationTracking();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta iniciada. Compartiendo ubicación en tiempo real.')),
      );
    }
  }

  Future<void> _finishRoute() async {
    _positionStreamSubscription?.cancel();
    setState(() => _isRouteActive = false);
    
    await _firestore.collection('rutas').doc(widget.rutaId).update({
      'estado': 'finalizada',
      'hora_fin_real': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta finalizada. Gracias por tu servicio.')),
      );
      Navigator.pop(context); 
    }
  }

  // --- LÓGICA DE GEOLOCALIZACIÓN ---

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('El servicio de ubicación está desactivado.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showError('Permisos de ubicación denegados.');
        return;
      }
    }
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position position) {
        final newLocation = LatLng(position.latitude, position.longitude);
        _currentDriverLocation = newLocation;
        _updateDriverMarker(newLocation);
        _updateLocationInFirestore(position);
        _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
      }, onError: (e) {
        _showError('Error de geolocalización: $e');
      });
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Tú (Conductor)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    });
  }

  void _updateLocationInFirestore(Position position) {
    final user = _auth.currentUser;
    if (user == null) return;
    
    _firestore.collection('rutas').doc(widget.rutaId).update({
      'conductor_ubicacion': {
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      }
    }).catchError((e) {
      print('Error al actualizar ubicación en Firestore: $e');
    });
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- WIDGETS DE PANTALLA ---

  void _setDestinationMarker(double lat, double lng) {
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(lat, lng),
        infoWindow: const InfoWindow(title: 'Destino: U. Central'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  // Widget para manejar el estado de las reservas (pasajeros)
  Widget _buildReservationsPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rutas').doc(widget.rutaId).collection('reservas').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Esperando reservas...', style: TextStyle(color: Colors.grey)));
        }

        final reservas = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Pasajeros (${reservas.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: reservas.length,
                itemBuilder: (context, index) {
                  final reservaDoc = reservas[index];
                  final data = reservaDoc.data() as Map<String, dynamic>;
                  final nombre = data['pasajero_nombre'] ?? 'Anónimo';
                  final recogida = data['punto_recogida'] ?? 'Sin dirección';
                  // ✅ CORRECCIÓN #1: LEER EL CAMPO CORRECTO
                  final recogido = data['estado_recogido'] ?? false;

                  return ListTile(
                    leading: recogido 
                        ? const Icon(Icons.check_circle, color: accentColor)
                        : const Icon(Icons.person_pin_circle, color: Colors.orange),
                    title: Text(nombre, style: TextStyle(decoration: recogido ? TextDecoration.lineThrough : null)),
                    subtitle: Text('Punto: $recogida'),
                    trailing: ElevatedButton(
                      onPressed: recogido ? null : () => _markPassengerPickedUp(reservaDoc.id, !recogido),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: recogido ? Colors.grey : primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(recogido ? 'Recogido' : 'Marcar Recogido'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markPassengerPickedUp(String reservaId, bool isPickedUp) async {
    try {
      // ✅ CORRECCIÓN #2: ACTUALIZAR EL CAMPO CORRECTO
      await _firestore
          .collection('rutas')
          .doc(widget.rutaId)
          .collection('reservas')
          .doc(reservaId)
          .update({'estado_recogido': isPickedUp});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasajero marcado como recogido.')),
      );
    } catch (e) {
      _showError('Error al actualizar reserva: $e');
    }
  }

  Widget _buildMapArea() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('rutas').doc(widget.rutaId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Ruta no encontrada.'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final origen = data['origen'] as Map<String, dynamic>?;
        
        final originLat = origen?['lat'] as double?;
        final originLng = origen?['lng'] as double?;
        
        const destinationLat = 4.6046; 
        const destinationLng = -74.0655;

        if (originLat != null && originLng != null) {
          _setDestinationMarker(destinationLat, destinationLng);
          
          _markers.removeWhere((m) => m.markerId.value == 'start_origin');
          _markers.add(
            Marker(
              markerId: const MarkerId('start_origin'),
              position: LatLng(originLat, originLng),
              infoWindow: InfoWindow(title: 'Origen de la Ruta', snippet: data['origen']['direccion']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        }

        final initialCameraPosition = (originLat != null && originLng != null) 
            ? CameraPosition(target: LatLng(originLat, originLng), zoom: 14.0)
            : const CameraPosition(target: LatLng(destinationLat, destinationLng), zoom: 14.0);

        return GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            if (_isRouteActive && _currentDriverLocation != null) {
              controller.animateCamera(CameraUpdate.newLatLng(_currentDriverLocation!));
            }
          },
          initialCameraPosition: initialCameraPosition,
          markers: _markers,
          myLocationEnabled: _isRouteActive,
          zoomControlsEnabled: true,
          mapType: MapType.normal,
        );
      },
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRouteActive ? 'Ruta en Curso' : 'Ruta Pendiente', style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.white),
            onPressed: () {
              final currentUserId = _auth.currentUser?.uid;
              if (currentUserId == null) {
                _showError('Error: Usuario no autenticado.');
                return;
              }
               Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(rutaId: widget.rutaId, userId: currentUserId),
                ),
              );
            },
          ),
          TextButton(
            onPressed: _isRouteActive ? _finishRoute : _startRoute,
            child: Text(
              _isRouteActive ? 'FINALIZAR RUTA' : 'INICIAR RUTA',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: _buildMapArea(),
            ),
          ),
          
          const Divider(height: 1, color: primaryColor),
          
          Expanded(
            flex: 2,
            child: _buildReservationsPanel(),
          ),
        ],
      ),
    );
  }
}