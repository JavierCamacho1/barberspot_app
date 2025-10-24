import Flutter
import UIKit
import GoogleMaps // <-- ¡AÑADE ESTA LÍNEA!

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ¡PEGA TU CLAVE DE API AQUÍ!
    GMSServices.provideAPIKey("AIzaSyB0cOFz5YiYDdJi_6yOFoLy8U-LzlqN1do") // <-- ¡AÑADE ESTA LÍNEA!

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
