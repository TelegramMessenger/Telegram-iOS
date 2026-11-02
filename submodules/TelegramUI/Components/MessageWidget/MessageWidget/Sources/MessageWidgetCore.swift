import Foundation
import MessageWidgetRendering
import QuartzCore
import WidgetRuntimeIOS
import WidgetSandboxIntl

/// One message widget, the worker half (spec 2026-10-15 D2), on WidgetRuntime (M1d plan, Task 8): its session
/// (`WRSession`: the runtime, its render tree and its CoreText host), its tree renderer and its tile drawer. Main never
/// calls into it: each method runs inside one of the widget's tasks (`MessageWidgetInstance.perform` → `run`), on the
/// thread running that task, and nothing here calls the host back — bridge calls, the size, the tiles and the state
/// leave in the task's `WidgetSnapshot`.
final class MessageWidgetCore {
    /// The most runtime steps one core task runs: a wake right after it runs the rest, so a widget that keeps a task
    /// runnable cannot hold its queue. Each step has its own CPU slice (widget-sandbox's limits, `MessageWidgetCpuLimits`).
    static let maximumStepsPerTask = 256
    /// The boot's own steps (its scripts and its load) never demote the widget for its first this many slices of CPU in
    /// all: a run of heavy scripts past them would keep main waiting for its wakes for as long as it lasted (the fourth
    /// fix-wave review).
    static let bootDemotionExemptionSlices = 2.0
    /// Tests only: the CPU and wall clocks (milliseconds) of every session made while set; the widget thread's otherwise.
    static var cpuClockForTesting: (cpu: () -> Double, wall: () -> Double)?
    /// Tests only: a source this answers true for fails to start, as when no session can be made (the pill).
    static var startFailureForTesting: ((String) -> Bool)?
    /// The longest bridge method name; a longer one is ignored.
    static let maximumBridgeMethodLength = 64
    private let source: String
    private let stoppedLabel: String
    private let maxMessageLength: Int
    /// SDK v1 §2.9: navigator.language.
    private let locale: String
    private let timers: MessageWidgetTimers
    /// The tiles' scale: the session records its drawing pixel-snapped at it.
    private let scale: CGFloat
    private let drawer: WidgetTileDrawer

    private(set) var renderer: WidgetTreeRenderer?
    private(set) var session: WRSession?
    /// The session's delegate, which it holds weakly.
    private var sessionDelegate: SessionDelegate?
    private var width: CGFloat = 0.0
    /// What the bubble draws over the widget (sdk-v1 §2.17), as last handed to the session.
    private var contentSafeArea: MessageWidgetContentSafeArea = .none
    private var visible = true
    private var state: WidgetSnapshot.State = .live
    private var tornDown = false
    private var bridgeCalls: [MessageWidgetInstance.BridgeCall] = []
    private var storageCommits: [MessageWidgetInstance.StorageCommit] = []
    /// Where the commits go: posted to main by the task itself, so the commits of a task running when its widget was
    /// destroyed and released still arrive (an area the widget reached is kept; spec D5 drops its presentation only).
    private let commitSink: MessageWidgetInstance.StorageCommitSink
    /// The stored areas the session reads at the widget's first touch of each (SDK v1 §3.1).
    private let storage: MessageWidgetStorage
    /// The message's context, fixed for the widget's life (sdk-v1 §2.14), set on the session before its boot.
    private let context: MessageWidgetContext
    /// The bot's state as last set (sdk-v1 §2.13): the one the boot starts with, then each change passed on.
    private var widgetState: MessageWidgetState = .empty
    /// The restart policy stopped the widget for good (SDK v1 §5.7): its boot makes no session.
    private let startsStopped: Bool
    private var diagnostics: [(kind: String, detail: String)] = []
    private var diagnosticCount = 0
    private var lastError: String?
    /// What the running task exported for the selection, when it is a `.selection` task.
    private var exportedSelection: (text: MessageWidgetSelectableText?, done: Bool) = (nil, false)
    private var sequence = 0
    /// The main-run-loop wake for the session's next runnable task or timer, and when it fires (CACurrentMediaTime s).
    private var wake: MessageWidgetTimerHandle?
    private var wakeAt = Double.infinity

