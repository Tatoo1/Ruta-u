import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruta_u/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class MainPassengerScreen extends StatefulWidget {
  const MainPassengerScreen({super.key});

  @override
  State<MainPassengerScreen> createState() => _MainPassengerScreenState();
}

class _MainPassengerScreenState extends State<MainPassengerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _originController = TextEditingController();
  final _searchController = TextEditingController();
  
  // Nuevo estado para la hora seleccionada
  TimeOfDay? _selectedTime;

  bool _isLoading = false;
  List<DocumentSnapshot> _availableRoutes = [];

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
    _originController.dispose();
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
          _originController.text = formattedAddress;
          _selectedOriginAddress = formattedAddress;
          _searchController.text = formattedAddress;
          
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
        
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(tappedCoordinates),
        );
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

  // Función para mostrar el selector de hora
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (newTime != null) {
      setState(() {
        _selectedTime = newTime;
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
          _originController.text = _searchController.text;
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

  Future<void> _searchRoutes() async {
    setState(() {
      _isLoading = true;
      _availableRoutes = [];
    });

    try {
      // Modificamos la consulta para que no use múltiples rangos
      Query query = _firestore
          .collection('rutas')
          .where('asientos_disponibles', isGreaterThan: 0)
          .where('origen.direccion', isGreaterThanOrEqualTo: _originController.text)
          .where('origen.direccion', isLessThan: _originController.text + 'z')
          .orderBy('origen.direccion')
          .orderBy('asientos_disponibles', descending: true);
      
      final querySnapshot = await query.get();

      // Filtramos los resultados localmente por la hora
      if (_selectedTime != null) {
        final now = DateTime.now();
        final selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final startRange = selectedDateTime.subtract(const Duration(minutes: 15));
        final endRange = selectedDateTime.add(const Duration(minutes: 15));

        final filteredRoutes = querySnapshot.docs.where((doc) {
          final horaSalida = (doc.data() as Map<String, dynamic>)['hora_salida'] as Timestamp?;
          if (horaSalida == null) return false;
          final departureTime = horaSalida.toDate();
          return departureTime.isAfter(startRange) && departureTime.isBefore(endRange);
        }).toList();

        setState(() {
          _availableRoutes = filteredRoutes;
        });
      } else {
        // Si no hay hora seleccionada, mostramos todos los resultados del filtro de origen
        setState(() {
          _availableRoutes = querySnapshot.docs;
        });
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar rutas: ${e.message}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.map, size: 100, color: primaryColor),
              const SizedBox(height: 24),
              const Text(
                '¡Encuentra tu próximo viaje!',
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
                      // Campo para la selección de hora con mejor visualización
                      ListTile(
                        leading: const Icon(Icons.access_time, color: accentColor),
                        title: Text(
                          _selectedTime != null
                              ? 'Hora de salida: ${_selectedTime!.format(context)}'
                              : 'Seleccionar hora de salida',
                          style: const TextStyle(fontSize: 16),
                        ),
                        onTap: () => _selectTime(context),
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        // El botón se deshabilita si no se ha seleccionado origen ni hora
                        onPressed: _isLoading || _originController.text.isEmpty || _selectedTime == null ? null : _searchRoutes,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Buscar Viaje',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Aquí se muestran los resultados de la búsqueda
              if (!_isLoading && _availableRoutes.isEmpty)
                const Text(
                  'No se encontraron rutas para tu búsqueda. Intenta con una dirección u hora diferente.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              if (_availableRoutes.isNotEmpty)
                const Text(
                  'Rutas disponibles:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              ..._availableRoutes.map((ruta) {
                final rutaData = ruta.data() as Map<String, dynamic>;
                final origen = rutaData['origen']['direccion'] as String;
                final horaSalida = (rutaData['hora_salida'] as Timestamp?)?.toDate();
                final asientosDisponibles = rutaData['asientos_disponibles'] as int;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.drive_eta, color: primaryColor),
                    title: Text(
                      'Origen: $origen',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Salida: ${horaSalida != null ? TimeOfDay.fromDateTime(horaSalida).format(context) : 'No definida'} - Asientos: $asientosDisponibles',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implementar la lógica para reservar el puesto
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funcionalidad de reserva por implementar.')),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
