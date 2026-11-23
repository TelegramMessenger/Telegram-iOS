import Foundation

public struct SupportTemplatesKeyMatch: Equatable {
    public let question: SupportTemplatesQuestion
    public let key: String
}

public struct SupportTemplatesExpansion: Equatable {
    public let range: NSRange
    public let value: String
}

public func supportTemplateValueIsContact(_ value: String) -> Bool {
    return value.hasPrefix("contact:")
}

public final class SupportTemplates {
    public static let queryLimit = 10
    private static let weightStep = 1000

    private struct Id: Hashable {
        let file: String
        let question: String

        static func precedes(_ lhs: Id, _ rhs: Id) -> Bool {
            if !utf16Equal(lhs.file, rhs.file) {
                return utf16Less(lhs.file, rhs.file)
            }
            return utf16Less(lhs.question, rhs.question)
        }
    }

    private struct Term: Hashable {
        let word: String
        let weight: Int

        static func precedes(_ lhs: Term, _ rhs: Term) -> Bool {
            if !utf16Equal(lhs.word, rhs.word) {
                return utf16Less(lhs.word, rhs.word)
            }
            return lhs.weight < rhs.weight
        }
    }

    // Keyed by file name.
    public let files: [String: SupportTemplatesFile]
    public let maxKeyLength: Int

    private let sortedEntries: [(file: String, normalized: String, question: SupportTemplatesQuestion)]
    private let first: [UInt16: [Id]]
    private let full: [Id: [Term]]

    public init(files: [String: SupportTemplatesFile]) {
        self.files = files

        var sortedEntries: [(file: String, normalized: String, question: SupportTemplatesQuestion)] = []
        for (name, file) in files.sorted(by: { utf16Less($0.key, $1.key) }) {
            for (normalized, question) in file.sortedQuestions {
                sortedEntries.append((file: name, normalized: normalized, question: question))
            }
        }
        self.sortedEntries = sortedEntries

        var maxKeyLength = 0
        var uniqueFirst: [UInt16: Set<Id>] = [:]
        var uniqueFull: [Id: Set<Term>] = [:]
        func push(_ id: Id, _ string: String, _ weight: Int) {
            for word in supportTemplatesSearchWords(string) {
                uniqueFirst[word.utf16.first!, default: []].insert(id)
                uniqueFull[id, default: []].insert(Term(word: word, weight: weight))
            }
        }
        for entry in sortedEntries {
            let id = Id(file: entry.file, question: entry.normalized)
            for key in entry.question.normalizedKeys {
                maxKeyLength = max(maxKeyLength, key.utf16.count)
                push(id, key, SupportTemplates.weightStep * SupportTemplates.weightStep)
            }
            push(id, entry.question.question, SupportTemplates.weightStep)
            push(id, entry.question.value, 1)
        }
        self.maxKeyLength = maxKeyLength
        self.first = uniqueFirst.mapValues { $0.sorted(by: Id.precedes) }
        self.full = uniqueFull.mapValues { $0.sorted(by: Term.precedes) }
    }

    private func weight(of id: Id, words: [String]) -> Int {
        guard let terms = self.full[id] else {
            return 0
        }
        var result = 0
        for word in words {
            var from = terms.startIndex
            while from < terms.endIndex && utf16Less(terms[from].word, word) {
                from += 1
            }
            var best: Term?
            var index = from
            while index < terms.endIndex && utf16HasPrefix(terms[index].word, word) {
                if best == nil || terms[index].weight > best!.weight {
                    best = terms[index]
                }
                index += 1
            }
            guard let best else {
                return 0
            }
            result += best.weight * (utf16Equal(best.word, word) ? 2 : 1)
        }
        return result
    }

    public func query(_ text: String) -> [SupportTemplatesQuestion] {
        let words = supportTemplatesSearchWords(text)
        var best: String?
        var bestCount = 0
        for word in words {
            let count = self.first[word.utf16.first!]?.count ?? 0
            if best == nil || count < bestCount {
                best = word
                bestCount = count
            }
        }
        guard let best, let narrowed = self.first[best.utf16.first!] else {
            return []
        }
        let weighted = narrowed.map { (id: $0, weight: self.weight(of: $0, words: words)) }.filter { $0.weight > 0 }
        let sorted = weighted.sorted(by: { lhs, rhs in
            if lhs.weight != rhs.weight {
                return lhs.weight > rhs.weight
            }
            if !utf16Equal(lhs.id.file, rhs.id.file) {
                return utf16Less(rhs.id.file, lhs.id.file)
            }
            return utf16Less(lhs.id.question, rhs.id.question)
        })
        return sorted.prefix(SupportTemplates.queryLimit).compactMap { self.files[$0.id.file]?.questions[$0.id.question] }
    }

    public func matchExact(_ query: String) -> SupportTemplatesKeyMatch? {
        if query.isEmpty || query.utf16.count > self.maxKeyLength {
            return nil
        }
        let normalized = supportTemplatesNormalizedKey(query)
        for entry in self.sortedEntries {
            for key in entry.question.normalizedKeys where utf16Equal(key, normalized) {
                return SupportTemplatesKeyMatch(question: entry.question, key: key)
            }
        }
        return nil
    }

    public func matchFromEnd(_ query: String) -> SupportTemplatesKeyMatch? {
        var units = Array(query.utf16)
        if units.count > self.maxKeyLength {
            units = Array(units.suffix(self.maxKeyLength))
        }
        let queries = (0 ..< units.count).map { i in
            supportTemplatesNormalizedKey(stringFromUnits(units.suffix(i + 1)))
        }
        var result: SupportTemplatesKeyMatch?
        for entry in self.sortedEntries {
            for key in entry.question.normalizedKeys {
                let length = key.utf16.count
                if length <= queries.count && utf16Equal(queries[length - 1], key) && (result == nil || result!.key.utf16.count <= length) {
                    result = SupportTemplatesKeyMatch(question: entry.question, key: key)
                }
            }
        }
        return result
    }

    public func expansion(text: String, selection: NSRange) -> SupportTemplatesExpansion? {
        let text = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= text.length else {
            return nil
        }
        if selection.length > 0 {
            guard let match = self.matchExact(text.substring(with: selection)) else {
                return nil
            }
            return SupportTemplatesExpansion(range: selection, value: match.question.value)
        }
        let length = min(selection.location, self.maxKeyLength)
        guard let match = self.matchFromEnd(text.substring(with: NSRange(location: selection.location - length, length: length))) else {
            return nil
        }
        let keyLength = match.key.utf16.count
        return SupportTemplatesExpansion(range: NSRange(location: selection.location - keyLength, length: keyLength), value: match.question.value)
    }
}