    /// Tests only: the most CPU milliseconds a task of each kind spent in its runtime steps (its snapshot's).
    private(set) var largestTaskCpuMilliseconds: [WidgetSnapshot.Kind: Double] = [:]
    /// The request number of the draw task running now (MessageWidgetInstance's).
    private var drawRequest = 0
    /// Tests only: the wall time of the last task's runtime work (its steps, publish included) and of its tile drawing.
    private(set) var lastStepMilliseconds: Double = 0.0
    private(set) var lastDrawMilliseconds: Double = 0.0
    /// The stress kit's runner (MessageWidgetStressStats): every task's step and draw time, and the frame and draw tasks.
    private var totalStepMilliseconds: Double = 0.0
    private var totalDrawMilliseconds: Double = 0.0
    private var frameTasks = 0
    private var drawTasks = 0
    /// Tests only: the loads the renderer refused (it fetches nothing), as of the last task; -1 without a session.
    private(set) var refusedLoads = -1
    /// The counted caps the session runs under (widget-sandbox v0.3.0), and its CPU limits.
    private let limits: MessageWidgetLimitPolicy
    private let cpuLimits: MessageWidgetCpuLimits

    init(source: String, stoppedLabel: String, maxMessageLength: Int, locale: String = "en-US", storage: MessageWidgetStorage = .empty, context: MessageWidgetContext = MessageWidgetContext(), startsStopped: Bool = false, commitSink: MessageWidgetInstance.StorageCommitSink = MessageWidgetInstance.StorageCommitSink(), timers: MessageWidgetTimers, scale: CGFloat, limits: MessageWidgetLimitPolicy = .strict, cpuLimits: MessageWidgetCpuLimits = .product) {
        self.limits = limits
        self.cpuLimits = cpuLimits
        self.source = source
        self.commitSink = commitSink
        self.storage = storage
        self.context = context
        self.startsStopped = startsStopped
        self.stoppedLabel = stoppedLabel
        self.maxMessageLength = maxMessageLength
        self.locale = locale
        self.timers = timers
        self.scale = scale
        self.drawer = WidgetTileDrawer(scale: scale)
    }

    // MARK: tasks

