import Foundation

/// What the stress kit's runner reads of a widget (widget-sandbox v0.3.0, packages/stress CLIENTS.md, "The host" and
/// "The renderer's own work"): cumulative since the widget was made, so a window is the difference of two. Statistics,
/// never a decision.
public struct MessageWidgetStressStats {
    /// Wall time of every task's runtime work (its JS, its render flush and publish), and of the tile draws.
    public let stepMilliseconds: Double
    public let drawMilliseconds: Double
    /// Of the steps' time, the render flushes' (style, layout, the layer tree).
    public let flushMilliseconds: Double
    /// Animation frame tasks run, and tile draw tasks.
    public let frameTasks: Int
    public let drawTasks: Int
    /// widget-sandbox's operations (limit.batch's count) since the widget began, and the largest batch.
    public let totalOps: UInt64
    public let maxBatchOps: UInt64
    public let layoutQueries: UInt64
    /// The QuickJS heap in use and the document's nodes, now.
    public let heapBytes: UInt64
    public let nodes: UInt64
    /// On the widget thread's CPU clock: the widget's JS time (what the JS quota records), the layout queries' time, the
    /// most one step took, and the steps the CPU windows deferred.
    public let jsMilliseconds: Double
    public let queryMilliseconds: Double
    public let largestStepMilliseconds: Double
    public let throttledSteps: UInt64
}
