import MessageWidgetRendering
import QuartzCore
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The drags of a press its widget takes for itself (SDK v1 §5.5): with `horizontal` the chat's horizontal gestures
/// (swipe-to-reply, the back swipe) stay off the touch, with `vertical` the list holds still.
struct MessageWidgetGestureClaim: OptionSet {
    let rawValue: Int

    static let horizontal = MessageWidgetGestureClaim(rawValue: 1 << 0)
    static let vertical = MessageWidgetGestureClaim(rawValue: 1 << 1)
}

/// What a press answered when it went down (SDK v1 §5.5): the drags it claims for the widget, and whether it landed on
/// something the widget handles. There the tap is the widget's at once and the bubble takes no double tap, as on a
/// message button; elsewhere the bubble waits for a double tap, its quick reaction.
struct MessageWidgetPress: Equatable {
    var claim: MessageWidgetGestureClaim
    var takesTaps: Bool

    /// No live widget answered (none booted, or it stopped: a stopped widget is a picture): the bubble's.
    static let none = MessageWidgetPress(claim: [], takesTaps: false)
    /// The widget did not answer within the wait: its taps are taken at once, its drags are the chat's.
    static let unanswered = MessageWidgetPress(claim: [], takesTaps: true)
}

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
    /// Under the tiles: the canvas colour from the document's bottom to the view's (WidgetFrame.canvasColor).
    private let canvasLayer = CALayer()
    /// The colours at the view's bottom-left and bottom-right corners as it shows them: the drawn corner pixels, or the
    /// canvas colour where the view runs below the document. A bubble continues them into its tail.
    public private(set) var bottomCornerColors: (left: CGColor?, right: CGColor?) = (nil, nil)
    /// Called on main when `bottomCornerColors` changes.
    public var onBottomCornerColorsChange: ((_ left: CGColor?, _ right: CGColor?) -> Void)?

    init(instance: MessageWidgetInstance) {
        self.instance = instance
        super.init(frame: .zero)
        self.clipsToBounds = true
        self.isMultipleTouchEnabled = false
        // The tiles are sublayers, so this layer renders nothing, and such a view gets no real touches on
        // iOS 26/27 (docs/ios27-windows-and-touches.md): transparent contents, no opacity threshold.
        self.layer.contents = MessageWidgetView.transparentContents
        self.contentLayer.actions = ["position": NSNull(), "bounds": NSNull()]
        self.canvasLayer.actions = ["position": NSNull(), "bounds": NSNull(), "backgroundColor": NSNull()]
        self.layer.addSublayer(self.canvasLayer)
        self.layer.addSublayer(self.contentLayer)
        let touchRecognizer = MessageWidgetTouchRecognizer()
        touchRecognizer.onTouch = { [weak self] phase, point in
            return self?.handleTouch(phase: phase, at: point) ?? .none
        }
        self.addGestureRecognizer(touchRecognizer)
        self.touchRecognizer = touchRecognizer
    }

    private weak var touchRecognizer: MessageWidgetTouchRecognizer?

    /// Whether the press at `point` takes horizontal drags for the widget (SDK v1 §5.5), for the host's back swipe
    /// (`interactiveTransitionGestureRecognizerTest`), which begins after 2 pt, before the widget's drag does. The swipe
    /// asks in its own touchesBegan, which UIKit calls before the widget's recognizer has the touch (measured, 2026-10-22),
    /// so the answer starts the press: the recognizer adopts it when the touch reaches it.
    public func claimsHorizontalDrag(at point: CGPoint) -> Bool {
        return self.touchRecognizer?.beginPressEarly(at: point).claim.contains(.horizontal) ?? false
    }

    /// Whether the press at `point` takes taps for the widget, for the bubble (`tapActionAtPoint`): where it does, the tap
    /// is the widget's at once and so is a long press; elsewhere the bubble waits for a double tap, its quick reaction, and
    /// a long press opens its menu. The bubble's tap recognizer asks at the touch's down and up (`duringTouch`), before the
    /// widget's own recognizer has the touch, so its question starts the press, as `claimsHorizontalDrag(at:)` does. Its
    /// context gesture asks too, at the down and again while the touch is held, and UIKit may tell it about the touch
    /// before anyone else: its question reads the press under way, or one that went down there, and starts the press when
    /// there is none yet (`pressAnswerOrBegin`), so a long press on a part the widget does not handle always gets its menu.
    public func pressTakesTaps(at point: CGPoint, duringTouch: Bool) -> Bool {
        guard let recognizer = self.touchRecognizer else {
            return false
        }
        if duringTouch {
            return recognizer.beginPressEarly(at: point).takesTaps
        }
        return recognizer.pressAnswerOrBegin(at: point).takesTaps
    }

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
        self.dead = true
        self.isUserInteractionEnabled = false
    }

    private var dead = false

    /// The bubble was lifted into its context menu (true) or put back: lifted, the widget keeps running and drawing but
    /// takes no input (its touch in flight ends cancelled), and exports what the reader may select (sdk-v1 §5.10).
    public func setExtracted(_ extracted: Bool) {
        if extracted {
            self.cancelTouches()
        }
        self.isUserInteractionEnabled = !extracted && !self.dead
        self.instance?.setExtracted(extracted)
    }

    /// What the reader may select while the bubble is lifted; nil otherwise or when nothing is.
    public var selectableText: MessageWidgetSelectableText? {
        return self.instance?.selectableText
    }

    /// Called on main after `selectableText` changes.
    public var onSelectableTextChange: (() -> Void)? {
        get {
            return self.instance?.onSelectableTextChange
        }
        set {
            self.instance?.onSelectableTextChange = newValue
        }
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
        // The tiles paint the canvas over the document; below it, as tall as the bubble makes the view, this layer does.
        let canvasTop = min(max(frame.canvasTop, 0.0), self.bounds.height)
        self.canvasLayer.frame = CGRect(x: 0.0, y: canvasTop, width: self.bounds.width, height: self.bounds.height - canvasTop)
        self.canvasLayer.backgroundColor = frame.canvasColor
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
        let belowDocument = self.bounds.height > frame.size.height + 0.5
        let corners = belowDocument ? (frame.canvasColor, frame.canvasColor) : (frame.bottomLeftColor ?? frame.canvasColor, frame.bottomRightColor ?? frame.canvasColor)
        if corners.0 != self.bottomCornerColors.left || corners.1 != self.bottomCornerColors.right {
            self.bottomCornerColors = (corners.0, corners.1)
            self.onBottomCornerColorsChange?(corners.0, corners.1)
        }
    }

    // MARK: touches

    @discardableResult
    func handleTouch(phase: TouchPhase, at point: CGPoint) -> MessageWidgetPress {
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
        return self.instance?.touch(action: action, at: point, pointer: 0, primary: true) ?? .none
    }
}