    /// One task: `body`, then the tree it published and the next wake, then its snapshot. Tiles are drawn only by a `.draw` task (the user, 2026-10-19: drawing may be async; only the size is
    /// critical), which main queues after a snapshot whose tree changed.
    func run(_ kind: WidgetSnapshot.Kind, _ body: () -> Void) -> WidgetSnapshot {
        // The task's CPU: its steps', each measured on this thread (a boot's session is made inside it).
        let cpuBefore = self.session?.stepCpuMilliseconds ?? 0.0
        // Of it, the boot lifecycle's own steps (its scripts and its load), wherever they run: no demotion within their
        // first `bootDemotionExemptionSlices` slices of CPU in all (the boot task's own included).
        let bootCpuBefore = self.session?.bootCpuMilliseconds ?? 0.0
        let stepStart = CACurrentMediaTime()
        if !self.tornDown {
            body()
        }
        // Read before the publish, which drops the session of a widget the task stopped.
        let bootExemption = MessageWidgetCore.bootDemotionExemptionSlices * self.cpuLimits.cpuLimitMs
        let bootCpuMilliseconds = self.session.map { max(0.0, min($0.bootCpuMilliseconds, bootExemption) - min(bootCpuBefore, bootExemption)) } ?? 0.0
        let cpuMilliseconds = self.session.map { max(0.0, $0.stepCpuMilliseconds - cpuBefore) } ?? 0.0
        self.publish()
        var frame: WidgetFrame?
        if kind == .draw {
            let drawStart = CACurrentMediaTime()
            frame = self.renderer.map { self.drawer.draw($0) }
            // A tile the renderer could not draw though it has a tree (a bitmap past its pixel cap, a refused
            // allocation): the drawer keeps the last frame up, and the diagnostics say why it is stale.
            if let renderer = self.renderer, renderer.hasTree, self.drawer.needsDraw(renderer) {
                self.appendDiag("tile-draw-failed", "the last frame stays at \(Int(renderer.documentSize.width))x\(Int(renderer.documentSize.height))")
            }
            self.lastDrawMilliseconds = (CACurrentMediaTime() - drawStart) * 1000.0
            self.totalDrawMilliseconds += self.lastDrawMilliseconds
            self.drawTasks += 1
        } else {
            self.lastStepMilliseconds = (CACurrentMediaTime() - stepStart) * 1000.0
            self.totalStepMilliseconds += self.lastStepMilliseconds
            if kind == .frame {
                self.frameTasks += 1
            }
        }
        self.largestTaskCpuMilliseconds[kind] = max(self.largestTaskCpuMilliseconds[kind] ?? 0.0, cpuMilliseconds)
        let needsDraw = kind != .draw && self.renderer.map { self.drawer.needsDraw($0) } == true
        self.scheduleWake()
        self.sequence += 1
        let wantsFrame = self.state == .live && self.session?.wantsAnimationFrame() == true
        let resizeAnchor: MessageWidgetResizeAnchor = self.session?.resizeAnchor == .bottom ? .bottom : .top
        let snapshot = WidgetSnapshot(sequence: self.sequence, kind: kind, width: self.width, size: self.renderer?.documentSize, resizeAnchor: resizeAnchor, frame: frame, needsDraw: needsDraw, drawRequest: kind == .draw ? self.drawRequest : 0, state: self.state, bridgeCalls: self.bridgeCalls, wantsFrame: wantsFrame, lastError: self.lastError, diagnostics: self.diagnostics, bootCpuMilliseconds: bootCpuMilliseconds, cpuMilliseconds: cpuMilliseconds, selectableText: self.exportedSelection.text, exportsSelection: self.exportedSelection.done)
        self.exportedSelection = (nil, false)
        self.bridgeCalls.removeAll()
        if !self.storageCommits.isEmpty {
            // Posted before the snapshot is handed over, so they reach main ahead of the snapshot's bridge calls.
            let commits = self.storageCommits
            let sink = self.commitSink
            DispatchQueue.main.async {
                for commit in commits {
                    sink.callback?(commit)
                }
            }
            self.storageCommits.removeAll()
        }
        self.diagnostics.removeAll()
        return snapshot
    }

