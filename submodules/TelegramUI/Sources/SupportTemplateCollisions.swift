import Foundation
import TelegramCore

/// TSupport Templates — shared collision-detection logic (Round B, D34, design §8). Two
/// independent axes, each with its own rule - see `ai-docs/tsupport/50-templates-design.md`
/// §8 for the full statement:
///
/// - **Official vs. User** is a priority relationship (yours is supposed to beat the stock
///   default): the `/`-strip drops an official template outright if any of its keys exactly
///   matches a key already covered by a User Template. The full browser never applies this -
///   it shows both, labeled, so a browsing context never hides a candidate silently.
/// - **User vs. User** are peers (no priority relationship between two of your own
///   templates): neither silently wins; the Detail view highlights the specific shared keys
///   so an overlap is never a silent landmine.
public enum SupportTemplateCollisions {
    /// Official templates that should be suppressed from the `/`-strip because at least one
    /// of their keys exactly matches a key already used by some User Template.
    public static func stripSuppressedOfficialQuestions(official: [SupportTemplate], user: [SupportUserTemplate]) -> Set<String> {
        guard !user.isEmpty else {
            return []
        }
        let userKeys = Set(user.flatMap { $0.template.keys })
        var suppressed = Set<String>()
        for template in official {
            if template.keys.contains(where: { userKeys.contains($0) }) {
                suppressed.insert(template.normalizedQuestion)
            }
        }
        return suppressed
    }

    /// The merged, deduplicated `/`-strip result (design §2, §8): your own matching
    /// templates first, then official matches with any user-overridden ones removed.
    public static func mergedStripTemplates(official: [SupportTemplate], user: [SupportUserTemplate], normalizedQuery: String) -> [SupportTemplate] {
        let userMatches = matchingSupportTemplates(user.map { $0.template }, normalizedQuery: normalizedQuery)
        let suppressed = self.stripSuppressedOfficialQuestions(official: official, user: user)
        let officialMatches = matchingSupportTemplates(official, normalizedQuery: normalizedQuery).filter { !suppressed.contains($0.normalizedQuestion) }
        return userMatches + officialMatches
    }

    /// Other User Templates (excluding `excludingId`) that also use this exact key -
    /// the red, tappable "jump to them" case in Detail (D34).
    public static func otherUserTemplatesSharingKey(_ key: String, excludingId: String?, in user: [SupportUserTemplate]) -> [SupportUserTemplate] {
        return user.filter { $0.id != excludingId && $0.template.keys.contains(key) }
    }

    /// Whether this key also appears in some Official template - the quieter, non-red
    /// "yours takes priority" case; not a conflict, purely informational.
    public static func officialTemplateSharesKey(_ key: String, in official: [SupportTemplate]) -> Bool {
        return official.contains { $0.keys.contains(key) }
    }
}
