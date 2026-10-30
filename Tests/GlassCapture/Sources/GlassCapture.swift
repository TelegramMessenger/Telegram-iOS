import Foundation
import UIKit
import ComponentFlow
import GlassBackgroundComponent
import StaticGlassBackground

@objc(Application)
public final class Application: UIApplication {
}

@objc(AppDelegate)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@objc(SceneDelegate)
public final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let parameters = CaptureParameters()
        let window = UIWindow(windowScene: windowScene)
        // Glass reads the interface style as well as its own parameters.
        window.overrideUserInterfaceStyle = parameters.isDark ? .dark : .light
        window.rootViewController = CaptureViewController(parameters: parameters)
        self.window = window
        window.makeKeyAndVisible()
    }
}

/// From the launch arguments: `-page RRGGBB`, `-dark 0|1`, `-tint panel|RRGGBB` (a styled tint, at 0.85 alpha as the
/// chat's styled buttons use, or at `-tintAlpha`), `-interactive 0|1`, `-label <name>` (recorded in the manifest),
/// `-mode static` (the captured images, StaticGlassBackgroundView, at the same frames, for comparing with the live
/// glass).
struct CaptureParameters {
    let pageHex: String
    let isDark: Bool
    let tintHex: String
    let tintAlpha: CGFloat
    let isInteractive: Bool
    let label: String
    let isStatic: Bool

    init() {
        let defaults = UserDefaults.standard
        self.isDark = defaults.bool(forKey: "dark")
        self.pageHex = defaults.string(forKey: "page") ?? (self.isDark ? "000000" : "FFFFFF")
        self.tintHex = defaults.string(forKey: "tint") ?? "panel"
        self.tintAlpha = defaults.object(forKey: "tintAlpha") == nil ? 0.85 : CGFloat(defaults.double(forKey: "tintAlpha"))
        self.isInteractive = defaults.object(forKey: "interactive") == nil ? true : defaults.bool(forKey: "interactive")
        self.label = defaults.string(forKey: "label") ?? "capture"
        self.isStatic = defaults.string(forKey: "mode") == "static"
    }

    var pageColor: UIColor {
        return colorFromHex(self.pageHex)
    }

    var tintColor: GlassBackgroundView.TintColor {
        if self.tintHex == "panel" {
            return .init(kind: .panel)
        }
        if self.tintHex == "media" {
            // The chat's dark glass over media.
            return .init(kind: .custom(style: .default, color: UIColor(white: 0.0, alpha: 0.3)))
        }
        return .init(kind: .custom(style: .default, color: colorFromHex(self.tintHex).withAlphaComponent(self.tintAlpha)))
    }

    var staticTint: StaticGlassTint {
        if self.tintHex == "panel" {
            return .panel
        }
        if self.tintHex == "media" {
            return .media
        }
        return .color(colorFromHex(self.tintHex).withAlphaComponent(self.tintAlpha))
    }
}

private func colorFromHex(_ hex: String) -> UIColor {
    let value = UInt32(hex, radix: 16) ?? 0
    return UIColor(red: CGFloat((value >> 16) & 0xff) / 255.0, green: CGFloat((value >> 8) & 0xff) / 255.0, blue: CGFloat(value & 0xff) / 255.0, alpha: 1.0)
}

/// One shape: a capsule (height 2r, a straight run of 60pt between the ends), a circle, or a vertical capsule.
private struct CaptureShape {
    let name: String
    let radius: CGFloat
    let size: CGSize
}

