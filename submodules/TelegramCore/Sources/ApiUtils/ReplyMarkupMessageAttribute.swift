import Foundation
import Postbox
import TelegramApi

extension ReplyMarkupButtonAction.PeerTypes {
    init(apiType: [Api.InlineQueryPeerType]) {
        var rawValue: Int32 = 0
        for type in apiType {
            switch type {
            case .inlineQueryPeerTypePM:
                rawValue |= ReplyMarkupButtonAction.PeerTypes.users.rawValue
            case .inlineQueryPeerTypeBotPM:
                rawValue |= ReplyMarkupButtonAction.PeerTypes.bots.rawValue
            case .inlineQueryPeerTypeBroadcast:
                rawValue |= ReplyMarkupButtonAction.PeerTypes.channels.rawValue
            case .inlineQueryPeerTypeChat, .inlineQueryPeerTypeMegagroup:
                rawValue |= ReplyMarkupButtonAction.PeerTypes.groups.rawValue
            case .inlineQueryPeerTypeSameBotPM:
                break
            }
        }
        self.init(rawValue: rawValue)
    }
}

extension ReplyMarkupButtonRequestPeerType {
    init(apiType: Api.RequestPeerType) {
        switch apiType {
        case let .requestPeerTypeUser(data):
            self = .user(ReplyMarkupButtonRequestPeerType.User(
                isBot: data.bot.flatMap({ $0 == .boolTrue }),
                isPremium: data.premium.flatMap({ $0 == .boolTrue })
            ))
        case let .requestPeerTypeChat(data):
            self = .group(ReplyMarkupButtonRequestPeerType.Group(
                isCreator: (data.flags & (1 << 0)) != 0,
                hasUsername: data.hasUsername.flatMap({ $0 == .boolTrue }),
                isForum: data.forum.flatMap({ $0 == .boolTrue }),
                botParticipant: (data.flags & (1 << 5)) != 0,
                userAdminRights: data.userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                botAdminRights: data.botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
            ))
        case let .requestPeerTypeBroadcast(data):
            self = .channel(ReplyMarkupButtonRequestPeerType.Channel(
                isCreator: (data.flags & (1 << 0)) != 0,
                hasUsername: data.hasUsername.flatMap({ $0 == .boolTrue }),
                userAdminRights: data.userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                botAdminRights: data.botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
            ))
        case let .requestPeerTypeCreateBot(data):
            self = .createBot(ReplyMarkupButtonRequestPeerType.CreateBot(
                suggestedName: data.suggestedName,
                suggestedUsername: data.suggestedUsername
            ))
        }
    }
}

public extension ReplyMarkupButtonAction {
    /// Reply-keyboard button behaviours. `fwdText` is always nil here — only the urlAuth
    /// constructors carry `fwd_text`, and those are inline-only.
    static func from(apiType: Api.ButtonType) -> (action: ReplyMarkupButtonAction, fwdText: String?) {
        switch apiType {
        case .buttonTypeDefault:
            return (.text, nil)
        case .buttonTypeRequestPhone:
            return (.requestPhone, nil)
        case .buttonTypeRequestGeoLocation:
            return (.requestMap, nil)
        case let .buttonTypeRequestPoll(data):
            let isQuiz: Bool? = data.quiz.flatMap { $0 == .boolTrue }
            return (.setupPoll(isQuiz: isQuiz), nil)
        case let .buttonTypeRequestPeer(data):
            return (.requestPeer(
                peerType: ReplyMarkupButtonRequestPeerType(apiType: data.peerType),
                buttonId: data.buttonId,
                maxQuantity: data.maxQuantity
            ), nil)
        case let .inputButtonTypeRequestPeer(data):
            return (.requestPeer(
                peerType: ReplyMarkupButtonRequestPeerType(apiType: data.peerType),
                buttonId: data.buttonId,
                maxQuantity: data.maxQuantity
            ), nil)
        case let .buttonTypeSimpleWebView(data):
            return (.openWebView(url: data.url, simple: true), nil)
        }
    }

