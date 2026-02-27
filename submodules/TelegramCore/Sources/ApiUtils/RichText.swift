import Foundation
import Postbox
import TelegramApi


extension RichText {
    init(apiText: Api.RichText) {
        switch apiText {
            case .textEmpty:
                self = .empty
            case let .textPlain(textPlainData):
                let text = textPlainData.text
                self = .plain(text)
            case let .textBold(textBoldData):
                let text = textBoldData.text
                self = .bold(RichText(apiText: text))
            case let .textItalic(textItalicData):
                let text = textItalicData.text
                self = .italic(RichText(apiText: text))
            case let .textUnderline(textUnderlineData):
                let text = textUnderlineData.text
                self = .underline(RichText(apiText: text))
            case let .textStrike(textStrikeData):
                let text = textStrikeData.text
                self = .strikethrough(RichText(apiText: text))
            case let .textFixed(textFixedData):
                let text = textFixedData.text
                self = .fixed(RichText(apiText: text))
            case let .textUrl(textUrlData):
                let (text, url, webpageId) = (textUrlData.text, textUrlData.url, textUrlData.webpageId)
                self = .url(text: RichText(apiText: text), url: url, webpageId: webpageId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId))
            case let .textEmail(textEmailData):
                let (text, email) = (textEmailData.text, textEmailData.email)
                self = .email(text: RichText(apiText: text), email: email)
            case let .textConcat(textConcatData):
                let texts = textConcatData.texts
                self = .concat(texts.map({ RichText(apiText: $0) }))
            case let .textSubscript(textSubscriptData):
                let text = textSubscriptData.text
                self = .subscript(RichText(apiText: text))
            case let .textSuperscript(textSuperscriptData):
                let text = textSuperscriptData.text
                self = .superscript(RichText(apiText: text))
            case let .textMarked(textMarkedData):
                let text = textMarkedData.text
                self = .marked(RichText(apiText: text))
            case let .textPhone(textPhoneData):
                let (text, phone) = (textPhoneData.text, textPhoneData.phone)
                self = .phone(text: RichText(apiText: text), phone: phone)
            case let .textImage(textImageData):
                let (documentId, w, h) = (textImageData.documentId, textImageData.w, textImageData.h)
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudFile, id: documentId), dimensions: PixelDimensions(width: w, height: h))
            case let .textAnchor(textAnchorData):
                let (text, name) = (textAnchorData.text, textAnchorData.name)
                self = .anchor(text: RichText(apiText: text), name: name)
        }
    }
}
