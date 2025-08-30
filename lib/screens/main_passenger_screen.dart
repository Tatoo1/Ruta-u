import 'package:flutter/material.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

// Pantalla principal del pasajero
class MainPassengerScreen extends StatelessWidget {
  const MainPassengerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta U - Pasajero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Añadir lógica de cierre de sesión de Firebase aquí.
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.map, size: 100, color: primaryColor),
              const SizedBox(height: 24),
              const Text(
                '¡Encuentra tu próximo viaje!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Origen',
                          prefixIcon: Icon(Icons.my_location, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Destino',
                          prefixIcon: Icon(Icons.pin_drop, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implementar lógica de búsqueda de rutas de Firebase.
                          // Se debe mostrar un listado de rutas disponibles.
                        },
                        child: const Text(
                          'Buscar Viaje',
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