import Foundation
import Observation

/// Returns the localized string for `key`, with `args` substituted for its
/// `%@` / `%d` / `%1$@` placeholders.
///
/// Keys are language pack keys of the `ios` localization target on
/// translations.telegram.org, so the watch shares translations with the iOS
/// app. Every key must also be in the bundled English table
/// (`Localization/Localizable.strings`), which is the fallback while no
/// language pack is loaded (first launch, offline) and for strings a language
/// pack doesn't have.
///
/// Reading a string from a SwiftUI `body` subscribes the view to language
/// pack changes, so views redraw when the strings arrive.
func L(_ key: String, _ args: CustomStringConvertible...) -> String {
    return AppStrings.shared.string(key, args)
}

/// Returns the plural form of `key` for `count`. The iOS strings file stores
/// the forms as `key_0`, `key_1`, `key_2`, `key_3_10`, `key_many`, `key_any`;
/// pass the bare `key`. With no `args`, `count` fills the placeholder.
func LPlural(_ key: String, _ count: Int, _ args: CustomStringConvertible...) -> String {
    return AppStrings.shared.plural(key, count: count, args)
}

enum LocalizedValue: Codable, Equatable {
    case plain(String)
    case plural(PluralizedValue)
}

struct PluralizedValue: Codable, Equatable {
    var zero: String?
    var one: String?
    var two: String?
    var few: String?
    var many: String?
    var other: String

    func value(for form: PluralForm) -> String {
        let value: String?
        switch form {
        case .zero: value = zero
        case .one: value = one
        case .two: value = two
        case .few: value = few
        case .many: value = many
        case .other: value = other
        }
        return value ?? other
    }
}

/// A loaded language pack: the strings the watch uses, as served for one
/// language pack of the `ios` localization target, plus those of its base
/// language pack, which fills strings the pack doesn't have.
struct LanguagePackSnapshot: Codable, Equatable {
    var languagePackId: String
    var pluralCode: String
    var strings: [String: LocalizedValue]
    var baseLanguagePackId: String? = nil
    var baseStrings: [String: LocalizedValue]? = nil
}

/// The app's string table: a language pack from translations.telegram.org
/// over the bundled English strings.
///
/// `L` / `LPlural` lookups are thread-safe, so formatters running off the main
/// actor can use them too; only main-thread reads register SwiftUI
/// observation. The language pack is only ever replaced on the main thread,
/// and `locale` and `revision` are for main-thread use.
@Observable
final class AppStrings: @unchecked Sendable {
    static let shared = AppStrings()

    /// Bumped whenever the language pack changes. Lookups read it so SwiftUI
    /// views redraw with the new strings.
    private(set) var revision = 0

    /// The language the UI is in: the loaded language pack's, with the
    /// user's regional formats. Use it for any date or number shown next to
    /// localized text, so the two don't mix languages.
    private(set) var locale: Locale = .current

    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private let base: [String: LocalizedValue]
    @ObservationIgnored private var pack: LanguagePackSnapshot?
    /// `locale`, readable under `lock` for formatting off the main thread.
    @ObservationIgnored private var formatLocale: Locale = .current
    @ObservationIgnored private let cacheURL: URL?

    /// Language pack keys to request from the server: the bundled table's
    /// keys, with plural forms collapsed to their base key.
    @ObservationIgnored let keys: [String]

    init(bundle: Bundle = .main, cacheURL: URL? = AppStrings.defaultCacheURL()) {
        let base = AppStrings.loadBundledStrings(bundle: bundle)
        self.base = base
        self.keys = base.keys.sorted()
        self.cacheURL = cacheURL
        if let cacheURL,
           let data = try? Data(contentsOf: cacheURL),
           let snapshot = try? JSONDecoder().decode(LanguagePackSnapshot.self, from: data) {
            self.pack = snapshot
            self.locale = AppStrings.makeLocale(languagePackId: snapshot.languagePackId)
            self.formatLocale = self.locale
        }
    }

    /// Identifier of the loaded language pack, or nil when the UI is in the
    /// bundled English.
    var languagePackId: String? {
        lock.lock()
        defer { lock.unlock() }
        return pack?.languagePackId
    }

