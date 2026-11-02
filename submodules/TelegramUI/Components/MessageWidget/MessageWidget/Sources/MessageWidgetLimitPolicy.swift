import Foundation

/// The counted caps a widget runs under (widget-sandbox v0.3.0, "Strict limits from the start"; WidgetRuntime's Limits):
/// `strict`, every widget the app shows, past a cap of which the widget stops with upstream's reason; `compat`, the caps
/// from before v0.3.0, past which nothing stops (the stress kit's measuring runs).
public enum MessageWidgetLimitPolicy {
    case strict
    case compat
}
