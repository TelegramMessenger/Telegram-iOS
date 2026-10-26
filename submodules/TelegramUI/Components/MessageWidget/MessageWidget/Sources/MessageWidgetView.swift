import MessageWidgetRendering
import QuartzCore
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The drags of a press its widget takes for itself (SDK v1 §5.5): with `horizontal` the chat's horizontal gestures
/// (swipe-to-reply, the back swipe) stay off the touch. A vertical drag is never the widget's, whatever it declares:
/// the chat always scrolls (the user, 2026-10-23: "widgets should not be able to prevent vertical scrolling, ever").
struct MessageWidgetGestureClaim: OptionSet {
    let rawValue: Int

    static let horizontal = MessageWidgetGestureClaim(rawValue: 1 << 0)
}

/// What a press answered when it went down (SDK v1 §5.5): the drags it claims for the widget, whether it landed on
/// something the widget handles, and whether its hold is the widget's (`touch-action: none`: the widget gets
/// `contextmenu`, the bubble opens no menu), else the bubble's (a hold opens the message's menu).
struct MessageWidgetPress: Equatable {
    var claim: MessageWidgetGestureClaim
    var takesTaps: Bool
    var hold: Bool = false

    /// No live widget answered (none booted, or it stopped: a stopped widget is a picture): the bubble's.
    static let none = MessageWidgetPress(claim: [], takesTaps: false)
    /// The widget did not answer within the wait (a busy game): its taps and its hold are taken for it (no menu, the
    /// chat's lock and step-back), its drags are the chat's.
    static let unanswered = MessageWidgetPress(claim: [], takesTaps: true, hold: true)
    /// An iPad pointer's press, as the policy's mouse answers it whatever its touch-action: its holds and sideways drags
    /// are the widget's (`MessageWidgetCore.touch`).
    static let pointer = MessageWidgetPress(claim: .horizontal, takesTaps: true, hold: true)
}

/// What presses a widget's pointer, as the gesture policy tells them apart: a finger or a pencil is a touch; an iPad's
/// trackpad or mouse (a `UITouch` of type `.indirectPointer`) is a mouse, with its button (0 primary, 2 secondary).
struct MessageWidgetPointerKind: Equatable {
    var mouse: Bool
    var button: Int

    static let touch = MessageWidgetPointerKind(mouse: false, button: 0)
}

/// The widget's pixels: one CALayer per 128 pt tile, whose `contents` is the image the widget's core drew for it
/// (`WidgetFrame`). The view draws nothing itself: it shows the frame its instance hands it.
public final class MessageWidgetView: UIView {
    enum TouchPhase {
        case began
        case moved
        case ended
        case cancelled
        /// A press started for the bubble's question that no touch took up (`beginPressEarly`): a cancel to the widget,
        /// and a press that never was to its double tap.
        case retracted
    }

    /// One fully transparent pixel, shared by every widget view's own layer.
    private static let transparentContents: CGImage? = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.clear(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        return context?.makeImage()
    }()

    public private(set) weak var instance: MessageWidgetInstance?
    /// Keyed by `WidgetFrame.key(row:column:)`. Sublayers of `contentLayer`.
    private var tiles: [Int: CALayer] = [:]
    private let contentLayer = CALayer()
    /// Under the tiles: the canvas colour from the document's bottom to the view's (WidgetFrame.canvasColor).
    private let canvasLayer = CALayer()
    /// The canvas colour right of a document narrower than the view, above `canvasLayer`: a stopped widget is clipped,
    /// not laid out again, at a wider width.
    private let canvasSideLayer = CALayer()
    /// The colours at the view's bottom-left and bottom-right corners as it shows them: the drawn corner pixels, or the
    /// canvas colour where the view runs below the document. A bubble continues them into its tail.
    public private(set) var bottomCornerColors: (left: CGColor?, right: CGColor?) = (nil, nil)
    /// Called on main when `bottomCornerColors` changes.
    public var onBottomCornerColorsChange: ((_ left: CGColor?, _ right: CGColor?) -> Void)?