    /// The loaded language pack, or nil when the UI is in the bundled English.
    var snapshot: LanguagePackSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return pack
    }

    /// Identifier of the loaded language pack's base language pack, if any.
    var baseLanguagePackId: String? {
        lock.lock()
        defer { lock.unlock() }
        return pack?.baseLanguagePackId
    }

    /// Calls `onChange` after every language pack change for as long as
    /// `owner` is alive. Stores that keep formatted strings use it to rebuild
    /// them, since only views re-read `L` on their own.
    @MainActor
    func observeChanges<Owner: AnyObject>(_ owner: Owner, _ onChange: @escaping @MainActor (Owner) -> Void) {
        withObservationTracking {
            _ = revision
        } onChange: { [weak self, weak owner] in
            // Called before the change is stored; act once `apply`/`merge`
            // has returned.
            Task { @MainActor in
                guard let self, let owner else { return }
                onChange(owner)
                self.observeChanges(owner, onChange)
            }
        }
    }

    func string(_ key: String, _ args: [CustomStringConvertible] = []) -> String {
        registerAccess()
        let (value, _, locale) = lookup(key)
        let template: String
        switch value {
        case .plain(let string):
            template = string
        case .plural(let forms):
            template = forms.other
        case nil:
            template = key
        }
        return AppStrings.format(template, AppStrings.localizedNumbers(args, locale: locale))
    }

    func plural(_ key: String, count: Int, _ args: [CustomStringConvertible] = []) -> String {
        registerAccess()
        let (value, pluralCode, locale) = lookup(key)
        let template: String
        switch value {
        case .plural(let forms):
            template = forms.value(for: pluralForm(languageCode: pluralCode, count))
        case .plain(let string):
            template = string
        case nil:
            template = key
        }
        return AppStrings.format(template, AppStrings.localizedNumbers(args.isEmpty ? [count] : args, locale: locale))
    }

    /// Replaces the language pack (nil switches back to the bundled English)
    /// and persists it, so the next launch starts in the same language.
    @MainActor
    func apply(_ snapshot: LanguagePackSnapshot?) {
        let newLocale = AppStrings.makeLocale(languagePackId: snapshot?.languagePackId)
        lock.lock()
        let changed = pack != snapshot
        pack = snapshot
        formatLocale = newLocale
        lock.unlock()
        guard changed else { return }
        locale = newLocale
        revision += 1
        persist(snapshot)
    }

    /// Merges updated strings into the loaded language pack or its base
    /// language pack. Values of nil mean the string was deleted and falls
    /// back to the base language pack or English.
    @MainActor
    func merge(languagePackId: String, strings: [String: LocalizedValue?]) {
        lock.lock()
        guard var snapshot = pack else {
            lock.unlock()
            return
        }
        if snapshot.languagePackId == languagePackId {
            for (key, value) in strings where base[key] != nil {
                snapshot.strings[key] = value
            }
        } else if snapshot.baseLanguagePackId == languagePackId {
            var baseStrings = snapshot.baseStrings ?? [:]
            for (key, value) in strings where base[key] != nil {
                baseStrings[key] = value
            }
            snapshot.baseStrings = baseStrings
        } else {
            lock.unlock()
            return
        }
        let changed = pack != snapshot
        pack = snapshot
        lock.unlock()
        guard changed else { return }
        revision += 1
        persist(snapshot)
    }

    private func registerAccess() {
        if Thread.isMainThread {
            _ = revision
        }
    }

    private func lookup(_ key: String) -> (LocalizedValue?, String, Locale) {
        lock.lock()
        defer { lock.unlock() }
        if let pack, let value = pack.strings[key] ?? pack.baseStrings?[key] {
            return (value, pack.pluralCode, formatLocale)
        }
        return (base[key], "en", formatLocale)
    }

    private func persist(_ snapshot: LanguagePackSnapshot?) {
        guard let cacheURL else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: cacheURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }

    // MARK: - Helpers

    nonisolated static func defaultCacheURL() -> URL? {
        // Tests expect the bundled English, whatever language the app last
        // ran in on this device.
        if NSClassFromString("XCTestCase") != nil {
            return nil
        }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("langpack.json", isDirectory: false)
    }

    /// The bundled English strings, with each `key_0` … `key_any` group of
    /// iOS plural forms folded into one plural value under `key`.
    static func loadBundledStrings(bundle: Bundle) -> [String: LocalizedValue] {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let raw = NSDictionary(contentsOf: url) as? [String: String] else {
            return [:]
        }
        return foldPluralForms(raw)
    }

    static func foldPluralForms(_ raw: [String: String]) -> [String: LocalizedValue] {
        var result: [String: LocalizedValue] = [:]
        var pluralBases = Set<String>()
        for key in raw.keys where key.hasSuffix("_any") {
            pluralBases.insert(String(key.dropLast("_any".count)))
        }
        for (key, value) in raw {
            if pluralFormSuffixes.contains(where: { key.hasSuffix($0) && pluralBases.contains(String(key.dropLast($0.count))) }) {
                continue
            }
            result[key] = .plain(value)
        }
        for key in pluralBases {
            result[key] = .plural(PluralizedValue(
                zero: raw["\(key)_0"],
                one: raw["\(key)_1"],
                two: raw["\(key)_2"],
                few: raw["\(key)_3_10"],
                many: raw["\(key)_many"],
                other: raw["\(key)_any"] ?? key
            ))
        }
        return result
    }

    private static let pluralFormSuffixes = ["_0", "_1", "_2", "_3_10", "_many", "_any"]

    /// Integer arguments with the locale's grouping separator ("1,234"), as
    /// the iOS app formats counts in its strings.
    static func localizedNumbers(_ args: [CustomStringConvertible], locale: Locale) -> [CustomStringConvertible] {
        return args.map { arg -> CustomStringConvertible in
            guard let number = arg as? any BinaryInteger else { return arg }
            return Int(truncatingIfNeeded: number).formatted(.number.locale(locale))
        }
    }

    /// Substitutes `args` for the placeholders in a translated template.
    /// Supports `%@`, `%d`, `%ld`, `%i`, `%s` (sequential), their positional
    /// `%1$@` forms and `%%`. Unlike `String(format:)` it never crashes on a
    /// template whose placeholders don't match the arguments, which matters
    /// for strings that come from the server: a missing argument becomes
    /// empty and an unknown specifier is kept as written.
    static func format(_ template: String, _ args: [CustomStringConvertible]) -> String {
        guard template.contains("%") else { return template }
        var result = ""
        var nextIndex = 0
        var iterator = Array(template).makeIterator()
        var pending: Character? = nil
        func next() -> Character? {
            if let c = pending {
                pending = nil
                return c
            }
            return iterator.next()
        }
        while let c = next() {
            guard c == "%" else {
                result.append(c)
                continue
            }
            var spec = "%"
            var position: Int? = nil
            var digits = ""
            var current = next()
            while let d = current, d.isASCII, d.isNumber {
                digits.append(d)
                current = next()
            }
            if !digits.isEmpty {
                if current == "$" {
                    position = Int(digits)
                    spec += digits + "$"
                    current = next()
                } else {
                    spec += digits
                }
            }
            if current == "l" {
                spec += "l"
                current = next()
            }
            guard let conversion = current else {
                result += spec
                break
            }
            switch conversion {
            case "%" where spec == "%":
                result.append("%")
            case "@", "d", "i", "s", "u":
                let index: Int
                if let position {
                    index = position - 1
                } else {
                    index = nextIndex
                    nextIndex += 1
                }
                if index >= 0 && index < args.count {
                    result += args[index].description
                }
            default:
                result += spec
                pending = conversion
            }
        }
        return result
    }

    /// The UI locale for a language pack: the pack's language with the
    /// user's region, hour cycle and calendar. The bundled English (no pack)
    /// keeps the system locale.
    static func makeLocale(languagePackId: String?) -> Locale {
        guard let languagePackId else { return .current }
        var components = Locale.Components(locale: .current)
        components.languageComponents = Locale.Language.Components(identifier: languagePackId)
        return Locale(components: components)
    }
}
