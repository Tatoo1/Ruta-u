import 'package:flutter/material.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

// Pantalla principal del conductor
class MainDriverScreen extends StatelessWidget {
  const MainDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta U - Conductor'),
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
              const Icon(Icons.drive_eta, size: 100, color: primaryColor),
              const SizedBox(height: 24),
              const Text(
                '¡Ofrece un viaje!',
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
                      const SizedBox(height: 16),
                      const TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Asientos Disponibles',
                          prefixIcon: Icon(Icons.event_seat, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implementar lógica para publicar la ruta en Firebase.
                        },
                        child: const Text(
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