    init(instance: MessageWidgetInstance) {
        self.instance = instance
        super.init(frame: .zero)
        self.clipsToBounds = true
        // Each finger is its own pointer (multitouch design §5.1), up to MessageWidgetTouchRecognizer.maximumTouches.
        self.isMultipleTouchEnabled = true
        // The tiles are sublayers, so this layer renders nothing, and such a view gets no real touches on
        // iOS 26/27 (docs/ios27-windows-and-touches.md): transparent contents, no opacity threshold.
        self.layer.contents = MessageWidgetView.transparentContents
        self.contentLayer.actions = ["position": NSNull(), "bounds": NSNull()]
        self.canvasLayer.actions = ["position": NSNull(), "bounds": NSNull(), "backgroundColor": NSNull()]
        self.canvasSideLayer.actions = ["position": NSNull(), "bounds": NSNull(), "backgroundColor": NSNull()]
        self.layer.addSublayer(self.canvasLayer)
        self.layer.addSublayer(self.canvasSideLayer)
        self.layer.addSublayer(self.contentLayer)
        let touchRecognizer = MessageWidgetTouchRecognizer()
        touchRecognizer.onTouch = { [weak self] phase, point, pointer, primary, kind in
            return self?.handleTouch(phase: phase, at: point, pointer: pointer, primary: primary, kind: kind) ?? .none
        }
        touchRecognizer.onSecondaryClick = { [weak self] point in
            self?.onSecondaryClick?(point)
        }
        self.addGestureRecognizer(touchRecognizer)
        self.touchRecognizer = touchRecognizer
        // An iPad pointer hovers before it clicks: where it is tells the bubble's questions, which come before the
        // pointer's touch reaches the recognizer, that a press there is a mouse's. A pencil's hover is left out.
        let hoverRecognizer = UIHoverGestureRecognizer(target: self, action: #selector(self.pointerHovered(_:)))
        hoverRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        self.addGestureRecognizer(hoverRecognizer)
    }

    private weak var touchRecognizer: MessageWidgetTouchRecognizer?

    @objc private func pointerHovered(_ recognizer: UIHoverGestureRecognizer) {
        self.touchRecognizer?.pointerHovered(at: recognizer.location(in: self))
    }

    /// An iPad pointer's secondary click on a part that claims no holds, at its point in the view: the chat's, for the
    /// message's menu, as a secondary click elsewhere on the message opens it.
    public var onSecondaryClick: ((CGPoint) -> Void)?

    /// Whether the press at `point` takes horizontal drags for the widget (SDK v1 §5.5), for the host's back swipe
    /// (`interactiveTransitionGestureRecognizerTest`), which begins after 2 pt, and the bubble's swipe to reply, which
    /// begins at about the widget's own slop: each asks at its start rather than racing the widget's drag. They ask in
    /// their own touchesBegan, which UIKit calls before the widget's recognizer has the touch (measured, 2026-10-22), so
    /// the answer starts the press: the recognizer adopts it when the touch reaches it.
    public func claimsHorizontalDrag(at point: CGPoint) -> Bool {
        return self.touchRecognizer?.beginPressEarly(at: point).claim.contains(.horizontal) ?? false
    }

    /// Whether the press at `point` claims its hold for the widget (`MessageWidgetPress.hold`, touch-action: none), for
    /// the bubble (`tapActionAtPoint`), whose context gesture opens the message's menu on a hold everywhere else over the
    /// widget. The bubble's tap recognizer asks at the touch's down and up (`duringTouch`), before the widget's own
    /// recognizer has the touch, so its question starts the press, as `claimsHorizontalDrag(at:)` does. Its context
    /// gesture asks at the down too, and UIKit may tell it about the touch before anyone else: its question reads the
    /// press under way, or one that went down there, and starts the press when there is none yet (`pressAnswerOrBegin`).
    public func pressClaimsHold(at point: CGPoint, duringTouch: Bool) -> Bool {
        guard let recognizer = self.touchRecognizer else {
            return false
        }
        if duringTouch {
            return recognizer.beginPressEarly(at: point).hold
        }
        return recognizer.pressAnswerOrBegin(at: point).hold
    }

    /// Ends every finger of the widget's as cancelled, so lifting one later clicks nothing: the host took the touches (a
    /// long press opened the message's context menu, which recognizes alongside the widget's recognizer).
    public func cancelTouches() {
        self.touchRecognizer?.cancelTrackedTouches()
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

    /// The live document's `<html>` attribute `name` (`MessageWidgetInstance.documentElementAttribute`), for the widget
    /// harness's readout. Main thread; waits for its turn on the widget's queue.
    public func documentElementAttribute(_ name: String) -> String? {
        return self.instance?.documentElementAttribute(name)
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
        // Out of its window (a recycled bubble) the widget's fingers end, and the chat's lock with them.
        if self.window == nil {
            self.cancelTouches()
        }
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

    /// Where the tiles of a document drawn `drawnHeight` tall go while the widget reports `reportedHeight`: a widget whose
    /// height changed shows its old tiles until the new ones are drawn, and a bottom-anchored one keeps them on its
    /// bubble's bottom edge, which stays put (widget-sandbox v0.1.3, integration.md "Which edge stays put"); otherwise
    /// they are laid from the top.
    static func tileOffset(anchor: MessageWidgetResizeAnchor, reportedHeight: CGFloat?, drawnHeight: CGFloat) -> CGFloat {
        guard anchor == .bottom, let reportedHeight, abs(reportedHeight - drawnHeight) > 0.5 else {
            return 0.0
        }
        return reportedHeight - drawnHeight
    }

    /// Shows `frame`: a layer per tile, laid over the frame's size. A tile whose image is unchanged keeps its contents.
    func apply(_ frame: WidgetFrame) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let offset = MessageWidgetView.tileOffset(anchor: self.instance?.resizeAnchor ?? .top, reportedHeight: self.instance?.reportedHeight, drawnHeight: frame.size.height)
        self.contentLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: offset), size: frame.size)
        // The tiles paint the canvas over the document; below it, as tall as the bubble makes the view, this layer does
        // (and above old tiles held on the bottom edge).
        let canvasTop = offset > 0.0 ? 0.0 : min(max(frame.canvasTop, 0.0), self.bounds.height)
        self.canvasLayer.frame = CGRect(x: 0.0, y: canvasTop, width: self.bounds.width, height: self.bounds.height - canvasTop)
        self.canvasLayer.backgroundColor = frame.canvasColor
        self.canvasSideLayer.frame = CGRect(x: frame.size.width, y: 0.0, width: max(0.0, self.bounds.width - frame.size.width), height: canvasTop)
        self.canvasSideLayer.backgroundColor = frame.canvasColor
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

    /// One finger's phase: `pointer` its id, `primary` whether it went down while none of the view's other fingers was,
    /// `kind` what presses it.
    @discardableResult
    func handleTouch(phase: TouchPhase, at point: CGPoint, pointer: Int32 = 0, primary: Bool = true, kind: MessageWidgetPointerKind = .touch) -> MessageWidgetPress {
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
        case .retracted:
            action = 4
        }
        return self.instance?.touch(action: action, at: point, pointer: pointer, primary: primary, mouse: kind.mouse, button: kind.button) ?? .none
    }
}

