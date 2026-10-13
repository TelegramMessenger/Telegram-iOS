import Foundation

/// The reply presets of the old watch app, offered as the text responses of Reply.
///
/// The keys are the ones the iPhone app shows under Settings > Apple Watch > Reply Presets
/// (`Watch.Suggestion.*`, translated on translations.telegram.org). Each falls back to its English
/// text while the app has no translation for it.
enum ReplyPresets {
    /// In the order of the iPhone app's settings.
    static let english: [(key: String, value: String)] = [
        ("Watch.Suggestion.OK", "OK"),
        ("Watch.Suggestion.Thanks", "Thanks!"),
        ("Watch.Suggestion.WhatsUp", "What's up?"),
        ("Watch.Suggestion.TalkLater", "Talk later?"),
        ("Watch.Suggestion.CantTalk", "Can't talk now..."),
        ("Watch.Suggestion.HoldOn", "Hold on a sec..."),
        ("Watch.Suggestion.BRB", "BRB"),
        ("Watch.Suggestion.OnMyWay", "I'm on my way."),
    ]

    /// In the reply input's language (`inputLanguage`, e.g. "it-IT", which the user can switch in
    /// the input), not the app's: the presets are what the user is about to send.
    static func suggestions(forInputLanguage inputLanguage: String, bundle: Bundle = .main) -> [String] {
        let localized = localizationBundle(forInputLanguage: inputLanguage, in: bundle) ?? bundle
        return english.map { localized.localizedString(forKey: $0.key, value: $0.value, table: nil) }
    }

    static func localizationBundle(forInputLanguage inputLanguage: String, in bundle: Bundle) -> Bundle? {
        for code in candidates(inputLanguage) {
            if let path = bundle.path(forResource: code, ofType: "lproj"), let localized = Bundle(path: path) {
                return localized
            }
        }
        return nil
    }

    /// "pt_BR" -> "pt-BR", "pt-br", "pt"; a few codes the system spells differently from the
    /// translation platform are added after the base language.
    static func candidates(_ inputLanguage: String) -> [String] {
        let dashed = inputLanguage.replacingOccurrences(of: "_", with: "-")
        let base = String(dashed.split(separator: "-").first ?? "")
        let aliases: [String: [String]] = ["pt": ["pt-BR", "pt-br"], "no": ["nb"], "nn": ["nb"], "iw": ["he"], "in": ["id"]]
        var result = [dashed, dashed.lowercased(), base.lowercased()]
        result += aliases[base.lowercased()] ?? []
        var seen = Set<String>()
        return result.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
