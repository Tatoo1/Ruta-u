import 'package:flutter/material.dart';
import 'package:ruta_u/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:async';

// Pantalla principal del conductor
class MainDriverScreen extends StatefulWidget {
  const MainDriverScreen({super.key});

  @override
  State<MainDriverScreen> createState() => _MainDriverScreenState();
}

class _MainDriverScreenState extends State<MainDriverScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _originAddressController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = false;
  int? _selectedSeats;
  TimeOfDay? _selectedTime;
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  LatLng? _selectedOriginCoordinates;
  String? _selectedOriginAddress;
  final LatLng _destinationCoordinates = const LatLng(4.6046, -74.0655);

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
  }

  @override
  void dispose() {
    _originAddressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setInitialMarkers() {
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationCoordinates,
        infoWindow: const InfoWindow(title: 'Universidad Central'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTapMap(LatLng tappedCoordinates) async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(tappedCoordinates.latitude, tappedCoordinates.longitude);
      
      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        final formattedAddress = '${address.street}, ${address.locality}, ${address.country}';

        setState(() {
          _selectedOriginCoordinates = tappedCoordinates;
          _originAddressController.text = formattedAddress;
          _selectedOriginAddress = formattedAddress;
          
          _markers.removeWhere((marker) => marker.markerId.value == 'origin');
          _markers.add(
            Marker(
              markerId: const MarkerId('origin'),
              position: tappedCoordinates,
              infoWindow: InfoWindow(title: 'Origen', snippet: formattedAddress),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener la dirección: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchAddress() async {
    if (_searchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una dirección para buscar.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final LatLng newOrigin = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _selectedOriginCoordinates = newOrigin;
          _selectedOriginAddress = _searchController.text;
          _markers.removeWhere((marker) => marker.markerId.value == 'origin');
          _markers.add(
            Marker(
              markerId: const MarkerId('origin'),
              position: newOrigin,
              infoWindow: InfoWindow(title: 'Origen', snippet: _searchController.text),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        });
        
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newOrigin),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo encontrar la dirección.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar la dirección: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (newTime != null) {
      setState(() {
        _selectedTime = newTime;
      });
    }
  }

  Future<void> _publishRoute() async {
    final user = _auth.currentUser;

    if (_selectedOriginCoordinates == null || _selectedSeats == null || _selectedSeats! <= 0 || user == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona el origen, la hora y el número de asientos.')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Combina la fecha actual con la hora seleccionada
      final now = DateTime.now();
      final routeTime = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);

      await _firestore.collection('rutas').add({
        'id_conductor': user.uid,
        'origen': {
          'direccion': _selectedOriginAddress,
          'lat': _selectedOriginCoordinates!.latitude,
          'lng': _selectedOriginCoordinates!.longitude,
        },
        'destino': 'Universidad Central',
        'asientos_disponibles': _selectedSeats,
        'hora_salida': routeTime,
        'creado': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedSeats = null;
        _selectedTime = null;
        _selectedOriginCoordinates = null;
        _selectedOriginAddress = null;
        _originAddressController.clear();
        _searchController.clear();
        _markers.removeWhere((marker) => marker.markerId.value == 'origin');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ruta publicada con éxito.')),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar la ruta: ${e.message}')),
      );
      print('Error de Firestore: ${e.code} - ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta U - Conductor', style: TextStyle(color: Colors.white)),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.drive_eta, size: 100, color: primaryColor),
              const SizedBox(height: 24),
              const Text(
                '¡Ofrece un viaje!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'Buscar dirección de origen',
                                prefixIcon: Icon(Icons.search, color: accentColor),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAddress,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            GoogleMap(
                              onMapCreated: _onMapCreated,
                              initialCameraPosition: CameraPosition(
                                target: _destinationCoordinates,
                                zoom: 14.0,
                              ),
                              markers: _markers,
                              onTap: _onTapMap,
                            ),
                            if (_isLoading)
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Destino: Universidad Central',
                          hintText: 'Universidad Central',
                          enabled: false,
                          prefixIcon: Icon(Icons.pin_drop, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedSeats,
                        decoration: const InputDecoration(
                          labelText: 'Asientos Disponibles',
                          prefixIcon: Icon(Icons.event_seat, color: accentColor),
                        ),
                        items: List.generate(4, (index) {
                          final value = index + 1;
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value'),
                          );
                        }),
                        onChanged: (int? newValue) {
                          setState(() {
                            _selectedSeats = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.access_time, color: accentColor),
                        title: Text(
                          _selectedTime != null
                              ? 'Hora de salida: ${_selectedTime!.format(context)}'
                              : 'Seleccionar hora de salida',
                        ),
                        onTap: _selectTime,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _publishRoute,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Publicar Ruta',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
