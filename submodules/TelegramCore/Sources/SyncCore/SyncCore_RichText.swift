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
    case formula = 16
    case textCustomEmoji = 17
    case textAutoEmail = 18
    case textAutoPhone = 19
    case textAutoUrl = 20
    case textBankCard = 21
    case textBotCommand = 22
    case textCashtag = 23
    case textHashtag = 24
    case textMention = 25
    case textMentionName = 26
    case textSpoiler = 27
    case textDate = 28
    case textButton = 29
    case textTonAddress = 30
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
    case formula(latex: String)
    case textCustomEmoji(fileId: Int64, alt: String)
    case textAutoEmail(text: RichText)
    case textAutoPhone(text: RichText)
    case textAutoUrl(text: RichText)
    case textBankCard(text: RichText)
    case textTonAddress(text: RichText)
    case textBotCommand(text: RichText)
    case textCashtag(text: RichText)
    case textHashtag(text: RichText)
    case textMention(text: RichText)
    case textMentionName(text: RichText, peerId: Int64)
    case textSpoiler(text: RichText)
    case textDate(text: RichText, date: Int32, format: MessageTextEntityType.DateTimeFormat?)
    /// An inline tappable button inside a text run. Its label is itself RichText, so it can sit
    /// mid-sentence. Not yet rendered as a pill — see Stage 2.
    case textButton(InstantPageButton)

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
            case RichTextTypes.formula.rawValue:
                self = .formula(latex: decoder.decodeStringForKey("l", orElse: ""))
            case RichTextTypes.textCustomEmoji.rawValue:
                self = .textCustomEmoji(fileId: decoder.decodeInt64ForKey("ce.f", orElse: 0), alt: decoder.decodeStringForKey("ce.a", orElse: ""))
            case RichTextTypes.textAutoEmail.rawValue:
                self = .textAutoEmail(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textAutoPhone.rawValue:
                self = .textAutoPhone(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textAutoUrl.rawValue:
                self = .textAutoUrl(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textBankCard.rawValue:
                self = .textBankCard(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textTonAddress.rawValue:
                self = .textTonAddress(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textBotCommand.rawValue:
                self = .textBotCommand(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textCashtag.rawValue:
                self = .textCashtag(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textHashtag.rawValue:
                self = .textHashtag(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textMention.rawValue:
                self = .textMention(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textMentionName.rawValue:
                self = .textMentionName(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, peerId: decoder.decodeInt64ForKey("mn.p", orElse: 0))
            case RichTextTypes.textSpoiler.rawValue:
                self = .textSpoiler(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case RichTextTypes.textDate.rawValue:
                self = .textDate(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, date: decoder.decodeInt32ForKey("dt", orElse: 0), format: decoder.decodeOptionalInt32ForKey("df").flatMap { MessageTextEntityType.DateTimeFormat(rawValue: $0) })
            case RichTextTypes.textButton.rawValue:
                self = .textButton(decoder.decodeObjectForKey("btn", decoder: { InstantPageButton(decoder: $0) }) as! InstantPageButton)
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
            case let .formula(latex):
                encoder.encodeInt32(RichTextTypes.formula.rawValue, forKey: "r")
                encoder.encodeString(latex, forKey: "l")
            case let .textCustomEmoji(fileId, alt):
                encoder.encodeInt32(RichTextTypes.textCustomEmoji.rawValue, forKey: "r")
                encoder.encodeInt64(fileId, forKey: "ce.f")
                encoder.encodeString(alt, forKey: "ce.a")
            case let .textAutoEmail(text):
                encoder.encodeInt32(RichTextTypes.textAutoEmail.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textAutoPhone(text):
                encoder.encodeInt32(RichTextTypes.textAutoPhone.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textAutoUrl(text):
                encoder.encodeInt32(RichTextTypes.textAutoUrl.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textBankCard(text):
                encoder.encodeInt32(RichTextTypes.textBankCard.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textTonAddress(text):
                encoder.encodeInt32(RichTextTypes.textTonAddress.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textBotCommand(text):
                encoder.encodeInt32(RichTextTypes.textBotCommand.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textCashtag(text):
                encoder.encodeInt32(RichTextTypes.textCashtag.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textHashtag(text):
                encoder.encodeInt32(RichTextTypes.textHashtag.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textMention(text):
                encoder.encodeInt32(RichTextTypes.textMention.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textMentionName(text, peerId):
                encoder.encodeInt32(RichTextTypes.textMentionName.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeInt64(peerId, forKey: "mn.p")
            case let .textSpoiler(text):
                encoder.encodeInt32(RichTextTypes.textSpoiler.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .textDate(text, date, format):
                encoder.encodeInt32(RichTextTypes.textDate.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeInt32(date, forKey: "dt")
                if let format {
                    encoder.encodeInt32(format.rawValue, forKey: "df")
                } else {
                    encoder.encodeNil(forKey: "df")
                }
            case let .textButton(button):
                encoder.encodeInt32(RichTextTypes.textButton.rawValue, forKey: "r")
                encoder.encodeObject(button, forKey: "btn")
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
            case let .formula(lhsLatex):
                if case let .formula(rhsLatex) = rhs, lhsLatex == rhsLatex {
                    return true
                } else {
                    return false
                }
            case let .textCustomEmoji(lhsFileId, lhsAlt):
                if case let .textCustomEmoji(rhsFileId, rhsAlt) = rhs, lhsFileId == rhsFileId, lhsAlt == rhsAlt {
                    return true
                } else {
                    return false
                }
            case let .textAutoEmail(text):
                if case .textAutoEmail(text) = rhs { return true } else { return false }
            case let .textAutoPhone(text):
                if case .textAutoPhone(text) = rhs { return true } else { return false }
            case let .textAutoUrl(text):
                if case .textAutoUrl(text) = rhs { return true } else { return false }
            case let .textBankCard(text):
                if case .textBankCard(text) = rhs { return true } else { return false }
            case let .textTonAddress(text):
                if case .textTonAddress(text) = rhs { return true } else { return false }
            case let .textBotCommand(text):
                if case .textBotCommand(text) = rhs { return true } else { return false }
            case let .textCashtag(text):
                if case .textCashtag(text) = rhs { return true } else { return false }
            case let .textHashtag(text):
                if case .textHashtag(text) = rhs { return true } else { return false }
            case let .textMention(text):
                if case .textMention(text) = rhs { return true } else { return false }
            case let .textMentionName(lhsText, lhsPeerId):
                if case let .textMentionName(rhsText, rhsPeerId) = rhs, lhsText == rhsText, lhsPeerId == rhsPeerId { return true } else { return false }
            case let .textSpoiler(text):
                if case .textSpoiler(text) = rhs { return true } else { return false }
            case let .textDate(lhsText, lhsDate, lhsFormat):
                if case let .textDate(rhsText, rhsDate, rhsFormat) = rhs, lhsText == rhsText, lhsDate == rhsDate, lhsFormat == rhsFormat { return true } else { return false }
            case let .textButton(lhsButton):
                if case let .textButton(rhsButton) = rhs, lhsButton == rhsButton { return true } else { return false }
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
            case let .formula(latex):
                return latex
            case let .textCustomEmoji(_, alt):
                return alt
            case let .textAutoEmail(text):
                return text.plainText
            case let .textAutoPhone(text):
                return text.plainText
            case let .textAutoUrl(text):
                return text.plainText
            case let .textBankCard(text):
                return text.plainText
            case let .textTonAddress(text):
                return text.plainText
            case let .textBotCommand(text):
                return text.plainText
            case let .textCashtag(text):
                return text.plainText
            case let .textHashtag(text):
                return text.plainText
            case let .textMention(text):
                return text.plainText
            case let .textMentionName(text, _):
                return text.plainText
            case let .textSpoiler(text):
                return text.plainText
            case let .textDate(text, _, _):
                return text.plainText
            case let .textButton(button):
                // The label is the button's only textual content, so previews and accessibility
                // read it rather than seeing an empty run.
                return button.text.plainText
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
                throw FlatBuffersError.missingRequiredField()
            }
            self = .plain(value.text)
        case .richtextBold:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Bold.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .bold(try RichText(flatBuffersObject: value.text))
        case .richtextItalic:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Italic.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .italic(try RichText(flatBuffersObject: value.text))
        case .richtextUnderline:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Underline.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .underline(try RichText(flatBuffersObject: value.text))
        case .richtextStrikethrough:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Strikethrough.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .strikethrough(try RichText(flatBuffersObject: value.text))
        case .richtextFixed:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Fixed.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .fixed(try RichText(flatBuffersObject: value.text))
        case .richtextUrl:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Url.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .url(text: try RichText(flatBuffersObject: value.text), url: value.url, webpageId: value.webpageId.flatMap { MediaId($0) })
        case .richtextEmail:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Email.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .email(text: try RichText(flatBuffersObject: value.text), 
                         email: value.email)
        case .richtextConcat:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Concat.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .concat(try (0..<value.textsCount).map { try RichText(flatBuffersObject: value.texts(at: $0)!) })
        case .richtextSubscript:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Subscript.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .subscript(try RichText(flatBuffersObject: value.text))
        case .richtextSuperscript:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Superscript.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .superscript(try RichText(flatBuffersObject: value.text))
        case .richtextMarked:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Marked.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .marked(try RichText(flatBuffersObject: value.text))
        case .richtextPhone:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Phone.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .phone(text: try RichText(flatBuffersObject: value.text), 
                         phone: value.phone)
        case .richtextImage:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Image.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .image(id: MediaId(value.id), dimensions: PixelDimensions(value.dimensions))
        case .richtextAnchor:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Anchor.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .anchor(text: try RichText(flatBuffersObject: value.text), 
                          name: value.name)
        case .richtextFormula:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Formula.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .formula(latex: value.latex)
        case .richtextCustomemoji:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_CustomEmoji.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textCustomEmoji(fileId: value.fileId, alt: value.alt)
        case .richtextAutoemail:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_AutoEmail.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textAutoEmail(text: try RichText(flatBuffersObject: value.text))
        case .richtextAutophone:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_AutoPhone.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textAutoPhone(text: try RichText(flatBuffersObject: value.text))
        case .richtextAutourl:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_AutoUrl.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textAutoUrl(text: try RichText(flatBuffersObject: value.text))
        case .richtextBankcard:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_BankCard.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textBankCard(text: try RichText(flatBuffersObject: value.text))
        case .richtextTonaddress:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_TonAddress.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textTonAddress(text: try RichText(flatBuffersObject: value.text))
        case .richtextBotcommand:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_BotCommand.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textBotCommand(text: try RichText(flatBuffersObject: value.text))
        case .richtextCashtag:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Cashtag.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textCashtag(text: try RichText(flatBuffersObject: value.text))
        case .richtextHashtag:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Hashtag.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textHashtag(text: try RichText(flatBuffersObject: value.text))
        case .richtextMention:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Mention.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textMention(text: try RichText(flatBuffersObject: value.text))
        case .richtextMentionname:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_MentionName.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textMentionName(text: try RichText(flatBuffersObject: value.text), peerId: value.peerId)
        case .richtextSpoiler:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Spoiler.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textSpoiler(text: try RichText(flatBuffersObject: value.text))
        case .richtextDate:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_Date.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            let formatValue = value.format
            self = .textDate(text: try RichText(flatBuffersObject: value.text), date: value.date, format: formatValue == -1 ? nil : MessageTextEntityType.DateTimeFormat(rawValue: formatValue))
        case .richtextTextbutton:
            guard let value = flatBuffersObject.value(type: TelegramCore_RichText_TextButton.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .textButton(try InstantPageButton(flatBuffersObject: value.button))
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
        case let .formula(latex):
            valueType = .richtextFormula
            let latexOffset = builder.create(string: latex)
            let start = TelegramCore_RichText_Formula.startRichText_Formula(&builder)
            TelegramCore_RichText_Formula.add(latex: latexOffset, &builder)
            offset = TelegramCore_RichText_Formula.endRichText_Formula(&builder, start: start)
        case let .textCustomEmoji(fileId, alt):
            valueType = .richtextCustomemoji
            let altOffset = builder.create(string: alt)
            let start = TelegramCore_RichText_CustomEmoji.startRichText_CustomEmoji(&builder)
            TelegramCore_RichText_CustomEmoji.add(fileId: fileId, &builder)
            TelegramCore_RichText_CustomEmoji.add(alt: altOffset, &builder)
            offset = TelegramCore_RichText_CustomEmoji.endRichText_CustomEmoji(&builder, start: start)
        case let .textAutoEmail(text):
            valueType = .richtextAutoemail
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_AutoEmail.startRichText_AutoEmail(&builder)
            TelegramCore_RichText_AutoEmail.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_AutoEmail.endRichText_AutoEmail(&builder, start: start)
        case let .textAutoPhone(text):
            valueType = .richtextAutophone
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_AutoPhone.startRichText_AutoPhone(&builder)
            TelegramCore_RichText_AutoPhone.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_AutoPhone.endRichText_AutoPhone(&builder, start: start)
        case let .textAutoUrl(text):
            valueType = .richtextAutourl
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_AutoUrl.startRichText_AutoUrl(&builder)
            TelegramCore_RichText_AutoUrl.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_AutoUrl.endRichText_AutoUrl(&builder, start: start)
        case let .textBankCard(text):
            valueType = .richtextBankcard
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_BankCard.startRichText_BankCard(&builder)
            TelegramCore_RichText_BankCard.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_BankCard.endRichText_BankCard(&builder, start: start)
        case let .textTonAddress(text):
            valueType = .richtextTonaddress
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_TonAddress.startRichText_TonAddress(&builder)
            TelegramCore_RichText_TonAddress.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_TonAddress.endRichText_TonAddress(&builder, start: start)
        case let .textBotCommand(text):
            valueType = .richtextBotcommand
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_BotCommand.startRichText_BotCommand(&builder)
            TelegramCore_RichText_BotCommand.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_BotCommand.endRichText_BotCommand(&builder, start: start)
        case let .textCashtag(text):
            valueType = .richtextCashtag
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Cashtag.startRichText_Cashtag(&builder)
            TelegramCore_RichText_Cashtag.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Cashtag.endRichText_Cashtag(&builder, start: start)
        case let .textHashtag(text):
            valueType = .richtextHashtag
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Hashtag.startRichText_Hashtag(&builder)
            TelegramCore_RichText_Hashtag.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Hashtag.endRichText_Hashtag(&builder, start: start)
        case let .textMention(text):
            valueType = .richtextMention
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Mention.startRichText_Mention(&builder)
            TelegramCore_RichText_Mention.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Mention.endRichText_Mention(&builder, start: start)
        case let .textMentionName(text, peerId):
            valueType = .richtextMentionname
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_MentionName.startRichText_MentionName(&builder)
            TelegramCore_RichText_MentionName.add(text: textOffset, &builder)
            TelegramCore_RichText_MentionName.add(peerId: peerId, &builder)
            offset = TelegramCore_RichText_MentionName.endRichText_MentionName(&builder, start: start)
        case let .textSpoiler(text):
            valueType = .richtextSpoiler
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Spoiler.startRichText_Spoiler(&builder)
            TelegramCore_RichText_Spoiler.add(text: textOffset, &builder)
            offset = TelegramCore_RichText_Spoiler.endRichText_Spoiler(&builder, start: start)
        case let .textDate(text, date, format):
            valueType = .richtextDate
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_Date.startRichText_Date(&builder)
            TelegramCore_RichText_Date.add(text: textOffset, &builder)
            TelegramCore_RichText_Date.add(date: date, &builder)
            TelegramCore_RichText_Date.add(format: format?.rawValue ?? -1, &builder)
            offset = TelegramCore_RichText_Date.endRichText_Date(&builder, start: start)
        case let .textButton(button):
            valueType = .richtextTextbutton
            let buttonOffset = button.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_RichText_TextButton.startRichText_TextButton(&builder)
            TelegramCore_RichText_TextButton.add(button: buttonOffset, &builder)
            offset = TelegramCore_RichText_TextButton.endRichText_TextButton(&builder, start: start)
        }

        return TelegramCore_RichText.createRichText(&builder, valueType: valueType, valueOffset: offset)
    }
}
