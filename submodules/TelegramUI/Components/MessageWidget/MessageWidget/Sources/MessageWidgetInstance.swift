import Foundation
import MessageWidgetRendering
import QuartzCore
import UIKit

/// One message widget, main's half (spec 2026-10-15 D2): the registry-facing API, the view, and the state the widget's
/// core last reported. Main never calls into the core: every change is one task of the core's (`MessageWidgetCore`),
/// which ends in a `WidgetSnapshot` that main applies in task order. Bridge calls and layout changes reach the host on
/// the main queue after their snapshot is applied, so a host reacting to them never re-enters a widget mid-apply.
/// Every task runs on the widget's queue in `MessageWidgetPool`; main waits for it within the turn's cap
/// (spec D3), and a snapshot that arrives later is applied, in order, from the handshake's mailbox.
/// SDK v1 §2.8 (V2b plan, Task 4): a widget's stored areas as the client keeps them, [key, value] in insertion order.
public struct MessageWidgetStorage: Equatable {
    public struct Entry: Equatable {
        public var key: String
        public var value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public var local: [Entry]
    public var session: [Entry]

    public init(local: [Entry], session: [Entry]) {
        self.local = local
        self.session = session
    }

    public static let empty = MessageWidgetStorage(local: [], session: [])
}

public enum MessageWidgetStorageArea: String {
    case local
    case session
}

public final class MessageWidgetInstance {
    /// SDK v1 §2.3 and §2.4 (WidgetTheme): the chat's colour scheme, its palette (theme key → #rrggbb), the client's
    /// button tokens and its text tokens. Two themes are equal when all four are, so a palette or text-size change in
    /// the same scheme is a change.
    public struct Theme: Equatable {
        public enum ColorScheme: Equatable {
            case light
            case dark
        }

        /// §2.4's tokens; a token left nil keeps the UA stylesheet's default.
        public struct ButtonTokens: Equatable {
            public var bg: String?
            public var text: String?
            public var radius: String?
            public var font: String?
            public var padding: String?
            public var height: String?
            public var pressedOpacity: Double?
            public var disabledOpacity: Double?

            public init(bg: String? = nil, text: String? = nil, radius: String? = nil, font: String? = nil, padding: String? = nil, height: String? = nil, pressedOpacity: Double? = nil, disabledOpacity: Double? = nil) {
                self.bg = bg
                self.text = text
                self.radius = radius
                self.font = font
                self.padding = padding
                self.height = height
                self.pressedOpacity = pressedOpacity
                self.disabledOpacity = disabledOpacity
            }

            /// As WRSession takes them.
            var dictionary: [String: Any] {
                var out: [String: Any] = [:]
                out["bg"] = self.bg
                out["text"] = self.text
                out["radius"] = self.radius
                out["font"] = self.font
                out["padding"] = self.padding
                out["height"] = self.height
                out["pressedOpacity"] = self.pressedOpacity
                out["disabledOpacity"] = self.disabledOpacity
                return out
            }
        }

        /// §2.4's text tokens (v0.1.1): the chat's message text. A token left nil is the reference value (15 px, 1.35,
        /// `8px 12px`); the runtime checks each against its grammar.
        public struct TextTokens: Equatable {
            /// CSS px (points), 8–64: the Text Size setting.
            public var fontSize: Double?
            /// Unitless, 1–3.
            public var lineHeight: Double?
            /// The body's margin: one to four lengths in px, em or rem.
            public var padding: String?

            public init(fontSize: Double? = nil, lineHeight: Double? = nil, padding: String? = nil) {
                self.fontSize = fontSize
                self.lineHeight = lineHeight
                self.padding = padding
            }

            /// As WRSession takes them.
            var dictionary: [String: Any] {
                var out: [String: Any] = [:]
                out["fontSize"] = self.fontSize
                out["lineHeight"] = self.lineHeight
                out["padding"] = self.padding
                return out
            }
        }

        public var colorScheme: ColorScheme
        public var params: [String: String]
        public var button: ButtonTokens
        public var text: TextTokens

        public init(colorScheme: ColorScheme, params: [String: String] = [:], button: ButtonTokens = ButtonTokens(), text: TextTokens = TextTokens()) {
            self.colorScheme = colorScheme
            self.params = params
            self.button = button
            self.text = text
        }

        /// The scheme alone: the framework's defaults for every colour and token.
        public static let light = Theme(colorScheme: .light)
        public static let dark = Theme(colorScheme: .dark)

        var isDark: Bool {
            return self.colorScheme == .dark
        }
    }

    /// §3.2: the whole content of a storage area a task changed, as the widget left it at the task's end.
    public struct StorageCommit: Equatable {
        public let area: MessageWidgetStorageArea
        public let entries: [MessageWidgetStorage.Entry]

        public init(area: MessageWidgetStorageArea, entries: [MessageWidgetStorage.Entry]) {
            self.area = area
            self.entries = entries
        }
    }