private func captureShapes() -> [CaptureShape] {
    var shapes: [CaptureShape] = []
    for radius: CGFloat in [10.0, 12.0, 13.0, 14.0, 15.0, 16.0, 18.0, 21.0, 24.0] {
        shapes.append(CaptureShape(name: "capsule-r\(Int(radius))", radius: radius, size: CGSize(width: radius * 2.0 + 60.0, height: radius * 2.0)))
    }
    shapes.append(CaptureShape(name: "circle-r15", radius: 15.0, size: CGSize(width: 30.0, height: 30.0)))
    shapes.append(CaptureShape(name: "vcapsule-r15", radius: 15.0, size: CGSize(width: 30.0, height: 60.0)))
    // Narrow inline buttons: seven to a row (37x42, its radius clamped to 18.5) and five to a row (60x42).
    shapes.append(CaptureShape(name: "button-37x42", radius: 21.0, size: CGSize(width: 37.0, height: 42.0)))
    shapes.append(CaptureShape(name: "button-60x42", radius: 21.0, size: CGSize(width: 60.0, height: 42.0)))
    // Revision 2's plates: the round controls over media and on files (44-48pt), and the reply plate beside a sticker
    // (radius 12 at any height), stretchable both ways.
    shapes.append(CaptureShape(name: "circle-r24", radius: 24.0, size: CGSize(width: 48.0, height: 48.0)))
    shapes.append(CaptureShape(name: "rect-r12", radius: 12.0, size: CGSize(width: 120.0, height: 80.0)))
    return shapes
}

final class CaptureViewController: UIViewController {
    private let parameters: CaptureParameters
    private var glassViews: [(CaptureShape, UIView)] = []
    private var didWriteManifest = false
    private var firstLayoutMilliseconds: Double?

    init(parameters: CaptureParameters) {
        self.parameters = parameters
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.parameters.pageColor
        for shape in captureShapes() {
            let glassView: UIView = self.parameters.isStatic ? StaticGlassBackgroundView() : GlassBackgroundView()
            self.view.addSubview(glassView)
            self.glassViews.append((shape, glassView))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let layoutStart = CFAbsoluteTimeGetCurrent()
        // Left to right, wrapping, 36pt clear around every shape so shadows never meet.
        let gap: CGFloat = 36.0
        var x = gap
        var y = gap + 20.0
        var rowHeight: CGFloat = 0.0
        for (shape, glassView) in self.glassViews {
            if x + shape.size.width + gap > self.view.bounds.width {
                x = gap
                y += rowHeight + gap
                rowHeight = 0.0
            }
            glassView.frame = CGRect(origin: CGPoint(x: x, y: y), size: shape.size)
            if let glassView = glassView as? GlassBackgroundView {
                glassView.update(size: shape.size, cornerRadius: shape.radius, isDark: self.parameters.isDark, tintColor: self.parameters.tintColor, isInteractive: self.parameters.isInteractive, transition: .immediate)
            } else if let glassView = glassView as? StaticGlassBackgroundView {
                glassView.update(size: shape.size, cornerRadius: shape.radius, isDark: self.parameters.isDark, tint: self.parameters.staticTint)
            }
            x += shape.size.width + gap
            rowHeight = max(rowHeight, shape.size.height)
        }

        if self.firstLayoutMilliseconds == nil {
            // The first pass makes every image (static mode): what a chat pays the first time it shows a shape.
            self.firstLayoutMilliseconds = (CFAbsoluteTimeGetCurrent() - layoutStart) * 1000.0
        }
        if !self.didWriteManifest {
            self.didWriteManifest = true
            // Glass renders from a committed state: the manifest, which the capture script waits for, comes later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.writeManifest()
            }
        }
    }

    private func writeManifest() {
        var shapes: [[String: Any]] = []
        for (shape, glassView) in self.glassViews {
            let frame = glassView.convert(glassView.bounds, to: nil)
            shapes.append([
                "name": shape.name,
                "radius": shape.radius,
                "frame": [frame.minX, frame.minY, frame.width, frame.height]
            ])
        }
        let manifest: [String: Any] = [
            "label": self.parameters.label,
            "page": self.parameters.pageHex,
            "dark": self.parameters.isDark,
            "tint": self.parameters.tintHex,
            "tintAlpha": self.parameters.tintAlpha,
            "interactive": self.parameters.isInteractive,
            "mode": self.parameters.isStatic ? "static" : "live",
            "firstLayoutMilliseconds": self.firstLayoutMilliseconds ?? 0.0,
            "scale": UIScreen.main.scale,
            "screen": [self.view.bounds.width, self.view.bounds.height],
            "shapes": shapes
        ]
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: documents.appendingPathComponent("manifest.json"), options: .atomic)
    }
}
