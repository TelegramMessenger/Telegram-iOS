import Foundation

/// A single canned-reply template, as used by TSupport volunteers.
///
/// Parsed from the `{QUESTION}/{KEYS}/{VALUE}` block format shared by the official
/// `templates.tsupport.org` files and by Telegram Desktop's own support client. See
/// `ai-docs/tsupport/50-templates-design.md` §1 for the full format description.
public struct SupportTemplate: Codable, Equatable {
    /// Hidden identity used only for matching across refresh/import, never shown as a label.
    public let question: String
    /// The short strings a volunteer actually types to find this template.
    public let keys: [String]
    public let value: SupportTemplateValue

    public init(question: String, keys: [String], value: SupportTemplateValue) {
        self.question = question
        self.keys = keys
        self.value = value
    }

    /// Identity used for de-duplication and cross-refresh/import matching. Ported from
    /// tdesktop's `NormalizeQuestion` so files exported here and re-imported elsewhere (or
    /// vice versa) match identically.
    public var normalizedQuestion: String {
        return normalizeSupportTemplateQuestion(self.question)
    }
}

public enum SupportTemplateValue: Codable, Equatable {
    case text(String)
    /// `contact:+<phone> <Name>` as the first line of `{VALUE}`, with any remaining lines as
    /// an explanatory message sent ahead of the contact card.
    case contact(phone: String, name: String, precedingText: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case text
        case phone
        case name
        case precedingText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Int32.self, forKey: .kind)
        switch kind {
        case 0:
            self = .text(try container.decode(String.self, forKey: .text))
        case 1:
            self = .contact(
                phone: try container.decode(String.self, forKey: .phone),
                name: try container.decode(String.self, forKey: .name),
                precedingText: try container.decode(String.self, forKey: .precedingText)
            )
        default:
            self = .text("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode(Int32(0), forKey: .kind)
            try container.encode(text, forKey: .text)
        case let .contact(phone, name, precedingText):
            try container.encode(Int32(1), forKey: .kind)
            try container.encode(phone, forKey: .phone)
            try container.encode(name, forKey: .name)
            try container.encode(precedingText, forKey: .precedingText)
        }
    }
}

/// Keep only letters/digits, lowercased; drop everything else (spaces, punctuation,
/// question marks). Unicode-aware, matching tdesktop's `support_templates.cpp` exactly, so
/// the same two Questions always normalize identically regardless of which client produced
/// them.
public func normalizeSupportTemplateQuestion(_ question: String) -> String {
    var result = ""
    for scalar in question.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            result.unicodeScalars.append(scalar)
        }
    }
    return result.lowercased()
}

/// Inverse of the `{VALUE}` parsing in `parseSupportTemplateFile` - produces the exact text
/// a `{VALUE}` section would contain for this value, so User Templates can round-trip
/// through export/import in the same real template-file format (D33).
public func serializeSupportTemplateValue(_ value: SupportTemplateValue) -> String {
    switch value {
    case let .text(text):
        return text
    case let .contact(phone, name, precedingText):
        let contactLine = "contact:\(phone) \(name)"
        if precedingText.isEmpty {
            return contactLine
        }
        return contactLine + "\n" + precedingText
    }
}

/// Serializes a list of templates back into the real `{QUESTION}/{KEYS}/{VALUE}` text
/// format (D33). Omits `{URL}`/`{COMMENT}` - those are official-file-only concepts with no
/// meaning for an exported User Template collection, which has no canonical server copy to
/// refresh from.
public func serializeSupportTemplateFile(_ templates: [SupportTemplate]) -> String {
    var lines: [String] = []
    for template in templates {
        lines.append("{QUESTION}")
        lines.append(template.question)
        lines.append("{KEYS}")
        lines.append(contentsOf: template.keys)
        lines.append("{VALUE}")
        lines.append(serializeSupportTemplateValue(template.value))
        lines.append("")
    }
    return lines.joined(separator: "\n")
}

