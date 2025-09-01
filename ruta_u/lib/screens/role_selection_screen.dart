import 'package:flutter/material.dart';
import 'package:ruta_u/main.dart'; // Importa el archivo principal para acceder a las constantes de color

// Pantalla para que el usuario seleccione su rol
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu Rol'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                '¿Cómo quieres usar Ruta U?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              RoleCard(
                icon: Icons.directions_car,
                title: 'Conductor',
                description: 'Ofrece viajes y comparte gastos.',
                onTap: () {
                  // TODO: Guardar el rol en Firebase y navegar a la pantalla del conductor.
                  Navigator.pushReplacementNamed(context, '/main_driver');
                },
              ),
              const SizedBox(height: 20),
              RoleCard(
                icon: Icons.person_pin,
                title: 'Pasajero',
                description: 'Encuentra viajes asequibles y seguros.',
                onTap: () {
                  // TODO: Guardar el rol en Firebase y navegar a la pantalla del pasajero.
                  Navigator.pushReplacementNamed(context, '/main_passenger');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 60, color: primaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}