    /// SDK v1 §2.5: a link the runtime checked and the press allowed. The host must confirm either before it opens.
    /// §2.6: a haptic the runtime let through its rate limit: `impact` with a style, `notification` with a type, or
    /// `selection` with none.
    /// widget-sandbox v0.2 (sdk-v1 §2.13–§2.15): a request the runtime's gate admitted, to answer with
    /// `completeRequest(id:outcome:)` exactly once (`wallet`, v0.5.0: it asks for the user's wallet card); a text to copy,
    /// after a tap; whether the widget watches its shared state. v0.5.0 (§2.18): a wallet call the gate admitted, answered
    /// the same way.
    public enum BridgeCall: Equatable {
        case openLink(String)
        case openTelegramLink(String)
        case haptic(kind: String, value: String?)
        case request(id: Int64, data: Data, wallet: Bool)
        case wallet(id: Int64, call: MessageWidgetWalletCall)
        case copyText(String)
        case watchPublicData(Bool)
    }

    /// The longest URL `openLink` hands the host, in UTF-8 bytes; a longer one is refused.
    public static let maximumLinkLength = 4096
    /// A widget whose boot has not finished is the offered width × this (spec D5): a fixed default, so the relayout
    /// when the boot lands moves the chat by the difference only.
    public static let placeholderHeight: CGFloat = 160.0
    /// A timer, wake or frame task whose steps spend more than this of the widget thread's CPU, less the boot's own steps
    /// within their exemption (`WidgetSnapshot.bootCpuMilliseconds`), demotes its widget: from then on its timer and
    /// frame tasks are not waited for (spec D6; the CPU-clock limits design).
    static let demotionCpuMilliseconds: Double = 10.0

    public private(set) var layoutVersion: Int = 0
    public private(set) var deadReason: String?
    /// What the widget lets the reader select while its bubble is lifted into the context menu (sdk-v1 §5.10): the last
    /// export applied, nil when nothing is selectable or the bubble is not lifted.
    public private(set) var selectableText: MessageWidgetSelectableText?
    /// Called on main after `selectableText` changes.
    public var onSelectableTextChange: (() -> Void)?
    /// The bubble is lifted into its context menu: the widget keeps running, exports its selectable text after every
    /// publish, takes no input, and main waits for none of its tasks (the selection spec, §5.3).
    private(set) var extracted = false
    public private(set) var lastError: String?
    /// The runtime could not be created or the widget did not start: the host draws the block as code instead.
    public private(set) var failedToStart = false
    public var onLayoutChange: (() -> Void)?
    public var onBridge: ((BridgeCall) -> Void)?
    /// SDK v1 §5.4: each storage commit, on main at its task's end, in commit order and before that task's bridge
    /// calls; also for the task running when the widget was destroyed, even once the instance is released. None after
    /// the widget has stopped.
    public var onStorageCommit: ((StorageCommit) -> Void)? {
        get {
            return self.storageCommitSink.callback
        }
        set {
            self.storageCommitSink.callback = newValue
        }
    }

    /// Holds `onStorageCommit` for the core, which outlives the instance until its last task ends. Main thread only.
    final class StorageCommitSink {
        var callback: ((StorageCommit) -> Void)?
    }

    private let storageCommitSink: StorageCommitSink
    /// The first stop of a widget that booted (SDK v1 §5.7's count), on main as its snapshot is applied; never for one
    /// that started stopped.
    public var onStopped: (() -> Void)?
    /// Made stopped by the restart policy: it never ran, and shows the stopped badge only.
    public let startedStopped: Bool