/// Delivers a widget's touches (`MessageWidgetView` routes them all through it), each finger as its own pointer, up to
/// `maximumTouches`. The view's own `touchesEnded` is not enough: any recognizer above a view that recognizes cancels the
/// view's touches, and in a chat one does on every tap (likely the history's keyboard-dismissing tap; not identified), so
/// the widget saw each tap end as cancelled and never clicked (measured in the simulator: began, then cancelled,
/// 2026-10-15). A recognizer receives its touches whatever other recognizers do with the view's, until one prevents it:
/// - a tap above it cannot (`canBePrevented(by:)`), so a tap always reaches the widget, which then owns it: it
///   recognizes on the touch's end, which fails the other taps waiting on the same touch;
/// - anything else can: a drag that starts on a widget the press claims nothing for is the chat's (the list scrolls,
///   a horizontal one swipes to reply), and the widget's touches end as cancelled.
/// A drag the press claims (SDK v1 §5.5) is the widget's: once the touch has moved `claimDistance` along a claimed axis
/// the recognizer begins and fails every recognizer still possible above it, as the bubble's long press does when it
/// takes a touch. A tap on something the widget handles (`MessageWidgetPress.takesTaps`) is the widget's, so the
/// recognizer recognizes on the last touch's end; a sequence of touches none of which did fails it there, which leaves
/// it to the chat's own taps (the bubble's never wait on a live widget). A hold is the bubble's context menu unless the
/// press claims it (`MessageWidgetPress.hold`).
/// Several fingers (multitouch design §2, §5.2): a finger that lands while another is down, when either press claims
/// its hold, takes the touches for the widget the same way, until every finger has lifted; a finger that lands while the
/// chat drags (a recognizer above has begun) starts nothing.
/// It never cancels or delays the touches of a view, its own included.
final class MessageWidgetTouchRecognizer: UIGestureRecognizer {
    /// How far a touch moves before a claimed drag takes it: past a resting finger's drift, short of the chat's own
    /// drags (the list's pan and swipe-to-reply begin at about 10 pt, and the list's took the touch when the widget's
    /// decision came at 10 pt too). Well short of the gesture policy's 10 px slop, which the runtime still applies: a
    /// press that stops before it is a tap, whoever holds the touch.
    static let claimDistance: CGFloat = 4.0
    /// The gesture policy's slop (10 px): a press that moves no further is a tap or a hold, whoever holds the touch.
    static let dragSlop: CGFloat = 10.0
    /// At most this many fingers at once (the runtime's kMaxPointers); another is ignored whole.
    static let maximumTouches = 5

