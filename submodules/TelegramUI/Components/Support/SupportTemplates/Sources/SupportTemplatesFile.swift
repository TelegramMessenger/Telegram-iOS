import Foundation

public struct SupportTemplatesQuestion: Equatable {
    public var question: String
    public var originalKeys: [String]
    public var normalizedKeys: [String]
    public var value: String

    public init(question: String = "", originalKeys: [String] = [], normalizedKeys: [String] = [], value: String = "") {
        self.question = question
        self.originalKeys = originalKeys
        self.normalizedKeys = normalizedKeys
        self.value = value
    }
}

public struct SupportTemplatesFile: Equatable {
    public var url: String
    // Keyed by the normalized question.
    public var questions: [String: SupportTemplatesQuestion]

    public init(url: String = "", questions: [String: SupportTemplatesQuestion] = [:]) {
        self.url = url
        self.questions = questions
    }

    public var isEmpty: Bool {
        return self.url.isEmpty && self.questions.isEmpty
    }

    var sortedQuestions: [(normalized: String, question: SupportTemplatesQuestion)] {
        return self.questions.sorted(by: { utf16Less($0.key, $1.key) }).map { (normalized: $0.key, question: $0.value) }
    }
}

public func isSupportTemplatesFileName(_ name: String) -> Bool {
    let lowercased = name.lowercased()
    return lowercased.hasPrefix("tl_") && lowercased.hasSuffix(".txt")
}

enum SupportTemplatesReadState {
    case none
    case question
    case keys
    case value
    case url
}

private func token(of line: [UInt16]) -> String? {
    guard line.count >= 3, line.first == 0x7B, line.last == 0x7D else {
        return nil
    }
    let name = line[1 ..< line.count - 1]
    for unit in name {
        if !((unit >= 0x41 && unit <= 0x5A) || unit == 0x5F) {
            return nil
        }
    }
    return stringFromUnits(name)
}

func valueLineText(_ line: String) -> String {
    var units = Array(line.utf16)
    if units.last == 0x0D {
        units.removeLast()
    }
    let start = units.firstIndex(where: { !isSpaceUnit($0) }) ?? units.endIndex
    return stringFromUnits(units[start...])
}

func readSupportTemplatesLines(_ data: Data, stateChange: (SupportTemplatesReadState) -> Void, line: (SupportTemplatesReadState, String, Bool) -> Void) {
    var state = SupportTemplatesReadState.none
    var hadKeys = false
    var hadValue = false
    let blob = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    for lineBytes in blob.split(separator: 0x0A, omittingEmptySubsequences: false) {
        let units = Array(trimmedUnits(Array(String(decoding: lineBytes, as: UTF8.self).utf16)))
        let text = stringFromUnits(units)
        if let token = token(of: units) {
            if state == .value {
                hadKeys = false
                hadValue = false
            }
            let newState: SupportTemplatesReadState
            switch token {
            case "VALUE":
                newState = hadValue ? .none : .value
            case "KEYS":
                newState = hadKeys ? .none : .keys
            case "QUESTION":
                newState = .question
            case "URL":
                newState = .url
            default:
                newState = .none
            }
            stateChange(state)
            state = newState
            line(state, text, true)
        } else {
            if !units.isEmpty {
                if state == .value {
                    hadValue = true
                } else if state == .keys {
                    hadKeys = true
                }
            }
            if state == .value && !units.isEmpty {
                line(state, valueLineText(String(decoding: lineBytes, as: UTF8.self)), false)
            } else {
                line(state, text, false)
            }
        }
    }
}

public func parseSupportTemplatesFile(_ data: Data) -> SupportTemplatesFile {
    var result = SupportTemplatesFile()
    var url = ""
    var question = SupportTemplatesQuestion()

    func emit() {
        var value = Array(question.value.utf16)
        while value.last == 0x0A {
            value.removeLast()
        }
        question.value = stringFromUnits(value)
        let normalized = supportTemplatesNormalizedQuestion(question.question)
        if !normalized.isEmpty && result.questions[normalized] == nil {
            result.questions[normalized] = question
        }
        question = SupportTemplatesQuestion()
    }

    readSupportTemplatesLines(data, stateChange: { previous in
        if previous == .value {
            emit()
        }
    }, line: { state, line, isStateChange in
        if isStateChange {
            return
        }
        switch state {
        case .keys:
            if !line.isEmpty {
                question.originalKeys.append(line)
                let normalized = supportTemplatesNormalizedKey(line)
                if !normalized.isEmpty {
                    question.normalizedKeys.append(normalized)
                }
            }
        case .value:
            if !question.value.isEmpty {
                question.value += "\n"
            }
            question.value += line
        case .question:
            if question.question.isEmpty {
                question.question = line
            }
        case .url:
            if url.isEmpty {
                url = line
            }
        case .none:
            break
        }
    })
    emit()
    result.url = url
    return result
}