    /// Creates the session and runs the widget's parse and boot. A session that cannot be made or a boot that does not
    /// start (a C++ failure, nothing published) is `.failedToStart`, but for markup past a count cap, which is `.frozen`
    /// with the badge alone; a boot its scripts stopped is `.frozen`, as at any other time, with its parsed markup.
    func boot(width: CGFloat, maximumHeight: CGFloat = WidgetTreeRenderer.maximumHeight, theme: MessageWidgetInstance.Theme, visible: Bool, reducedMotion: Bool = false, contentSafeArea: MessageWidgetContentSafeArea = .none) {
        self.width = width
        self.visible = visible
        if self.startsStopped {
            // §5.7: stopped twice in a row; the badge alone, and none of the widget's code runs.
            let renderer = WidgetTreeRenderer(width: width, maximumHeight: maximumHeight)
            renderer.freeze(label: self.stoppedLabel)
            self.renderer = renderer
            self.state = .frozen("Stopped twice in a row")
            return
        }
        if let fails = MessageWidgetCore.startFailureForTesting, fails(self.source) {
            self.appendDiag("core-error", "the widget runtime could not be created")
            self.state = .failedToStart
            return
        }
        let delegate = SessionDelegate(core: self)
        guard let session = WRSession(width: width, dark: theme.isDark, themeParams: theme.params, buttonTokens: theme.button.dictionary, textTokens: theme.text.dictionary, scale: self.scale, delegate: delegate, policy: self.limits == .compat ? .compat : .strict, cpuLimits: self.cpuLimits.session) else {
            self.appendDiag("core-error", "the widget runtime could not be created")
            self.state = .failedToStart
            return
        }
        self.sessionDelegate = delegate
        if let clock = MessageWidgetCore.cpuClockForTesting {
            session.setCpuClockForTesting(clock.cpu, wall: clock.wall)
        }
        session.setLocale(self.locale)
        // The first layout's prefers-reduced-motion: the render tree exists already, the boot builds it.
        session.setReducedMotion(reducedMotion)
        // sdk-v1 §2.17: what the bubble draws over the widget, in the first layout, so the first height has the band.
        self.contentSafeArea = contentSafeArea
        session.setContentSafeAreaTop(Double(contentSafeArea.top), right: Double(contentSafeArea.right), bottom: Double(contentSafeArea.bottom), left: Double(contentSafeArea.left), cornerLeft: Double(contentSafeArea.cornerLeft), cornerRight: Double(contentSafeArea.cornerRight))
        session.setStoragePreloadLocal(self.storage.local.map { [$0.key, $0.value] }, session: self.storage.session.map { [$0.key, $0.value] })
        let context = self.context
        let viewer = context.viewer.map { WRWidgetViewer(id: $0.id, firstName: $0.firstName, lastName: $0.lastName, username: $0.username, isPremium: $0.isPremium) }
        session.setContextCopy(context.isCopy, canQuery: context.canQuery, backgroundQuery: context.backgroundQuery, chatType: context.chatType?.rawValue, viewer: viewer, preview: context.isPreview, wallet: context.wallet)
        session.setChatData(self.widgetState.chatData, publicData: self.widgetState.publicData)
        self.session = session
        self.renderer = WidgetTreeRenderer(width: width, maximumHeight: maximumHeight)
        // A document starts visible; a hidden one is hidden by a task that runs before the boot's scripts.
        if !visible {
            session.setVisible(false)
        }
        let started = session.boot(withSource: self.source)
        if !started && session.stopReason == .limit, let renderer = self.renderer {
            // The parsed markup already passes a counted cap: a stop, never the pill, which tells the user to update
            // the app. Nothing was published, so the badge stands alone, as for a widget stopped twice in a row.
            self.state = .frozen(session.stopDetail ?? "Limit exceeded")
            self.refusedLoads = Int(clamping: session.refusedLoads)
            renderer.freeze(label: self.stoppedLabel)
            self.dropSession()
        } else if !started {
            self.appendDiag("core-error", session.failed ? "the widget runtime failed" : "the widget did not start")
            self.state = .failedToStart
            self.renderer = nil
            self.dropSession()
        }
    }

