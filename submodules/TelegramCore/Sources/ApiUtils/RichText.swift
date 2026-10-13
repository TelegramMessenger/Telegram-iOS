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
        case let .textCustomEmoji(data):
            self = .textCustomEmoji(fileId: data.documentId, alt: data.alt)
        case let .textMath(textMath):
            self = .formula(latex: textMath.source)
        case let .textAutoEmail(textAutoEmailData):
            self = .textAutoEmail(text: RichText(apiText: textAutoEmailData.text))
        case let .textAutoPhone(textAutoPhoneData):
            self = .textAutoPhone(text: RichText(apiText: textAutoPhoneData.text))
        case let .textAutoUrl(textAutoUrlData):
            self = .textAutoUrl(text: RichText(apiText: textAutoUrlData.text))
        case let .textBankCard(textBankCardData):
            self = .textBankCard(text: RichText(apiText: textBankCardData.text))
        case let .textTonAddress(data):
            self = .textTonAddress(text: RichText(apiText: data.text))
        case let .textBotCommand(textBotCommandData):
            self = .textBotCommand(text: RichText(apiText: textBotCommandData.text))
        case let .textCashtag(textCashtagData):
            self = .textCashtag(text: RichText(apiText: textCashtagData.text))
        case let .textDate(value):
            let format: MessageTextEntityType.DateTimeFormat? = value.flags == 0 ? nil : MessageTextEntityType.DateTimeFormat(rawValue: value.flags)
            self = .textDate(text: RichText(apiText: value.text), date: value.date, format: format)
        case let .textHashtag(textHashtagData):
            self = .textHashtag(text: RichText(apiText: textHashtagData.text))
        case let .textMention(textMentionData):
            self = .textMention(text: RichText(apiText: textMentionData.text))
        case let .textMentionName(textMentionNameData):
            self = .textMentionName(text: RichText(apiText: textMentionNameData.text), peerId: textMentionNameData.userId)
        case let .textSpoiler(textSpoilerData):
            self = .textSpoiler(text: RichText(apiText: textSpoilerData.text))
        case .textDiff:
            self = .empty
        case let .textButton(data):
            self = .textButton(InstantPageButton(
                text: RichText(apiText: data.text),
                action: ReplyMarkupButtonAction.from(apiType: data.type).action,
                color: data.style.flatMap(ReplyMarkupButton.Style.Color.init(apiRichStyle:)),
                isLink: InstantPageButton.isLinkStyle(data.style)
            ))
        }
    }

    func apiRichText() -> Api.RichText {
        switch self {
        case .empty:
            return .textPlain(Api.RichText.Cons_textPlain(text: ""))
        case let .plain(value):
            return .textPlain(Api.RichText.Cons_textPlain(text: value))
        case let .bold(value):
            return .textBold(Api.RichText.Cons_textBold(text: value.apiRichText()))
        case let .italic(value):
            return .textItalic(Api.RichText.Cons_textItalic(text: value.apiRichText()))
        case let .underline(value):
            return .textUnderline(Api.RichText.Cons_textUnderline(text: value.apiRichText()))
        case let .strikethrough(value):
            return .textStrike(Api.RichText.Cons_textStrike(text: value.apiRichText()))
        case let .fixed(value):
            return .textFixed(Api.RichText.Cons_textFixed(text: value.apiRichText()))
        case let .url(text, url, webpageId):
            return .textUrl(Api.RichText.Cons_textUrl(text: text.apiRichText(), url: url, webpageId: webpageId?.id ?? 0))
        case let .email(text, email):
            return .textEmail(Api.RichText.Cons_textEmail(text: text.apiRichText(), email: email))
        case let .concat(values):
            return .textConcat(Api.RichText.Cons_textConcat(texts: values.map { $0.apiRichText() }))
        case let .`subscript`(value):
            return .textSubscript(Api.RichText.Cons_textSubscript(text: value.apiRichText()))
        case let .superscript(value):
            return .textSuperscript(Api.RichText.Cons_textSuperscript(text: value.apiRichText()))
        case let .marked(value):
            return .textMarked(Api.RichText.Cons_textMarked(text: value.apiRichText()))
        case let .phone(text, phone):
            return .textPhone(Api.RichText.Cons_textPhone(text: text.apiRichText(), phone: phone))
        case let .image(id, dimensions):
            return .textImage(Api.RichText.Cons_textImage(documentId: id.id, w: dimensions.width, h: dimensions.height))
        case let .anchor(text, name):
            return .textAnchor(Api.RichText.Cons_textAnchor(text: text.apiRichText(), name: name))
        case let .formula(latex):
            return .textMath(Api.RichText.Cons_textMath(source: latex))
        case let .textCustomEmoji(fileId, alt):
            return .textCustomEmoji(Api.RichText.Cons_textCustomEmoji(documentId: fileId, alt: alt))
        case let .textAutoEmail(text):
            return .textAutoEmail(Api.RichText.Cons_textAutoEmail(text: text.apiRichText()))
        case let .textAutoPhone(text):
            return .textAutoPhone(Api.RichText.Cons_textAutoPhone(text: text.apiRichText()))
        case let .textAutoUrl(text):
            return .textAutoUrl(Api.RichText.Cons_textAutoUrl(text: text.apiRichText()))
        case let .textBankCard(text):
            return .textBankCard(Api.RichText.Cons_textBankCard(text: text.apiRichText()))
        case let .textTonAddress(text):
            return .textTonAddress(Api.RichText.Cons_textTonAddress(text: text.apiRichText()))
        case let .textBotCommand(text):
            return .textBotCommand(Api.RichText.Cons_textBotCommand(text: text.apiRichText()))
        case let .textCashtag(text):
            return .textCashtag(Api.RichText.Cons_textCashtag(text: text.apiRichText()))
        case let .textHashtag(text):
            return .textHashtag(Api.RichText.Cons_textHashtag(text: text.apiRichText()))
        case let .textMention(text):
            return .textMention(Api.RichText.Cons_textMention(text: text.apiRichText()))
        case let .textMentionName(text, peerId):
            return .textMentionName(Api.RichText.Cons_textMentionName(text: text.apiRichText(), userId: peerId))
        case let .textSpoiler(text):
            return .textSpoiler(Api.RichText.Cons_textSpoiler(text: text.apiRichText()))
        case let .textDate(text, date, format):
            return .textDate(Api.RichText.Cons_textDate(flags: format?.rawValue ?? 0, text: text.apiRichText(), date: date))
        case let .textButton(button):
            let (flags, style) = button.apiFlagsAndStyle()
            return .textButton(Api.RichText.Cons_textButton(
                flags: flags,
                text: button.text.apiRichText(),
                type: button.action.apiInlineButtonType(),
                style: style
            ))
        }
    }
}
