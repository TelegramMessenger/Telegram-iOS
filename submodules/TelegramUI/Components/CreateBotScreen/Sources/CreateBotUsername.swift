import Foundation
import TelegramCore

/// The endings a new bot's username may have.
///
/// 'bot' is always allowed and free; it is also what the field appends when the typed text has no
/// ending of its own. Every other ending comes from the `bot_allowed_suffixes` app config list and
/// needs Telegram Premium. Without that key only 'bot' is offered, which is the sheet's behaviour from
/// before the server allowed anything else.
public struct CreateBotUsernameEndings: Equatable {
    public static let freeEnding = "bot"
    public static let appConfigurationKey = "bot_allowed_suffixes"

    /// The configured endings that need Premium, lowercased, in the server's order.
    public let premium: [String]

    /// `value` is the raw `bot_allowed_suffixes` entry: an array of strings.
    public init(configuredValue value: Any?) {
        var premium: [String] = []
        for case let item as String in (value as? [Any]) ?? [] {
            let ending = item.lowercased()
            if !ending.isEmpty, ending != CreateBotUsernameEndings.freeEnding, !premium.contains(ending) {
                premium.append(ending)
            }
        }
        self.premium = premium
    }

    public init(appConfiguration: AppConfiguration) {
        self.init(configuredValue: appConfiguration.data?[CreateBotUsernameEndings.appConfigurationKey])
    }

    public var all: [String] {
        return [CreateBotUsernameEndings.freeEnding] + self.premium
    }
}

/// The username the Create Bot sheet's username field stands for.
///
/// When the typed text already ends in an allowed ending — after at least one character of its own —
/// the username is exactly what was typed; otherwise the field shows a grey 'bot' after the text, and
/// that is appended. The grey suffix, local validation, the availability check, the Create button and
/// the create call all read this one value, so they cannot disagree about what will be created.
public struct CreateBotUsername: Equatable {
    public enum ValidationError: Equatable {
        case unsupportedCharacters
        case startsWithNumber
        case tooShort
        case tooLong
    }

    public static let minLength = 5
    public static let maxLength = 32
    /// How many Premium-ending usernames an account may hold across its bots, for the error text when
    /// the server's error does not carry the number.
    public static let defaultSuffixLimit: Int32 = 2

    public let typedText: String
    /// The ending the username has, lowercased.
    public let ending: String
    /// The grey text shown after the typed text and appended to it, or nil when the user typed an
    /// ending themselves.
    public let appendedSuffix: String?

    public init(typedText: String, endings: CreateBotUsernameEndings) {
        self.typedText = typedText
        let lowercasedText = typedText.lowercased()
        // Longest first, so a configured ending that ends in another one wins.
        let candidates = endings.all.sorted(by: { $0.count > $1.count })
        if let ending = candidates.first(where: { lowercasedText.count > $0.count && lowercasedText.hasSuffix($0) }) {
            self.ending = ending
            self.appendedSuffix = nil
        } else {
            self.ending = CreateBotUsernameEndings.freeEnding
            self.appendedSuffix = CreateBotUsernameEndings.freeEnding
        }
    }

    /// What is checked and created.
    public var username: String {
        return self.typedText + (self.appendedSuffix ?? "")
    }

    public var requiresPremium: Bool {
        return self.ending != CreateBotUsernameEndings.freeEnding
    }

    /// The first rule the full username breaks, or nil when it may be checked against the server.
    public var validationError: ValidationError? {
        let username = self.username
        var allowedCharacters = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
        allowedCharacters.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
        allowedCharacters.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
        allowedCharacters.insert("_")
        if !username.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
            return .unsupportedCharacters
        }
        if let first = username.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
            return .startsWithNumber
        }
        if username.count < CreateBotUsername.minLength {
            return .tooShort
        }
        if username.count > CreateBotUsername.maxLength {
            return .tooLong
        }
        return nil
    }
}
