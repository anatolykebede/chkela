import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var securityDepth = 0
  private var captureObserver: NSObjectProtocol?
  private var overlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    DispatchQueue.main.async { [weak self] in
      self?.registerContentSecurityChannel()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerContentSecurityChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.chkela/content_security",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.enableSecureContent()
        result(nil)
      case "disable":
        self?.disableSecureContent()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enableSecureContent() {
    securityDepth += 1
    if securityDepth > 1 { return }

    // iOS does not allow reliable screenshot blocking without crashing Flutter's
    // window layer. Only blank the UI while the screen is actively recorded.
    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.syncCaptureOverlay()
    }
    syncCaptureOverlay()
  }

  private func disableSecureContent() {
    if securityDepth == 0 { return }
    securityDepth -= 1
    if securityDepth > 0 { return }

    if let observer = captureObserver {
      NotificationCenter.default.removeObserver(observer)
      captureObserver = nil
    }
    hideCaptureOverlay()
  }

  private func syncCaptureOverlay() {
    if UIScreen.main.isCaptured {
      showCaptureOverlay()
    } else {
      hideCaptureOverlay()
    }
  }

  private func showCaptureOverlay() {
    guard overlayView == nil, let window = window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.isUserInteractionEnabled = true
    overlay.tag = 882211
    window.addSubview(overlay)
    overlayView = overlay
  }

  private func hideCaptureOverlay() {
    overlayView?.removeFromSuperview()
    overlayView = nil
    window?.viewWithTag(882211)?.removeFromSuperview()
  }
}