    /// A finger's phase: its point, its pointer id, whether it is the primary pointer, and what presses it.
    var onTouch: ((MessageWidgetView.TouchPhase, CGPoint, Int32, Bool, MessageWidgetPointerKind) -> MessageWidgetPress)?
    /// A pointer's secondary click whose press claims no holds ended, at its point: the chat's menu.
    var onSecondaryClick: ((CGPoint) -> Void)?
    /// Tests: whether the chat is dragging; nil reads the recognizers above the view.
    var chatIsDragging: (() -> Bool)?
    /// Tests: where a touch is; nil is its location in the view.
    var touchLocation: ((UITouch) -> CGPoint)?
    /// Tests: what presses a touch; nil reads its type and the event's buttons.
    var touchKind: ((UITouch, UIEvent) -> MessageWidgetPointerKind)?

    /// A finger the widget is following: its pointer, what its press answered, where it went down and last was, and
    /// whether its direction is decided (a claimed drag is taken, or it moved past `claimDistance` along an axis its press
    /// did not claim).
    private struct Tracked {
        let touch: UITouch
        let pointer: Int32
        let primary: Bool
        let kind: MessageWidgetPointerKind
        let press: MessageWidgetPress
        let downLocation: CGPoint
        var lastLocation: CGPoint
        var directionDecided = false
    }
    private var tracked: [Tracked] = []
    /// The finger whose claimed drag began the recognizer while its press leaves the hold to the bubble: the recognizers
    /// above that are not pans (the bubble's long press, the message's menu) fail only once it passes `dragSlop`, so a
    /// hold short of the slop is still the menu, as the policy has it.
    private var sparesUntilSlop: UITouch?
    /// Whether a press of the current sequence took taps: the recognizer then ends at the last touch's end, else fails.
    private var sequenceTakesTaps = false
    /// Whether the widget took the sequence's touches (`takeTouches`: a second finger, or a pointer press that claims its
    /// hold): until every finger has lifted, every question is the widget's, since a recognizer failed from outside can
    /// still act on a timer (the bubble's long tap does) and asks then.
    private(set) var tookTouches = false
    /// A finger went sideways (a claimed drag, or one of the touches the widget took): UIKit's exclusion keeps the pans
    /// out from then on (`canPrevent`). Until then none, so the chat's scroll survives the widget taking the touches.
    private var preventsPans = false
    /// Pointer ids count up, one per press.
    private var nextPointer: Int32 = 1
    /// A press started before its touch reached the recognizer (`beginPressEarly`), always a finger's (a question
    /// carries no touch, and where a pointer hovers none starts): adopted by a finger that begins at its point, else
    /// cancelled, by a pointer's touch there or on the next run-loop turn.
    private var earlyPress: (location: CGPoint, pointer: Int32, primary: Bool, press: MessageWidgetPress)?
    /// Where an iPad pointer last hovered over the view, until a finger touches it.
    private var hoverLocation: CGPoint?
    /// The last press that went down, kept after it ends for the bubble's questions about its tap (`pressAnswer(near:)`).
    private var lastPress: (location: CGPoint, press: MessageWidgetPress)?

