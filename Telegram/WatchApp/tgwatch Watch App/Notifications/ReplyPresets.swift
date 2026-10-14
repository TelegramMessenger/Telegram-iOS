import Foundation

/// The reply presets of the old watch app, offered as the text responses of Reply.
///
/// The keys are the iOS app's `Watch.Suggestion.*`, translated on translations.telegram.org and
/// shown in the app's language like every other string (`L`, from the language pack).
enum ReplyPresets {
    /// In the order the old watch app and the iPhone app's Reply Presets listed them.
    static let keys = [
        "Watch.Suggestion.OK",
        "Watch.Suggestion.Thanks",
        "Watch.Suggestion.WhatsUp",
        "Watch.Suggestion.TalkLater",
        "Watch.Suggestion.CantTalk",
        "Watch.Suggestion.HoldOn",
        "Watch.Suggestion.BRB",
        "Watch.Suggestion.OnMyWay",
    ]

    static func suggestions() -> [String] {
        keys.map { L($0) }
    }
}
