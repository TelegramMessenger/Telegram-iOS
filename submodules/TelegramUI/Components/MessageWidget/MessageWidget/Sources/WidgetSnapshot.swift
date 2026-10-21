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
        /// Draws the tiles the tasks before it changed (MessageWidgetInstance queues one, never waited for, after a
        /// snapshot that needs it): drawing is off the critical path, which is the size.
        case draw
    }

    enum State: Equatable {
        case live
        /// Stopped (its budget, its memory, a renderer error): it keeps its last frame, with the stopped label.
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
    /// The units the task spent over every budget it ran on (its meter): demotion reads them (spec D6).
    let units: UInt64
}
