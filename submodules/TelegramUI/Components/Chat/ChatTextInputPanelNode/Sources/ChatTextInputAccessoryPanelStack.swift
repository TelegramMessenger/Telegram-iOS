import Foundation
import ComponentFlow
import ChatInputAccessoryPanel

/// A panel that can fill the slot above the input field (link preview, forward, reply, …).
///
/// `key` names what the panel shows (its kind and subject: the URL, the replied-to message), so that showing
/// something else counts as a new panel; `panel.id` stays the kind, which keeps the in-place update of a panel
/// whose subject changes.
public struct ChatTextInputAccessoryPanelCandidate {
    public let key: AnyHashable
    public let panel: AnyComponentWithIdentity<ChatInputAccessoryPanelEnvironment>

    public init(key: AnyHashable, panel: AnyComponentWithIdentity<ChatInputAccessoryPanelEnvironment>) {
        self.key = key
        self.panel = panel
    }
}

/// The panels above the input field share one slot. A panel that appears is shown over the one already there,
/// and dismissing it brings back the one it covered; panels that appear together keep the order they are listed
/// in, highest priority first. While the slot is hidden (search, selection, previewing) the order is kept.
public struct ChatTextInputAccessoryPanelStack {
    /// The keys of the panels that can show, oldest first: the last one is on screen.
    private var keys: [AnyHashable] = []

    public init() {
    }

    /// `availableKeys` are the panels that can show now, highest priority first, or nil while the slot is hidden.
    /// Returns the key to show.
    public mutating func update(availableKeys: [AnyHashable]?) -> AnyHashable? {
        guard let availableKeys else {
            return nil
        }
        let available = Set(availableKeys)
        var updatedKeys = self.keys.filter { available.contains($0) }
        let known = Set(updatedKeys)
        for key in availableKeys.reversed() where !known.contains(key) {
            updatedKeys.append(key)
        }
        self.keys = updatedKeys
        return updatedKeys.last
    }
}
