import CoreGraphics

/// What one core task leaves for main (spec 2026-10-15 D4). Main applies snapshots in `sequence` order: each one's
/// frame holds the tiles its task changed, on top of the ones before.
struct WidgetSnapshot {
    enum Kind: Hashable {
        case boot
        case layout
        case theme
        case touch
        case timer
        case wake
        case frame
        case visibility
        case event
        /// The bot's state changed (sdk-v1 §2.13), or a request's outcome came (§2.14): the widget's events run.
        case state
        /// Draws the tiles the tasks before it changed (MessageWidgetInstance queues one, never waited for, after a
        /// snapshot that needs it): drawing is off the critical path, which is the size.
        case draw
        /// The selectable text, exported while the widget's bubble is lifted into its context menu (sdk-v1 §5.10).
        case selection
    }

    enum State: Equatable {
        case live
        /// Stopped (its CPU limits, its memory, a count cap, a renderer error): it keeps its last frame, with the stopped
        /// label.
        case frozen(String)
        /// The runtime could not be created or the widget did not start: the host draws the block as code.
        case failedToStart
    }

    let sequence: Int
    let kind: Kind
    /// The width the core is laid out at after the task.
    let width: CGFloat
    /// The document's size after the task; nil without a renderer (a start that failed).
    let size: CGSize?
    /// The edge the widget asked to stay put when its height changes (sdk-v1 §5.6), reported with the size.
    let resizeAnchor: MessageWidgetResizeAnchor
    /// The tiles a `.draw` task drew (nil for every other kind, and without a renderer).
    let frame: WidgetFrame?
    /// The task left tiles to draw: main queues a `.draw` task when it applies this snapshot.
    let needsDraw: Bool
    /// A `.draw` task's request number (MessageWidgetInstance's), 0 for every other kind.
    let drawRequest: Int
    let state: State
    /// Calls the task's tap allowed.
    let bridgeCalls: [MessageWidgetInstance.BridgeCall]
    /// The widget asked for an animation frame during the task.
    let wantsFrame: Bool
    let lastError: String?
    /// The diagnostics the task added.
    let diagnostics: [(kind: String, detail: String)]
    /// Of `cpuMilliseconds`, the boot lifecycle's own steps (its scripts and its load) within their first
    /// `MessageWidgetCore.bootDemotionExemptionSlices` slices of CPU in all: the boot task stops once it has spent a slice
    /// and wakes run the rest, which is the boot's work, never a demotion.
    let bootCpuMilliseconds: Double
    /// The CPU milliseconds of the task's runtime steps, on the widget's thread: demotion reads them (spec D6).
    let cpuMilliseconds: Double
    /// A `.selection` task's export: nil when nothing is selectable or once the widget has stopped.
    let selectableText: MessageWidgetSelectableText?
    let exportsSelection: Bool
}
