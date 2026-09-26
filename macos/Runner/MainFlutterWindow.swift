import Carbon.HIToolbox
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerKeyboardChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// Auto-type on macOS. Posting CGEvents needs only the PostEvent grant,
  /// which a sandboxed app can request. enigo also insists on Accessibility,
  /// which the sandbox never gets, so macOS types here instead.
  private func registerKeyboardChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "network_barcode_scanner/keyboard", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "canPostEvents":
        result(CGPreflightPostEventAccess())
      case "requestPostEvents":
        result(CGRequestPostEventAccess())
      case "openSettings":
        let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        result(NSWorkspace.shared.open(url))
      case "relaunch":
        // A PostEvent grant only takes effect in a fresh process
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) {
          _, _ in DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        result(nil)
      case "typeText":
        MainFlutterWindow.type(call.arguments as? String ?? "")
        result(nil)
      case "pressKey":
        let key = call.arguments as? String
        MainFlutterWindow.press(CGKeyCode(key == "tab" ? kVK_Tab : kVK_Return))
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Posts each character as a Unicode string rather than a key code, so case
  /// and symbols come out right whatever keyboard layout is active.
  private static func type(_ text: String) {
    let source = CGEventSource(stateID: .hidSystemState)
    for character in text {
      let units = Array(String(character).utf16)
      for keyDown in [true, false] {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown)
        else { continue }
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        event.post(tap: .cghidEventTap)
      }
    }
  }

  private static func press(_ keyCode: CGKeyCode) {
    let source = CGEventSource(stateID: .hidSystemState)
    for keyDown in [true, false] {
      CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)?
        .post(tap: .cghidEventTap)
    }
  }
}
