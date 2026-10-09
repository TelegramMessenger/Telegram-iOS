import Foundation
import UIKit

public extension DeviceMetrics {
    /// Whether wide layouts on this device show optional floating presentations. iPhone Duo is a phone whose
    /// unfolded screen is regular width in landscape: it keeps the split view but uses the phone
    /// presentations, folded or unfolded.
    var presentsFloatingPanels: Bool {
        if case .iPhoneDuo = self {
            return false
        }
        return true
    }
}

public extension ContainerViewLayout {
    /// Whether this layout shows optional floating presentations — anchored popovers, centered sheets and
    /// centered modals — instead of the phone ones: wide layouts, except on a device that never shows them.
    var presentsFloatingPanels: Bool {
        return self.metrics.widthClass == .regular && self.deviceMetrics.presentsFloatingPanels
    }

    /// This layout for a presentation that has a floating and a phone form: with compact metrics where a
    /// wide layout does not present floating panels, so the presentation and everything inside it lays out
    /// as on a phone. Unchanged otherwise.
    var forOptionalFloatingPresentation: ContainerViewLayout {
        if self.metrics.widthClass == .regular && !self.deviceMetrics.presentsFloatingPanels {
            return self.withUpdatedMetrics(LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: self.metrics.orientation, windowSize: self.metrics.windowSize))
        }
        return self
    }
}
