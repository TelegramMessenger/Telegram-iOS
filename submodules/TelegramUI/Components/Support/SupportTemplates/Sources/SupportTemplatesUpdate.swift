import Foundation

public struct SupportTemplatesDelta: Equatable {
    public var added: [SupportTemplatesQuestion] = []
    public var changed: [SupportTemplatesQuestion] = []
    public var removed: [SupportTemplatesQuestion] = []
    var keys: [String: [String]] = [:]

    public var isEmpty: Bool {
        return self.added.isEmpty && self.changed.isEmpty && self.removed.isEmpty
    }
}

func supportTemplatesFileKeepingOwnData(downloaded: SupportTemplatesFile, existing: SupportTemplatesFile) -> SupportTemplatesFile {
    var result = downloaded
    result.url = existing.url
    for (normalized, question) in downloaded.questions {
        if let own = existing.questions[normalized] {
            var updated = question
            updated.originalKeys = own.originalKeys
            updated.normalizedKeys = own.normalizedKeys
            result.questions[normalized] = updated
        }
    }
    return result
}

func supportTemplatesDelta(was: SupportTemplatesFile, now: SupportTemplatesFile) -> SupportTemplatesDelta {
    var result = SupportTemplatesDelta()
    for (normalized, question) in now.sortedQuestions {
        if let existing = was.questions[normalized] {
            result.keys[normalized] = existing.originalKeys
            if existing.value != question.value {
                result.changed.append(question)
            }
        } else {
            result.added.append(question)
        }
    }
    for (normalized, question) in was.sortedQuestions where result.keys[normalized] == nil {
        result.removed.append(question)
    }
    return result
}

func supportTemplatesRewrittenFile(downloaded: Data, url: String, ownKeys: [String: [String]]) -> Data {
    struct Section {
        let state: SupportTemplatesReadState
        var lines: [String]
    }

    var output = url.isEmpty ? "" : "{URL}\n\(url)\n\n"
    var block: [Section] = []
    var question = ""

    func write(_ lines: [String]) {
        for line in lines {
            output += line
            output += "\n"
        }
    }

    func flush() {
        let normalized = supportTemplatesNormalizedQuestion(question)
        let own = normalized.isEmpty ? nil : ownKeys[normalized]
        var didWriteOwnKeys = false
        for section in block {
            if let own {
                if section.state == .keys {
                    if !didWriteOwnKeys {
                        write(["{KEYS}"] + own)
                        didWriteOwnKeys = true
                    }
                    continue
                } else if section.state == .value && !didWriteOwnKeys {
                    if !own.isEmpty {
                        write(["{KEYS}"] + own)
                    }
                    didWriteOwnKeys = true
                }
            }
            write(section.lines)
        }
        block = []
        question = ""
    }

    readSupportTemplatesLines(downloaded, stateChange: { previous in
        if previous == .value {
            flush()
        }
    }, line: { state, line, isStateChange in
        switch state {
        case .none, .url:
            return
        case .question, .keys, .value:
            break
        }
        if isStateChange {
            block.append(Section(state: state, lines: [line]))
        } else if !block.isEmpty {
            block[block.count - 1].lines.append(line)
            if state == .question && question.isEmpty {
                question = line
            }
        }
    })
    flush()
    return Data(output.utf8)
}

public func supportTemplatesNotificationParts(_ text: String, limit: Int = 4096) -> [String] {
    var result: [String] = []
    var units = ArraySlice(Array(text.utf16))
    while !units.isEmpty {
        var end = units.startIndex + min(limit, units.count)
        if end < units.endIndex {
            if let newline = units[units.startIndex ..< end].lastIndex(of: 0x0A), newline > units.startIndex {
                end = newline + 1
            } else if units[end - 1] >= 0xD800 && units[end - 1] <= 0xDBFF && end - 1 > units.startIndex {
                end -= 1
            }
        }
        let part = trimmedString(stringFromUnits(units[units.startIndex ..< end]))
        if !part.isEmpty {
            result.append(part)
        }
        units = units[end...]
    }
    return result
}
