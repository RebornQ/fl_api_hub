import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(
        name: "com.mallotec.reb.flapihub/app",
        binaryMessenger: controller.engine.binaryMessenger
      )
    }
    _wireSettingsMenuItem()
    super.applicationDidFinishLaunching(notification)
  }

  private func _wireSettingsMenuItem() {
    guard let menu = NSApp.mainMenu?.items.first?.submenu else { return }
    for item in menu.items {
      if item.keyEquivalent == "," {
        item.target = self
        item.action = #selector(showSettings(_:))
        break
      }
    }
  }

  @objc func showSettings(_ sender: Any) {
    methodChannel?.invokeMethod("openSettings", arguments: nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    (mainFlutterWindow as? MainFlutterWindow)?.saveWindowState()
  }
}