/// Delivers a widget's touches (`MessageWidgetView` routes them all through it). The view's own `touchesEnded` is not
/// enough: any recognizer above a view that recognizes cancels the view's touches, and in a chat one does on every tap
/// (likely the history's keyboard-dismissing tap; not identified), so the widget saw each tap end as cancelled and
/// never clicked (measured in the simulator: began, then cancelled, 2026-10-15). A recognizer receives its touches whatever other
/// recognizers do with the view's, until one prevents it:
/// - a tap above it cannot (`canBePrevented(by:)`), so a tap always reaches the widget, which then owns it: it
///   recognizes on the touch's end, which fails the other taps waiting on the same touch;
/// - anything else can: a drag that starts on a widget the press claims nothing for is the chat's (the list scrolls,
///   a horizontal one swipes to reply), and the widget's touch ends as cancelled.
/// A drag the press claims (SDK v1 §5.5) is the widget's: once the touch has moved `claimDistance` along a claimed axis
/// the recognizer begins and fails every recognizer still possible above it, as the bubble's long press does when it
/// takes a touch. A touch on something the widget handles (`MessageWidgetPress.takesTaps`) is the widget's, held or not, so
/// the recognizer recognizes on its end; any other touch fails it at its end, which leaves it to the chat's taps and the
/// bubble's double tap, and a long press there is the bubble's context menu.
/// It never cancels or delays the touches of a view, its own included.
final class MessageWidgetTouchRecognizer: UIGestureRecognizer {
    /// How far a touch moves before a claimed drag takes it: past a resting finger's drift, short of the chat's own
    /// drags (swipe-to-reply and the list's pan begin at about 10 pt).
    static let claimDistance: CGFloat = 4.0

