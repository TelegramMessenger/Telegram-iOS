// Ours, not upstream's (VENDOR.md): the entry WidgetRuntime's host calls widget-sandbox's iOS glue through, and the one
// member of upstream's SandboxEngine that IntlBridge.swift reads.
import Foundation

/// widget-sandbox's `intl` capability: a request as its shim sends one (`{"kind":…,"locale":…,"opts":{…},…}`), the
/// answer as its iOS glue gives it. Pure formatting with Foundation's formatters; safe on any thread.
public enum WidgetSandboxIntl {
    public static func answer(_ requestJson: String) -> String {
        return IntlBridge.format(requestJson: requestJson)
    }
}

/// Upstream's SandboxEngine.parse, as SandboxEngine.swift has it.
enum SandboxEngine {
    static func parse(_ json: String) -> Any? {
        try? JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
    }
}
