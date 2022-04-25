import Foundation
import Postbox
import TelegramApi


extension ReplyMarkupButton {
    init(apiButton: Api.KeyboardButton) {
        switch apiButton {
            case let .keyboardButton(text):
                self.init(title: text, titleWhenForwarded: nil, action: .text)
            case let .keyboardButtonCallback(flags, text, data):
                let memory = malloc(data.size)!
                memcpy(memory, data.data, data.size)
                let dataBuffer = MemoryBuffer(memory: memory, capacity: data.size, length: data.size, freeWhenDone: true)
                self.init(title: text, titleWhenForwarded: nil, action: .callback(requiresPassword: (flags & (1 << 0)) != 0, data: dataBuffer))
            case let .keyboardButtonRequestGeoLocation(text):
                self.init(title: text, titleWhenForwarded: nil, action: .requestMap)
            case let .keyboardButtonRequestPhone(text):
                self.init(title: text, titleWhenForwarded: nil, action: .requestPhone)
            case let .keyboardButtonSwitchInline(flags, text, query):
                self.init(title: text, titleWhenForwarded: nil, action: .switchInline(samePeer: (flags & (1 << 0)) != 0, query: query))
            case let .keyboardButtonUrl(text, url):
                self.init(title: text, titleWhenForwarded: nil, action: .url(url))
            case let .keyboardButtonGame(text):
                self.init(title: text, titleWhenForwarded: nil, action: .openWebApp)
            case let .keyboardButtonBuy(text):
                self.init(title: text, titleWhenForwarded: nil, action: .payment)
            case let .keyboardButtonUrlAuth(_, text, fwdText, url, buttonId):
                self.init(title: text, titleWhenForwarded: fwdText, action: .urlAuth(url: url, buttonId: buttonId))
            case let .inputKeyboardButtonUrlAuth(_, text, fwdText, url, _):
                self.init(title: text, titleWhenForwarded: fwdText, action: .urlAuth(url: url, buttonId: 0))
            case let .keyboardButtonRequestPoll(_, quiz, text):
                let isQuiz: Bool? = quiz.flatMap { quiz in
                    if case .boolTrue = quiz {
                        return true
                    } else {
                        return false
                    }
                }
                self.init(title: text, titleWhenForwarded: nil, action: .setupPoll(isQuiz: isQuiz))
            case let .keyboardButtonUserProfile(text, userId):
                self.init(title: text, titleWhenForwarded: nil, action: .openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))))
            case let .inputKeyboardButtonUserProfile(text, _):
                self.init(title: text, titleWhenForwarded: nil, action: .openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0))))
            case let .keyboardButtonWebView(text, url):
                self.init(title: text, titleWhenForwarded: nil, action: .openWebView(url: url, simple: false))
            case let .keyboardButtonSimpleWebView(text, url):
                self.init(title: text, titleWhenForwarded: nil, action: .openWebView(url: url, simple: true))
        }
    }
}

extension ReplyMarkupRow {
    init(apiRow: Api.KeyboardButtonRow) {
        switch apiRow {
            case let .keyboardButtonRow(buttons):
                self.init(buttons: buttons.map { ReplyMarkupButton(apiButton: $0) })
        }
    }
}

extension ReplyMarkupMessageAttribute {
    convenience init(apiMarkup: Api.ReplyMarkup) {
        var rows: [ReplyMarkupRow] = []
        var flags = ReplyMarkupMessageFlags()
        var placeholder: String?
        switch apiMarkup {
            case let .replyKeyboardMarkup(markupFlags, apiRows, apiPlaceholder):
                rows = apiRows.map { ReplyMarkupRow(apiRow: $0) }
                if (markupFlags & (1 << 0)) != 0 {
                    flags.insert(.fit)
                }
                if (markupFlags & (1 << 1)) != 0 {
                    flags.insert(.once)
                }
                if (markupFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
                placeholder = apiPlaceholder
            case let .replyInlineMarkup(apiRows):
                rows = apiRows.map { ReplyMarkupRow(apiRow: $0) }
                flags.insert(.inline)
            case let .replyKeyboardForceReply(forceReplyFlags, apiPlaceholder):
                if (forceReplyFlags & (1 << 1)) != 0 {
                    flags.insert(.once)
                }
                if (forceReplyFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
                flags.insert(.setupReply)
                placeholder = apiPlaceholder
            case let .replyKeyboardHide(hideFlags):
                if (hideFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
        }
        self.init(rows: rows, flags: flags, placeholder: placeholder)
    }
}
