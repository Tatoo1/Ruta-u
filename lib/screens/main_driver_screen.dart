import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:ruta_u/screens/main_passenger_screen.dart'; // Importamos la pantalla de pasajero
import 'package:ruta_u/screens/start_route_screen.dart'; // ¡Añadido! Pantalla de ruta activa
import 'package:ruta_u/main.dart'; 

// Definición de colores para consistencia
const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

// Pantalla principal del conductor con tabs
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
  // Controladores para los datos del vehículo
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  bool _isLoading = false;
  int? _selectedSeats;
  TimeOfDay? _selectedTime;
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  LatLng? _selectedOriginCoordinates;
  String? _selectedOriginAddress;
  final LatLng _destinationCoordinates = const LatLng(4.6046, -74.0655); // Coordenadas de la UC (Bogotá)

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
  }

  @override
  void dispose() {
    _originAddressController.dispose();
    _searchController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
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
      // 1. Convertir coordenadas a dirección de texto
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(tappedCoordinates.latitude, tappedCoordinates.longitude);
      
      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        final formattedAddress = '${address.street}, ${address.locality}, ${address.country}';

        setState(() {
          _selectedOriginCoordinates = tappedCoordinates;
          _originAddressController.text = formattedAddress;
          _selectedOriginAddress = formattedAddress;
          
          // 2. Actualizar marcador en el mapa
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
      // 1. Convertir dirección de texto a coordenadas
      List<geocoding.Location> locations = await geocoding.locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final LatLng newOrigin = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _selectedOriginCoordinates = newOrigin;
          _selectedOriginAddress = _searchController.text;
          
          // 2. Actualizar marcador y centrar mapa
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

    // Validar que los campos del vehículo no estén vacíos
    if (_vehicleColorController.text.isEmpty || _vehiclePlateController.text.isEmpty || _vehicleModelController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los detalles del vehículo.')),
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
        'vehiculo': {
          'color': _vehicleColorController.text,
          'placa': _vehiclePlateController.text,
          'modelo': _vehicleModelController.text,
        },
        'estado': 'activa', // Estado inicial de la ruta
      });

      setState(() {
        _selectedSeats = null;
        _selectedTime = null;
        _selectedOriginCoordinates = null;
        _selectedOriginAddress = null;
        _originAddressController.clear();
        _searchController.clear();
        // Limpiar también los datos del vehículo después de publicar
        _vehicleColorController.clear();
        _vehiclePlateController.clear();
        _vehicleModelController.clear();
        _markers.removeWhere((marker) => marker.markerId.value == 'origin');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ruta publicada con éxito.')),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar la ruta: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Nuevo método para borrar una ruta
  Future<void> _deleteRoute(String routeId) async {
    // Diálogo de confirmación antes de borrar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar esta ruta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // También se deberían eliminar las subcolecciones de reservas y mensajes si existen
        await _firestore.collection('rutas').doc(routeId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta eliminada con éxito.')),
        );
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la ruta: ${e.message}')),
        );
      }
    }
  }

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
          // Se asume que 'rol' es un campo de tipo List<String> en Firestore
          final userRoles = (userData['rol'] as List<dynamic>?)?.cast<String>() ?? ['No disponible'];

          final hasPasajeroRole = userRoles.contains('pasajero');

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.person_pin, size: 100, color: primaryColor),
                ),
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
                        _buildProfileInfoRow(Icons.account_box, 'Roles', userRoles.join(', ')),
                        const Divider(),
                        _buildProfileInfoRow(Icons.badge, 'ID de Usuario', userId),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Botón para conmutar a la vista de pasajero
                if (hasPasajeroRole)
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text('Cambiar a Pasajero', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        // Navega a la pantalla principal del pasajero
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const MainPassengerScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ruta U - Conductor', style: TextStyle(color: Colors.white)),
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_road, color: Colors.white), text: 'Publicar Ruta'),
              Tab(icon: Icon(Icons.list_alt, color: Colors.white), text: 'Mis Rutas'),
            ],
            indicatorColor: accentColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildPublishRouteTab(),
            _buildDriverRoutesListTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishRouteTab() {
    return SingleChildScrollView(
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
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  // Mapa interactivo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: SizedBox(
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
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _originAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Origen Seleccionado',
                      enabled: false,
                      prefixIcon: Icon(Icons.location_on, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Destino: Universidad Central',
                      enabled: false,
                      prefixIcon: Icon(Icons.pin_drop, color: accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Datos del vehículo
                  TextFormField(
                    controller: _vehicleColorController,
                    decoration: const InputDecoration(
                      labelText: 'Color del vehículo',
                      prefixIcon: Icon(Icons.palette, color: accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehiclePlateController,
                    decoration: const InputDecoration(
                      labelText: 'Placa del vehículo',
                      prefixIcon: Icon(Icons.badge, color: accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleModelController,
                    decoration: const InputDecoration(
                      labelText: 'Modelo del vehículo',
                      prefixIcon: Icon(Icons.directions_car, color: accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Asientos y Hora
                  DropdownButtonFormField<int>(
                    value: _selectedSeats,
                    decoration: const InputDecoration(
                      labelText: 'Asientos Disponibles',
                      prefixIcon: Icon(Icons.event_seat, color: accentColor),
                      border: OutlineInputBorder(),
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
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: _selectTime,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _publishRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
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
    );
  }

  Widget _buildDriverRoutesListTab() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tus rutas.', style: TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Tus Rutas Publicadas y Reservas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('rutas').where('id_conductor', isEqualTo: user.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No has publicado ninguna ruta aún.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }
              final rutas = snapshot.data!.docs;
              final now = DateTime.now();
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rutas.length,
                itemBuilder: (context, index) {
                  final ruta = rutas[index];
                  final data = ruta.data() as Map<String, dynamic>;
                  final rutaId = ruta.id;
                  
                  final origen = (data['origen'] is Map) ? data['origen']['direccion'] as String? : (data['origen'] as String?);
                  final destino = data['destino'] is String ? data['destino'] as String? : null;
                  final horaSalida = (data['hora_salida'] as Timestamp?)?.toDate();
                  final formattedTime = horaSalida != null ? DateFormat.jm().format(horaSalida) : 'Hora no definida';

                  // Lógica para habilitar el botón:
                  // Permitir iniciar la ruta si faltan 30 minutos o menos para la hora de salida
                  // y la ruta no ha pasado hace más de 1 hora (para rutas olvidadas)
                  final bool canStartRoute = horaSalida != null && 
                      horaSalida.difference(now).inMinutes <= 30 && 
                      horaSalida.isAfter(now.subtract(const Duration(hours: 1)));
                  final String buttonText = canStartRoute ? 'Iniciar Ruta' : 'Ruta Pendiente';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 4,
                    child: Column(
                      children: [
                        ExpansionTile(
                          title: Text(
                            'Ruta: ${origen ?? 'No especificado'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Destino: ${destino ?? 'No especificado'}\nHora: $formattedTime'),
                          children: [
                            _buildReservationsList(rutaId),
                          ],
                        ),
                        // Fila de acciones (Iniciar Ruta y Eliminar)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Botón "Iniciar Ruta"
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: canStartRoute ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => StartRouteScreen(rutaId: rutaId),
                                      ),
                                    );
                                  } : null, // Deshabilitar si no es el momento
                                  icon: const Icon(Icons.navigation, color: Colors.white),
                                  label: Text(buttonText, style: const TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canStartRoute ? accentColor : Colors.grey,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Botón "Eliminar"
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRoute(rutaId),
                                  tooltip: 'Eliminar Ruta',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList(String rutaId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rutas').doc(rutaId).collection('reservas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No hay reservas para esta ruta.'),
          );
        }

        final reservas = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
              child: Text(
                'Pasajeros (${reservas.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
            ...reservas.map((reservaDoc) {
              final reserva = reservaDoc.data() as Map<String, dynamic>;
              final pasajeroNombre = reserva['pasajero_nombre'] ?? 'Nombre no disponible';
              final puntoRecogida = reserva['punto_recogida'] ?? 'Punto de recogida no definido';

              return ListTile(
                leading: const Icon(Icons.person, color: accentColor),
                title: Text(pasajeroNombre),
                subtitle: Text('Recogida: $puntoRecogida'),
                dense: true,
              );
            }).toList(),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}
