import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext

/// TSupport Templates — Official template fetch/cache/language-setting layer (Round A).
/// See `ai-docs/tsupport/50-templates-design.md` for the full design; decisions D28-D37.
/// Support accounts only; nothing here is reachable from a regular account's code paths.

public let supportTemplatesBaseURL = "https://templates.tsupport.org/"
private let supportTemplateRedirectFileName = "tl_redirect.txt"
/// Sentinel cache/fetch key for the redirect file - distinct from every real language code.
private let supportTemplateRedirectKey = "_redirect"

public struct SupportTemplateLanguage: Equatable {
    public let code: String
    public let fileName: String
    public let displayName: String
}

/// The owner-supplied, hardcoded list of official template files. There is no server-side
/// manifest/index to discover these from (F20): the domain root is a static page.
public let supportTemplateLanguages: [SupportTemplateLanguage] = [
    SupportTemplateLanguage(code: "ar", fileName: "tl_general_ar.txt", displayName: "العربية"),
    SupportTemplateLanguage(code: "de", fileName: "tl_general_de.txt", displayName: "Deutsch"),
    SupportTemplateLanguage(code: "en", fileName: "tl_general_en.txt", displayName: "English"),
    SupportTemplateLanguage(code: "es", fileName: "tl_general_es.txt", displayName: "Español"),
    SupportTemplateLanguage(code: "es-419", fileName: "tl_general_es_419.txt", displayName: "Español (Latinoamérica)"),
    SupportTemplateLanguage(code: "fa-IR", fileName: "tl_general_fa_IR.txt", displayName: "فارسی"),
    SupportTemplateLanguage(code: "id", fileName: "tl_general_id.txt", displayName: "Bahasa Indonesia"),
    SupportTemplateLanguage(code: "it", fileName: "tl_general_it.txt", displayName: "Italiano"),
    SupportTemplateLanguage(code: "ms", fileName: "tl_general_ms.txt", displayName: "Bahasa Melayu"),
    SupportTemplateLanguage(code: "nl", fileName: "tl_general_nl.txt", displayName: "Nederlands"),
    SupportTemplateLanguage(code: "pt-BR", fileName: "tl_general_pt_BR.txt", displayName: "Português (Brasil)"),
    SupportTemplateLanguage(code: "ru", fileName: "tl_general_ru.txt", displayName: "Русский"),
]

public struct SupportTemplateSettings: Codable, Equatable {
    public static let defaultLanguage = "en"

    public var language: String

    public init(language: String) {
        self.language = language
    }

    private enum CodingKeys: String, CodingKey {
        case language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? SupportTemplateSettings.defaultLanguage
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.language, forKey: .language)
    }
}

private final class CachedSupportTemplateList: Codable {
    let templates: [SupportTemplate]
    let updatedAt: Int32

    init(templates: [SupportTemplate], updatedAt: Int32) {
        self.templates = templates
        self.updatedAt = updatedAt
    }
}

private func defaultSupportTemplateLanguage(context: AccountContext) -> String {
    let appLanguageCode = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    if supportTemplateLanguages.contains(where: { $0.code == appLanguageCode }) {
        return appLanguageCode
    }
    let primary = appLanguageCode.components(separatedBy: "-").first ?? appLanguageCode
    if let match = supportTemplateLanguages.first(where: { $0.code == primary || $0.code.hasPrefix(primary + "-") }) {
        return match.code
    }
    return SupportTemplateSettings.defaultLanguage
}

private func supportTemplateSettingsKey(context: AccountContext) -> EngineDataBuffer {
    return ApplicationSpecificSharedDataKeys.supportTemplateSettings(peerId: context.account.peerId, testingEnvironment: context.account.testingEnvironment)
}

/// Persisted per-account "my template language" (D35), in the app-wide database so it
/// survives logging out and back in. Defaults to the app's current language when nothing has
/// been saved yet.
public func supportTemplateLanguageSetting(context: AccountContext) -> Signal<String, NoError> {
    let key = supportTemplateSettingsKey(context: context)
    return context.sharedContext.accountManager.sharedData(keys: [key])
    |> map { sharedData -> String in
        if let settings = sharedData.entries[key]?.get(SupportTemplateSettings.self) {
            return settings.language
        }
        return defaultSupportTemplateLanguage(context: context)
    }
    |> distinctUntilChanged
}

public func updateSupportTemplateLanguage(context: AccountContext, language: String) -> Signal<Never, NoError> {
    let key = supportTemplateSettingsKey(context: context)
    return context.sharedContext.accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(key, { _ in
            return SharedPreferencesEntry(SupportTemplateSettings(language: language))
        })
    }
    |> ignoreValues
}

private func cachedSupportTemplates(context: AccountContext, key: String) -> Signal<(templates: [SupportTemplate], updatedAt: Int32?), NoError> {
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.supportTemplateCache, id: EngineDataBuffer(key)))
    |> map { entry -> (templates: [SupportTemplate], updatedAt: Int32?) in
        if let cached = entry?.get(CachedSupportTemplateList.self) {
            return (cached.templates, cached.updatedAt)
        }
        return ([], nil)
    }
}