    /// A new width (`fill`: exactly that width, for a bubble wider than the widget's own; the session lays out at the
    /// width either way). A frozen widget keeps its last tree, clipped to the new width.
    func setWidth(_ width: CGFloat, fill: Bool) {
        self.width = width
        self.renderer?.setWidth(width)
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setWidth(width)
        // The width change's rendering update (media changes, ResizeObserver, IntersectionObserver) is a task.
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The stress kit's statistics now (widget-sandbox v0.3.0, packages/stress); nil without a session.
    func stressStats() -> MessageWidgetStressStats? {
        guard let session = self.session, let stats = session.stats() else {
            return nil
        }
        return MessageWidgetStressStats(stepMilliseconds: self.totalStepMilliseconds, drawMilliseconds: self.totalDrawMilliseconds, flushMilliseconds: stats.flushMilliseconds, frameTasks: self.frameTasks, drawTasks: self.drawTasks, totalOps: stats.totalOps, maxBatchOps: stats.maxBatchOps, layoutQueries: stats.layoutQueries, heapBytes: stats.heapBytes, nodes: stats.nodes, jsMilliseconds: stats.jsMilliseconds, queryMilliseconds: stats.queryMilliseconds, largestStepMilliseconds: stats.largestStepMilliseconds, throttledSteps: stats.throttledSteps)
    }

    /// The live document's `<html>` attribute `name` (`WRSession.documentElementAttribute`).
    func documentElementAttribute(_ name: String) -> String? {
        return self.session?.documentElementAttribute(name)
    }

    /// The most the document may be tall (`WidgetTreeRenderer.setMaximumHeight`): the next snapshot carries the new size.
    func setMaximumHeight(_ maximumHeight: CGFloat) {
        self.renderer?.setMaximumHeight(maximumHeight)
    }

    /// What the bubble draws over the widget changed (sdk-v1 §2.17, §5.12): the session lays out now and gives the widget
    /// its contentSafeAreaChanged in a task, which runs in this one. An equal value is nothing.
    func setContentSafeArea(_ area: MessageWidgetContentSafeArea) {
        guard area != self.contentSafeArea else {
            return
        }
        self.contentSafeArea = area
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setContentSafeAreaTop(Double(area.top), right: Double(area.right), bottom: Double(area.bottom), left: Double(area.left), cornerLeft: Double(area.cornerLeft), cornerRight: Double(area.cornerRight))
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The theme: the session rebuilds now and queues the TelegramWidget.onTheme callbacks, which run in this task.
    func setTheme(_ theme: MessageWidgetInstance.Theme) {
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setDark(theme.isDark, themeParams: theme.params, buttonTokens: theme.button.dictionary, textTokens: theme.text.dictionary)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The bot's state (sdk-v1 §2.13). Before the boot it is the state the boot starts with; after it, a change the
    /// session puts in place with its events, which run in this task.
    func setState(_ state: MessageWidgetState) {
        self.widgetState = state
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setChatData(state.chatData, publicData: state.publicData)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The client's outcome for the widget's request or wallet call `id` (sdk-v1 §2.14, §2.18), settled in this task.
    func completeRequest(id: Int64, outcome: MessageWidgetRequestOutcome) {
        guard self.state == .live, let session = self.session else {
            return
        }
        switch outcome {
        case let .answered(result):
            session.completeRequest(id, result: result, failure: .none)
        case .timeout:
            session.completeRequest(id, result: nil, failure: .timeout)
        case .rateLimited:
            session.completeRequest(id, result: nil, failure: .rateLimited)
        case .failed:
            session.completeRequest(id, result: nil, failure: .failed)
        case .rejected:
            session.completeRequest(id, result: nil, failure: .rejected)
        case .badRequest:
            session.completeRequest(id, result: nil, failure: .badRequest)
        }
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The system's Reduce Motion changed: prefers-reduced-motion follows, and the media query lists whose answer flipped
    /// report a change.
    func setReducedMotion(_ reduced: Bool) {
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setReducedMotion(reduced)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// One touch phase, queued as the session's task and run with whatever else is runnable, after what was runnable
    /// before it. The press's permission for a link call is the runtime's (SDK v1 §2.5: one call per press, from the
    /// press's own events only). A press's down answers what the press is to the widget (SDK v1 §5.5).
    @discardableResult
    func touch(action: Int32, at point: CGPoint, pointer: Int32, primary: Bool, mouse: Bool = false, button: Int = 0) -> MessageWidgetPress {
        guard self.state == .live, let session = self.session else {
            return .none
        }
        let phase: WRPointerPhase
        switch action {
        case 0:
            phase = .down
        case 1:
            phase = .move
        case 2:
            phase = .up
        case 4:
            phase = .retract
        default:
            phase = .cancel
        }
        let now = CACurrentMediaTime() * 1000.0
        self.drain(at: now)
        guard self.state == .live, !self.isStopped(session) else {
            return .none
        }
        session.pointer(phase, at: point, pointerId: pointer, primary: primary, mouse: mouse, button: button)
        self.drain(at: now)
        // Every finger's down answers, not only the primary's (multitouch design §5.1).
        guard phase == .down else {
            return .none
        }
        // A widget the drains stopped is a picture: the bubble's press.
        guard self.state == .live, !self.isStopped(session) else {
            return .none
        }
        // A down whose task is still behind the drains' backlog (more than they may spend) is unanswered, as when main's
        // wait ends first: never the claim of the press before it (the fix waves' review).
        if session.pressDownPending {
            return .unanswered
        }
        let axes = session.gestureClaim
        if mouse {
            // The policy's mouse: no hold menu and no swipes, so its holds and sideways drags are the widget's whatever
            // the touch-action (a vertical drag still scrolls the chat). Its secondary click claims holds where a touch
            // would (the widget's contextmenu), else it is the chat's menu.
            return MessageWidgetPress(claim: .horizontal, takesTaps: session.pressTakesTaps, hold: button != 2 || axes.contains(.hold))
        }
        // Only the horizontal axis: the chat always scrolls (`MessageWidgetGestureClaim`; widget-sandbox v0.1.3's G2,
        // whose policy never claims the vertical one).
        let claim: MessageWidgetGestureClaim = axes.contains(.horizontal) ? .horizontal : []
        return MessageWidgetPress(claim: claim, takesTaps: session.pressTakesTaps, hold: axes.contains(.hold))
    }

    /// One animation frame, while the widget is visible and wants one.
    func frame(time: Double) {
        guard self.state == .live, self.visible, let session = self.session, session.wantsAnimationFrame() else {
            return
        }
        _ = session.runAnimationFrame(at: time)
    }

    /// Hidden, the widget gets no frames and its wakes come at most once a second; the visibility change itself is a
    /// task of the session's, which runs now.
    func setVisible(_ visible: Bool) {
        self.visible = visible
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setVisible(visible)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// A `.selection` task's body: the selectable text of the current layout, text wholly below `visibleHeight` left out
    /// (sdk-v1 §5.10). The host's work: it runs no script and never reaches the widget's limits.
    func exportSelection(visibleHeight: CGFloat) {
        var text: MessageWidgetSelectableText?
        if self.state == .live, let session = self.session {
            text = session.selectableText(withVisibleHeight: visibleHeight).map(MessageWidgetSelectableText.init)
        }
        self.exportedSelection = (text?.isEmpty == false ? text : nil, true)
    }

    /// A `.draw` task's body: `run` draws the tiles; this records the request it answers.
    func draw(request: Int) {
        self.drawRequest = request
    }

    /// Tests only: `code` in the widget's context as one event-kind task.
    func evaluate(_ code: String) -> String? {
        guard self.state == .live, let session = self.session else {
            return nil
        }
        return session.evaluate(forTesting: code)
    }

    /// Tests only: the border box of the first element `selector` matches, at the current layout.
    func borderBox(_ selector: String) -> CGRect? {
        guard self.state == .live, let session = self.session else {
            return nil
        }
        let box = session.borderBox(forTesting: selector)
        return box.isNull ? nil : box
    }

    /// After the widget's last task (spec D5): the session goes (main keeps the frame).
    func teardown() {
        self.tornDown = true
        self.cancelWake()
        self.dropSession()
        self.renderer = nil
    }

    // MARK: steps and wakes

    /// The session's runnable tasks at `now`, one step each on its own CPU slice, at most `maximumStepsPerTask` of them
    /// and one slice of CPU (`cpuLimitMs`) in all, so the drain leaves the pool thread to other widgets; a step the CPU
    /// windows defer ends the drain (the wake follows `nextTimerDeadline`, the retry). `now` is fixed for
    /// the whole drain, so a timer the steps set is not due within it; what is left is the next wake's.
    private func drain(at now: Double) {
        guard let session = self.session else {
            return
        }
        var steps = 0
        // One slice of CPU per drain, whatever the steps' kinds: a chain of follow-ups inherits its root's kind, and a
        // boot's, an event's or a visibility change's is never deferred by the JS quota (the final review's I1).
        let cpuStart = session.stepCpuMilliseconds
        while self.state == .live, steps < MessageWidgetCore.maximumStepsPerTask, !self.isStopped(session), session.hasRunnableTask(at: now),
              session.stepCpuMilliseconds - cpuStart < self.cpuLimits.cpuLimitMs {
            steps += 1
            if session.runNextTask(at: now) != .ran {
                break
            }
        }
    }

    /// A wake (inside its own task): what is runnable now.
    private func runWake() {
        self.wake = nil
        self.wakeAt = .infinity
        guard self.state == .live else {
            return
        }
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// One main-run-loop wake for the session's next runnable task or timer deadline; hidden, no sooner than a second
    /// from now (today's 1 Hz). A wake already due earlier stands.
    private func scheduleWake() {
        guard self.state == .live, !self.tornDown, let session = self.session else {
            self.cancelWake()
            return
        }
        let now = CACurrentMediaTime()
        var delay: Double
        if session.hasRunnableTask(at: now * 1000.0) {
            delay = 0.0
        } else if let deadline = session.nextTimerDeadline() {
            delay = max(0.0, (deadline.doubleValue - now * 1000.0) / 1000.0)
        } else {
            self.cancelWake()
            return
        }
        if !self.visible {
            delay = max(delay, 1.0)
        }
        let at = now + delay
        if self.wake != nil, at >= self.wakeAt {
            return
        }
        self.wake?.cancel()
        self.wakeAt = at
        self.wake = self.timers.schedule(after: delay, key: "wake") { [weak self] in
            self?.runWake()
        }
    }

    private func cancelWake() {
        self.wake?.cancel()
        self.wake = nil
        self.wakeAt = .infinity
    }

    // MARK: publishing and freezing

    /// The session's tree and what changed since the last task, to the renderer; then a stop, if one came, freezes.
    private func publish() {
        guard let session = self.session, let renderer = self.renderer else {
            return
        }
        if self.state == .live, let tree = session.tree() {
            let rects = session.changedRects()?.map { value -> CGRect in
                var rect = CGRect.zero
                value.getValue(&rect, size: MemoryLayout<CGRect>.size)
                return rect
            }
            renderer.publish(tree, changed: rects, contentSize: session.contentSize)
        }
        self.refusedLoads = Int(clamping: session.refusedLoads)
        guard self.state == .live, self.isStopped(session) else {
            return
        }
        let reason: String
        switch session.stopReason {
        case .memory:
            reason = "Memory limit exceeded (\(session.memoryLimitBytes >> 20) MB)"
        case .layoutQuery:
            // widget-sandbox's own words, with the task they name.
            reason = session.stopDetail ?? "Layout query limit exceeded"
        case .cpu:
            // widget-sandbox's runtime limits on the CPU clock, in upstream's words.
            reason = session.stopDetail ?? "CPU limit exceeded"
        case .limit:
            // A counted cap of the strict policy, in upstream's words (widget-sandbox v0.3.0): the conformance set's
            // stop tests are judged by its start.
            reason = session.stopDetail ?? "Limit exceeded"
        default:
            reason = "Widget core error"
        }
        self.state = .frozen(reason)
        renderer.freeze(label: self.stoppedLabel)
        self.cancelWake()
        self.dropSession()
    }

    private func isStopped(_ session: WRSession) -> Bool {
        return session.failed || session.stopReason != .none
    }

    private func dropSession() {
        self.session?.teardown()
        self.session = nil
        self.sessionDelegate = nil
    }

    // MARK: the session's delegate (inside a session call, on this task's thread)

    fileprivate func diagnostic(_ kind: String, detail: String) {
        if kind == "uncaught-exception" {
            self.lastError = detail
        }
        self.appendDiag(kind, detail)
    }

    private func appendDiag(_ kind: String, _ detail: String) {
        if self.diagnosticCount < 500 {
            self.diagnosticCount += 1
            self.diagnostics.append((kind: kind, detail: detail))
        }
    }

    /// SDK v1 §3.2: an area the task changed, posted to main at the task's end.
    fileprivate func storageCommit(_ area: String, entries: [[String]]) {
        guard let area = MessageWidgetStorageArea(rawValue: area) else {
            return
        }
        self.storageCommits.append(MessageWidgetInstance.StorageCommit(area: area, entries: entries.compactMap { pair in
            pair.count == 2 ? MessageWidgetStorage.Entry(key: pair[0], value: pair[1]) : nil
        }))
    }

    /// The runtime posts a link call only once it has checked the URL (SDK v1 §2.5) and the press allowed it; the host
    /// still refuses one longer than `maximumLinkLength`. A haptic arrives checked and rate-limited (§2.6). A request, a
    /// copyText and watchPublicData (widget-sandbox v0.2) and a wallet call (v0.5.0) arrive checked by the runtime's
    /// policy. Any other method is ignored.
    fileprivate func bridge(_ method: String, argsJson: String) {
        guard method.count <= MessageWidgetCore.maximumBridgeMethodLength else {
            self.appendDiag("bridge-ignored", String(method.prefix(MessageWidgetCore.maximumBridgeMethodLength)))
            return
        }
        let args = (try? JSONSerialization.jsonObject(with: Data(argsJson.utf8), options: [.fragmentsAllowed])) as? [Any] ?? []
        let first = args.first as? String ?? ""
        switch method {
        case "openLink", "openTelegramLink":
            guard !first.isEmpty else {
                return
            }
            guard first.utf8.count <= MessageWidgetInstance.maximumLinkLength else {
                self.appendDiag("bridge-refused", "\(method): URL longer than \(MessageWidgetInstance.maximumLinkLength) bytes")
                return
            }
            self.bridgeCalls.append(method == "openLink" ? .openLink(first) : .openTelegramLink(first))
        case "haptic":
            guard !first.isEmpty else {
                return
            }
            self.bridgeCalls.append(.haptic(kind: first, value: args.count > 1 ? args[1] as? String : nil))
        case "request":
            // sdk-v1 §2.14: [id, data], both checked by the runtime (its request gate admitted it); a request for the
            // user's wallet card (§2.18) adds {"wallet": true}.
            guard args.count == 2 || args.count == 3, let id = Int64(first), let data = args[1] as? String else {
                return
            }
            let wallet = args.count == 3 && ((args[2] as? [String: Any])?["wallet"] as? Bool ?? false)
            self.bridgeCalls.append(.request(id: id, data: Data(data.utf8), wallet: wallet))
        case "wallet":
            // sdk-v1 §2.18: [id, method, the checked transaction or payload, data].
            guard args.count == 4, let id = Int64(first), let method = args[1] as? String, let argument = args[2] as? [String: Any], let data = args[3] as? String,
                  let json = try? JSONSerialization.data(withJSONObject: argument, options: [.sortedKeys, .withoutEscapingSlashes]),
                  let text = String(data: json, encoding: .utf8) else {
                return
            }
            switch method {
            case "sendTransaction":
                self.bridgeCalls.append(.wallet(id: id, call: .sendTransaction(json: text, data: Data(data.utf8))))
            case "signData":
                self.bridgeCalls.append(.wallet(id: id, call: .signData(json: text, data: Data(data.utf8))))
            default:
                self.appendDiag("bridge-ignored", "wallet." + method)
            }
        case "copyText":
            guard !first.isEmpty else {
                return
            }
            self.bridgeCalls.append(.copyText(first))
        case "watchPublicData":
            self.bridgeCalls.append(.watchPublicData(first == "true"))
        default:
            self.appendDiag("bridge-ignored", method)
        }
    }

}

/// The session's delegate: forwards to the core, which owns the session (the session holds its delegate weakly).
private final class SessionDelegate: NSObject, WRSessionDelegate {
    weak var core: MessageWidgetCore?

    init(core: MessageWidgetCore) {
        self.core = core
        super.init()
    }

    func session(_ session: WRSession, diagnostic kind: String, detail: String) {
        self.core?.diagnostic(kind, detail: detail)
    }

    func session(_ session: WRSession, log level: Int, text: String) {
    }

    func session(_ session: WRSession, bridge method: String, args argsJson: String) {
        self.core?.bridge(method, argsJson: argsJson)
    }

    func session(_ session: WRSession, storageCommit area: String, entries: [[String]]) {
        self.core?.storageCommit(area, entries: entries)
    }

    func session(_ session: WRSession, intl requestJson: String) -> String {
        return WidgetSandboxIntl.answer(requestJson)
    }
}
