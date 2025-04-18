import Postbox
import FlatBuffers
import FlatSerialization

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
    case `subscript` = 10
    case superscript = 11
    case marked = 12
    case phone = 13
    case image = 14
    case anchor = 15
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
    case `subscript`(RichText)
    case superscript(RichText)
    case marked(RichText)
    case phone(text: RichText, phone: String)
    case image(id: MediaId, dimensions: PixelDimensions)
    case anchor(text: RichText, name: String)
    
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
            case RichTextTypes.subscript.rawValue:
                self = .subscript(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.superscript.rawValue:
                self = .superscript(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.marked.rawValue:
                self = .marked(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.phone.rawValue:
                self = .phone(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, phone: decoder.decodeStringForKey("p", orElse: ""))
            case RichTextTypes.image.rawValue:
                self = .image(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), dimensions: PixelDimensions(width: decoder.decodeInt32ForKey("sw", orElse: 0), height: decoder.decodeInt32ForKey("sh", orElse: 0)))
            case RichTextTypes.anchor.rawValue:
                self = .anchor(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, name: decoder.decodeStringForKey("n", orElse: ""))
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
            case let .subscript(text):
                encoder.encodeInt32(RichTextTypes.subscript.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .superscript(text):
                encoder.encodeInt32(RichTextTypes.superscript.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .marked(text):
                encoder.encodeInt32(RichTextTypes.marked.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .phone(text, phone):
                encoder.encodeInt32(RichTextTypes.phone.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeString(phone, forKey: "p")
            case let .image(id, dimensions):
                encoder.encodeInt32(RichTextTypes.image.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeInt32(Int32(dimensions.width), forKey: "sw")
                encoder.encodeInt32(Int32(dimensions.height), forKey: "sh")
            case let .anchor(text, name):
                encoder.encodeInt32(RichTextTypes.anchor.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeString(name, forKey: "n")
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
            case let .subscript(text):
                if case .subscript(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .superscript(text):
                if case .superscript(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .marked(text):
                if case .marked(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .phone(text, phone):
                if case .phone(text, phone) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(id, dimensions):
                if case .image(id, dimensions) = rhs {
                    return true
                } else {
                    return false
                }
            case let .anchor(text, name):
                if case .anchor(text, name) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public extension RichText {
    var plainText: String {
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
            case let .subscript(text):
                return text.plainText
            case let .superscript(text):
                return text.plainText
            case let .marked(text):
                return text.plainText
            case let .phone(text, _):
                return text.plainText
            case .image:
                return ""
            case let .anchor(text, _):
                return text.plainText
        }
    }
}

extension RichText {
    public init(flatBuffersObject: TelegramCore_RichText) throws {
        switch flatBuffersObject.valueType {
        case .richtextEmpty:
            self = .empty
        case .richtextPlain:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Plain.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .plain(value.text)
        case .richtextBold:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Bold.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .bold(try RichText(flatBuffersObject: value.text))
        case .richtextItalic:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Italic.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .italic(try RichText(flatBuffersObject: value.text))
        case .richtextUnderline:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Underline.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .underline(try RichText(flatBuffersObject: value.text))
        case .richtextStrikethrough:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Strikethrough.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .strikethrough(try RichText(flatBuffersObject: value.text))
        case .richtextFixed:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Fixed.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .fixed(try RichText(flatBuffersObject: value.text))
        case .richtextUrl:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Url.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .url(text: try RichText(flatBuffersObject: value.text), url: value.url, webpageId: value.webpageId.flatMap { MediaId($0) })
        case .richtextEmail:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Email.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .email(text: try RichText(flatBuffersObject: value.text), 
                         email: value.email)
        case .richtextConcat:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Concat.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .concat(try (0..<value.textsCount).map { try RichText(flatBuffersObject: value.texts(at: $0)!) })
        case .richtextSubscript:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Subscript.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .subscript(try RichText(flatBuffersObject: value.text))
        case .richtextSuperscript:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Superscript.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .superscript(try RichText(flatBuffersObject: value.text))
        case .richtextMarked:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Marked.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .marked(try RichText(flatBuffersObject: value.text))
        case .richtextPhone:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Phone.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .phone(text: try RichText(flatBuffersObject: value.text), 
                         phone: value.phone)
        case .richtextImage:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Image.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .image(id: MediaId(value.id), dimensions: PixelDimensions(value.dimensions))
        case .richtextAnchor:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Anchor.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .anchor(text: try RichText(flatBuffersObject: value.text), 
                          name: value.name)
        case .none_:
            self = .empty
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_RichText_Value
        let offset: Offset
        
        switch self {
        case .empty:
            valueType = .richtextEmpty
            let start = TelegramCore_RichText_Empty.startRichText_Empty(&builder)
            offset = TelegramCore_RichText_Empty.endRichText_Empty(&builder, start: start)
        case let .plain(text):
            valueType = .richtextPlain
            let textOffset = builder.create(string: text)
            let start = TelegramCore_RichText_Plain.startRichText_Plain(&builder)
            TelegramCore_RichText_Plain.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Plain.endRichText_Plain(&builder, start: start)
        case let .bold(text):
            valueType = .richtextBold
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Bold.startRichText_Bold(&builder)
            TelegramCore_RichText_Bold.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Bold.endRichText_Bold(&builder, start: start)
        case let .italic(text):
            valueType = .richtextItalic
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Italic.startRichText_Italic(&builder)
            TelegramCore_RichText_Italic.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Italic.endRichText_Italic(&builder, start: start)
        case let .underline(text):
            valueType = .richtextUnderline
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Underline.startRichText_Underline(&builder)
            TelegramCore_RichText_Underline.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Underline.endRichText_Underline(&builder, start: start)
        case let .strikethrough(text):
            valueType = .richtextStrikethrough
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Strikethrough.startRichText_Strikethrough(&builder)
            TelegramCore_RichText_Strikethrough.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Strikethrough.endRichText_Strikethrough(&builder, start: start)
        case let .fixed(text):
            valueType = .richtextFixed
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Fixed.startRichText_Fixed(&builder)
            TelegramCore_RichText_Fixed.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Fixed.endRichText_Fixed(&builder, start: start)
        case let .url(text, url, webpageId):
            valueType = .richtextUrl
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let urlOffset = builder.create(string: url)
            let start = TelegramCore_RichText_Url.startRichText_Url(&builder)
            TelegramCore_RichText_Url.add(text: textOffset, &builder)
            TelegramCore_RichText_Url.add(url: urlOffset, &builder)
            if let webpageId {
                TelegramCore_RichText_Url.add(webpageId: webpageId.asFlatBuffersObject(), &builder)
            }
            offset = TelegramCore_RichText_Url.endRichText_Url(&builder, start: start)
        case let .email(text, email):
            valueType = .richtextEmail
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let emailOffset = builder.create(string: email)
            let start = TelegramCore_RichText_Email.startRichText_Email(&builder)
            TelegramCore_RichText_Email.add(text: textOffset, &builder)
            TelegramCore_RichText_Email.add(email: emailOffset, &builder)
            offset = TelegramCore_RichText_Email.endRichText_Email(&builder, start: start)
        case let .concat(texts):
            valueType = .richtextConcat
            let textsOffsets = texts.map { $0.encodeToFlatBuffers(builder: &builder) }
            let textsOffset = builder.createVector(ofOffsets: textsOffsets, len: textsOffsets.count)
            let start = TelegramCore_RichText_Concat.startRichText_Concat(&builder)
            TelegramCore_RichText_Concat.addVectorOf(texts: textsOffset, &builder)
            offset = TelegramCore_RichText_Concat.endRichText_Concat(&builder, start: start)
        case let .subscript(text):
            valueType = .richtextSubscript
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Subscript.startRichText_Subscript(&builder)
            TelegramCore_RichText_Subscript.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Subscript.endRichText_Subscript(&builder, start: start)
        case let .superscript(text):
            valueType = .richtextSuperscript
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Superscript.startRichText_Superscript(&builder)
            TelegramCore_RichText_Superscript.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Superscript.endRichText_Superscript(&builder, start: start)
        case let .marked(text):
            valueType = .richtextMarked
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Marked.startRichText_Marked(&builder)
            TelegramCore_RichText_Marked.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Marked.endRichText_Marked(&builder, start: start)
        case let .phone(text, phone):
            valueType = .richtextPhone
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let phoneOffset = builder.create(string: phone)
            let start = TelegramCore_RichText_Phone.startRichText_Phone(&builder)
            TelegramCore_RichText_Phone.add(text: textOffset, &builder)
            TelegramCore_RichText_Phone.add(phone: phoneOffset, &builder)
            offset = TelegramCore_RichText_Phone.endRichText_Phone(&builder, start: start)
        case let .image(id, dimensions):
            valueType = .richtextImage
            let start = TelegramCore_RichText_Image.startRichText_Image(&builder)
            TelegramCore_RichText_Image.add(id: id.asFlatBuffersObject(), &builder)
            TelegramCore_RichText_Image.add(dimensions: dimensions.asFlatBuffersObject(), &builder)
            offset = TelegramCore_RichText_Image.endRichText_Image(&builder, start: start)
        case let .anchor(text, name):
            valueType = .richtextAnchor
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let nameOffset = builder.create(string: name)
            let start = TelegramCore_RichText_Anchor.startRichText_Anchor(&builder)
            TelegramCore_RichText_Anchor.add(text: textOffset, &builder)
            TelegramCore_RichText_Anchor.add(name: nameOffset, &builder)
            offset = TelegramCore_RichText_Anchor.endRichText_Anchor(&builder, start: start)
        }
        
        return TelegramCore_RichText.createRichText(&builder, valueType: valueType, valueOffset: offset)
    }
}
