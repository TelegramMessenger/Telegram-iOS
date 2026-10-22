import Foundation
import TelegramUIPreferences

/// Which editor the harness asks the REAL panel to select.
public enum HarnessBackend: String, Equatable {
    case legacy
    case engine
}

/// The mutable knobs the arrange channel writes. Held by reference so the toolbar can change a
/// value and the next panel construction reads it, with no second source of truth.
public final class HarnessSettings {
    public var backend: HarnessBackend = .engine
    public var useDarkTheme: Bool = false
    /// Settings ▸ Appearance ▸ Text Size. The composer scales its text from this.
    public var fontSize: PresentationFontSize = .regular
    public init() {}
}
