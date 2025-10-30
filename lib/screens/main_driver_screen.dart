import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:ruta_u/screens/main_passenger_screen.dart';
import 'package:ruta_u/screens/start_route_screen.dart';

// Definición de colores para consistencia
const primaryColor = Color(0xFF6200EE);
const accentColor = Color(0xFF03DAC6);

// ✅ NUEVO: Enum para controlar el modo de selección en el mapa
enum SelectionMode { origin, destination }

// Pantalla principal del conductor con tabs
class MainDriverScreen extends StatefulWidget {
  const MainDriverScreen({super.key});

  @override
  State<MainDriverScreen> createState() => _MainDriverScreenState();
}

class _MainDriverScreenState extends State<MainDriverScreen> {
  // --- VARIABLES Y ESTADO ---
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _originAddressController = TextEditingController();
  final _searchOriginController = TextEditingController(); // Renombrado para claridad
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _soatController = TextEditingController();
  final _tecnoController = TextEditingController();

  // ✅ NUEVOS CONTROLADORES PARA EL DESTINO
  final _destinationAddressController = TextEditingController();
  final _searchDestinationController = TextEditingController();

  bool _isLoading = false;
  int? _selectedSeats;
  TimeOfDay? _selectedTime;
  DateTime? _soatExpirationDate;
  DateTime? _tecnoExpirationDate;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng? _selectedOriginCoordinates;
  String? _selectedOriginAddress;

  // ✅ NUEVAS VARIABLES PARA EL DESTINO
  LatLng? _selectedDestinationCoordinates;
  String? _selectedDestinationAddress;

  // ✅ NUEVA VARIABLE DE ESTADO PARA EL MODO DE SELECCIÓN
  SelectionMode _selectionMode = SelectionMode.origin;

  // Coordenadas iniciales para centrar el mapa en Bogotá
  final LatLng _initialMapCenter = const LatLng(4.60971, -74.08175);

