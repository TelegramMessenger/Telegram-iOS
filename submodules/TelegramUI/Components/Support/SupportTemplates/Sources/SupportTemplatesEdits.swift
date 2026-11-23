import Foundation

public let supportOwnTemplatesFileName = "My Templates"

public struct SupportTemplateEdit: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case question
        case value
        case addedKeys
        case removedKeys
        case isRemoved
    }

    public var question: String?
    public var value: String?
    public var addedKeys: [String]
    public var removedKeys: [String]
    public var isRemoved: Bool

    public static let removal = SupportTemplateEdit(isRemoved: true)

    public init(question: String? = nil, value: String? = nil, addedKeys: [String] = [], removedKeys: [String] = [], isRemoved: Bool = false) {
        self.question = question
        self.value = value
        self.addedKeys = addedKeys
        self.removedKeys = removedKeys
        self.isRemoved = isRemoved
    }

    public init(original: SupportTemplatesQuestion, question: String, keys: [String], value: String) {
        let edited = supportTemplatesQuestion(question: question, keys: keys, value: value)
        let originalKeys = Set(original.originalKeys.map(supportTemplatesNormalizedKey))
        let editedKeys = Set(edited.originalKeys.map(supportTemplatesNormalizedKey))
        self.init(
            question: utf16Equal(edited.question, original.question) ? nil : edited.question,
            value: utf16Equal(edited.value, original.value) ? nil : edited.value,
            addedKeys: edited.originalKeys.filter { !originalKeys.contains(supportTemplatesNormalizedKey($0)) },
            removedKeys: original.originalKeys.filter { !editedKeys.contains(supportTemplatesNormalizedKey($0)) }
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.question = try container.decodeIfPresent(String.self, forKey: .question)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        self.addedKeys = try container.decodeIfPresent([String].self, forKey: .addedKeys) ?? []
        self.removedKeys = try container.decodeIfPresent([String].self, forKey: .removedKeys) ?? []
        self.isRemoved = try container.decodeIfPresent(Bool.self, forKey: .isRemoved) ?? false
    }

    var isEmpty: Bool {
        return !self.isRemoved && self.question == nil && self.value == nil && self.addedKeys.isEmpty && self.removedKeys.isEmpty
    }

    func applied(to original: SupportTemplatesQuestion) -> SupportTemplatesQuestion {
        let removed = Set(self.removedKeys.map(supportTemplatesNormalizedKey))
        var keys = original.originalKeys.filter { !removed.contains(supportTemplatesNormalizedKey($0)) }
        var present = Set(keys.map(supportTemplatesNormalizedKey))
        for key in self.addedKeys {
            let normalized = supportTemplatesNormalizedKey(key)
            if !present.contains(normalized) {
                keys.append(key)
                present.insert(normalized)
            }
        }
        return supportTemplatesQuestion(question: self.question ?? original.question, keys: keys, value: self.value ?? original.value)
    }
}

public struct SupportOwnTemplate: Codable, Equatable {
    public var id: String
    public var question: String
    public var keys: [String]
    public var value: String

    public init(id: String = SupportOwnTemplate.newId(), question: String, keys: [String], value: String) {
        self.id = id
        self.question = question
        self.keys = keys
        self.value = value
    }

    public static func newId() -> String {
        return String(format: "%016llx", UInt64.random(in: 1 ... UInt64.max))
    }

    var asQuestion: SupportTemplatesQuestion {
        return supportTemplatesQuestion(question: self.question, keys: self.keys, value: self.value)
    }
}

public enum SupportTemplatesSource: Equatable {
    case file(String)
    case own
}

public struct SupportTemplatesListEntry: Equatable {
    public enum Status: Equatable {
        case original
        case edited
        case removed
    }

    public let id: String
    public let template: SupportTemplatesQuestion
    public let original: SupportTemplatesQuestion?
    public let status: Status
}

func supportTemplatesQuestion(question: String, keys: [String], value: String) -> SupportTemplatesQuestion {
    let keys = keys.map(trimmedString).filter { !$0.isEmpty }
    return SupportTemplatesQuestion(question: trimmedString(question), originalKeys: keys, normalizedKeys: keys.map(supportTemplatesNormalizedKey).filter { !$0.isEmpty }, value: supportTemplatesValueDroppingTrailingNewlines(value))
}

public func supportTemplatesValueDroppingTrailingNewlines(_ value: String) -> String {
    var units = Array(value.utf16)
    while units.last == 0x0A || units.last == 0x0D {
        units.removeLast()
    }
    return stringFromUnits(units)
}

func supportTemplatesFileApplyingEdits(_ file: SupportTemplatesFile, edits: [String: SupportTemplateEdit]) -> SupportTemplatesFile {
    var result = file
    for (id, edit) in edits {
        guard let original = result.questions[id] else {
            continue
        }
        result.questions[id] = edit.isRemoved ? nil : edit.applied(to: original)
    }
    return result
}

func supportTemplatesOwnFile(_ templates: [SupportOwnTemplate]) -> SupportTemplatesFile {
    var result = SupportTemplatesFile()
    for template in templates {
        result.questions[template.id] = template.asQuestion
    }
    return result
}

func supportTemplatesListEntries(file: SupportTemplatesFile, edits: [String: SupportTemplateEdit]) -> [SupportTemplatesListEntry] {
    let entries = file.sortedQuestions.map { id, question -> SupportTemplatesListEntry in
        guard let edit = edits[id] else {
            return SupportTemplatesListEntry(id: id, template: question, original: question, status: .original)
        }
        if edit.isRemoved {
            return SupportTemplatesListEntry(id: id, template: question, original: question, status: .removed)
        }
        return SupportTemplatesListEntry(id: id, template: edit.applied(to: question), original: question, status: .edited)
    }
    return entries.filter { $0.status != .original } + entries.filter { $0.status == .original }
}

func supportTemplatesEditCount(file: SupportTemplatesFile, edits: [String: SupportTemplateEdit]?) -> Int {
    guard let edits else {
        return 0
    }
    return edits.keys.filter { file.questions[$0] != nil }.count
}

public func supportTemplatesFileText(_ templates: [SupportTemplatesQuestion]) -> String {
    var result = ""
    for template in templates {
        result += "{QUESTION}\n\(template.question)\n"
        if !template.originalKeys.isEmpty {
            result += "{KEYS}\n" + template.originalKeys.joined(separator: "\n") + "\n"
        }
        result += "{VALUE}\n\(template.value)\n\n"
    }
    return result
}
