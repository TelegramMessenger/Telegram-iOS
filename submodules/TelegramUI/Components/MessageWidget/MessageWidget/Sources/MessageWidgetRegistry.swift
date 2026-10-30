import UIKit

/// The widget runtimes of one bubble. A runtime lives as long as its bubble: the bubble node
/// calls `beginPass` with its message's stable id, and a different id destroys everything.
/// Within a message, a widget is keyed by its block's structural path plus its source and its message's context
/// (widget-sandbox v0.2: fixed for a widget's life), so an edited source or another context gets a fresh runtime and two
/// widget blocks get two. The bot's state is not in the key: a pass hands a new state to the running widget. Main
/// thread only.
public final class MessageWidgetRegistry {
    public struct Key: Hashable {
        public let path: [Int]
        public let source: String
        public let context: MessageWidgetContext
    }

    public typealias Factory = (_ source: String, _ theme: MessageWidgetInstance.Theme, _ stoppedLabel: String, _ maxMessageLength: Int, _ locale: String, _ storage: MessageWidgetStorage, _ context: MessageWidgetContext, _ state: MessageWidgetState, _ startsStopped: Bool) -> MessageWidgetInstance?

    /// Widgets one bubble runs at most, in layout order; a block past them draws as code. Each widget is one runtime
    /// (a 64 MiB memory limit; the server bounds the source at 32 KB) plus its decoded images (at most 24 MiB alive) and
    /// its tiles. The examples use one per message.
    public static let maximumWidgets = 4

    public var stoppedLabel: String = "Widget stopped"
    public var maxMessageLength: Int = 4096
    /// The client's UI language, for widgets made from now on (SDK v1 §2.9).
    public var locale: String = "en-US"
    /// The stored areas for widgets made from now on (SDK v1 §3.1): the bubble's message's, set on every pass.
    public var storage: MessageWidgetStorage = .empty
    /// The most a widget asked for in this pass may be tall (`MessageWidgetInstance.maximumHeight`): its bubble's fixed
    /// height, else the 600 pt bound. Handed over on every `size`, so an edit of the anchors reaches a running widget.
    public var maximumHeight: CGFloat = MessageWidgetBubbleSize.maximumHeight
    /// What the bubble draws over a widget asked for in this pass (`MessageWidgetInstance.contentSafeArea`): its time over
    /// the bottom corner when no caption is below it (sdk-v1 §2.17, §5.12), `none` otherwise. Handed over on every pass.
    public var contentSafeArea: MessageWidgetContentSafeArea = .none
    /// The bubble's message's context (sdk-v1 §2.13, §2.14), set on every pass: part of a widget's key.
    public var context = MessageWidgetContext()
    /// The bot's state of the bubble's message (sdk-v1 §2.13), set on every pass: widgets made in it start with it, and
    /// a running one gets it as a change (`MessageWidgetInstance.setState`).
    public var state: MessageWidgetState = .empty
    public var onLayoutChange: (() -> Void)?
    /// A bridge call and the widget that made it (to answer a request on).
    public var onBridge: ((MessageWidgetInstance.BridgeCall, MessageWidgetInstance) -> Void)?
    /// widget-sandbox v0.2 (W2): an instance's `wantsPublicDataPolling` changed.
    public var onPublicDataPollingChange: ((Bool, MessageWidgetInstance) -> Void)?
    /// Where the widgets made from now on send their storage commits (SDK v1 §5.4); each keeps the sink it was made
    /// with.
    public var onStorageCommit: ((MessageWidgetInstance.StorageCommit) -> Void)?

    private let factory: Factory
    private var ownerId: AnyHashable?
    private var theme: MessageWidgetInstance.Theme = .light
    private var visible = true
    private var instances: [Key: MessageWidgetInstance] = [:]
    private var usedInPass = Set<Key>()
    /// Keys whose widget could not start. Remembered so that a failing boot is not repeated, on main, by every layout pass.
    private var failedKeys = Set<Key>()
    /// SDK v1 §5.7: whether a widget may boot, counted per message and source across the bubbles that show it.
    private let restartPolicy: MessageWidgetRestartPolicy
    /// Each running widget's key in the restart policy (its message and its source).
    private var restartKeys: [Key: MessageWidgetRestartPolicy.Key] = [:]

