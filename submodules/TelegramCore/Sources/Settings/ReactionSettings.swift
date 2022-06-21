import Postbox
import SwiftSignalKit

public struct ReactionSettings: Equatable, Codable {
    public static var `default` = ReactionSettings(quickReaction: "👍")

    public var quickReaction: String

    public init(quickReaction: String) {
        self.quickReaction = quickReaction
    }
}

func updateReactionSettings(transaction: Transaction, _ f: (ReactionSettings) -> ReactionSettings) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.reactionSettings, { current in
        let previous = current?.get(ReactionSettings.self) ?? ReactionSettings.default
        let updated = f(previous)
        return PreferencesEntry(updated)
    })
}

public func updateReactionSettingsInteractively(postbox: Postbox, _ f: @escaping (ReactionSettings) -> ReactionSettings) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        updateReactionSettings(transaction: transaction, f)
    }
    |> ignoreValues
}
