import Foundation

public enum Block: Equatable {
    case paragraph(ParagraphBlock)
    case media(MediaBlock)
    case table(TableBlock)
    case code(CodeBlock)
    case pullQuote(PullQuote)
    case blockQuote(BlockQuote)
    case details(DetailsBlock)
    case buttonRow(ButtonRowBlock)

    public var id: BlockID {
        switch self {
        case .paragraph(let p): return p.id
        case .media(let m): return m.id
        case .table(let t): return t.id
        case .code(let c): return c.id
        case .pullQuote(let q): return q.id
        case .blockQuote(let q): return q.id
        case .details(let d): return d.id
        case .buttonRow(let r): return r.id
        }
    }
}

extension Block: Codable {
    private enum Kind: String, Codable { case paragraph, media, table, code, pullQuote, blockQuote, details, buttonRow }
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .paragraph: self = .paragraph(try c.decode(ParagraphBlock.self, forKey: .value))
        case .media:     self = .media(try c.decode(MediaBlock.self, forKey: .value))
        case .table:     self = .table(try c.decode(TableBlock.self, forKey: .value))
        case .code:      self = .code(try c.decode(CodeBlock.self, forKey: .value))
        case .pullQuote: self = .pullQuote(try c.decode(PullQuote.self, forKey: .value))
        case .blockQuote: self = .blockQuote(try c.decode(BlockQuote.self, forKey: .value))
        case .details: self = .details(try c.decode(DetailsBlock.self, forKey: .value))
        case .buttonRow: self = .buttonRow(try c.decode(ButtonRowBlock.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let p):
            try c.encode(Kind.paragraph, forKey: .type)
            try c.encode(p, forKey: .value)
        case .media(let i):
            try c.encode(Kind.media, forKey: .type)
            try c.encode(i, forKey: .value)
        case .table(let t):
            try c.encode(Kind.table, forKey: .type)
            try c.encode(t, forKey: .value)
        case .code(let code):
            try c.encode(Kind.code, forKey: .type)
            try c.encode(code, forKey: .value)
        case .pullQuote(let q):
            try c.encode(Kind.pullQuote, forKey: .type)
            try c.encode(q, forKey: .value)
        case .blockQuote(let q):
            try c.encode(Kind.blockQuote, forKey: .type)
            try c.encode(q, forKey: .value)
        case .details(let d):
            try c.encode(Kind.details, forKey: .type)
            try c.encode(d, forKey: .value)
        case .buttonRow(let r):
            try c.encode(Kind.buttonRow, forKey: .type)
            try c.encode(r, forKey: .value)
        }
    }
}
