import MessageWidgetRendering
import QuartzCore
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The widget's pixels: one CALayer per 128 pt tile, whose `contents` is the image the widget's core drew for it
/// (`WidgetFrame`). The view draws nothing itself: it shows the frame its instance hands it.
public final class MessageWidgetView: UIView {
    enum TouchPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    /// One fully transparent pixel, shared by every widget view's own layer.
    private static let transparentContents: CGImage? = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.clear(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        return context?.makeImage()
    }()

    weak var instance: MessageWidgetInstance?
    /// Keyed by `WidgetFrame.key(row:column:)`. Sublayers of `contentLayer`.
    private var tiles: [Int: CALayer] = [:]
    private let contentLayer = CALayer()

    init(instance: MessageWidgetInstance) {
        self.instance = instance
        super.init(frame: .zero)
        self.clipsToBounds = true
        self.isMultipleTouchEnabled = false
        // The tiles are sublayers, so this layer renders nothing, and such a view gets no real touches on
        // iOS 26/27 (docs/ios27-windows-and-touches.md): transparent contents, no opacity threshold.
        self.layer.contents = MessageWidgetView.transparentContents
        self.contentLayer.actions = ["position": NSNull(), "bounds": NSNull()]
        self.layer.addSublayer(self.contentLayer)
        let touchRecognizer = MessageWidgetTouchRecognizer()
        touchRecognizer.onTouch = { [weak self] phase, point in
            self?.handleTouch(phase: phase, at: point)
        }
        self.addGestureRecognizer(touchRecognizer)
        self.touchRecognizer = touchRecognizer
    }

    private weak var touchRecognizer: MessageWidgetTouchRecognizer?

    /// Ends the widget's current touch as cancelled, so lifting the finger later clicks nothing: the host took the touch
    /// (a long press opened the message's context menu, which recognizes alongside the widget's recognizer).
    public func cancelTouches() {
        self.touchRecognizer?.cancelTrackedTouch()
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// Tests only: the number of tile layers.
    var tileCount: Int {
        return self.tiles.count
    }

    /// Tests only: the pixels held by every tile's backing image.
    var backingPixelCount: Int {
        return self.tiles.values.reduce(0) { total, layer in
            guard let image = layer.contents.map({ $0 as! CGImage }) else {
                return total
            }
            return total + image.width * image.height
        }
    }

    func setDead() {
        self.isUserInteractionEnabled = false
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.update()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        // Out of its window (a screen pushed over the chat) the widget is hidden whatever its bubble's visibility.
        self.instance?.viewWindowDidChange(attached: self.window != nil)
        self.update()
    }

    /// Tests only.
    var contentLayerForTesting: CALayer {
        return self.contentLayer
    }

    /// Shows the instance's frame again (nothing is drawn: a destroyed or released instance's view keeps its tiles).
    func update() {
        if let frame = self.instance?.currentFrame {
            self.apply(frame)
        }
    }

    /// Shows `frame`: a layer per tile, laid over the frame's size. A tile whose image is unchanged keeps its contents.
    func apply(_ frame: WidgetFrame) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.contentLayer.frame = CGRect(origin: .zero, size: frame.size)
        for (key, image) in frame.tiles {
            let layer: CALayer
            if let existing = self.tiles[key] {
                layer = existing
            } else {
                layer = CALayer()
                layer.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull()]
                self.contentLayer.addSublayer(layer)
                self.tiles[key] = layer
            }
            layer.frame = WidgetFrame.rect(forKey: key, size: frame.size)
            if (layer.contents as AnyObject?) !== image {
                layer.contentsScale = frame.scale
                layer.contents = image
            }
        }
        for (key, layer) in self.tiles where frame.tiles[key] == nil {
            layer.removeFromSuperlayer()
            self.tiles[key] = nil
        }
        CATransaction.commit()
    }

    // MARK: touches

    func handleTouch(phase: TouchPhase, at point: CGPoint) {
        let action: Int32
        switch phase {
        case .began:
            action = 0
        case .moved:
            action = 1
        case .ended:
            action = 2
        case .cancelled:
            action = 3
        }
        self.instance?.touch(action: action, at: point, pointer: 0, primary: true)
    }
}

/// Delivers a widget's touches (`MessageWidgetView` routes them all through it). The view's own `touchesEnded` is not
/// enough: any recognizer above a view that recognizes cancels the view's touches, and in a chat one does on every tap
/// (likely the history's keyboard-dismissing tap; not identified), so the widget saw each tap end as cancelled and
/// never clicked (measured in the simulator: began, then cancelled, 2026-10-15). A recognizer receives its touches whatever other
/// recognizers do with the view's, until one prevents it:
/// - a tap above it cannot (`canBePrevented(by:)`), so a tap always reaches the widget, which then owns it: it
///   recognizes on the touch's end, which fails the other taps waiting on the same touch;
/// - anything else can: a drag that starts on a widget scrolls the chat, and the widget's touch ends as cancelled.
/// It never cancels or delays the touches of a view, its own included.
final class MessageWidgetTouchRecognizer: UIGestureRecognizer {
    var onTouch: ((MessageWidgetView.TouchPhase, CGPoint) -> Void)?
    /// The touch the widget is following (the view takes one touch at a time), and where it last was.
    private var tracked: UITouch?
    private var lastLocation: CGPoint = .zero

    init() {
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }

    private func location(of touch: UITouch) -> CGPoint {
        return touch.location(in: self.view)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard self.tracked == nil, let touch = touches.first else {
            return
        }
        self.tracked = touch
        self.lastLocation = self.location(of: touch)
        self.onTouch?(.began, self.lastLocation)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.lastLocation = self.location(of: tracked)
        self.onTouch?(.moved, self.lastLocation)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.tracked = nil
        self.lastLocation = self.location(of: tracked)
        self.onTouch?(.ended, self.lastLocation)
        self.state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.tracked = nil
        self.onTouch?(.cancelled, self.lastLocation)
        self.state = .failed
    }

    /// The host took the touch: it ends here as cancelled, and its later end is ignored.
    func cancelTrackedTouch() {
        if self.tracked != nil {
            self.tracked = nil
            self.onTouch?(.cancelled, self.lastLocation)
        }
    }

    /// UIKit resets a recognizer another one prevented without a `touchesCancelled`: the widget's touch ends there.
    override func reset() {
        super.reset()
        if self.tracked != nil {
            self.tracked = nil
            self.onTouch?(.cancelled, self.lastLocation)
        }
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if preventingGestureRecognizer is UITapGestureRecognizer {
            return false
        }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }
}
