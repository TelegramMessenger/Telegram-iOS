import Foundation

// MARK: - Intl delegation (pure formatting, no I/O)

enum IntlBridge {
    /// A BCP 47 tag as a Locale. Locale(identifier:) misreads a Unicode extension ("ar-EG-u-nu-arab" becomes
    /// "ar_EG@numbers=yes") and Foundation traps on the formatters of such a locale; Locale.Components parses it.
    /// Before macOS 13 the extension is dropped instead, so it never reaches Locale(identifier:).
    static func bcp47Locale(_ tag: String) -> Locale {
        if #available(macOS 13, iOS 16, *) {
            return Locale(components: Locale.Components(identifier: tag))
        }
        return Locale(identifier: withoutUnicodeExtension(tag))
    }

    static func withoutUnicodeExtension(_ tag: String) -> String {
        var kept: [Substring] = []
        var inExtension = false
        for part in tag.split(separator: "-", omittingEmptySubsequences: false) {
            if part.count == 1 {
                inExtension = part.lowercased() == "u"
            }
            if !inExtension {
                kept.append(part)
            }
        }
        return kept.joined(separator: "-")
    }

    static func format(requestJson: String) -> String {
        guard let req = SandboxEngine.parse(requestJson) as? [String: Any], let kind = req["kind"] as? String else { return "" }
        let locale = (req["locale"] as? String).map(bcp47Locale) ?? ((req["locale"] as? [String])?.first).map(bcp47Locale) ?? .current
        let opts = req["opts"] as? [String: Any] ?? [:]
        let value = (req["value"] as? NSNumber)?.doubleValue ?? 0
        switch kind {
        case "number":
            let f = numberFormatter(locale: locale, options: opts, value: value)
            return f.string(from: NSNumber(value: value)) ?? String(value)
        case "numberParts":
            let f = numberFormatter(locale: locale, options: opts, value: value)
            return json(numberParts(f.string(from: NSNumber(value: value)) ?? String(value), f))
        case "date", "dateMethod":
            let date = Date(timeIntervalSince1970: value / 1000)
            let method = req["method"] as? String
            let f = dateFormatter(locale: locale, options: opts, method: method)
            return f.string(from: date)
        case "dateParts":
            let method = req["method"] as? String
            let f = dateFormatter(locale: locale, options: opts, method: method)
            return json(dateParts(Date(timeIntervalSince1970: value / 1000), f))
        case "numberOptions":
            let f = numberFormatter(locale: locale, options: opts)
            var out: [String: Any] = ["locale": languageTag(locale), "numberingSystem": "latn", "style": opts["style"] as? String ?? "decimal",
                                      "minimumIntegerDigits": f.minimumIntegerDigits, "minimumFractionDigits": f.minimumFractionDigits,
                                      "maximumFractionDigits": f.maximumFractionDigits, "useGrouping": f.usesGroupingSeparator ? "auto" : false,
                                      "signDisplay": opts["signDisplay"] as? String ?? "auto"]
            if let currency = opts["currency"] as? String { out["currency"] = currency.uppercased() }
            return jsonObject(out)
        case "dateOptions":
            let zone = (opts["timeZone"] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
            var out = opts.filter { $0.value is String || $0.value is NSNumber }
            out.merge(["locale": languageTag(locale), "calendar": "gregory", "numberingSystem": "latn", "timeZone": zone.identifier]) { $1 }
            return jsonObject(out)
        case "plural":
            return CLDRPluralRules.select(value, locale: locale, options: opts)
        case "relative":
            guard #available(macOS 10.15, iOS 13.0, *) else {
                return ""
            }
            return relative(value, unit: req["unit"] as? String ?? "second", locale: locale, options: opts)
        case "list":
            let items = (req["value"] as? [Any])?.map { "\($0)" } ?? []
            guard #available(macOS 10.15, iOS 13.0, *) else {
                return items.joined(separator: ", ")
            }
            let type = opts["type"] as? String, style = opts["style"] as? String
            if #available(macOS 12, iOS 15, *) {
                // Foundation has no unit lists: a narrow conjunction is the closest (the same in English).
                let narrow = style == "narrow" || type == "unit"
                return items.formatted(.list(type: type == "disjunction" ? .or : .and, width: narrow ? .narrow : style == "short" ? .short : .standard).locale(locale))
            }
            let f = ListFormatter()
            f.locale = locale
            return f.string(from: items) ?? items.joined(separator: ", ")
        case "compare":
            let a = req["a"] as? String ?? "", b = req["b"] as? String ?? ""
            var options: String.CompareOptions = []
            switch opts["sensitivity"] as? String {
            case "base": options.formUnion([.caseInsensitive, .diacriticInsensitive])
            case "accent": options.insert(.caseInsensitive)
            case "case": options.insert(.diacriticInsensitive)
            default: break
            }
            if opts["numeric"] as? Bool == true { options.insert(.numeric) }
            return String(a.compare(b, options: options, range: nil, locale: locale).rawValue)
        case "upper":
            return (req["value"] as? String ?? "").uppercased(with: locale)
        case "lower":
            return (req["value"] as? String ?? "").lowercased(with: locale)
        default:
            return ""
        }
    }

    @available(macOS 10.15, iOS 13.0, *)
    private static func relative(_ value: Double, unit rawUnit: String, locale: Locale, options: [String: Any]) -> String {
        if rawUnit == "quarter" || rawUnit == "quarters" {
            // RelativeDateTimeFormatter has no quarter: English is written out, other languages count months.
            if CLDRPluralRules.languageKey(locale) == "en" { return englishQuarters(value, options: options) }
            return relative(value * 3, unit: "month", locale: locale, options: options)
        }
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.dateTimeStyle = options["numeric"] as? String == "auto" ? .named : .numeric
        switch options["style"] as? String {
        case "short": f.unitsStyle = .short
        case "narrow": f.unitsStyle = .abbreviated
        default: f.unitsStyle = .full
        }
        let unit = rawUnit.hasSuffix("s") ? String(rawUnit.dropLast()) : rawUnit
        if value == value.rounded(), abs(value) < 1e9 {
            let n = Int(value)
            var c = DateComponents()
            switch unit {
            case "second": c.second = n
            case "minute": c.minute = n
            case "hour": c.hour = n
            case "day": c.day = n
            case "week": c.weekOfMonth = n
            case "month": c.month = n
            case "year": c.year = n
            default: c.second = nil
            }
            if c != DateComponents() {
                let s = f.localizedString(from: c)
                if !s.isEmpty { return s }
            }
        }
        let seconds: Double = ["second": 1, "minute": 60, "hour": 3600, "day": 86400, "week": 604800, "month": 2_592_000, "quarter": 7_776_000, "year": 31_536_000][unit] ?? 1
        return f.localizedString(fromTimeInterval: value * seconds)
    }

    /// `RelativeTimeFormat` in English for the quarter unit, as CLDR words it.
    private static func englishQuarters(_ value: Double, options: [String: Any]) -> String {
        let style = options["style"] as? String ?? "long"
        if options["numeric"] as? String == "auto", value == value.rounded(), abs(value) <= 1 {
            let unit = style == "long" ? "quarter" : "qtr."
            return (value < 0 ? "last " : value > 0 ? "next " : "this ") + unit
        }
        let n = NumberFormatter()
        n.locale = Locale(identifier: "en_US")
        n.numberStyle = .decimal
        n.maximumFractionDigits = 3
        let count = n.string(from: NSNumber(value: abs(value))) ?? String(abs(value))
        let one = count == "1"
        let amount = style == "narrow" ? count + "q" : count + " " + (style == "short" ? (one ? "qtr." : "qtrs.") : (one ? "quarter" : "quarters"))
        return value < 0 || (value == 0 && value.sign == .minus) ? amount + " ago" : "in " + amount
    }

    /// ECMA-402's signDisplay on a formatter: "always" signs everything, "exceptZero" what does not round to zero,
    /// "negative" puts a minus only on negatives that do not round to zero, "never" shows none ("auto" is the default).
    private static func applySignDisplay(_ sign: String, value: Double, to f: NumberFormatter) {
        let shown = f.string(from: NSNumber(value: abs(value))) ?? ""
        let zero = !shown.unicodeScalars.contains { $0.properties.numericType == .decimal && $0.properties.numericValue != 0 }
        let negative = value < 0 || (value == 0 && value.sign == .minus)
        let plus = (sign == "always" && !negative) || (sign == "exceptZero" && !negative && !zero)
        let noMinus = sign == "never" || ((sign == "exceptZero" || sign == "negative") && zero)
        if plus { f.positivePrefix = (f.plusSign ?? "+") + (f.positivePrefix ?? "") }
        if noMinus {
            f.negativePrefix = f.positivePrefix
            f.negativeSuffix = f.positiveSuffix
        }
    }

    private static func numberFormatter(locale: Locale, options opts: [String: Any], value: Double? = nil) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        // ECMA-402 rounds half away from zero (halfExpand); NumberFormatter's default is half-even.
        f.roundingMode = .halfUp
        switch opts["style"] as? String {
        case "currency": f.numberStyle = .currency; if let c = opts["currency"] as? String { f.currencyCode = c }
        case "percent": f.numberStyle = .percent
        default: f.numberStyle = .decimal
        }
        if let n = (opts["minimumFractionDigits"] as? NSNumber)?.intValue { f.minimumFractionDigits = n }
        if let n = (opts["maximumFractionDigits"] as? NSNumber)?.intValue { f.maximumFractionDigits = n }
        if let g = opts["useGrouping"] as? Bool { f.usesGroupingSeparator = g }
        if let n = (opts["minimumIntegerDigits"] as? NSNumber)?.intValue { f.minimumIntegerDigits = n }
        if opts["minimumSignificantDigits"] != nil || opts["maximumSignificantDigits"] != nil {
            f.usesSignificantDigits = true
            if let n = (opts["minimumSignificantDigits"] as? NSNumber)?.intValue { f.minimumSignificantDigits = n }
            f.maximumSignificantDigits = (opts["maximumSignificantDigits"] as? NSNumber)?.intValue ?? 21
        }
        if f.numberStyle == .currency {
            switch opts["currencyDisplay"] as? String {
            case "code": f.numberStyle = .currencyISOCode
            case "name": f.numberStyle = .currencyPlural
            default: break
            }
        }
        if let sign = opts["signDisplay"] as? String, sign != "auto", let value { applySignDisplay(sign, value: value, to: f) }
        return f
    }

    private static func languageTag(_ locale: Locale) -> String {
        if #available(macOS 13, iOS 16, *) {
            return locale.identifier(.bcp47)
        }
        return locale.identifier.replacingOccurrences(of: "_", with: "-")
    }

    private static func jsonObject(_ object: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private static func json(_ parts: [(String, String)]) -> String {
        let list = parts.map { ["type": $0.0, "value": $0.1] }
        return (try? JSONSerialization.data(withJSONObject: list)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    /// JS `NumberFormat.formatToParts`: the formatted string split by the formatter's own symbols.
    static func numberParts(_ s: String, _ f: NumberFormatter) -> [(String, String)] {
        var out: [(String, String)] = []
        func push(_ type: String, _ text: String) {
            if let last = out.last, last.0 == type, type == "literal" || type == "currency" { out[out.count - 1].1 += text } else { out.append((type, text)) }
        }
        let symbols: [(String, String)] = [(f.currencySymbol ?? "", "currency"), (f.internationalCurrencySymbol ?? "", "currency"), (f.percentSymbol ?? "", "percentSign"),
                                           (f.minusSign ?? "", "minusSign"), (f.plusSign ?? "", "plusSign"), (f.exponentSymbol ?? "", "exponentSeparator"),
                                           (f.notANumberSymbol ?? "", "nan"), ("∞", "infinity")].filter { !$0.0.isEmpty }.sorted { $0.0.count > $1.0.count }
        var i = s.startIndex
        var fraction = false
        var digits = ""
        func flush() { if !digits.isEmpty { push(fraction ? "fraction" : "integer", digits); digits = "" } }
        while i < s.endIndex {
            let rest = s[i...]
            if s[i].isWholeNumber { digits.append(s[i]); i = s.index(after: i); continue }
            if !fraction, !digits.isEmpty, let decimal = f.decimalSeparator, !decimal.isEmpty, rest.hasPrefix(decimal), rest.dropFirst(decimal.count).first?.isWholeNumber == true {
                flush(); push("decimal", decimal); fraction = true; i = s.index(i, offsetBy: decimal.count); continue
            }
            if !fraction, !digits.isEmpty, let group = f.groupingSeparator, !group.isEmpty, rest.hasPrefix(group), rest.dropFirst(group.count).first?.isWholeNumber == true {
                flush(); push("group", group); i = s.index(i, offsetBy: group.count); continue
            }
            flush()
            if let symbol = symbols.first(where: { rest.hasPrefix($0.0) }) {
                push(symbol.1, symbol.0); i = s.index(i, offsetBy: symbol.0.count); continue
            }
            push("literal", String(s[i])); i = s.index(after: i)
        }
        flush()
        return out
    }

    /// JS `DateTimeFormat.formatToParts`: the formatter's pattern split into fields, each formatted on its own.
    static func dateParts(_ date: Date, _ f: DateFormatter) -> [(String, String)] {
        let types: [Character: String] = ["G": "era", "y": "year", "u": "year", "Y": "year", "M": "month", "L": "month", "d": "day", "E": "weekday", "c": "weekday", "e": "weekday",
                                          "a": "dayPeriod", "b": "dayPeriod", "B": "dayPeriod", "h": "hour", "H": "hour", "k": "hour", "K": "hour", "m": "minute", "s": "second",
                                          "S": "fractionalSecond", "z": "timeZoneName", "Z": "timeZoneName", "v": "timeZoneName", "V": "timeZoneName", "O": "timeZoneName", "X": "timeZoneName", "x": "timeZoneName"]
        var out: [(String, String)] = []
        func literal(_ text: String) {
            if text.isEmpty { return }
            if let last = out.last, last.0 == "literal" { out[out.count - 1].1 += text } else { out.append(("literal", text)) }
        }
        let pattern = Array(f.dateFormat ?? "")
        var i = 0
        while i < pattern.count {
            let c = pattern[i]
            if c == "'" {
                var j = i + 1
                var text = ""
                while j < pattern.count {
                    if pattern[j] == "'" { if j + 1 < pattern.count && pattern[j + 1] == "'" { text.append("'"); j += 2; continue }; break }
                    text.append(pattern[j]); j += 1
                }
                literal(i + 1 == j ? "'" : text)
                i = j + 1
            } else if c.isASCII && c.isLetter {
                var j = i
                while j < pattern.count && pattern[j] == c { j += 1 }
                let single = DateFormatter()
                single.locale = f.locale
                single.timeZone = f.timeZone
                single.calendar = f.calendar
                single.dateFormat = String(pattern[i..<j])
                let text = single.string(from: date)
                if let type = types[c] { out.append((type, text)) } else { literal(text) }
                i = j
            } else {
                literal(String(c)); i += 1
            }
        }
        return out
    }

    /// `pattern` with every unquoted run of the field letter `field` replaced by `with`.
    static func replacingField(_ field: Character, in pattern: String, with replacement: String) -> String {
        var out = "", quoted = false, inField = false
        for c in pattern {
            if c == "'" { quoted.toggle() }
            if !quoted && c == field {
                if !inField { out += replacement }
                inField = true
            } else {
                inField = false
                out.append(c)
            }
        }
        return out
    }

    /// Apple's patterns join a medium or short date to the time with the "at" connector; ECMA-402 (CLDR's standard
    /// date-time format) uses it only after a long date (full month or weekday name) and joins the others as the
    /// numeric skeleton does ("Jan 1, 1970, 1:45 PM").
    static func plainConnector(_ pattern: String, locale: Locale) -> String {
        func middle(_ whole: String?, _ head: String?, _ tail: String?) -> String? {
            guard let whole, let head, let tail, whole.count > head.count + tail.count, whole.hasPrefix(head), whole.hasSuffix(tail) else { return nil }
            return String(whole.dropFirst(head.count).dropLast(tail.count))
        }
        let template = { (t: String) in DateFormatter.dateFormat(fromTemplate: t, options: 0, locale: locale) }
        let styled = { (d: DateFormatter.Style, t: DateFormatter.Style) -> String? in
            let f = DateFormatter()
            f.locale = locale
            f.dateStyle = d
            f.timeStyle = t
            return f.dateFormat
        }
        guard let at = middle(styled(.medium, .short), styled(.medium, .none), styled(.none, .short)),
              let plain = middle(template("yMdjmm"), template("yMd"), template("jmm")),
              at != plain, pattern.contains(at),
              !["MMMM", "LLLL", "EEEE", "cccc"].contains(where: pattern.contains) else { return pattern }
        return pattern.replacingOccurrences(of: at, with: plain)
    }

    private static func dateFormatter(locale: Locale, options: [String: Any], method: String?) -> DateFormatter {
        let zone = (options["timeZone"] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
        let optionsData = (try? JSONSerialization.data(withJSONObject: options, options: [.sortedKeys])) ?? Data()
        let key = "\(locale.identifier)|\(zone.identifier)|\(method ?? "")|\(String(decoding: optionsData, as: UTF8.self))" as NSString
        let cache: NSCache<NSString, DateFormatter>
        if let existing = Thread.current.threadDictionary["WidgetSandbox.IntlBridge.dateFormatters"] as? NSCache<NSString, DateFormatter> {
            cache = existing
        } else {
            cache = NSCache<NSString, DateFormatter>()
            cache.countLimit = 64
            Thread.current.threadDictionary["WidgetSandbox.IntlBridge.dateFormatters"] = cache
        }
        if let formatter = cache.object(forKey: key) { return formatter }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        let wantsDate = ["era", "weekday", "year", "month", "day", "dateStyle"].contains { options[$0] != nil }
        let wantsTime = ["hour", "minute", "second", "fractionalSecondDigits", "timeZoneName", "timeStyle"].contains { options[$0] != nil }
        var hourSymbol = "j"
        if let hour12 = options["hour12"] as? Bool {
            hourSymbol = hour12 ? "h" : "H"
        } else if let cycle = options["hourCycle"] as? String {
            hourSymbol = ["h11": "K", "h12": "h", "h23": "H", "h24": "k"][cycle] ?? "j"
        }
        if let cycle = ["K": "h11", "h": "h12", "H": "h23", "k": "h24"][hourSymbol] {
            var components = Locale.components(fromIdentifier: locale.identifier)
            components["hours"] = cycle
            formatter.locale = Locale(identifier: Locale.identifier(fromComponents: components))
        }
        if wantsDate || wantsTime {
            var template = ""
            if let weekday = options["weekday"] as? String { template += weekday == "long" ? "EEEE" : weekday == "narrow" ? "EEEEE" : "EEE" }
            if let month = options["month"] as? String { template += month == "long" ? "MMMM" : month == "short" ? "MMM" : month == "narrow" ? "MMMMM" : month == "numeric" ? "M" : "MM" }
            if let day = options["day"] as? String { template += day == "2-digit" ? "dd" : "d" }
            if let year = options["year"] as? String { template += year == "2-digit" ? "yy" : "y" }
            if let hour = options["hour"] as? String { template += hour == "2-digit" ? hourSymbol + hourSymbol : hourSymbol }
            if options["minute"] != nil { template += "mm" }
            if options["second"] != nil { template += "ss" }
            if let digits = (options["fractionalSecondDigits"] as? NSNumber)?.intValue, (1...3).contains(digits) { template += String(repeating: "S", count: digits) }
            if let era = options["era"] as? String { template += era == "long" ? "GGGG" : era == "narrow" ? "GGGGG" : "G" }
            if let zone = options["timeZoneName"] as? String {
                template += ["long": "zzzz", "shortOffset": "O", "longOffset": "OOOO", "shortGeneric": "v", "longGeneric": "vvvv"][zone] ?? "z"
            }
            if template.isEmpty {
                formatter.dateStyle = Self.style(options["dateStyle"] as? String)
                formatter.timeStyle = Self.style(options["timeStyle"] as? String)
            } else {
                formatter.setLocalizedDateFormatFromTemplate(template)
                // The pattern generator may pick another era width than asked for (en: "GGGGG", a lone "A").
                if let era = options["era"] as? String {
                    formatter.dateFormat = replacingField("G", in: formatter.dateFormat ?? "", with: era == "long" ? "GGGG" : era == "narrow" ? "GGGGG" : "G")
                }
                // ECMA-402 calls the UTC zone "UTC" (Foundation: "GMT").
                if options["timeZoneName"] as? String == "short", ["UTC", "GMT", "Etc/UTC", "Etc/GMT"].contains(zone.identifier) {
                    formatter.dateFormat = replacingField("z", in: formatter.dateFormat ?? "", with: "'UTC'")
                }
            }
            formatter.dateFormat = plainConnector(formatter.dateFormat ?? "", locale: locale)
        }
        if hourSymbol != "j" || options["hour"] as? String == "2-digit" {
            let defaultTimePattern = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale) ?? ""
            let inferredPadding = (options["hour"] as? String != "numeric" || defaultTimePattern.contains("h")) && ["hh", "HH", "KK", "kk"].contains(where: (formatter.dateFormat ?? "").contains)
            let stylePadding = options["timeStyle"] != nil && (defaultTimePattern.contains("HH") || defaultTimePattern.contains("kk"))
            let paddedHour = options["hour"] as? String == "2-digit" || inferredPadding || stylePadding
            var quoted = false
            var inHour = false
            var pattern = ""
            for character in formatter.dateFormat ?? "" {
                if character == "'" { quoted.toggle() }
                if !quoted && "hHKk".contains(character) {
                    if !inHour {
                        let symbol = hourSymbol == "j" ? String(character) : hourSymbol
                        pattern += paddedHour ? symbol + symbol : symbol
                    }
                    inHour = true
                } else {
                    inHour = false
                    pattern.append(!quoted && "bB".contains(character) ? "a" : character)
                }
            }
            formatter.dateFormat = pattern
        }
        cache.setObject(formatter, forKey: key)
        return formatter
    }

    private static func style(_ s: String?) -> DateFormatter.Style {
        switch s { case "full": return .full; case "long": return .long; case "medium": return .medium; case "short": return .short; default: return .none }
    }
}
