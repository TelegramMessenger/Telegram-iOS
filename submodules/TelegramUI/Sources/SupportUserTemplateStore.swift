import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext

/// TSupport Templates — User Templates local storage (Round B). See
/// `ai-docs/tsupport/50-templates-design.md` §6 and D33. Local-only, per support account, no
/// cloud sync. Support accounts only; nothing here is reachable from a regular account's
/// code paths.

/// A volunteer-authored template. Wraps the shared `SupportTemplate` content with a stable
/// `id` that survives edits to the Question/Keys/Value - needed so Edit/Delete and collision
/// "jump to other template" navigation keep referring to the same entry even after its
/// content (and therefore its `normalizedQuestion`) changes.
public struct SupportUserTemplate: Codable, Equatable {
    public let id: String
    public var template: SupportTemplate

    public init(id: String = UUID().uuidString, template: SupportTemplate) {
        self.id = id
        self.template = template
    }
}

private final class SupportUserTemplateListPreference: Codable {
    let templates: [SupportUserTemplate]

    init(templates: [SupportUserTemplate]) {
        self.templates = templates
    }
}

/// Summary surfaced right after an import completes (D34): how many entries were added vs.
/// merged into an existing one by matching `{QUESTION}`, plus any *newly*-created key
/// overlaps with templates that already existed before the import (never a silent landmine).
public struct SupportUserTemplateImportSummary: Equatable {
    public var addedCount: Int
    public var updatedCount: Int
    public var newCollisionKeys: [String]

    public var isEmpty: Bool {
        return self.addedCount == 0 && self.updatedCount == 0
    }
}

public func supportUserTemplates(context: AccountContext) -> Signal<[SupportUserTemplate], NoError> {
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.supportUserTemplates))
    |> map { entry -> [SupportUserTemplate] in
        return entry?.get(SupportUserTemplateListPreference.self)?.templates ?? []
    }
}

private func updateSupportUserTemplates(context: AccountContext, _ f: @escaping ([SupportUserTemplate]) -> [SupportUserTemplate]) -> Signal<Never, NoError> {
    return context.engine.preferences.update(id: ApplicationSpecificPreferencesKeys.supportUserTemplates, { entry in
        let current = entry?.get(SupportUserTemplateListPreference.self)?.templates ?? []
        return SharedPreferencesEntry(SupportUserTemplateListPreference(templates: f(current)))
    })
}

/// Upsert by `id` - an existing entry's content is replaced in place (its position in the
/// list is preserved), a new `id` is appended.
public func addOrUpdateSupportUserTemplate(context: AccountContext, _ template: SupportUserTemplate) -> Signal<Never, NoError> {
    return updateSupportUserTemplates(context: context) { current in
        var current = current
        if let index = current.firstIndex(where: { $0.id == template.id }) {
            current[index] = template
        } else {
            current.append(template)
        }
        return current
    }
}

public func deleteSupportUserTemplate(context: AccountContext, id: String) -> Signal<Never, NoError> {
    return updateSupportUserTemplates(context: context) { current in
        return current.filter { $0.id != id }
    }
}

/// Merge-import (D33, D34): matches incoming templates against the existing collection by
/// normalized `{QUESTION}`, never by key. A match updates that entry's Keys/Value in place
/// (keeping its stable `id`); no match appends a new entry with a fresh `id`. Nothing already
/// in the list is ever deleted by an import. Returns a summary including any key collisions
/// the import *newly* introduced against templates that already existed.
public func importSupportUserTemplates(context: AccountContext, text: String) -> Signal<SupportUserTemplateImportSummary, NoError> {
    let (_, incoming) = parseSupportTemplateFile(text)
    guard !incoming.isEmpty else {
        return .single(SupportUserTemplateImportSummary(addedCount: 0, updatedCount: 0, newCollisionKeys: []))
    }
    return supportUserTemplates(context: context)
    |> take(1)
    |> mapToSignal { existing -> Signal<SupportUserTemplateImportSummary, NoError> in
        let preExistingKeys = Set(existing.flatMap { $0.template.keys })
        var merged = existing
        var addedCount = 0
        var updatedCount = 0
        var newCollisionKeys: [String] = []
        for incomingTemplate in incoming {
            let normalized = incomingTemplate.normalizedQuestion
            if let index = merged.firstIndex(where: { $0.template.normalizedQuestion == normalized }) {
                merged[index] = SupportUserTemplate(id: merged[index].id, template: incomingTemplate)
                updatedCount += 1
            } else {
                merged.append(SupportUserTemplate(template: incomingTemplate))
                addedCount += 1
                for key in incomingTemplate.keys where preExistingKeys.contains(key) && !newCollisionKeys.contains(key) {
                    newCollisionKeys.append(key)
                }
            }
        }
        let summary = SupportUserTemplateImportSummary(addedCount: addedCount, updatedCount: updatedCount, newCollisionKeys: newCollisionKeys)
        // `Never`-typed signals make any subsequent `map`/`mapToSignal` closure body
        // statically unreachable (a hard error in this codebase's build, not just a
        // warning), so the update signal is bridged manually: run it for its side effect,
        // then emit the already-computed summary once it completes.
        return Signal { subscriber in
            return updateSupportUserTemplates(context: context, { _ in merged }).start(completed: {
                subscriber.putNext(summary)
                subscriber.putCompletion()
            })
        }
    }
}

public func exportSupportUserTemplatesText(_ templates: [SupportUserTemplate]) -> String {
    return serializeSupportTemplateFile(templates.map { $0.template })
}
