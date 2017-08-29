import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum RichTextTypes: Int32 {
    case empty = 0
    case plain = 1
    case bold = 2
    case italic = 3
    case underline = 4
    case strikethrough = 5
    case fixed = 6
    case url = 7
    case email = 8
    case concat = 9
}

public indirect enum RichText: PostboxCoding, Equatable {
    case empty
    case plain(String)
    case bold(RichText)
    case italic(RichText)
    case underline(RichText)
    case strikethrough(RichText)
    case fixed(RichText)
    case url(text: RichText, url: String, webpageId: MediaId?)
    case email(text: RichText, email: String)
    case concat([RichText])
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case RichTextTypes.empty.rawValue:
                self = .empty
            case RichTextTypes.plain.rawValue:
                self = .plain(decoder.decodeStringForKey("s", orElse: ""))
            case RichTextTypes.bold.rawValue:
                self = .bold(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.italic.rawValue:
                self = .italic(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.underline.rawValue:
                self = .underline(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.strikethrough.rawValue:
                self = .strikethrough(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.fixed.rawValue:
                self = .fixed(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.url.rawValue:
                let webpageIdNamespace: Int32? = decoder.decodeOptionalInt32ForKey("w.n")
                let webpageIdId: Int64? = decoder.decodeOptionalInt64ForKey("w.i")
                var webpageId: MediaId?
                if let webpageIdNamespace = webpageIdNamespace, let webpageIdId = webpageIdId {
                    webpageId = MediaId(namespace: webpageIdNamespace, id: webpageIdId)
                }
                self = .url(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, url: decoder.decodeStringForKey("u", orElse: ""), webpageId: webpageId)
            case RichTextTypes.email.rawValue:
                self = .email(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, email: decoder.decodeStringForKey("e", orElse: ""))
            case RichTextTypes.concat.rawValue:
                self = .concat(decoder.decodeObjectArrayWithDecoderForKey("a"))
            default:
                self = .empty
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .empty:
                encoder.encodeInt32(RichTextTypes.empty.rawValue, forKey: "r")
            case let .plain(string):
                encoder.encodeInt32(RichTextTypes.plain.rawValue, forKey: "r")
                encoder.encodeString(string, forKey: "s")
            case let .bold(text):
                encoder.encodeInt32(RichTextTypes.bold.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .italic(text):
                encoder.encodeInt32(RichTextTypes.italic.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .underline(text):
                encoder.encodeInt32(RichTextTypes.underline.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .strikethrough(text):
                encoder.encodeInt32(RichTextTypes.strikethrough.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .fixed(text):
                encoder.encodeInt32(RichTextTypes.fixed.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .url(text, url, webpageId):
                encoder.encodeInt32(RichTextTypes.url.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeString(url, forKey: "u")
                if let webpageId = webpageId {
                    encoder.encodeInt32(webpageId.namespace, forKey: "w.n")
                    encoder.encodeInt64(webpageId.id, forKey: "w.i")
                } else {
                    encoder.encodeNil(forKey: "w.n")
                    encoder.encodeNil(forKey: "w.i")
                }
            case let .email(text, email):
                encoder.encodeInt32(RichTextTypes.email.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeString(email, forKey: "e")
            case let .concat(texts):
                encoder.encodeInt32(RichTextTypes.concat.rawValue, forKey: "r")
                encoder.encodeObjectArray(texts, forKey: "a")
        }
    }
    
    public static func ==(lhs: RichText, rhs: RichText) -> Bool {
        switch lhs {
            case .empty:
                if case .empty = rhs {
                    return true
                } else {
                    return false
                }
            case let .plain(string):
                if case .plain(string) = rhs {
                    return true
                } else {
                    return false
                }
            case let .bold(text):
                if case .bold(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .italic(text):
                if case .italic(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .underline(text):
                if case .underline(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .strikethrough(text):
                if case .strikethrough(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .fixed(text):
                if case .fixed(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .url(lhsText, lhsUrl, lhsWebpageId):
                if case let .url(rhsText, rhsUrl, rhsWebpageId) = rhs, lhsText == rhsText && lhsUrl == rhsUrl &&  lhsWebpageId == rhsWebpageId {
                    return true
                } else {
                    return false
                }
            case let .email(text, email):
                if case .email(text, email) = rhs {
                    return true
                } else {
                    return false
                }
            case let .concat(lhsTexts):
                if case let .concat(rhsTexts) = rhs, lhsTexts == rhsTexts {
                    return true
                } else {
                    return false
                }
        }
    }
}

public extension RichText {
    public var plainText: String {
        switch self {
            case .empty:
                return ""
            case let .plain(string):
                return string
            case let .bold(text):
                return text.plainText
            case let .italic(text):
                return text.plainText
            case let .underline(text):
                return text.plainText
            case let .strikethrough(text):
                return text.plainText
            case let .fixed(text):
                return text.plainText
            case let .url(text, _, _):
                return text.plainText
            case let .email(text, _):
                return text.plainText
            case let .concat(texts):
                var string = ""
                for text in texts {
                    string += text.plainText
                }
                return string
        }
    }
}

extension RichText {
    init(apiText: Api.RichText) {
        switch apiText {
            case .textEmpty:
                self = .empty
            case let .textPlain(text):
                self = .plain(text)
            case let .textBold(text):
                self = .bold(RichText(apiText: text))
            case let .textItalic(text):
                self = .italic(RichText(apiText: text))
            case let .textUnderline(text):
                self = .underline(RichText(apiText: text))
            case let .textStrike(text):
                self = .strikethrough(RichText(apiText: text))
            case let .textFixed(text):
                self = .fixed(RichText(apiText: text))
            case let .textUrl(text, url, webpageId):
                self = .url(text: RichText(apiText: text), url: url, webpageId: webpageId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId))
            case let .textEmail(text, email):
                self = .email(text: RichText(apiText: text), email: email)
            case let .textConcat(texts):
                self = .concat(texts.map({ RichText(apiText: $0) }))
        }
    }
}