private func fetchAndStoreSupportTemplates(context: AccountContext, url: String, cacheKey: String) -> Signal<Never, NoError> {
    return fetchHttpResource(url: url)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<EngineMediaResourceDataFetchResult?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard case let .dataPart(_, data, _, complete)? = result, complete, let text = String(data: data, encoding: .utf8) else {
            // Fetch failed or came back empty: silently keep whatever is already cached
            // (D32) - no error surfaced mid-chat.
            return .complete()
        }
        let (_, templates) = parseSupportTemplateFile(text)
        let cacheItem = CachedSupportTemplateList(templates: templates, updatedAt: Int32(Date().timeIntervalSince1970))
        return context.engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.supportTemplateCache, id: EngineDataBuffer(cacheKey), item: cacheItem)
    }
}

private let fetchedSupportTemplateKeys = Atomic<Set<String>>(value: [])

/// Returns `true` only the first time this exact key is seen for the lifetime of the
/// process, so repeated subscriptions to the same language don't each re-trigger a fetch.
private func markSupportTemplateFetchRequested(_ key: String) -> Bool {
    var wasNew = false
    let _ = fetchedSupportTemplateKeys.modify { set in
        if set.contains(key) {
            return set
        }
        wasNew = true
        var updated = set
        updated.insert(key)
        return updated
    }
    return wasNew
}

/// Fetch-on-first-use: the first subscriber for a given (account, language) triggers a
/// background fetch; everyone else just observes the resulting cache update. In practice
/// this is warm well before a volunteer opens a chat, since the chat list itself is the
/// first screen shown after login. (Documented simplification vs. D32's literal "prefetch
/// the moment an account becomes support" - same warm-by-first-use outcome, no extra hook
/// into the isSupportUser reconciliation path.)
private func ensureSupportTemplatesFetched(context: AccountContext, language: String) {
    let accountKey = "\(context.account.id)"
    if markSupportTemplateFetchRequested("\(accountKey)-\(language)"), let info = supportTemplateLanguages.first(where: { $0.code == language }) {
        let _ = fetchAndStoreSupportTemplates(context: context, url: supportTemplatesBaseURL + info.fileName, cacheKey: language).startStandalone()
    }
    if markSupportTemplateFetchRequested("\(accountKey)-\(supportTemplateRedirectKey)") {
        let _ = fetchAndStoreSupportTemplates(context: context, url: supportTemplatesBaseURL + supportTemplateRedirectFileName, cacheKey: supportTemplateRedirectKey).startStandalone()
    }
}

/// Official templates for `language`, merged with the (language-independent) redirect
/// templates. Triggers a background fetch on first use if nothing is cached yet.
public func supportTemplates(context: AccountContext, language: String) -> Signal<[SupportTemplate], NoError> {
    ensureSupportTemplatesFetched(context: context, language: language)
    
    return combineLatest(
        cachedSupportTemplates(context: context, key: language),
        cachedSupportTemplates(context: context, key: supportTemplateRedirectKey)
    )
    |> map { language, redirect -> [SupportTemplate] in
        return language.templates + redirect.templates
    }
}

public func supportTemplateLastUpdated(context: AccountContext, language: String) -> Signal<Date?, NoError> {
    return cachedSupportTemplates(context: context, key: language)
    |> map { result -> Date? in
        return result.updatedAt.flatMap { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

/// Manual "Reload" (D32): unconditionally re-fetches and full-replaces this language's cache
/// plus the redirect file, bypassing the first-use guard.
public func reloadSupportTemplates(context: AccountContext, language: String) -> Signal<Never, NoError> {
    guard let info = supportTemplateLanguages.first(where: { $0.code == language }) else {
        return .complete()
    }
    return combineLatest(
        fetchAndStoreSupportTemplates(context: context, url: supportTemplatesBaseURL + info.fileName, cacheKey: language),
        fetchAndStoreSupportTemplates(context: context, url: supportTemplatesBaseURL + supportTemplateRedirectFileName, cacheKey: supportTemplateRedirectKey)
    )
    |> ignoreValues
}

/// Below this length, a bare substring match against Question/Value text is too noisy to be
/// useful (almost every template would match a 1-2 character query) - keys-prefix matching
/// has no such floor since keys are deliberately short, purpose-built tags.
private let supportTemplateContentMatchMinimumLength = 3

/// Matches `normalizedQuery` as a prefix of any of a template's keys (after normalizing the
/// key the same way), deduplicating so a template with several matching keys still produces
/// exactly one result. Owner feedback (Round B): once the query is long enough to be
/// meaningful, also match it as a substring of the Question or Value text, so the `/`-strip
/// isn't limited to exact short tag prefixes.
public func matchingSupportTemplates(_ templates: [SupportTemplate], normalizedQuery: String) -> [SupportTemplate] {
    guard !normalizedQuery.isEmpty else {
        return templates
    }
    let matchContent = normalizedQuery.count >= supportTemplateContentMatchMinimumLength
    return templates.filter { template in
        if template.keys.contains(where: { normalizeSupportTemplateQuestion($0).hasPrefix(normalizedQuery) }) {
            return true
        }
        guard matchContent else {
            return false
        }
        if normalizeSupportTemplateQuestion(template.question).contains(normalizedQuery) {
            return true
        }
        if case let .text(text) = template.value, normalizeSupportTemplateQuestion(text).contains(normalizedQuery) {
            return true
        }
        return false
    }
}
