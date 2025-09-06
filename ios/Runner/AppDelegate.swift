import Flutter
import UIKit
import GoogleMaps


@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Proporciona tu clave de API de Google Maps antes de que se registre el plugin.
    GMSServices.provideAPIKey("AIzaSyAGt_avTWBRYMzlgCuyvNlQv5mW94dmLUE")

    // Este es el paso crucial: se registra el PlatformView para Google Maps
    if #available(iOS 10.0, *) {
      // Este registro se maneja automáticamente en versiones más nuevas de Flutter,
      // pero es una buena práctica de depuración para asegurarse.
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