/// Parses one `tl_*.txt` support-template file.
///
/// Format: repeating `{TAG}` marker lines (on their own line), each followed by its content
/// until the next marker or end of file. `{URL}` (if present, always first) is a self-update
/// anchor; `{COMMENT}` is ignored anywhere it appears. Everything else is grouped into
/// consecutive `{QUESTION}` + `{KEYS}` + `{VALUE}` triples.
public func parseSupportTemplateFile(_ text: String) -> (url: String?, templates: [SupportTemplate]) {
    enum Tag: String {
        case url = "{URL}"
        case comment = "{COMMENT}"
        case question = "{QUESTION}"
        case keys = "{KEYS}"
        case value = "{VALUE}"
    }

    var sections: [(Tag, [String])] = []
    var currentTag: Tag?
    var currentLines: [String] = []

    func flush() {
        if let tag = currentTag {
            sections.append((tag, currentLines))
        }
        currentLines = []
    }

    for rawLine in text.components(separatedBy: "\n") {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
        if let tag = Tag(rawValue: line.trimmingCharacters(in: .whitespaces)) {
            flush()
            currentTag = tag
        } else {
            currentLines.append(line)
        }
    }
    flush()

    func joinedTrimmed(_ lines: [String]) -> String {
        while lines.first?.isEmpty == true {
            return joinedTrimmed(Array(lines.dropFirst()))
        }
        var lines = lines
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    var url: String?
    var templates: [SupportTemplate] = []

    var pendingQuestion: String?
    var pendingKeys: [String]?

    for (tag, lines) in sections {
        switch tag {
        case .url:
            url = joinedTrimmed(lines)
        case .comment:
            break
        case .question:
            pendingQuestion = joinedTrimmed(lines)
            pendingKeys = nil
        case .keys:
            pendingKeys = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        case .value:
            guard let question = pendingQuestion, let keys = pendingKeys, !keys.isEmpty else {
                continue
            }
            let valueText = joinedTrimmed(lines)
            let value: SupportTemplateValue
            if valueText.hasPrefix("contact:") {
                let firstLine: String
                let rest: String
                if let newlineIndex = valueText.firstIndex(of: "\n") {
                    firstLine = String(valueText[valueText.startIndex ..< newlineIndex])
                    rest = String(valueText[valueText.index(after: newlineIndex)...])
                } else {
                    firstLine = valueText
                    rest = ""
                }
                let contactLine = String(firstLine.dropFirst("contact:".count)).trimmingCharacters(in: .whitespaces)
                let components = contactLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if let phone = components.first, phone.hasPrefix("+") {
                    let name = components.count > 1 ? String(components[1]) : ""
                    value = .contact(phone: String(phone), name: name, precedingText: rest.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    value = .text(valueText)
                }
            } else {
                value = .text(valueText)
            }
            if !isTestFixtureTemplate(question: question, keys: keys, value: value) {
                templates.append(SupportTemplate(question: question, keys: keys, value: value))
            }
            pendingQuestion = nil
            pendingKeys = nil
        }
    }

    return (url, templates)
}

/// Most (not all) of the official files end with a batch of `q_extra_N` / `k_extra_N` /
/// `v_extra_N` placeholder blocks - verified by fetching every real file directly; these
/// parse as structurally valid templates but are clearly test/QA fixtures, not real support
/// content, and should never reach a volunteer. Matches on any of the three fields since a
/// future file revision might only change one of them.
private func isTestFixtureTemplate(question: String, keys: [String], value: SupportTemplateValue) -> Bool {
    func isFixtureToken(_ text: String) -> Bool {
        return text.range(of: "^[qkv]_extra_[0-9]+$", options: [.regularExpression, .caseInsensitive]) != nil
    }
    if isFixtureToken(question) {
        return true
    }
    if keys.allSatisfy(isFixtureToken) {
        return true
    }
    if case let .text(text) = value, isFixtureToken(text) {
        return true
    }
    return false
}
