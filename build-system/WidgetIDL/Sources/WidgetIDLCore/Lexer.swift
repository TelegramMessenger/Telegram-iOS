struct Token: Equatable {
    enum Kind: Equatable {
        case identifier
        case integer
        case decimal
        case string
        case punctuation
        case end
    }

    var kind: Kind
    var text: String
    var line: Int
}

/// The WebIDL lexical grammar (https://webidl.spec.whatwg.org/#lexical-grammar), comments and whitespace skipped.
func tokenize(_ source: String, file: String) throws -> [Token] {
    let identifier = /[_-]?[A-Za-z][0-9A-Z_a-z-]*/
    let decimal = /-?(([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([Ee][+-]?[0-9]+)?|[0-9]+[Ee][+-]?[0-9]+)/
    let integer = /-?([1-9][0-9]*|0[Xx][0-9A-Fa-f]+|0[0-7]*)/
    var tokens: [Token] = []
    var line = 1
    var index = source.startIndex
    while index < source.endIndex {
        let c = source[index]
        if c.isNewline {
            line += 1
            index = source.index(after: index)
            continue
        }
        if c.isWhitespace {
            index = source.index(after: index)
            continue
        }
        let rest = source[index...]
        if rest.hasPrefix("//") {
            index = rest.firstIndex(where: { $0.isNewline }) ?? source.endIndex
            continue
        }
        if rest.hasPrefix("/*") {
            guard let end = rest.firstRange(of: "*/") else {
                throw IDLError(file: file, line: line, message: "unterminated comment")
            }
            line += rest[rest.startIndex..<end.lowerBound].filter { $0.isNewline }.count
            index = end.upperBound
            continue
        }
        if c == "\"" {
            guard let close = rest.dropFirst().firstIndex(of: "\"") else {
                throw IDLError(file: file, line: line, message: "unterminated string")
            }
            tokens.append(Token(kind: .string, text: String(source[source.index(after: index)..<close]), line: line))
            index = source.index(after: close)
            continue
        }
        if c == "-", let next = rest.dropFirst().first, next.isLetter, let match = rest.prefixMatch(of: identifier) {
            tokens.append(Token(kind: .identifier, text: String(match.output), line: line))
            index = match.range.upperBound
            continue
        }
        if let match = rest.prefixMatch(of: decimal) {
            tokens.append(Token(kind: .decimal, text: String(match.output.0), line: line))
            index = match.range.upperBound
            continue
        }
        if let match = rest.prefixMatch(of: integer) {
            tokens.append(Token(kind: .integer, text: String(match.output.0), line: line))
            index = match.range.upperBound
            continue
        }
        if let match = rest.prefixMatch(of: identifier) {
            tokens.append(Token(kind: .identifier, text: String(match.output), line: line))
            index = match.range.upperBound
            continue
        }
        if rest.hasPrefix("...") {
            tokens.append(Token(kind: .punctuation, text: "...", line: line))
            index = source.index(index, offsetBy: 3)
            continue
        }
        tokens.append(Token(kind: .punctuation, text: String(c), line: line))
        index = source.index(after: index)
    }
    tokens.append(Token(kind: .end, text: "", line: line))
    return tokens
}
