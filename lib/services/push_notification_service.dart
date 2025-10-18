import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Manejador para notificaciones en segundo plano (cuando la app está cerrada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static String? token;
  static final StreamController<String> _messageStream = StreamController.broadcast();
  static Stream<String> get messagesStream => _messageStream.stream;

  static Future<void> initializeApp() async {
    // Solicitar permisos de notificación al usuario
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Obtener el token del dispositivo
    token = await messaging.getToken();
    print('FCM Token: $token');

    // Configurar los manejadores de notificaciones
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _onMessageListener();
    _onMessageOpenAppListener();
  }

  // Listener para cuando la app está en primer plano
  static void _onMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification!.title}');
        _messageStream.add(message.notification?.title ?? 'Sin título');
      }
    });
  }

  // Listener para cuando se toca la notificación y la app estaba en segundo plano
  static void _onMessageOpenAppListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _messageStream.add(message.notification?.title ?? 'Sin título');
      // Aquí podrías añadir lógica para navegar a una pantalla específica
    });
  }

  // Función para guardar el token en el perfil del usuario en Firestore
  static Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null) return;

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'fcm_token': token,
      });
      print('FCM Token guardado en Firestore para el usuario ${user.uid}');
    } catch (e) {
      print('Error al guardar el token en Firestore: $e');
    }
  }

  static void close() {
    _messageStream.close();
  }
}