    private let core: MessageWidgetCore
    /// Queues the core's tasks on the widget's queue in the pool, waits within the turn's cap, and hands
    /// their snapshots to `apply` in task order (spec D3).
    private let handshake: WidgetHandshake<WidgetSnapshot>
    private(set) var theme: Theme
    /// The size the latest applied snapshot reported; nil until one has.
    private var reportedSize: CGSize?
    /// The content height the widget last reported at the requested width; nil until its first render.
    public var reportedHeight: CGFloat? {
        return self.reportedSize?.height
    }
    /// The edge the widget asked to stay put when its height changes (sdk-v1 §5.6), as its latest live snapshot reported
    /// it; top until then. A stopped widget keeps the last one.
    public private(set) var resizeAnchor: MessageWidgetResizeAnchor = .top
    /// The width last asked of the core: the boot's, `layout`'s or `fill`'s.
    private var requestedWidth: CGFloat = 0.0
    /// The width the layout pass last offered (`layout(width:)`), and whether `fill` has set the widget's width since.
    /// A bubble wider than its widget asks for both on every pass, the offered width and then the fill; a filled widget
    /// keeps its width while the same width is offered (final review I1: two width tasks a pass, the fill's landing late
    /// with another size, laid the bubble out again without end).
    private var offeredWidth: CGFloat = 0.0
    private var filled = false
    private var bootQueued = false
    private var destroyed = false
    /// Set while `layout` or `fill` runs: a size applied then is the call's answer, not a change to report.
    private var inLayoutCall = false
    /// The maximum height the core has: the boot's, then the last change `layout` handed over.
    private var requestedMaximumHeight: CGFloat = WidgetTreeRenderer.maximumHeight
    private var requestedContentSafeArea: MessageWidgetContentSafeArea = .none
    private var appliedSequence = 0
    /// The tile draws main asked for, and the newest one applied: a draw is pending while they differ.
    private var drawRequested = 0
    private var drawApplied = 0
    private var frameRequested = false
    /// A frame task is queued or running: no other is queued until its snapshot is applied (spec D6).
    private var frameInFlight = false
    /// Its timer and frame tasks are no longer waited for (spec D6).
    private(set) var demoted = false
    /// Effective visibility: the bubble's (`setVisible`), the view's window and the app's active state together.
    private(set) var visible = true
    /// The effective visibility, for the host's work that follows the screen (sdk-v1 §2.13: shared state is polled only
    /// for widgets on screen).
    public var isVisible: Bool {
        return self.visible
    }
    /// Whether the widget watches its shared state (`TelegramWidget.watchPublicData`, sdk-v1 §2.13), as its last applied
    /// snapshot reported it; set before `onBridge` hears the call.
    public private(set) var watchesPublicData = false
    /// widget-sandbox v0.2 (W2): whether the host polls this widget's shared state: it watches and is effectively
    /// visible (on screen, in a window, the app active), and is not destroyed (upstream integration.md).
    public var wantsPublicDataPolling: Bool {
        return !self.destroyed && self.visible && self.watchesPublicData
    }
    /// Called on a later main-queue turn (as `onBridge`) when `wantsPublicDataPolling` changes, with the new value.
    public var onPublicDataPollingChange: ((Bool) -> Void)?
    /// The value `onPublicDataPollingChange` was last called with.
    private var reportedPublicDataPolling = false
    /// The bot's state as last set: the one the boot passes, then each change handed on (`setState`).
    private var state: MessageWidgetState
    private var hostVisible = true
    /// False once the view has left its window, until it is in one again. A view never put in a window does not
    /// hide the widget: the bubble's visibility decides then.
    private var windowAttached = true
    private var applicationObserver: NSObjectProtocol?
    /// The system's Reduce Motion, which the widget reads as prefers-reduced-motion: read at creation (on main) and
    /// followed through `UIAccessibility.reduceMotionStatusDidChangeNotification`.
    private var reducedMotion = UIAccessibility.isReduceMotionEnabled
    private var reduceMotionObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var viewStorage: MessageWidgetView?
    public private(set) var diagnostics: [(kind: String, detail: String)] = []
    /// Main's frame: the latest image of every tile (the tile layers' own contents, so it costs nothing extra).
    private let tileScale: CGFloat
    private var tileImages: [Int: CGImage] = [:]
    private var canvasColor: CGColor?
    private var canvasTop: CGFloat = 0.0
    private var bottomCornerColors: (left: CGColor?, right: CGColor?) = (nil, nil)
    private var frameSize: CGSize = .zero
    /// Tests only: the tasks main queued, by kind, waited for or not; the snapshots it applied, by kind.
    private(set) var queuedForTesting: [WidgetSnapshot.Kind: (waited: Int, unwaited: Int)] = [:]
    private(set) var appliedForTesting: [WidgetSnapshot.Kind: Int] = [:]