    init() {
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }

    private func location(of touch: UITouch) -> CGPoint {
        return self.touchLocation?(touch) ?? touch.location(in: self.view)
    }

    private func kind(of touch: UITouch, in event: UIEvent) -> MessageWidgetPointerKind {
        if let touchKind = self.touchKind {
            return touchKind(touch, event)
        }
        guard touch.type == .indirectPointer else {
            return .touch
        }
        return MessageWidgetPointerKind(mouse: true, button: event.buttonMask.contains(.secondary) ? 2 : 0)
    }

    private func takePointer() -> Int32 {
        let pointer = self.nextPointer
        self.nextPointer = pointer == Int32.max ? 1 : pointer + 1
        return pointer
    }

    /// Whether a recognizer above the view (the list's pan, swipe-to-reply, the back swipe) has begun: a finger that lands
    /// then is the chat's to ignore (the user, 2026-10-23).
    private func isChatDragging() -> Bool {
        if let chatIsDragging = self.chatIsDragging {
            return chatIsDragging()
        }
        var view = self.view?.superview
        while let current = view, !(current is UIWindow) {
            for recognizer in current.gestureRecognizers ?? [] where MessageWidgetTouchRecognizer.isChatDrag(recognizer, state: recognizer.state) {
                return true
            }
            view = current.superview
        }
        return false
    }

    /// A recognizer above the view in `state` is a chat drag: a pan (the list's, swipe-to-reply, the back swipe) that
    /// has begun. A recognizer that began otherwise is no drag: the bubble's tap waiting for a double tap, or the chat's
    /// lock, whose locked finger leaves a finger then landing on the held widget the widget's.
    static func isChatDrag(_ recognizer: UIGestureRecognizer, state: UIGestureRecognizer.State) -> Bool {
        return (state == .began || state == .changed) && recognizer is UIPanGestureRecognizer
    }

    /// Whether a drag or a second finger the widget takes (or a finger the chat's lock holds) fails `recognizer` above
    /// it: everything but the chat's lock, which must still hear the fingers that land elsewhere, and, until a finger has
    /// moved sideways (`pans`), a pan inside the chat's view `chat` (its scroll, a bubble's swipe to reply, which needs
    /// 10 pt sideways): a vertical drag is never a widget's to stop (the user, 2026-10-23: "widgets should not be able to
    /// prevent vertical scrolling, ever"). A pan on the chat's view or above it (the navigation's back swipe, which
    /// begins at 2 pt) goes at once.
    static func failsAbove(_ recognizer: UIGestureRecognizer, pans: Bool, chat: UIView?) -> Bool {
        if recognizer is MessageWidgetChatLockRecognizer {
            return false
        }
        if !pans, recognizer is UIPanGestureRecognizer, let chat, let view = recognizer.view, view !== chat, view.isDescendant(of: chat) {
            return false
        }
        return true
    }

    /// The chat's lock (`MessageWidgetTouchLock`) is held while a finger's press claims its hold (a game's control).
    private func updateHolding() {
        if let view = self.view {
            MessageWidgetTouchLock.setHolding(view, self.tracked.contains(where: { $0.press.hold }))
        }
    }