    public init(factory: Factory? = nil, restartPolicy: MessageWidgetRestartPolicy = .shared) {
        self.factory = factory ?? { source, theme, label, max, locale, storage, context, state, startsStopped in
            MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, locale: locale, storage: storage, context: context, state: state, startsStopped: startsStopped)
        }
        self.restartPolicy = restartPolicy
    }

    deinit {
        for (key, instance) in self.instances {
            self.ended(key, instance)
            instance.destroy()
        }
    }

    /// A widget that goes without having stopped starts its restart count over (§5.7).
    private func ended(_ key: Key, _ instance: MessageWidgetInstance) {
        if let restartKey = self.restartKeys.removeValue(forKey: key), instance.deadReason == nil, !instance.failedToStart {
            self.restartPolicy.noteEndedWithoutStop(restartKey)
        }
    }

    public func beginPass(ownerId: AnyHashable, theme: MessageWidgetInstance.Theme) {
        if self.ownerId != ownerId {
            self.destroyAll()
            self.ownerId = ownerId
        }
        if self.theme != theme {
            self.theme = theme
            for (_, instance) in self.instances {
                instance.setTheme(theme)
            }
        }
        self.usedInPass.removeAll()
    }

    /// The size of the widget for this block, or nil when the block is drawn as code: an empty
    /// source, a widget that could not start, a block past `maximumWidgets` in this pass, or a call off
    /// the main thread (a list that lays out off main passes no widget host, and a runtime is main-thread only).
    public func size(path: [Int], source: String, width: CGFloat) -> CGSize? {
        guard Thread.isMainThread, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let key = self.key(path: path, source: source)
        if self.failedKeys.contains(key) {
            self.usedInPass.insert(key)
            return nil
        }
        // A key already answered in this pass is answered again, so a layout that asks twice gets one answer.
        if !self.usedInPass.contains(key) && self.usedInPass.filter({ self.instances[$0] != nil }).count >= MessageWidgetRegistry.maximumWidgets {
            // Not marked used: an instance this key may still have from an earlier pass is destroyed at endPass.
            return nil
        }
        let instance: MessageWidgetInstance
        if let existing = self.instances[key] {
            instance = existing
            existing.setState(self.state)
        } else {
            let restartKey = MessageWidgetRestartPolicy.Key(owner: self.ownerId ?? AnyHashable(0), source: source)
            let startsStopped = !self.restartPolicy.allowsBoot(restartKey)
            guard let created = self.factory(source, self.theme, self.stoppedLabel, self.maxMessageLength, self.locale, self.storage, self.context, self.state, startsStopped) else {
                self.failedKeys.insert(key)
                self.usedInPass.insert(key)
                return nil
            }
            created.onLayoutChange = { [weak self] in
                self?.onLayoutChange?()
            }
            created.onBridge = { [weak self, weak created] call in
                guard let created else {
                    return
                }
                self?.onBridge?(call, created)
            }
            created.onPublicDataPollingChange = { [weak self, weak created] wants in
                guard let created else {
                    return
                }
                self?.onPublicDataPollingChange?(wants, created)
            }
            // The sink as it is now: it carries this message's key, and a commit the widget makes just before its bubble
            // goes is still delivered.
            created.onStorageCommit = self.onStorageCommit
            if !startsStopped {
                self.restartKeys[key] = restartKey
                let restartPolicy = self.restartPolicy
                created.onStopped = {
                    restartPolicy.noteStopped(restartKey)
                }
            }
            created.setVisible(self.visible)
            self.instances[key] = created
            instance = created
        }
        instance.maximumHeight = self.maximumHeight
        instance.contentSafeArea = self.contentSafeArea
        let size = instance.layout(width: width)
        if instance.failedToStart {
            instance.destroy()
            self.instances[key] = nil
            self.restartKeys[key] = nil
            self.failedKeys.insert(key)
            self.usedInPass.insert(key)
            return nil
        }
        self.usedInPass.insert(key)
        return size
    }

    /// The size of this block's widget laid out exactly `width` wide (`MessageWidgetInstance.fill`), for a bubble wider
    /// than the widget's own width; nil when the block has no running widget.
    public func fill(path: [Int], source: String, width: CGFloat) -> CGSize? {
        guard Thread.isMainThread, let instance = self.instances[self.key(path: path, source: source)] else {
            return nil
        }
        return instance.fill(width: width)
    }

    public func endPass() {
        for (key, instance) in self.instances where !self.usedInPass.contains(key) {
            self.ended(key, instance)
            instance.destroy()
            self.instances[key] = nil
        }
        // A failure is kept only while its block keeps asking: an edited source is a new key anyway.
        self.failedKeys.formIntersection(self.usedInPass)
    }

    public func view(path: [Int], source: String) -> UIView? {
        return self.instances[self.key(path: path, source: source)]?.view
    }

    /// The height the widget at `path` last reported, nil until its first render (main thread). A bubble in auto height
    /// uses it, and its placeholder or cached height until then.
    public func reportedHeight(path: [Int], source: String) -> CGFloat? {
        return self.instances[self.key(path: path, source: source)]?.reportedHeight
    }

    /// The edge the widget at `path` asked to stay put when its height changes (sdk-v1 §5.6), nil without a widget.
    public func resizeAnchor(path: [Int], source: String) -> MessageWidgetResizeAnchor? {
        return self.instances[self.key(path: path, source: source)]?.resizeAnchor
    }

    /// The widget at `path` as its bubble's next update reads it (`MessageWidgetBubbleSize.resizeAnchor`): its report,
    /// its edge and whether it failed to start (late, or found by a pass); nil without one.
    public func runState(path: [Int], source: String) -> MessageWidgetRunState? {
        let key = self.key(path: path, source: source)
        if let instance = self.instances[key] {
            return MessageWidgetRunState(reportedHeight: instance.reportedHeight, resizeAnchor: instance.resizeAnchor, failedToStart: instance.failedToStart)
        }
        if self.failedKeys.contains(key) {
            return MessageWidgetRunState(reportedHeight: nil, resizeAnchor: .top, failedToStart: true)
        }
        return nil
    }

    public func isLive(path: [Int]) -> Bool {
        return self.instances.contains { $0.key.path == path && $0.value.deadReason == nil }
    }

    /// widget-sandbox v0.2 (W2): whether the live widget at `path` wants its shared state polled (it watches on screen).
    public func wantsPublicDataPolling(path: [Int]) -> Bool {
        return self.instances.contains { $0.key.path == path && $0.value.deadReason == nil && $0.value.wantsPublicDataPolling }
    }

    public var layoutVersions: [Key: Int] {
        return self.instances.mapValues { $0.layoutVersion }
    }

    /// The key of the block at `path` with `source` in this pass's context.
    private func key(path: [Int], source: String) -> Key {
        return Key(path: path, source: source, context: self.context)
    }

    public func setVisible(_ visible: Bool) {
        self.visible = visible
        for (_, instance) in self.instances {
            instance.setVisible(visible)
        }
    }

    public func destroyAll() {
        for (key, instance) in self.instances {
            self.ended(key, instance)
            instance.destroy()
        }
        self.instances.removeAll()
        self.usedInPass.removeAll()
        self.failedKeys.removeAll()
    }
}