    var onTouch: ((MessageWidgetView.TouchPhase, CGPoint) -> MessageWidgetPress)?
    /// The touch the widget is following (the view takes one touch at a time), and where it last was.
    private var tracked: UITouch?
    private var lastLocation: CGPoint = .zero
    /// What the tracked touch's press answered, where it went down, and whether its direction is decided: a claimed drag
    /// is taken, or the touch moved past `claimDistance` along an axis its press did not claim.
    private var press: MessageWidgetPress = .none
    private var downLocation: CGPoint = .zero
    private var directionDecided = false
    /// A press started before its touch reached the recognizer (`beginPressEarly`): adopted by the touch that begins at
    /// its point, else cancelled on the next run-loop turn.
    private var earlyPress: (location: CGPoint, press: MessageWidgetPress)?
    /// The last press that went down, kept after it ends for the bubble's questions about its tap (`pressAnswer(near:)`).
    private var lastPress: (location: CGPoint, press: MessageWidgetPress)?

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
        self.downLocation = self.lastLocation
        self.directionDecided = false
        if let early = self.earlyPress, MessageWidgetTouchRecognizer.isNear(early.location, self.lastLocation) {
            self.earlyPress = nil
            self.press = early.press
        } else {
            self.cancelEarlyPress()
            self.press = self.onTouch?(.began, self.lastLocation) ?? .none
            self.lastPress = (self.lastLocation, self.press)
        }
    }

    /// Starts the press at `point` for a touch the recognizer has not seen yet, and answers it; the press of the touch it
    /// is tracking, or of one already started there, answers instead.
    func beginPressEarly(at point: CGPoint) -> MessageWidgetPress {
        if self.tracked != nil {
            return self.press
        }
        if let early = self.earlyPress {
            if MessageWidgetTouchRecognizer.isNear(early.location, point) {
                return early.press
            }
            self.cancelEarlyPress()
        }
        let press = self.onTouch?(.began, point) ?? .none
        self.earlyPress = (point, press)
        self.lastPress = (point, press)
        DispatchQueue.main.async { [weak self] in
            self?.cancelEarlyPress()
        }
        return press
    }

    /// The answer of the press a question is about, starting nothing: while a touch is down, its press, wherever the
    /// question is asked from (the view takes one touch at a time, and the bubble's press animation scales it during a
    /// long press, so the point a held finger converts to drifts: 1.3 pt measured, and a press matched by point was not
    /// found, so the long press read as the widget's and opened no menu); after it, the last press that went down at
    /// `point`.
    func pressAnswer(near point: CGPoint) -> MessageWidgetPress? {
        if self.tracked != nil {
            return self.press
        }
        if let last = self.lastPress, MessageWidgetTouchRecognizer.isNear(last.location, point) {
            return last.press
        }
        return nil
    }

    /// The press a question is about (`pressAnswer(near:)`), or, when there is none, the press started at `point`: a
    /// question at a touch's down can come before anything else heard of the touch.
    func pressAnswerOrBegin(at point: CGPoint) -> MessageWidgetPress {
        return self.pressAnswer(near: point) ?? self.beginPressEarly(at: point)
    }

    /// Two answers to one touch come in different views' coordinates, converted back to this one: equal up to rounding.
    private static func isNear(_ a: CGPoint, _ b: CGPoint) -> Bool {
        return abs(a.x - b.x) < 1.0 && abs(a.y - b.y) < 1.0
    }

    /// Ends a press no touch adopted as cancelled.
    private func cancelEarlyPress() {
        if let early = self.earlyPress {
            self.earlyPress = nil
            _ = self.onTouch?(.cancelled, early.location)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.lastLocation = self.location(of: tracked)
        _ = self.onTouch?(.moved, self.lastLocation)
        switch self.state {
        case .possible:
            if self.takesDrag(at: self.lastLocation) {
                self.state = .began
                self.failRecognizersAbove()
            }
        case .began, .changed:
            self.state = .changed
        default:
            break
        }
    }

    /// Whether the touch, now at `location`, is a drag its press claimed: decided once, the first time it is
    /// `claimDistance` from where it went down, by the axis it moved along most.
    private func takesDrag(at location: CGPoint) -> Bool {
        guard !self.directionDecided, !self.press.claim.isEmpty else {
            return false
        }
        let dx = abs(location.x - self.downLocation.x)
        let dy = abs(location.y - self.downLocation.y)
        guard max(dx, dy) >= MessageWidgetTouchRecognizer.claimDistance else {
            return false
        }
        self.directionDecided = true
        return self.press.claim.contains(dx >= dy ? .horizontal : .vertical)
    }

    /// The drag is the widget's: the list's pan, swipe-to-reply, the back swipe and the bubble's taps and long press fail
    /// (the window's own recognizers are the system's and are left alone).
    private func failRecognizersAbove() {
        var view = self.view?.superview
        while let current = view, !(current is UIWindow) {
            for recognizer in current.gestureRecognizers ?? [] where recognizer !== self && recognizer.state == .possible {
                recognizer.state = .failed
            }
            view = current.superview
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.tracked = nil
        self.lastLocation = self.location(of: tracked)
        _ = self.onTouch?(.ended, self.lastLocation)
        self.state = self.state == .possible && !self.press.takesTaps ? .failed : .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let tracked = self.tracked, touches.contains(tracked) else {
            return
        }
        self.tracked = nil
        _ = self.onTouch?(.cancelled, self.lastLocation)
        self.state = self.state == .possible ? .failed : .cancelled
    }

    /// The host took the touch: it ends here as cancelled, and its later end is ignored.
    func cancelTrackedTouch() {
        if self.tracked != nil {
            self.tracked = nil
            _ = self.onTouch?(.cancelled, self.lastLocation)
        }
    }

    /// UIKit resets a recognizer another one prevented without a `touchesCancelled`: the widget's touch ends there.
    override func reset() {
        super.reset()
        self.press = .none
        self.directionDecided = false
        if self.tracked != nil {
            self.tracked = nil
            _ = self.onTouch?(.cancelled, self.lastLocation)
        }
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if preventingGestureRecognizer is UITapGestureRecognizer {
            return false
        }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }
}
