import Foundation
import OSLog
import TDShim

/// Loads the watch's strings from translations.telegram.org through TDLib.
///
/// The watch uses the iOS app's localization target (`ios`), so it gets the
/// same translations as the iPhone: the legacy `Watch.*` keys plus any iOS
/// key the watch reuses. The language follows the watch's preferred
/// languages, matched against the official language packs, with the
/// server's English pack when none matches. Every language, English included,
/// comes from the platform and updates live; the bundled English is only the
/// fallback until a pack has loaded (first launch, offline).
enum LanguagePackSync {
    static let localizationTarget = "ios"

    private static let logger = Logger(subsystem: "com.isaac.tgwatch", category: "l10n")

    /// Sets the language pack options. Call right before
    /// `setTdlibParameters`, without waiting for the results: TDLib holds
    /// option changes sent before its parameters and applies them before it
    /// creates its language pack manager, which reads the database path only
    /// then.
    ///
    /// The database keeps the language pack and its version on disk, shared
    /// by all accounts, so TDLib downloads a pack once and afterwards only
    /// fetches what changed, like the iOS app. Passing the pack in use (from
    /// the cache) lets TDLib start syncing it before `run` has picked one.
    static func configure(client: TDLibClient, strings: AppStrings = .shared) {
        var options: [(String, OptionValue)] = [
            ("localization_target", .optionValueString(OptionValueString(value: localizationTarget)))
        ]
        if let databasePath = databaseURL()?.path {
            options.insert(("language_pack_database_path", .optionValueString(OptionValueString(value: databasePath))), at: 0)
        }
        if let languagePackId = strings.languagePackId {
            options.append(("language_pack_id", .optionValueString(OptionValueString(value: languagePackId))))
        }
        for (name, value) in options {
            do {
                try client.setOption(name: name, value: value) { result in
                    if case .failure(let error) = result {
                        logger.warning("setOption \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } catch {
                logger.warning("setOption \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Selects the language pack for the watch's language and loads its
    /// strings into `AppStrings`. Call once per TDLib client, after
    /// `setTdlibParameters` (and `configure`); the language pack requests work
    /// before authorization.
    ///
    /// TDLib then keeps the pack current: when the server reports a new
    /// version it fetches the difference and sends `updateLanguagePackStrings`,
    /// which `handle` applies.
    static func run(client: TDLibClient, strings: AppStrings = .shared) async {
        do {
            let info: LocalizationTargetInfo
            do {
                info = try await client.getLocalizationTargetInfo(onlyLocal: false)
            } catch {
                // Offline: choose from the pack list TDLib stored last time,
                // so a changed watch language still applies; the strings come
                // from TDLib's database if that pack was synced before.
                logger.notice("language pack list unavailable (\(error.localizedDescription, privacy: .public)); using the stored list")
                info = try await client.getLocalizationTargetInfo(onlyLocal: true)
            }
            guard let pack = selectLanguagePack(
                from: info.languagePacks,
                preferredLanguages: Locale.preferredLanguages
            ) else {
                // The server lists no official pack, not even English; keep
                // whatever is loaded.
                logger.warning("no official language pack for \(Locale.preferredLanguages, privacy: .public)")
                return
            }
            try await client.setOption(
                name: "language_pack_id",
                value: .optionValueString(OptionValueString(value: pack.id))
            )
            let snapshot = try await loadSnapshot(
                client: client,
                languagePackId: pack.id,
                pluralCode: pack.pluralCode.isEmpty ? pack.id : pack.pluralCode,
                baseLanguagePackId: pack.baseLanguagePackId.isEmpty ? nil : pack.baseLanguagePackId,
                keys: strings.keys
            )
            await strings.apply(snapshot)
        } catch {
            // Keep whatever is loaded (the cached pack or English); the next
            // launch retries.
            logger.warning("language pack sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reloads the strings of the loaded pack. TDLib serves them from its
    /// database, so this makes no network request once the pack is synced.
    private static func reload(client: TDLibClient, strings: AppStrings) async {
        guard let current = strings.snapshot else { return }
        do {
            let snapshot = try await loadSnapshot(
                client: client,
                languagePackId: current.languagePackId,
                pluralCode: current.pluralCode,
                baseLanguagePackId: current.baseLanguagePackId,
                keys: strings.keys
            )
            await strings.apply(snapshot)
        } catch {
            logger.warning("language pack reload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadSnapshot(
        client: TDLibClient,
        languagePackId: String,
        pluralCode: String,
        baseLanguagePackId: String?,
        keys: [String]
    ) async throws -> LanguagePackSnapshot {
        let values = try await loadStrings(client: client, languagePackId: languagePackId, keys: keys)
        // Strings missing from a pack come from its base pack, if it has one.
        var baseValues: [String: LocalizedValue]? = nil
        if let baseLanguagePackId {
            baseValues = try await loadStrings(client: client, languagePackId: baseLanguagePackId, keys: keys)
        }
        logger.notice("loaded language pack \(languagePackId, privacy: .public) (base \(baseLanguagePackId ?? "none", privacy: .public)): \(values.count) of \(keys.count) strings")
        return LanguagePackSnapshot(
            languagePackId: languagePackId,
            pluralCode: pluralCode,
            strings: values,
            baseLanguagePackId: baseLanguagePackId,
            baseStrings: baseValues
        )
    }

    /// Applies `updateLanguagePackStrings` for the loaded pack or its base
    /// pack. An update with no strings means the whole pack changed (TDLib
    /// also sends one when it has finished downloading a pack), so the
    /// strings are loaded again.
    @MainActor
    static func handle(_ update: UpdateLanguagePackStrings, client: TDLibClient, strings: AppStrings = .shared) {
        guard update.localizationTarget == localizationTarget,
              update.languagePackId == strings.languagePackId
                || update.languagePackId == strings.baseLanguagePackId else { return }
        if update.strings.isEmpty {
            Task { await reload(client: client, strings: strings) }
            return
        }
        var changed: [String: LocalizedValue?] = [:]
        for entry in update.strings {
            changed[entry.key] = localizedValue(entry.value)
        }
        logger.notice("language pack \(update.languagePackId, privacy: .public) updated: \(update.strings.count) strings")
        strings.merge(languagePackId: update.languagePackId, strings: changed)
    }

    /// The official language pack for the first preferred language that has
    /// one, matching `pt-BR` to `pt-br` before `pt`, or the English pack when
    /// none has one.
    static func selectLanguagePack(from packs: [LanguagePackInfo], preferredLanguages: [String]) -> LanguagePackInfo? {
        let official = Dictionary(
            packs.filter { $0.isOfficial }.map { ($0.id.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for identifier in preferredLanguages {
            let language = Locale.Language(identifier: identifier)
            guard let code = language.languageCode?.identifier.lowercased() else { continue }
            var candidates: [String] = []
            if let script = language.script?.identifier.lowercased() {
                candidates.append("\(code)-\(script)")
            }
            if let region = language.region?.identifier.lowercased() {
                candidates.append("\(code)-\(region)")
            }
            candidates.append(code)
            for candidate in candidates {
                if let pack = official[candidate] {
                    return pack
                }
            }
        }
        return official["en"]
    }

    private static func loadStrings(
        client: TDLibClient,
        languagePackId: String,
        keys: [String]
    ) async throws -> [String: LocalizedValue] {
        let result = try await client.getLanguagePackStrings(keys: keys, languagePackId: languagePackId)
        var values: [String: LocalizedValue] = [:]
        for entry in result.strings {
            if let value = localizedValue(entry.value) {
                values[entry.key] = value
            }
        }
        return values
    }

    /// TDLib's language pack database, next to the per-account databases.
    private static func databaseURL() -> URL? {
        guard let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else { return nil }
        let dir = support.appendingPathComponent("tdlib", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("langpack.sqlite", isDirectory: false)
    }

    private static func localizedValue(_ value: LanguagePackStringValue?) -> LocalizedValue? {
        switch value {
        case .languagePackStringValueOrdinary(let ordinary):
            return .plain(ordinary.value)
        case .languagePackStringValuePluralized(let forms):
            func nonEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }
            return .plural(PluralizedValue(
                zero: nonEmpty(forms.zeroValue),
                one: nonEmpty(forms.oneValue),
                two: nonEmpty(forms.twoValue),
                few: nonEmpty(forms.fewValue),
                many: nonEmpty(forms.manyValue),
                other: forms.otherValue
            ))
        case .languagePackStringValueDeleted, .unsupported, nil:
            return nil
        }
    }
}