    /// `locale`: the client's UI language (SDK v1 §2.9, navigator.language).
    /// `storage`: the stored areas the widget reads at its first touch of each (SDK v1 §3.1). `startsStopped`: the
    /// restart policy's (§5.7): the widget's code never runs, and it shows the stopped badge.
    /// `context` and `state` (widget-sandbox v0.2): where the widget is and what it may do, fixed for its life; and the
    /// bot's state it starts with, which `setState` changes.
    /// `limits`: widget-sandbox v0.3.0's counted caps, strict for every widget the app shows (compat: the stress kit's
    /// measuring runs). `cpuLimits`: its runtime limits, the product's for every widget the app shows.
    public init?(source: String, theme: Theme, stoppedLabel: String, maxMessageLength: Int, locale: String = "en-US", storage: MessageWidgetStorage = .empty, context: MessageWidgetContext = MessageWidgetContext(), state: MessageWidgetState = .empty, startsStopped: Bool = false, pool: MessageWidgetPool = .shared, waitPolicy: MessageWidgetWaitPolicy = .standard, turn: MessageWidgetTurn = .shared, scale: CGFloat = UIScreen.main.scale, limits: MessageWidgetLimitPolicy = .strict, cpuLimits: MessageWidgetCpuLimits = .product) {
        let timers = MessageWidgetTimers()
        self.startedStopped = startsStopped
        let storageCommitSink = StorageCommitSink()
        self.storageCommitSink = storageCommitSink
        self.state = state
        self.core = MessageWidgetCore(source: source, stoppedLabel: stoppedLabel, maxMessageLength: maxMessageLength, locale: locale, storage: storage, context: context, startsStopped: startsStopped, commitSink: storageCommitSink, timers: timers, scale: scale, limits: limits, cpuLimits: cpuLimits)
        self.handshake = WidgetHandshake(queue: pool.makeQueue(), policy: waitPolicy, turn: turn)
        self.theme = theme
        self.tileScale = scale
        self.visible = MessageWidgetApplicationState.shared.isActive
        timers.fire = { [weak self] key, body in
            self?.timerFired(key: key, body)
        }
        self.handshake.apply = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        self.applicationObserver = NotificationCenter.default.addObserver(forName: MessageWidgetApplicationState.didChangeNotification, object: nil, queue: nil, using: { [weak self] _ in
            self?.updateVisibility()
        })
        self.reduceMotionObserver = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.setReducedMotion(UIAccessibility.isReduceMotionEnabled)
        })
    }

    deinit {
        // Not destroyed (a test's instance going out of scope): the core still leaves after its last task.
        let core = self.core
        self.handshake.queue.close {
            core.teardown()
        }
        self.displayLink?.invalidate()
        if let applicationObserver = self.applicationObserver {
            NotificationCenter.default.removeObserver(applicationObserver)
        }
        if let reduceMotionObserver = self.reduceMotionObserver {
            NotificationCenter.default.removeObserver(reduceMotionObserver)
        }
    }

    // MARK: host API (main thread)

    /// The tallest the widget's document may be: a bubble with a fixed height passes it (clamped to the 50...600 bounds), so
    /// its widget reports no more than the bubble shows and a stopped widget's badge stays inside the clip. Read by the
    /// next `layout`: the first boots with it, a later one hands a change to the running widget (an edit of the anchors
    /// keeps the runtime), waited for like a width.
    public var maximumHeight: CGFloat = WidgetTreeRenderer.maximumHeight
    /// widget-sandbox v0.4.0 (sdk-v1 §2.17, §5.12): what the bubble draws over the widget, its time over the bottom corner
    /// when no caption is below it. Read by the next `layout`: the first boots with it, so the first height has the band;
    /// a later one hands a change to the running widget, waited for like a width. An equal value is nothing.
    public var contentSafeArea: MessageWidgetContentSafeArea = .none

    /// The widget's size at most `width` wide (spec D5). The first call boots the widget, a new width relays it out;
    /// either is waited for within the turn's cap. Until it finishes the answer is the placeholder (no
    /// boot yet) or the previous size, and the bubble lays out again when it does (`onLayoutChange`).
    public func layout(width: CGFloat) -> CGSize {
        dispatchPrecondition(condition: .onQueue(.main))
        if self.destroyed {
            return self.answer(within: width)
        }
        self.inLayoutCall = true
        defer {
            self.inLayoutCall = false
        }
        if self.bootQueued, abs(self.maximumHeight - self.requestedMaximumHeight) >= 0.01 {
            self.requestedMaximumHeight = self.maximumHeight
            let maximumHeight = self.maximumHeight
            self.perform(.layout, wait: true, key: "maximumHeight") { core in
                core.setMaximumHeight(maximumHeight)
            }
        }
        if self.bootQueued, self.deadReason == nil, self.contentSafeArea != self.requestedContentSafeArea {
            // sdk-v1 §5.12: only with the bubble's layout (a caption edited, "edited"), never per frame: an equal value is
            // nothing, and a frozen widget takes none.
            self.requestedContentSafeArea = self.contentSafeArea
            let area = self.contentSafeArea
            self.perform(.layout, wait: true, key: "contentSafeArea") { core in
                core.setContentSafeArea(area)
            }
        }
        if !self.bootQueued {
            self.offeredWidth = width
            self.boot(width: width)
        } else if self.filled && abs(width - self.offeredWidth) <= 0.5 {
            // Filled since this width was offered: the fill's width stands, and the pass asks for it again next.
        } else {
            self.offeredWidth = width
            self.filled = false
            if abs(width - self.requestedWidth) > 0.5 {
                self.requestedWidth = width
                self.perform(.layout, wait: true, key: "width") { core in
                    core.setWidth(width, fill: false)
                }
            }
        }
        return self.answer(within: width)
    }

    /// Lays the widget out exactly `width` wide: its bubble came out wider than the widget's own width (a header,
    /// reactions), and the widget fills it as a photo fills its bubble. Later layouts keep that width.
    public func fill(width: CGFloat) -> CGSize {
        dispatchPrecondition(condition: .onQueue(.main))
        guard self.bootQueued, !self.destroyed else {
            return self.answer(within: width)
        }
        self.inLayoutCall = true
        defer {
            self.inLayoutCall = false
        }
        self.filled = true
        if abs(width - self.requestedWidth) > 0.5 {
            self.requestedWidth = width
            self.perform(.layout, wait: true, key: "width") { core in
                core.setWidth(width, fill: true)
            }
        }
        return self.answer(within: width)
    }

    /// What the layout pass gets: the latest snapshot's size, at most `width` wide; the placeholder until a snapshot
    /// has reported one (spec D5).
    private func answer(within width: CGFloat) -> CGSize {
        guard let size = self.reportedSize else {
            return CGSize(width: width, height: MessageWidgetInstance.placeholderHeight)
        }
        return CGSize(width: size.width > 0.0 ? min(size.width, width) : width, height: size.height)
    }

    public var view: MessageWidgetView {
        if let view = self.viewStorage {
            return view
        }
        let view = MessageWidgetView(instance: self)
        self.viewStorage = view
        view.update()
        if self.deadReason != nil {
            view.setDead()
        }
        return view
    }

    /// The frame the view shows: every tile's latest image.
    var currentFrame: WidgetFrame {
        return WidgetFrame(size: self.frameSize, scale: self.tileScale, tiles: self.tileImages, canvasColor: self.canvasColor, canvasTop: self.canvasTop, bottomLeftColor: self.bottomCornerColors.left, bottomRightColor: self.bottomCornerColors.right)
    }

    /// A theme change is waited for, like a width (spec D6), so the switch redraws in the same frame.
    public func setTheme(_ theme: Theme) {
        guard self.theme != theme else {
            return
        }
        self.theme = theme
        guard self.bootQueued, !self.destroyed else {
            return
        }
        self.perform(.theme, wait: true) { core in
            core.setTheme(theme)
        }
    }

    /// The bot's state changed (sdk-v1 §2.13): the widget gets chatDataChanged and publicDataChanged for what changed, and
    /// keeps its page. Before the boot it is the state the boot passes. Waited for like a theme: the change usually
    /// changes what the bubble shows.
    public func setState(_ state: MessageWidgetState) {
        guard self.state != state else {
            return
        }
        self.state = state
        guard self.bootQueued, !self.destroyed else {
            return
        }
        self.perform(.state, wait: true) { core in
            core.setState(state)
        }
    }

    /// The client's outcome for the widget's request or wallet call `id` (`BridgeCall.request`, `.wallet`; sdk-v1 §2.14,
    /// §2.18), settled in the widget's
    /// next task; never waited for. Nothing once the widget is destroyed, and the runtime ignores an id it has no request
    /// out for.
    public func completeRequest(id: Int64, outcome: MessageWidgetRequestOutcome) {
        guard self.bootQueued, !self.destroyed else {
            return
        }
        self.perform(.state, wait: false) { core in
            core.completeRequest(id: id, outcome: outcome)
        }
    }

    /// The bubble's visibility. The widget is visible only while this is true, its view is in a window and the app
    /// is active (`MessageWidgetApplicationState`).
    /// The system's Reduce Motion changed (the observer's; tests call it): the widget's prefers-reduced-motion follows.
    func setReducedMotion(_ reduced: Bool) {
        guard self.reducedMotion != reduced else {
            return
        }
        self.reducedMotion = reduced
        guard self.bootQueued, !self.destroyed else {
            return
        }
        self.perform(.theme, wait: true) { core in
            core.setReducedMotion(reduced)
        }
    }

    public func setVisible(_ visible: Bool) {
        guard self.hostVisible != visible else {
            return
        }
        self.hostVisible = visible
        self.updateVisibility()
    }

    /// Leaves main at once; the core is torn down after its current task, if any (spec D5).
    public func destroy() {
        if self.destroyed {
            return
        }
        self.destroyed = true
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.publicDataPollingMayHaveChanged()
        let core = self.core
        self.handshake.queue.close {
            core.teardown()
        }
    }

    /// A pointer phase, as `MessageWidgetView`'s touch recognizer delivers them.
    public enum PointerPhase: Int32 {
        case down = 0
        case move = 1
        case up = 2
        case cancel = 3
    }

    /// `phase` at `point` (CSS px from the widget's top-left), delivered as the view's touch recognizer delivers it: the
    /// conformance runner's scripted input (widget-sandbox v0.1.0 CLIENTS.md step 6). An up carries the tap's
    /// permission. Main thread; waited for.
    public func pointer(_ phase: PointerPhase, at point: CGPoint) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.touch(action: phase.rawValue, at: point, pointer: 0, primary: true)
    }

    // MARK: internal (view, tests)

    /// A touch is waited for (spec D6); its task carries the tap's permission (`MessageWidgetCore.touch`).
    /// A press's down answers what the press is to the widget (SDK v1 §5.5); `.unanswered` when the down has not run
    /// within the wait.
    @discardableResult
    func touch(action: Int32, at point: CGPoint, pointer: Int32, primary: Bool, mouse: Bool = false, button: Int = 0) -> MessageWidgetPress {
        guard self.bootQueued, !self.destroyed, self.deadReason == nil else {
            return .none
        }
        // Lifted, the widget takes no input; only a cancel or a retraction, which end a press the lift interrupted, still
        // reach it.
        if self.extracted && action != 3 && action != 4 {
            return .none
        }
        var press: MessageWidgetPress = .none
        let finished = self.perform(.touch, wait: true) { core in
            press = core.touch(action: action, at: point, pointer: pointer, primary: primary, mouse: mouse, button: button)
        }
        return finished ? press : .unanswered
    }

    /// The bubble was lifted into its context menu, or put back (`MessageWidgetView.setExtracted`).
    func setExtracted(_ extracted: Bool) {
        guard extracted != self.extracted else {
            return
        }
        self.extracted = extracted
        if extracted {
            self.requestSelectionExport()
        } else {
            self.updateSelectableText(nil)
        }
    }

    /// Queues the export after the tasks queued so far; never waited for, and one still queued is replaced.
    private func requestSelectionExport() {
        guard self.extracted, self.bootQueued, !self.destroyed, self.deadReason == nil else {
            return
        }
        let visibleHeight = self.maximumHeight
        self.perform(.selection, wait: false, key: "selection") { core in
            core.exportSelection(visibleHeight: visibleHeight)
        }
    }

    private func updateSelectableText(_ text: MessageWidgetSelectableText?) {
        guard text != self.selectableText else {
            return
        }
        self.selectableText = text
        DispatchQueue.main.async { [weak self] in
            self?.onSelectableTextChange?()
        }
    }

    /// From the view's `didMoveToWindow`: a view out of its window (a screen pushed over the chat) hides the widget.
    func viewWindowDidChange(attached: Bool) {
        self.windowAttached = attached
        self.updateVisibility()
    }

    /// Applies the effective visibility: hidden, the widget gets no frames, its timers fire at 1 Hz and the shim
    /// reports `document.hidden`. Never waited for; the newest change replaces one still queued (spec D6).
    private func updateVisibility() {
        let visible = self.hostVisible && self.windowAttached && MessageWidgetApplicationState.shared.isActive
        guard visible != self.visible else {
            return
        }
        self.visible = visible
        if self.bootQueued {
            self.perform(.visibility, wait: false, key: "visibility") { core in
                core.setVisible(visible)
            }
        }
        self.updateDisplayLink()
        self.publicDataPollingMayHaveChanged()
    }

    private func publicDataPollingMayHaveChanged() {
        let wants = self.wantsPublicDataPolling
        guard wants != self.reportedPublicDataPolling else {
            return
        }
        self.reportedPublicDataPolling = wants
        // On a later main-queue turn, as `onBridge` is: never inside the layout pass (or the registry's loop) that made
        // the change, where the host has not taken its new item yet.
        DispatchQueue.main.async { [weak self] in
            self?.onPublicDataPollingChange?(wants)
        }
    }

    func evaluateForTesting(_ code: String) -> String? {
        var result: String?
        let finished = self.perform(.event, wait: true, policy: .unbounded) { core in
            result = core.evaluate(code)
        }
        return finished ? result : nil
    }

    /// The live document's `<html>` attribute `name`, read where the widget's work runs, after every task queued before
    /// it (the conformance runner reads `data-conformance`, widget-sandbox v0.1.0 CLIENTS.md). nil when absent or once
    /// the widget is destroyed. Main thread; waits for its turn on the widget's queue.
    public func documentElementAttribute(_ name: String) -> String? {
        dispatchPrecondition(condition: .onQueue(.main))
        return self.onCore { $0.documentElementAttribute(name) } ?? nil
    }

    /// The widget's document, `rect` (CSS px) drawn at `scale` by its renderer, where the widget's work runs (the
    /// conformance runner's 2× crops). nil before the first render or once the widget is destroyed. Main thread.
    public func documentImage(rect: CGRect, scale: CGFloat) -> CGImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        return self.onCore { $0.renderer?.image(rect: rect, scale: scale) } ?? nil
    }

    /// Tests only: `body` on the core, as a task of its own after every task queued before it (no snapshot); nil once the
    /// widget is destroyed.
    /// The stress kit's statistics (widget-sandbox v0.3.0, packages/stress), read on the widget's queue after what it
    /// runs now; nil once the widget has no session (stopped, destroyed). Development tooling: it waits for the queue.
    public func stressStats() -> MessageWidgetStressStats? {
        return self.onCore { $0.stressStats() } ?? nil
    }

    func onCoreForTesting<T>(_ body: @escaping (MessageWidgetCore) -> T) -> T? {
        return self.onCore(body)
    }

    private func onCore<T>(_ body: @escaping (MessageWidgetCore) -> T) -> T? {
        let core = self.core
        var result: T?
        let done = DispatchSemaphore(value: 0)
        let queued = self.handshake.queue.enqueue {
            result = body(core)
            done.signal()
        }
        guard queued else {
            return nil
        }
        done.wait()
        return result
    }

    /// Tests only (planning ruling 6, spec D9's stuck widget): holds the next task the instance queues. The task
    /// signals `started` once a thread runs it, then waits for `release` before doing anything. Never used with
    /// `.unbounded`: main would wait for a task that waits for main.
    final class TaskGate {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)

        fileprivate func pass() {
            self.started.signal()
            self.release.wait()
        }
    }

    private var pendingGate: TaskGate?

    func gateNextTaskForTesting() -> TaskGate {
        let gate = TaskGate()
        self.pendingGate = gate
        return gate
    }

    /// Tests only: no task of the widget's is running or queued.
    var isIdleForTesting: Bool {
        return self.handshake.queue.isIdle
    }

    /// Tests only: the most CPU milliseconds a core task of `kind` spent in its runtime steps.
    func largestTaskCpuMillisecondsForTesting(_ kind: WidgetSnapshot.Kind) -> Double {
        return self.onCoreForTesting { $0.largestTaskCpuMilliseconds[kind] ?? 0.0 } ?? 0.0
    }

    /// Tests only: the steps the CPU windows deferred so far.
    var throttledStepsForTesting: UInt64 {
        return self.onCoreForTesting { $0.session?.stats()?.throttledSteps ?? 0 } ?? 0
    }

    // MARK: tasks and snapshots

    private func boot(width: CGFloat) {
        self.bootQueued = true
        self.requestedWidth = width
        // Read here, on main: a test clears it in a `defer` that may run before a boot it did not wait for.
        let theme = self.theme, visible = self.visible, maximumHeight = self.maximumHeight
        let reducedMotion = self.reducedMotion
        let state = self.state
        let contentSafeArea = self.contentSafeArea
        self.requestedMaximumHeight = maximumHeight
        self.requestedContentSafeArea = contentSafeArea
        self.perform(.boot, wait: true) { core in
            core.setState(state)
            core.boot(width: width, maximumHeight: maximumHeight, theme: theme, visible: visible, reducedMotion: reducedMotion, contentSafeArea: contentSafeArea)
        }
    }

    /// Runs one task of the core (spec D2: main never calls into it) and applies its snapshot. True when the snapshot
    /// was applied before this returned.
    @discardableResult
    private func perform(_ kind: WidgetSnapshot.Kind, wait: Bool, key: String? = nil, policy: MessageWidgetWaitPolicy? = nil, _ work: @escaping (MessageWidgetCore) -> Void) -> Bool {
        guard !self.destroyed else {
            return false
        }
        if wait {
            self.queuedForTesting[kind, default: (waited: 0, unwaited: 0)].waited += 1
        } else {
            self.queuedForTesting[kind, default: (waited: 0, unwaited: 0)].unwaited += 1
        }
        let core = self.core
        let gate = self.pendingGate
        self.pendingGate = nil
        return self.handshake.run(wait: wait, key: key, policy: policy) {
            gate?.pass()
            return core.run(kind) {
                work(core)
            }
        }
    }

    /// Main: one task's snapshot, in task order (spec D4).
    private func apply(_ snapshot: WidgetSnapshot) {
        assert(snapshot.sequence > self.appliedSequence, "widget snapshots applied out of order")
        self.appliedSequence = snapshot.sequence
        self.appliedForTesting[snapshot.kind, default: 0] += 1
        if snapshot.kind == .frame {
            self.frameInFlight = false
        }
        // A task running when the widget was destroyed changes nothing (spec D5).
        if self.destroyed {
            return
        }
        for diagnostic in snapshot.diagnostics where self.diagnostics.count < 500 {
            self.diagnostics.append(diagnostic)
        }
        self.lastError = snapshot.lastError
        if !self.demoted, [.timer, .wake, .frame].contains(snapshot.kind),
           snapshot.cpuMilliseconds - snapshot.bootCpuMilliseconds > MessageWidgetInstance.demotionCpuMilliseconds {
            self.demoted = true
        }
        if let frame = snapshot.frame {
            self.applyFrame(frame)
        }
        var changed = false
        switch snapshot.state {
        case .live:
            self.resizeAnchor = snapshot.resizeAnchor
        case let .frozen(reason):
            if self.deadReason == nil {
                self.deadReason = reason
                self.updateSelectableText(nil)
                self.frameRequested = false
                self.viewStorage?.setDead()
                if !self.startedStopped {
                    self.onStopped?()
                }
            }
        case .failedToStart:
            if !self.failedToStart {
                self.failedToStart = true
                changed = true
            }
        }
        // Laid out at a width main has since asked to change: its tiles and state apply, but the size to answer with is
        // the newer width's, whose task is queued behind this one (planning ruling 3).
        let atRequestedWidth = abs(snapshot.width - self.requestedWidth) <= 0.5
        if atRequestedWidth, let size = snapshot.size, size != self.reportedSize {
            self.reportedSize = size
            changed = true
        }
        // A change the layout pass did not ask for (a task's, or a boot or width that finished after its wait): the
        // bubble lays out again (spec D5).
        if changed && !self.inLayoutCall {
            self.layoutVersion += 1
            DispatchQueue.main.async { [weak self] in
                self?.onLayoutChange?()
            }
        }
        if snapshot.exportsSelection {
            if self.extracted {
                self.updateSelectableText(snapshot.selectableText)
            }
        } else if self.extracted, snapshot.kind != .draw, snapshot.needsDraw || changed {
            // Every publish while lifted re-exports: a transform animation moves text without a layout change.
            self.requestSelectionExport()
        }
        for call in snapshot.bridgeCalls {
            if case let .watchPublicData(on) = call {
                self.watchesPublicData = on
                self.publicDataPollingMayHaveChanged()
            }
            DispatchQueue.main.async { [weak self] in
                self?.onBridge?(call)
            }
        }
        if snapshot.wantsFrame {
            self.frameRequested = true
        }
        self.updateDisplayLink()
        if snapshot.kind == .draw {
            self.drawApplied = max(self.drawApplied, snapshot.drawRequest)
        }
        if snapshot.needsDraw {
            self.requestDraw()
        }
    }

    /// Queues the tiles' drawing after the tasks queued so far, never waited for. A draw still waiting is replaced in its
    /// place, and draws everything changed by the time it runs.
    private func requestDraw() {
        self.drawRequested += 1
        let request = self.drawRequested
        self.perform(.draw, wait: false, key: "draw") { core in
            core.draw(request: request)
        }
    }

    /// Tests only: a tile draw main asked for has not been applied yet.
    var isDrawPendingForTesting: Bool {
        return !self.destroyed && self.drawApplied < self.drawRequested
    }

    /// Merges a task's changed tiles into main's frame, drops the tiles outside its size, and shows it.
    private func applyFrame(_ changed: WidgetFrame) {
        self.frameSize = changed.size
        self.canvasColor = changed.canvasColor
        self.canvasTop = changed.canvasTop
        self.bottomCornerColors = (changed.bottomLeftColor, changed.bottomRightColor)
        self.tileImages.merge(changed.tiles) { _, new in
            new
        }
        let grid = Set(WidgetFrame.grid(for: changed.size))
        self.tileImages = self.tileImages.filter { grid.contains($0.key) }
        self.viewStorage?.apply(self.currentFrame)
    }

    /// Main: an engine timer, or the hidden widget's 1 Hz wake, fired. Queued as a task, and waited for while the widget
    /// is visible and not demoted (spec D6); `key` replaces a fire of the same timer still waiting. A destroyed widget's
    /// fire queues nothing (`perform`).
    private func timerFired(key: String, _ body: @escaping () -> Void) {
        self.perform(key == "wake" ? .wake : .timer, wait: self.visible && !self.demoted && !self.extracted, key: key) { _ in
            body()
        }
    }

    // MARK: frames

    private final class DisplayLinkTarget: NSObject {
        weak var instance: MessageWidgetInstance?

        init(instance: MessageWidgetInstance) {
            self.instance = instance
            super.init()
        }

        @objc func tick(_ link: CADisplayLink) {
            self.instance?.frameTick()
        }
    }

    /// Whether the display link should run: a frame is requested and the widget is visible and alive.
    private var wantsFrames: Bool {
        return self.frameRequested && self.visible && !self.destroyed && self.deadReason == nil
    }

    /// Tests only: the display link's tick, when the instance wants one. A test process may have no
    /// display to tick it: under Bazel's test runner `CADisplayLink(target:selector:)` returns nil.
    func deliverFrameForTesting() {
        if self.wantsFrames {
            self.frameTick()
        }
    }

    private func updateDisplayLink() {
        let wanted = self.wantsFrames
        if wanted, self.displayLink == nil {
            let link = CADisplayLink(target: DisplayLinkTarget(instance: self), selector: #selector(DisplayLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        } else if !wanted, let link = self.displayLink {
            link.invalidate()
            self.displayLink = nil
        }
    }

    /// One frame task at a time (spec D6), waited for while the widget is visible and not demoted.
    private func frameTick() {
        guard self.frameRequested, !self.frameInFlight, !self.destroyed else {
            return
        }
        self.frameRequested = false
        self.frameInFlight = true
        let time = CACurrentMediaTime() * 1000.0
        self.perform(.frame, wait: self.visible && !self.demoted && !self.extracted, key: "frame") { core in
            core.frame(time: time)
        }
        self.updateDisplayLink()
    }
}
