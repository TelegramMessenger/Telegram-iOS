import Foundation
import Postbox
import TelegramApi


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
            case let .textSubscript(text):
                self = .subscript(RichText(apiText: text))
            case let .textSuperscript(text):
                self = .superscript(RichText(apiText: text))
            case let .textMarked(text):
                self = .marked(RichText(apiText: text))
            case let .textPhone(text, phone):
                self = .phone(text: RichText(apiText: text), phone: phone)
            case let .textImage(documentId, w, h):
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudFile, id: documentId), dimensions: PixelDimensions(width: w, height: h))
            case let .textAnchor(text, name):
                self = .anchor(text: RichText(apiText: text), name: name)
        }
    }
}
