import Foundation

struct BotUsernameConfiguration {
    enum ValidationError: Error {
        case insufficientLength
        case unsupportedCharacters
        case startsWithNumber
        case invalidSuffix
    }

    let allowedSuffixes: [String]

    init(allowedSuffixes: [String]?) {
        if let suffixes = allowedSuffixes, suffixes.allSatisfy({ !$0.isEmpty }) {
            self.allowedSuffixes = suffixes
        } else {
            self.allowedSuffixes = ["bot"]
        }
    }

    private func hasAllowedSuffix(_ username: String) -> Bool {
        let username = username.lowercased()
        return self.allowedSuffixes.contains(where: { username.hasSuffix($0.lowercased()) })
    }

    func initialUsername(_ suggestion: String?) -> String {
        guard let suggestion, !suggestion.isEmpty else {
            return ""
        }
        if self.hasAllowedSuffix(suggestion) {
            return suggestion
        }
        return suggestion + (self.allowedSuffixes.first ?? "")
    }

    func validate(_ username: String) -> Result<String, ValidationError> {
        let usernameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        if username.unicodeScalars.contains(where: { !usernameCharacters.contains($0) }) {
            return .failure(.unsupportedCharacters)
        }
        if let first = username.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
            return .failure(.startsWithNumber)
        }
        if username.count < 5 {
            return .failure(.insufficientLength)
        }
        if !self.hasAllowedSuffix(username) {
            return .failure(.invalidSuffix)
        }
        return .success(username)
    }
}