    /// Inline button behaviours. Stage 2 reuses this for InstantPage page buttons — the 10
    /// distinct actions it can return are exactly the ones representable in the
    /// `InstantPageButtonAction` FlatBuffers union.
    static func from(apiType: Api.InlineButtonType) -> (action: ReplyMarkupButtonAction, fwdText: String?) {
        switch apiType {
        case let .inlineButtonTypeUrl(data):
            return (.url(data.url), nil)
        case let .inlineButtonTypeUrlAuth(data):
            return (.urlAuth(url: data.url, buttonId: data.buttonId), data.fwdText)
        case let .inputInlineButtonTypeUrlAuth(data):
            return (.urlAuth(url: data.url, buttonId: 0), data.fwdText)
        case let .inlineButtonTypeWebView(data):
            return (.openWebView(url: data.url, simple: false), nil)
        case let .inlineButtonTypeCallback(data):
            let memory = malloc(data.data.size)!
            memcpy(memory, data.data.data, data.data.size)
            let dataBuffer = MemoryBuffer(memory: memory, capacity: data.data.size, length: data.data.size, freeWhenDone: true)
            return (.callback(requiresPassword: (data.flags & (1 << 0)) != 0, data: dataBuffer), nil)
        case .inlineButtonTypeGame:
            return (.openWebApp, nil)
        case .inlineButtonTypeBuy:
            return (.payment, nil)
        case let .inlineButtonTypeSwitchInline(data):
            var peerTypes = ReplyMarkupButtonAction.PeerTypes()
            if let types = data.peerTypes {
                peerTypes = ReplyMarkupButtonAction.PeerTypes(apiType: types)
            }
            return (.switchInline(samePeer: (data.flags & (1 << 0)) != 0, query: data.query, peerTypes: peerTypes), nil)
        case let .inlineButtonTypeUserProfile(data):
            return (.openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(data.userId))), nil)
        case .inputInlineButtonTypeUserProfile:
            return (.openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0))), nil)
        case let .inlineButtonTypeCopy(data):
            return (.copyText(payload: data.copyText), nil)
        case .inlineButtonTypeDisabled:
            return (.disabled, nil)
        }
    }
}

extension ReplyMarkupButton {
    // `style` sits at flags bit 10 on both `keyboardButton` and `keyboardInlineButton` — read once
    // per initializer rather than per-behaviour as the pre-unification code did. The two are separate
    // TL types (and so separate initializers), but they collapse to the same domain button here;
    // `ReplyMarkupMessageFlags.inline` on the attribute is what distinguishes them downstream.
    init(apiButton: Api.KeyboardButton) {
        switch apiButton {
        case let .keyboardButton(data):
            let mapped = ReplyMarkupButtonAction.from(apiType: data.type)
            self.init(
                title: data.text,
                titleWhenForwarded: mapped.fwdText,
                action: mapped.action,
                style: data.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:))
            )
        }
    }

    init(apiInlineButton: Api.KeyboardInlineButton) {
        switch apiInlineButton {
        case let .keyboardInlineButton(data):
            let mapped = ReplyMarkupButtonAction.from(apiType: data.type)
            self.init(
                title: data.text,
                titleWhenForwarded: mapped.fwdText,
                action: mapped.action,
                style: data.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:))
            )
        }
    }
}

extension ReplyMarkupRow {
    init(apiRow: Api.KeyboardButtonRow) {
        switch apiRow {
            case let .keyboardButtonRow(keyboardButtonRowData):
                let buttons = keyboardButtonRowData.buttons
                self.init(buttons: buttons.map { ReplyMarkupButton(apiButton: $0) })
        }
    }

    init(apiInlineRow: Api.KeyboardInlineButtonRow) {
        switch apiInlineRow {
            case let .keyboardInlineButtonRow(keyboardInlineButtonRowData):
                let buttons = keyboardInlineButtonRowData.buttons
                self.init(buttons: buttons.map { ReplyMarkupButton(apiInlineButton: $0) })
        }
    }
}

extension ReplyMarkupMessageAttribute {
    convenience init(apiMarkup: Api.ReplyMarkup) {
        var rows: [ReplyMarkupRow] = []
        var flags = ReplyMarkupMessageFlags()
        var placeholder: String?
        switch apiMarkup {
            case let .replyKeyboardMarkup(replyKeyboardMarkupData):
                let (markupFlags, apiRows, apiPlaceholder) = (replyKeyboardMarkupData.flags, replyKeyboardMarkupData.rows, replyKeyboardMarkupData.placeholder)
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
                if (markupFlags & (1 << 4)) != 0 {
                    flags.insert(.persistent)
                }
                if (markupFlags & (1 << 5)) != 0 {
                    flags.insert(.setupReply)
                }
                placeholder = apiPlaceholder
            case let .replyInlineMarkup(replyInlineMarkupData):
                let markupFlags = replyInlineMarkupData.flags
                let apiRows = replyInlineMarkupData.rows
                rows = apiRows.map { ReplyMarkupRow(apiInlineRow: $0) }
                if (markupFlags & (1 << 5)) != 0 {
                    flags.insert(.setupReply)
                }
                flags.insert(.inline)
            case let .replyKeyboardForceReply(replyKeyboardForceReplyData):
                let (forceReplyFlags, apiPlaceholder) = (replyKeyboardForceReplyData.flags, replyKeyboardForceReplyData.placeholder)
                if (forceReplyFlags & (1 << 1)) != 0 {
                    flags.insert(.once)
                }
                if (forceReplyFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
                flags.insert(.setupReply)
                placeholder = apiPlaceholder
            case let .replyKeyboardHide(replyKeyboardHideData):
                let hideFlags = replyKeyboardHideData.flags
                if (hideFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
        }
        self.init(rows: rows, flags: flags, placeholder: placeholder)
    }
}
