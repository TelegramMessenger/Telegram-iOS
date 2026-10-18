import Foundation

public func parsePassStrings(_ data: Data) -> [String: String] {
    guard let table = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: String] else {
        return [:]
    }
    return table
}

private func normalizedLanguageCode(_ language: String) -> String {
    return language.lowercased().replacingOccurrences(of: "_", with: "-")
}

public struct PassStringTables {
    private let tables: [String: [String: String]]

    public init(tables: [String: [String: String]]) {
        var normalized: [String: [String: String]] = [:]
        for (language, table) in tables {
            normalized[normalizedLanguageCode(language)] = table
        }
        self.tables = normalized
    }

    public func localized(_ string: String, language: String) -> String {
        let language = normalizedLanguageCode(language)
        var candidates: [String] = [language]
        if let base = language.split(separator: "-").first, String(base) != language {
            candidates.append(String(base))
        }
        candidates.append("en")
        for candidate in candidates {
            if let value = self.tables[candidate]?[string] {
                return passCappedString(value)
            }
        }
        return string
    }
}

public struct PassFormattingContext {
    public var language: String
    public var timeZone: TimeZone

    public init(language: String, timeZone: TimeZone = .current) {
        self.language = language
        self.timeZone = timeZone
    }
}

private func dateFormatterStyle(_ value: String?) -> DateFormatter.Style? {
    switch value {
    case "PKDateStyleNone":
        return DateFormatter.Style.none
    case "PKDateStyleShort":
        return .short
    case "PKDateStyleMedium":
        return .medium
    case "PKDateStyleLong":
        return .long
    case "PKDateStyleFull":
        return .full
    default:
        return nil
    }
}

private func parseISO8601(_ string: String) -> (date: Date, zone: TimeZone?)? {
    let formatter = ISO8601DateFormatter()
    var parsedDate: Date?
    let optionSets: [ISO8601DateFormatter.Options] = [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]]
    for options in optionSets {
        formatter.formatOptions = options
        if let value = formatter.date(from: string) {
            parsedDate = value
            break
        }
    }
    if parsedDate == nil {
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"
        parsedDate = fallback.date(from: string)
    }
    guard let date = parsedDate else {
        return nil
    }
    var zone: TimeZone?
    if string.hasSuffix("Z") || string.hasSuffix("z") {
        zone = TimeZone(secondsFromGMT: 0)
    } else if let signIndex = string.lastIndex(where: { $0 == "+" || $0 == "-" }), string.distance(from: signIndex, to: string.endIndex) <= 6 {
        let digits = string[string.index(after: signIndex)...].filter { $0.isNumber }
        if digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)) {
            zone = TimeZone(secondsFromGMT: (hours * 3600 + minutes * 60) * (string[signIndex] == "-" ? -1 : 1))
        }
    }
    return (date, zone)
}

public func passFieldLabel(_ field: PassField, strings: PassStringTables, context: PassFormattingContext) -> String? {
    guard let label = field.label, !label.isEmpty else {
        return nil
    }
    return strings.localized(label, language: context.language)
}

public func passFieldText(_ field: PassField, strings: PassStringTables, context: PassFormattingContext) -> String {
    return passCappedString(passFormattedFieldText(field, strings: strings, context: context))
}

private func passFormattedFieldText(_ field: PassField, strings: PassStringTables, context: PassFormattingContext) -> String {
    let locale = Locale(identifier: context.language)
    switch field.value {
    case let .string(string):
        let dateStyle = dateFormatterStyle(field.dateStyle)
        let timeStyle = dateFormatterStyle(field.timeStyle)
        if dateStyle != nil || timeStyle != nil, let (date, zone) = parseISO8601(string) {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = dateStyle ?? .none
            formatter.timeStyle = timeStyle ?? .none
            formatter.timeZone = field.ignoresTimeZone ? (zone ?? context.timeZone) : context.timeZone
            return formatter.string(from: date)
        }
        return strings.localized(string, language: context.language)
    case let .number(number):
        let formatter = NumberFormatter()
        formatter.locale = locale
        if let currencyCode = field.currencyCode {
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
        } else {
            switch field.numberStyle {
            case "PKNumberStylePercent":
                formatter.numberStyle = .percent
            case "PKNumberStyleScientific":
                formatter.numberStyle = .scientific
            case "PKNumberStyleSpellOut":
                formatter.numberStyle = .spellOut
            default:
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 6
            }
        }
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
