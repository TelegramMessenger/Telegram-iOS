import Foundation

public struct ListMembership: Codable, Equatable {
    public var marker: ListMarker
    /// 0-based nesting level.
    public var level: Int
    /// Checked state for a `.checklist` item: `nil` for bullet/ordered, `false`/`true` for a checkbox.
    public var checked: Bool?

    public init(marker: ListMarker, level: Int = 0, checked: Bool? = nil) {
        self.marker = marker
        self.level = level
        self.checked = checked
    }
}
