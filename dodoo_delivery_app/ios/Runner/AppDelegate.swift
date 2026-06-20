import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ════════════════════════════════════════════════════════════════
    // GOOGLE MAPS API KEY — REPLACE THE PLACEHOLDER BELOW
    // Enable "Maps SDK for iOS" in Google Cloud Console, create a key,
    // restrict it to this app's bundle id, and paste it here.
    // Until a real key is set, iOS map tiles will render blank.
    // ════════════════════════════════════════════════════════════════
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
