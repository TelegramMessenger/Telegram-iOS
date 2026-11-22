import Foundation
import WidgetRuntimeIOS

/// widget-sandbox's runtime limits (LIMIT_DEFAULTS; docs/decisions.md "CPU time, not wall-clock time"), in milliseconds
/// of the widget thread's CPU time: a task's slice (past it the widget stops), the JS quota and the main-thread window per
/// `cpuQuotaWindowMs` (past either, the widget's timers, frames and other deferrable tasks wait), and how long throttling
/// may last before the widget stops (0: never). The product's in every build and under both limit policies; tests and the
/// stress kit's measure pass set their own.
public struct MessageWidgetCpuLimits: Equatable {
    public var cpuLimitMs: Double
    public var cpuQuotaMs: Double
    public var cpuQuotaWindowMs: Double
    public var cpuKillAfterMs: Double
    public var mainThreadQuotaMs: Double

    public init(cpuLimitMs: Double, cpuQuotaMs: Double, cpuQuotaWindowMs: Double, cpuKillAfterMs: Double, mainThreadQuotaMs: Double) {
        self.cpuLimitMs = cpuLimitMs
        self.cpuQuotaMs = cpuQuotaMs
        self.cpuQuotaWindowMs = cpuQuotaWindowMs
        self.cpuKillAfterMs = cpuKillAfterMs
        self.mainThreadQuotaMs = mainThreadQuotaMs
    }

    public static let product = MessageWidgetCpuLimits(cpuLimitMs: 500.0, cpuQuotaMs: 300.0, cpuQuotaWindowMs: 1000.0, cpuKillAfterMs: 0.0, mainThreadQuotaMs: 100.0)

    var session: WRCpuLimits {
        return WRCpuLimits(cpuLimitMs: self.cpuLimitMs, cpuQuotaMs: self.cpuQuotaMs, cpuQuotaWindowMs: self.cpuQuotaWindowMs, cpuKillAfterMs: self.cpuKillAfterMs, mainThreadQuotaMs: self.mainThreadQuotaMs)
    }
}