    /// Whether a finger landing now starts nothing: the chat drags, or another widget in the chat holds a control (the
    /// chat's lock: "anywhere else in the chat").
    private func startsNothing() -> Bool {
        if self.isChatDragging() {
            return true
        }
        if let view = self.view, MessageWidgetTouchLock.isHeld(elsewhereThan: view) {
            return true
        }
        return false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        // Two fingers landing in one event: the one the bubble's question started (`touches.first`) adopts its press,
        // whichever order the set iterates in.
        let isEarly = { (touch: UITouch) -> Bool in
            return self.earlyPress.map { MessageWidgetTouchRecognizer.isNear($0.location, self.location(of: touch)) } ?? false
        }
        let ordered = touches.sorted { a, b in isEarly(a) && !isEarly(b) }
        for touch in ordered {
            if self.tracked.count >= MessageWidgetTouchRecognizer.maximumTouches || self.startsNothing() {
                self.ignore(touch, for: event)
                continue
            }
            let location = self.location(of: touch)
            let kind = self.kind(of: touch, in: event)
            let pointer: Int32
            let primary: Bool
            let press: MessageWidgetPress
            if kind == .touch {
                self.hoverLocation = nil
            }
            if kind == .touch, let early = self.earlyPress, MessageWidgetTouchRecognizer.isNear(early.location, location) {
                self.earlyPress = nil
                (pointer, primary, press) = (early.pointer, early.primary, early.press)
            } else {
                self.cancelEarlyPress()
                pointer = self.takePointer()
                primary = self.tracked.isEmpty
                press = self.onTouch?(.began, location, pointer, primary, kind) ?? .none
                self.lastPress = (location, press)
            }
            let others = self.tracked
            self.tracked.append(Tracked(touch: touch, pointer: pointer, primary: primary, kind: kind, press: press, downLocation: location, lastLocation: location))
            self.sequenceTakesTaps = self.sequenceTakesTaps || press.takesTaps
            // The chat steps back (multitouch design §5.2): a second finger, and a press that claims its hold under
            // either.
            if !others.isEmpty && (press.hold || others.contains(where: { $0.press.hold })) {
                self.takeTouches()
            }
            // A pointer has no hold menu and no swipes (the policy's mouse): a press that claims its hold is the widget's
            // whole, whatever the bubble's questions at its down were told.
            if kind.mouse && press.hold {
                self.takeTouches()
            }
        }
        self.updateHolding()
    }

    /// The touches are the widget's until every finger has lifted: nothing above it can begin meanwhile.
    private func takeTouches() {
        self.tookTouches = true
        switch self.state {
        case .possible:
            self.state = .began
            self.failRecognizersAbove(pans: false)
        case .began, .changed:
            self.state = .changed
        default:
            break
        }
    }

    /// Starts the press at `point` for a touch the recognizer has not seen yet, and answers it; while a finger is down,
    /// its press answers instead (the nearest one's when there are several), while the chat drags nothing starts, and
    /// where an iPad pointer hovers nothing starts either and the mouse's answer is given (`MessageWidgetPress.pointer`).
    func beginPressEarly(at point: CGPoint) -> MessageWidgetPress {
        if self.startsNothing() {
            return .none
        }
        if let press = self.trackedPress(near: point) {
            return press
        }
        if let early = self.earlyPress {
            if MessageWidgetTouchRecognizer.isNear(early.location, point) {
                return early.press
            }
            self.cancelEarlyPress()
        }
        // Where an iPad pointer hovers the press is its, and its button is not known until its touch arrives: the answer
        // is the mouse's, and the touch starts the widget's press, with its real button.
        if self.hoverLocation.map({ MessageWidgetTouchRecognizer.isNear($0, point) }) == true {
            return .pointer
        }
        let pointer = self.takePointer()
        let primary = self.tracked.isEmpty
        let press = self.onTouch?(.began, point, pointer, primary, .touch) ?? .none
        self.earlyPress = (point, pointer, primary, press)
        self.lastPress = (point, press)
        DispatchQueue.main.async { [weak self] in
            self?.cancelEarlyPress()
        }
        return press
    }

