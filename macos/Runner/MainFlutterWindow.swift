import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let kMinWidth: CGFloat = 1024
  private let kMinHeight: CGFloat = 768
  private let kScreenRatio: CGFloat = 0.8

  private let kKeyWidth = "window_width"
  private let kKeyHeight = "window_height"
  private let kKeyX = "window_x"
  private let kKeyY = "window_y"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let frame = calculateFrame()
    self.setFrame(frame, display: true)
    self.minSize = NSSize(width: kMinWidth, height: kMinHeight)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private func calculateFrame() -> NSRect {
    guard let screen = NSScreen.main else {
      return NSRect(x: 0, y: 0, width: kMinWidth, height: kMinHeight)
    }
    let screenFrame = screen.visibleFrame
    let defaults = UserDefaults.standard

    let width: CGFloat
    let height: CGFloat
    let x: CGFloat
    let y: CGFloat

    if defaults.object(forKey: kKeyWidth) != nil,
       defaults.object(forKey: kKeyHeight) != nil,
       defaults.object(forKey: kKeyX) != nil,
       defaults.object(forKey: kKeyY) != nil {
      width = max(CGFloat(defaults.double(forKey: kKeyWidth)), kMinWidth)
      height = max(CGFloat(defaults.double(forKey: kKeyHeight)), kMinHeight)
      x = CGFloat(defaults.double(forKey: kKeyX))
      y = CGFloat(defaults.double(forKey: kKeyY))
    } else {
      width = max(screenFrame.width * kScreenRatio, kMinWidth)
      height = max(screenFrame.height * kScreenRatio, kMinHeight)
      x = screenFrame.origin.x + (screenFrame.width - width) / 2
      y = screenFrame.origin.y + (screenFrame.height - height) / 2
    }

    return NSRect(x: x, y: y, width: width, height: height)
  }

  func saveWindowState() {
    if self.styleMask.contains(.fullScreen) { return }

    let frame = self.frame
    let defaults = UserDefaults.standard
    defaults.set(Double(frame.width), forKey: kKeyWidth)
    defaults.set(Double(frame.height), forKey: kKeyHeight)
    defaults.set(Double(frame.origin.x), forKey: kKeyX)
    defaults.set(Double(frame.origin.y), forKey: kKeyY)
  }
}