  @override
  void dispose() {
    _originAddressController.dispose();
    _searchOriginController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    _vehicleMakeController.dispose();
    _soatController.dispose();
    _tecnoController.dispose();
    _destinationAddressController.dispose();
    _searchDestinationController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // ✅ FUNCIÓN MODIFICADA: Ahora funciona para origen y destino según el modo
  void _onTapMap(LatLng tappedCoordinates) async {
    setState(() => _isLoading = true);
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(tappedCoordinates.latitude, tappedCoordinates.longitude);
      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        final formattedAddress = '${address.street}, ${address.locality}';

        setState(() {
          if (_selectionMode == SelectionMode.origin) {
            _selectedOriginCoordinates = tappedCoordinates;
            _originAddressController.text = formattedAddress;
            _selectedOriginAddress = formattedAddress;
            _markers.removeWhere((m) => m.markerId.value == 'origin');
            _markers.add(Marker(markerId: const MarkerId('origin'), position: tappedCoordinates, infoWindow: InfoWindow(title: 'Origen', snippet: formattedAddress), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
          } else {
            _selectedDestinationCoordinates = tappedCoordinates;
            _destinationAddressController.text = formattedAddress;
            _selectedDestinationAddress = formattedAddress;
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(Marker(markerId: const MarkerId('destination'), position: tappedCoordinates, infoWindow: InfoWindow(title: 'Destino', snippet: formattedAddress), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener la dirección: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ FUNCIÓN MODIFICADA: Busca dirección para origen o destino
  Future<void> _searchAddress(bool isOrigin) async {
    final searchController = isOrigin ? _searchOriginController : _searchDestinationController;
    if (searchController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newCoordinates = LatLng(location.latitude, location.longitude);
        
        setState(() {
          if (isOrigin) {
            _selectedOriginCoordinates = newCoordinates;
            _selectedOriginAddress = searchController.text;
            _originAddressController.text = searchController.text;
            _markers.removeWhere((m) => m.markerId.value == 'origin');
            _markers.add(Marker(markerId: const MarkerId('origin'), position: newCoordinates, infoWindow: InfoWindow(title: 'Origen', snippet: searchController.text), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
          } else {
            _selectedDestinationCoordinates = newCoordinates;
            _selectedDestinationAddress = searchController.text;
            _destinationAddressController.text = searchController.text;
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(Marker(markerId: const MarkerId('destination'), position: newCoordinates, infoWindow: InfoWindow(title: 'Destino', snippet: searchController.text), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)));
          }
        });
        
        _mapController?.animateCamera(CameraUpdate.newLatLng(newCoordinates));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar la dirección.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al buscar la dirección: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? newTime = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (newTime != null) setState(() => _selectedTime = newTime);
  }

  Future<void> _selectDate(BuildContext context, {required bool isSoat}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: isSoat ? 'Vigencia del SOAT' : 'Vigencia Tecnomecánica',
    );
    if (picked != null) {
      setState(() {
        if (isSoat) {
          _soatExpirationDate = picked;
          _soatController.text = DateFormat.yMMMd().format(picked);
        } else {
          _tecnoExpirationDate = picked;
          _tecnoController.text = DateFormat.yMMMd().format(picked);
        }
      });
    }
  }

  // ✅ FUNCIÓN MODIFICADA PARA VALIDAR Y GUARDAR AMBOS PUNTOS
  Future<void> _publishRoute() async {
    final user = _auth.currentUser;
    // Validación actualizada para origen y destino
    if (_selectedOriginCoordinates == null || _selectedDestinationCoordinates == null || _selectedSeats == null || _selectedSeats! <= 0 || user == null || _selectedTime == null || _vehicleColorController.text.isEmpty || _vehiclePlateController.text.isEmpty || _vehicleModelController.text.isEmpty || _vehicleMakeController.text.isEmpty || _soatExpirationDate == null || _tecnoExpirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos, incluyendo origen y destino.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final routeTime = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);
      await _firestore.collection('rutas').add({
        'id_conductor': user.uid,
        'origen': {'direccion': _selectedOriginAddress, 'lat': _selectedOriginCoordinates!.latitude, 'lng': _selectedOriginCoordinates!.longitude},
        'destino': {'direccion': _selectedDestinationAddress, 'lat': _selectedDestinationCoordinates!.latitude, 'lng': _selectedDestinationCoordinates!.longitude},
        'asientos_disponibles': _selectedSeats,
        'hora_salida': routeTime,
        'creado': FieldValue.serverTimestamp(),
        'vehiculo': {
          'color': _vehicleColorController.text, 'placa': _vehiclePlateController.text, 'modelo': _vehicleModelController.text,
          'marca': _vehicleMakeController.text, 'soat_vigencia': _soatExpirationDate, 'tecno_vigencia': _tecnoExpirationDate,
        },
        'estado': 'activa',
      });
      setState(() {
        _selectedSeats = null; _selectedTime = null;
        _selectedOriginCoordinates = null; _selectedOriginAddress = null;
        _selectedDestinationCoordinates = null; _selectedDestinationAddress = null;
        _originAddressController.clear(); _searchOriginController.clear();
        _destinationAddressController.clear(); _searchDestinationController.clear();
        _vehicleColorController.clear(); _vehiclePlateController.clear(); _vehicleModelController.clear();
        _vehicleMakeController.clear(); _soatController.clear(); _tecnoController.clear();
        _soatExpirationDate = null; _tecnoExpirationDate = null;
        _markers.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Ruta publicada con éxito.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar la ruta: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // (El resto de funciones como _deleteRoute, _showUserProfile, etc., no necesitan cambios)
  Future<void> _deleteRoute(String routeId) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar Eliminación'), content: const Text('¿Estás seguro de que deseas eliminar esta ruta?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) {
      try {
        await _firestore.collection('rutas').doc(routeId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta eliminada con éxito.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar la ruta: ${e.toString()}')));
      }
    }
  }

  void _showUserProfile() {
    final user = _auth.currentUser;
    if (user != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => _buildUserProfileScreen(user.uid)));
    }
  }

  Widget _buildUserProfileScreen(String userId) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)), backgroundColor: primaryColor),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('usuarios').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userRoles = (userData['rol'] as List<dynamic>?)?.cast<String>() ?? [];
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Center(child: Icon(Icons.person_pin, size: 100, color: primaryColor)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildProfileInfoRow(Icons.person_outline, 'Nombre', userData['nombre'] ?? ''),
                        const Divider(),
                        _buildProfileInfoRow(Icons.email_outlined, 'Email', userData['email'] ?? ''),
                        const Divider(),
                        _buildProfileInfoRow(Icons.badge, 'ID de Usuario', userId),
                      ],
                    ),
                  ),
                ),
                if (userRoles.contains('pasajero')) ...[
                  const SizedBox(height: 24),
                  Center(child: ElevatedButton.icon(icon: const Icon(Icons.swap_horiz, color: Colors.white), label: const Text('Cambiar a Pasajero', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainPassengerScreen())), style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Icon(icon, color: accentColor), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16))]))]));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ruta U - Conductor', style: TextStyle(color: Colors.white)),
          backgroundColor: primaryColor,
          actions: [
            IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: _showUserProfile),
            IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async { await _auth.signOut(); if (mounted) Navigator.pushReplacementNamed(context, '/'); }),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_road, color: Colors.white), text: 'Publicar'),
              Tab(icon: Icon(Icons.list_alt, color: Colors.white), text: 'Activas'),
              Tab(icon: Icon(Icons.history, color: Colors.white), text: 'Historial'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildPublishRouteTab(),
            _buildDriverActiveRoutesTab(),
            _buildHistoryAndRatingsTab(),
          ],
        ),
      ),
    );
  }

  // ✅ WIDGET COMPLETAMENTE REESTRUCTURADO PARA ORIGEN Y DESTINO
  Widget _buildPublishRouteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text('Publicar una Nueva Ruta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor))),
              const SizedBox(height: 24),
              const Text('Información del Viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              
              // Selector de modo
              SegmentedButton<SelectionMode>(
                segments: const <ButtonSegment<SelectionMode>>[
                  ButtonSegment<SelectionMode>(value: SelectionMode.origin, label: Text('Origen'), icon: Icon(Icons.my_location)),
                  ButtonSegment<SelectionMode>(value: SelectionMode.destination, label: Text('Destino'), icon: Icon(Icons.flag)),
                ],
                selected: <SelectionMode>{_selectionMode},
                onSelectionChanged: (Set<SelectionMode> newSelection) {
                  setState(() => _selectionMode = newSelection.first);
                },
              ),
              const SizedBox(height: 16),
              
              // Búsqueda de Origen
              TextField(controller: _searchOriginController, decoration: InputDecoration(labelText: 'Buscar origen', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () => _searchAddress(true)))),
              const SizedBox(height: 8),
              // Búsqueda de Destino
              TextField(controller: _searchDestinationController, decoration: InputDecoration(labelText: 'Buscar destino', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () => _searchAddress(false)))),
              
              const SizedBox(height: 16),
              Text('Toca el mapa para seleccionar ${_selectionMode == SelectionMode.origin ? 'el origen' : 'el destino'}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              SizedBox(height: 250, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: GoogleMap(onMapCreated: _onMapCreated, initialCameraPosition: CameraPosition(target: _initialMapCenter, zoom: 12.0), markers: _markers, onTap: _onTapMap))),
              const SizedBox(height: 16),
              
              TextField(controller: _originAddressController, enabled: false, decoration: const InputDecoration(labelText: 'Origen seleccionado', prefixIcon: Icon(Icons.location_on))),
              const SizedBox(height: 16),
              TextField(controller: _destinationAddressController, enabled: false, decoration: const InputDecoration(labelText: 'Destino seleccionado', prefixIcon: Icon(Icons.flag))),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<int>(value: _selectedSeats, decoration: const InputDecoration(labelText: 'Asientos', border: OutlineInputBorder()), items: List.generate(6, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))), onChanged: (val) => setState(() => _selectedSeats = val))),
                  const SizedBox(width: 16),
                  Expanded(child: InkWell(onTap: _selectTime, child: InputDecorator(decoration: const InputDecoration(labelText: 'Hora', border: OutlineInputBorder()), child: Text(_selectedTime != null ? _selectedTime!.format(context) : 'Seleccionar')))),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Información del Vehículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              TextField(controller: _vehicleMakeController, decoration: const InputDecoration(labelText: 'Marca', prefixIcon: Icon(Icons.car_rental))),
              const SizedBox(height: 16),
              TextField(controller: _vehicleModelController, decoration: const InputDecoration(labelText: 'Modelo', prefixIcon: Icon(Icons.car_repair))),
              const SizedBox(height: 16),
              TextField(controller: _vehicleColorController, decoration: const InputDecoration(labelText: 'Color', prefixIcon: Icon(Icons.palette))),
              const SizedBox(height: 16),
              TextField(controller: _vehiclePlateController, decoration: const InputDecoration(labelText: 'Placa', prefixIcon: Icon(Icons.badge))),
              const SizedBox(height: 16),
              TextField(controller: _soatController, readOnly: true, decoration: const InputDecoration(labelText: 'Vigencia SOAT', prefixIcon: Icon(Icons.security), suffixIcon: Icon(Icons.calendar_today)), onTap: () => _selectDate(context, isSoat: true)),
              const SizedBox(height: 16),
              TextField(controller: _tecnoController, readOnly: true, decoration: const InputDecoration(labelText: 'Vigencia Tecnomecánica', prefixIcon: Icon(Icons.construction), suffixIcon: Icon(Icons.calendar_today)), onTap: () => _selectDate(context, isSoat: false)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishRoute,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.publish, color: Colors.white),
                label: Text(_isLoading ? 'Publicando...' : 'Publicar Ruta', style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 15), minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Las pestañas de Rutas Activas e Historial no necesitan cambios
  Widget _buildDriverActiveRoutesTab() {
     final user = _auth.currentUser;
    if (user == null) return const Center(child: Text('Inicia sesión para ver tus rutas.'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rutas').where('id_conductor', isEqualTo: user.uid).where('estado', whereIn: ['activa', 'en_curso']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No tienes rutas activas.'));
        
        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final horaSalida = (data['hora_salida'] as Timestamp).toDate();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ExpansionTile(
                    leading: Icon(data['estado'] == 'en_curso' ? Icons.route : Icons.watch_later_outlined, color: primaryColor),
                    title: Text((data['origen'] is Map ? data['origen']['direccion'] : data['origen']) ?? 'Origen desconocido', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Estado: ${data['estado']}\nHora: ${DateFormat.jm().format(horaSalida)}'),
                    children: [_buildReservationsList(doc.id)],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => StartRouteScreen(rutaId: doc.id))),
                          icon: const Icon(Icons.navigation, color: Colors.white),
                          label: Text(data['estado'] == 'en_curso' ? 'Ver Ruta' : 'Iniciar', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                        ),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRoute(doc.id)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryAndRatingsTab() {
       final user = _auth.currentUser;
    if (user == null) return const Center(child: Text('Inicia sesión para ver tu historial.'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu Calificación General', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('calificaciones').where('conductor_id', isEqualTo: user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Card(child: ListTile(leading: Icon(Icons.star_border), title: Text('Aún no has recibido calificaciones.')));
              }
              
              final ratings = snapshot.data!.docs;
              double totalRating = 0;
              ratings.forEach((doc) => totalRating += (doc.data() as Map<String, dynamic>)['calificacion'] ?? 0);
              final averageRating = totalRating / ratings.length;

              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Promedio', style: TextStyle(color: Colors.grey.shade600)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: primaryColor)),
                          const SizedBox(width: 8),
                          _buildStarRatingDisplay(averageRating),
                        ],
                      ),
                      Text('Basado en ${ratings.length} calificación(es)'),
                      const Divider(height: 32),
                      const Text('Comentarios Recientes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...ratings.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['comentario'] != null && (data['comentario'] as String).trim().isNotEmpty;
                      }).take(3).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.comment, color: accentColor),
                          title: Text('"${data['comentario']}"'),
                          dense: true,
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Rutas Pasadas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('rutas').where('id_conductor', isEqualTo: user.uid).where('estado', isEqualTo: 'finalizada').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No tienes rutas completadas.'));
              
              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final origen = (data['origen'] is Map) ? data['origen']['direccion'] : 'Origen desconocido';
                  final hora = (data['hora_salida'] as Timestamp).toDate();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: Text('Desde: $origen'),
                      subtitle: Text('Fecha: ${DateFormat.yMMMd().format(hora)}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStarRatingDisplay(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _buildReservationsList(String rutaId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rutas').doc(rutaId).collection('reservas').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No hay reservas para esta ruta.'));

        return Column(
          children: snapshot.data!.docs.map((reservaDoc) {
            final reserva = reservaDoc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.person, color: accentColor),
              title: Text(reserva['pasajero_nombre'] ?? 'Nombre no disponible'),
              subtitle: Text('Recogida: ${reserva['punto_recogida'] ?? 'No definido'}'),
              dense: true,
            );
          }).toList(),
        );
      },
    );
  }
}