    /// While fingers are down, the press a question is about: once a second finger took the touches, one that takes taps;
    /// else with one finger, its press wherever the question is asked from
    /// (the bubble's press animation scales it during a long press, so the point a held finger converts to drifts: 1.3
    /// pt measured, and a press matched by point was not found, so the long press read as the widget's and opened no
    /// menu); with several, the press of the finger nearest `point`.
    private func trackedPress(near point: CGPoint) -> MessageWidgetPress? {
        if self.tookTouches, let first = self.tracked.first {
            return MessageWidgetPress(claim: first.press.claim, takesTaps: true, hold: true)
        }
        if self.tracked.count <= 1 {
            return self.tracked.first?.press
        }
        let distance = { (location: CGPoint) in hypot(location.x - point.x, location.y - point.y) }
        return self.tracked.min(by: { distance($0.lastLocation) < distance($1.lastLocation) })?.press
    }

    /// The answer of the press a question is about, starting nothing: while fingers are down, theirs
    /// (`trackedPress(near:)`); after them, the last press that went down at `point`.
    func pressAnswer(near point: CGPoint) -> MessageWidgetPress? {
        if let press = self.trackedPress(near: point) {
            return press
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

    /// Retracts a press no touch adopted: the widget sees it cancelled, its double tap never sees it (a pointer's click
    /// after the bubble's question there still makes a double click).
    private func cancelEarlyPress() {
        if let early = self.earlyPress {
            self.earlyPress = nil
            _ = self.onTouch?(.retracted, early.location, early.pointer, early.primary, .touch)
        }
    }

    /// An iPad pointer hovers at `point` over the view.
    func pointerHovered(at point: CGPoint) {
        self.hoverLocation = point
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        // The chat scrolls (a pan above began, which nothing here stops): the widget's fingers end, as a finger landing
        // during a scroll starts nothing.
        if !self.tracked.isEmpty && self.isChatDragging() {
            self.cancelTrackedTouches()
            return
        }
        for touch in touches {
            guard let index = self.tracked.firstIndex(where: { $0.touch === touch }) else {
                continue
            }
            let location = self.location(of: touch)
            self.tracked[index].lastLocation = location
            let finger = self.tracked[index]
            _ = self.onTouch?(.moved, location, finger.pointer, finger.primary, finger.kind)
            // The callback may have ended the touches (the host's cancel): the finger is looked up again.
            guard let current = self.tracked.firstIndex(where: { $0.touch === touch }) else {
                continue
            }
            let sideways = self.movedSideways(current, at: location)
            switch self.state {
            case .possible:
                // A drag its press claimed (horizontal: a vertical one is never the widget's).
                if sideways == true && self.tracked[current].press.claim.contains(.horizontal) {
                    // Set before beginning: the exclusion at the transition is what keeps a pan that would begin in the
                    // same event (swipe-to-reply on a fast drag) out; failing it from here does not hold within the event.
                    self.preventsPans = true
                    self.state = .began
                    let down = self.tracked[current].downLocation
                    if self.tracked[current].press.hold || hypot(location.x - down.x, location.y - down.y) > MessageWidgetTouchRecognizer.dragSlop {
                        self.failRecognizersAbove(pans: true)
                    } else {
                        self.sparesUntilSlop = touch
                        self.failRecognizersAbove(pans: true, sparingOthers: true)
                    }
                }
            case .began, .changed:
                // The widget holds the touches: a finger moving sideways first takes the chat's pans off them too, one
                // moving vertically leaves the chat's scroll to begin.
                if sideways == true {
                    self.preventsPans = true
                    self.failRecognizersAbove(pans: true)
                }
                // Past the slop the claimed drag is a drag: the menu's long press goes too.
                if self.sparesUntilSlop === touch {
                    let down = self.tracked[current].downLocation
                    if hypot(location.x - down.x, location.y - down.y) > MessageWidgetTouchRecognizer.dragSlop {
                        self.sparesUntilSlop = nil
                        self.failRecognizersAbove(pans: true)
                    }
                }
                self.state = .changed
            default:
                break
            }
        }
    }

    /// Whether the finger at `index`, now at `location`, moved mostly sideways: decided once, the first time it is
    /// `claimDistance` from where it went down; nil before and after.
    private func movedSideways(_ index: Int, at location: CGPoint) -> Bool? {
        let finger = self.tracked[index]
        guard !finger.directionDecided else {
            return nil
        }
        let dx = abs(location.x - finger.downLocation.x)
        let dy = abs(location.y - finger.downLocation.y)
        guard max(dx, dy) >= MessageWidgetTouchRecognizer.claimDistance else {
            return nil
        }
        self.tracked[index].directionDecided = true
        return dx >= dy
    }

    /// The touches are the widget's: the bubble's taps and long press, swipe-to-reply, the back swipe fail (the window's
    /// own recognizers are the system's and are left alone). `pans`: a finger went sideways, so the pans inside the
    /// chat's view (`failsAbove`) go too. `sparingOthers`: only the pans fail (`sparesUntilSlop`).
    private func failRecognizersAbove(pans: Bool, sparingOthers: Bool = false) {
        let chat = MessageWidgetTouchLock.chatView(of: self.view)
        var view = self.view?.superview
        while let current = view, !(current is UIWindow) {
            for recognizer in current.gestureRecognizers ?? [] where recognizer !== self && (!sparingOthers || recognizer is UIPanGestureRecognizer) && MessageWidgetTouchRecognizer.failsAbove(recognizer, pans: pans, chat: chat) && recognizer.state == .possible {
                recognizer.state = .failed
            }
            view = current.superview
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        var ended = false
        for touch in touches {
            guard let index = self.tracked.firstIndex(where: { $0.touch === touch }) else {
                continue
            }
            let finger = self.tracked.remove(at: index)
            let location = self.location(of: touch)
            _ = self.onTouch?(.ended, location, finger.pointer, finger.primary, finger.kind)
            ended = true
            if finger.kind.mouse && finger.kind.button == 2 && !finger.press.hold {
                self.onSecondaryClick?(location)
            }
        }
        self.updateHolding()
        if ended && self.tracked.isEmpty {
            self.state = self.state == .possible && !self.sequenceTakesTaps ? .failed : .ended
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        var cancelled = false
        for touch in touches {
            guard let index = self.tracked.firstIndex(where: { $0.touch === touch }) else {
                continue
            }
            let finger = self.tracked.remove(at: index)
            _ = self.onTouch?(.cancelled, finger.lastLocation, finger.pointer, finger.primary, finger.kind)
            cancelled = true
        }
        self.updateHolding()
        if cancelled && self.tracked.isEmpty {
            self.state = self.state == .possible ? .failed : .cancelled
        }
    }

    /// The host took the touches: each finger ends here as cancelled, and its later end is ignored. The widget no longer
    /// holds them either: a recognizer that took them ends cancelled, so UIKit resets it, and later questions are the
    /// later touches' (setExtracted and the view leaving its window come here, never through `reset`).
    func cancelTrackedTouches() {
        let fingers = self.tracked
        self.tracked = []
        self.tookTouches = false
        self.sequenceTakesTaps = false
        if self.state == .began || self.state == .changed {
            self.state = .cancelled
        }
        self.updateHolding()
        for finger in fingers {
            _ = self.onTouch?(.cancelled, finger.lastLocation, finger.pointer, finger.primary, finger.kind)
        }
    }

    /// UIKit resets a recognizer another one prevented without a `touchesCancelled`: the widget's fingers end there.
    override func reset() {
        super.reset()
        self.sequenceTakesTaps = false
        self.tookTouches = false
        self.preventsPans = false
        self.sparesUntilSlop = nil
        self.cancelTrackedTouches()
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if preventingGestureRecognizer is UITapGestureRecognizer || preventingGestureRecognizer is MessageWidgetChatLockRecognizer {
            return false
        }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        // A pan only once a finger went sideways (`preventsPans`): when the widget takes the touches for two fingers,
        // UIKit would otherwise fail every pan still possible, the chat's scroll included.
        if preventedGestureRecognizer is UIPanGestureRecognizer {
            return self.preventsPans
        }
        return super.canPrevent(preventedGestureRecognizer)
    }
}
