import Postbox
import SwiftSignalKit

public struct ReactionSettings: Equatable, Codable {
    public static var `default` = ReactionSettings(quickReaction: .builtin("👍"))

    public var quickReaction: MessageReaction.Reaction

    public init(quickReaction: MessageReaction.Reaction) {
        self.quickReaction = quickReaction
    }
}

public extension ReactionSettings {
    func effectiveQuickReaction(hasPremium: Bool) -> MessageReaction.Reaction {
        switch self.quickReaction {
        case .builtin:
            return self.quickReaction
        case .custom:
            if hasPremium {
                return self.quickReaction
            } else {
                return ReactionSettings.default.quickReaction
            }
        }
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
