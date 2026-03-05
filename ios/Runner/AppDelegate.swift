import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let METHOD_CHANNEL = "app.channel.links"
  private let EVENT_CHANNEL = "app.channel.linkstream"

  private var initialLink: String? = nil
  private var eventSink: FlutterEventSink? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Capture any initial URL
    if let url = launchOptions?[.url] as? URL {
      initialLink = url.absoluteString
    }

    // Set up method & event channels once Flutter engine is available
    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(name: METHOD_CHANNEL, binaryMessenger: controller.binaryMessenger)
      methodChannel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getInitialLink" {
          result(self?.initialLink)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let eventChannel = FlutterEventChannel(name: EVENT_CHANNEL, binaryMessenger: controller.binaryMessenger)
      eventChannel.setStreamHandler(self)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle incoming deeplink / universal link
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    let link = url.absoluteString
    // send to event sink if listening
    if let sink = eventSink {
      sink(link)
    } else {
      initialLink = link
    }
    return true
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
