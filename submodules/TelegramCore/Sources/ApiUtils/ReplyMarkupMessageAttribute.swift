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

extension ReplyMarkupButton {
    init(apiButton: Api.KeyboardButton) {
        switch apiButton {
        case let .keyboardButton(keyboardButtonData):
            let text = keyboardButtonData.text
            self.init(title: text, titleWhenForwarded: nil, action: .text, style: keyboardButtonData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonCallback(keyboardButtonCallbackData):
            let (flags, text, data) = (keyboardButtonCallbackData.flags, keyboardButtonCallbackData.text, keyboardButtonCallbackData.data)
            let memory = malloc(data.size)!
            memcpy(memory, data.data, data.size)
            let dataBuffer = MemoryBuffer(memory: memory, capacity: data.size, length: data.size, freeWhenDone: true)
            self.init(title: text, titleWhenForwarded: nil, action: .callback(requiresPassword: (flags & (1 << 0)) != 0, data: dataBuffer), style: keyboardButtonCallbackData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonRequestGeoLocation(keyboardButtonRequestGeoLocationData):
            let text = keyboardButtonRequestGeoLocationData.text
            self.init(title: text, titleWhenForwarded: nil, action: .requestMap, style: keyboardButtonRequestGeoLocationData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonRequestPhone(keyboardButtonRequestPhoneData):
            let text = keyboardButtonRequestPhoneData.text
            self.init(title: text, titleWhenForwarded: nil, action: .requestPhone, style: keyboardButtonRequestPhoneData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonSwitchInline(keyboardButtonSwitchInlineData):
            let (flags, text, query, types) = (keyboardButtonSwitchInlineData.flags, keyboardButtonSwitchInlineData.text, keyboardButtonSwitchInlineData.query, keyboardButtonSwitchInlineData.peerTypes)
            var peerTypes = ReplyMarkupButtonAction.PeerTypes()
            if let types = types {
                for type in types {
                    switch type {
                    case .inlineQueryPeerTypePM:
                        peerTypes.insert(.users)
                    case .inlineQueryPeerTypeBotPM:
                        peerTypes.insert(.bots)
                    case .inlineQueryPeerTypeBroadcast:
                        peerTypes.insert(.channels)
                    case .inlineQueryPeerTypeChat, .inlineQueryPeerTypeMegagroup:
                        peerTypes.insert(.groups)
                    case .inlineQueryPeerTypeSameBotPM:
                        break
                    }
                }
            }
            self.init(title: text, titleWhenForwarded: nil, action: .switchInline(samePeer: (flags & (1 << 0)) != 0, query: query, peerTypes: peerTypes), style: keyboardButtonSwitchInlineData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonUrl(keyboardButtonUrlData):
            let (text, url) = (keyboardButtonUrlData.text, keyboardButtonUrlData.url)
            self.init(title: text, titleWhenForwarded: nil, action: .url(url), style: keyboardButtonUrlData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonGame(keyboardButtonGameData):
            let text = keyboardButtonGameData.text
            self.init(title: text, titleWhenForwarded: nil, action: .openWebApp, style: keyboardButtonGameData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonBuy(keyboardButtonBuyData):
            let text = keyboardButtonBuyData.text
            self.init(title: text, titleWhenForwarded: nil, action: .payment, style: keyboardButtonBuyData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonUrlAuth(keyboardButtonUrlAuthData):
            let (text, fwdText, url, buttonId) = (keyboardButtonUrlAuthData.text, keyboardButtonUrlAuthData.fwdText, keyboardButtonUrlAuthData.url, keyboardButtonUrlAuthData.buttonId)
            self.init(title: text, titleWhenForwarded: fwdText, action: .urlAuth(url: url, buttonId: buttonId), style: keyboardButtonUrlAuthData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .inputKeyboardButtonUrlAuth(inputKeyboardButtonUrlAuthData):
            let (text, fwdText, url) = (inputKeyboardButtonUrlAuthData.text, inputKeyboardButtonUrlAuthData.fwdText, inputKeyboardButtonUrlAuthData.url)
            self.init(title: text, titleWhenForwarded: fwdText, action: .urlAuth(url: url, buttonId: 0), style: inputKeyboardButtonUrlAuthData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonRequestPoll(keyboardButtonRequestPollData):
            let (quiz, text) = (keyboardButtonRequestPollData.quiz, keyboardButtonRequestPollData.text)
            let isQuiz: Bool? = quiz.flatMap { quiz in
                if case .boolTrue = quiz {
                    return true
                } else {
                    return false
                }
            }
            self.init(title: text, titleWhenForwarded: nil, action: .setupPoll(isQuiz: isQuiz), style: keyboardButtonRequestPollData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonUserProfile(keyboardButtonUserProfileData):
            let (text, userId) = (keyboardButtonUserProfileData.text, keyboardButtonUserProfileData.userId)
            self.init(title: text, titleWhenForwarded: nil, action: .openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))), style: keyboardButtonUserProfileData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .inputKeyboardButtonUserProfile(inputKeyboardButtonUserProfileData):
            let text = inputKeyboardButtonUserProfileData.text
            self.init(title: text, titleWhenForwarded: nil, action: .openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0))), style: inputKeyboardButtonUserProfileData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonWebView(keyboardButtonWebViewData):
            let (text, url) = (keyboardButtonWebViewData.text, keyboardButtonWebViewData.url)
            self.init(title: text, titleWhenForwarded: nil, action: .openWebView(url: url, simple: false), style: keyboardButtonWebViewData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonSimpleWebView(keyboardButtonSimpleWebViewData):
            let (text, url) = (keyboardButtonSimpleWebViewData.text, keyboardButtonSimpleWebViewData.url)
            self.init(title: text, titleWhenForwarded: nil, action: .openWebView(url: url, simple: true), style: keyboardButtonSimpleWebViewData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonRequestPeer(keyboardButtonRequestPeerData):
            let (text, buttonId, peerType, maxQuantity) = (keyboardButtonRequestPeerData.text, keyboardButtonRequestPeerData.buttonId, keyboardButtonRequestPeerData.peerType, keyboardButtonRequestPeerData.maxQuantity)
            let mappedPeerType: ReplyMarkupButtonRequestPeerType
            switch peerType {
            case let .requestPeerTypeUser(requestPeerTypeUserData):
                let (bot, premium) = (requestPeerTypeUserData.bot, requestPeerTypeUserData.premium)
                mappedPeerType = .user(ReplyMarkupButtonRequestPeerType.User(
                    isBot: bot.flatMap({ $0 == .boolTrue }),
                    isPremium: premium.flatMap({ $0 == .boolTrue })
                ))
            case let .requestPeerTypeChat(requestPeerTypeChatData):
                let (flags, hasUsername, forum, userAdminRights, botAdminRights) = (requestPeerTypeChatData.flags, requestPeerTypeChatData.hasUsername, requestPeerTypeChatData.forum, requestPeerTypeChatData.userAdminRights, requestPeerTypeChatData.botAdminRights)
                mappedPeerType = .group(ReplyMarkupButtonRequestPeerType.Group(
                    isCreator: (flags & (1 << 0)) != 0,
                    hasUsername: hasUsername.flatMap({ $0 == .boolTrue }),
                    isForum: forum.flatMap({ $0 == .boolTrue }),
                    botParticipant: (flags & (1 << 5)) != 0,
                    userAdminRights: userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                    botAdminRights: botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
                ))
            case let .requestPeerTypeBroadcast(requestPeerTypeBroadcastData):
                let (flags, hasUsername, userAdminRights, botAdminRights) = (requestPeerTypeBroadcastData.flags, requestPeerTypeBroadcastData.hasUsername, requestPeerTypeBroadcastData.userAdminRights, requestPeerTypeBroadcastData.botAdminRights)
                mappedPeerType = .channel(ReplyMarkupButtonRequestPeerType.Channel(
                    isCreator: (flags & (1 << 0)) != 0,
                    hasUsername: hasUsername.flatMap({ $0 == .boolTrue }),
                    userAdminRights: userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                    botAdminRights: botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
                ))
            }
            self.init(title: text, titleWhenForwarded: nil, action: .requestPeer(peerType: mappedPeerType, buttonId: buttonId, maxQuantity: maxQuantity), style: keyboardButtonRequestPeerData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .inputKeyboardButtonRequestPeer(inputKeyboardButtonRequestPeerData):
            let (text, buttonId, peerType, maxQuantity) = (inputKeyboardButtonRequestPeerData.text, inputKeyboardButtonRequestPeerData.buttonId, inputKeyboardButtonRequestPeerData.peerType, inputKeyboardButtonRequestPeerData.maxQuantity)
            let mappedPeerType: ReplyMarkupButtonRequestPeerType
            switch peerType {
            case let .requestPeerTypeUser(requestPeerTypeUserData):
                let (bot, premium) = (requestPeerTypeUserData.bot, requestPeerTypeUserData.premium)
                mappedPeerType = .user(ReplyMarkupButtonRequestPeerType.User(
                    isBot: bot.flatMap({ $0 == .boolTrue }),
                    isPremium: premium.flatMap({ $0 == .boolTrue })
                ))
            case let .requestPeerTypeChat(requestPeerTypeChatData):
                let (flags, hasUsername, forum, userAdminRights, botAdminRights) = (requestPeerTypeChatData.flags, requestPeerTypeChatData.hasUsername, requestPeerTypeChatData.forum, requestPeerTypeChatData.userAdminRights, requestPeerTypeChatData.botAdminRights)
                mappedPeerType = .group(ReplyMarkupButtonRequestPeerType.Group(
                    isCreator: (flags & (1 << 0)) != 0,
                    hasUsername: hasUsername.flatMap({ $0 == .boolTrue }),
                    isForum: forum.flatMap({ $0 == .boolTrue }),
                    botParticipant: (flags & (1 << 5)) != 0,
                    userAdminRights: userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                    botAdminRights: botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
                ))
            case let .requestPeerTypeBroadcast(requestPeerTypeBroadcastData):
                let (flags, hasUsername, userAdminRights, botAdminRights) = (requestPeerTypeBroadcastData.flags, requestPeerTypeBroadcastData.hasUsername, requestPeerTypeBroadcastData.userAdminRights, requestPeerTypeBroadcastData.botAdminRights)
                mappedPeerType = .channel(ReplyMarkupButtonRequestPeerType.Channel(
                    isCreator: (flags & (1 << 0)) != 0,
                    hasUsername: hasUsername.flatMap({ $0 == .boolTrue }),
                    userAdminRights: userAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:)),
                    botAdminRights: botAdminRights.flatMap(TelegramChatAdminRights.init(apiAdminRights:))
                ))
            }
            self.init(title: text, titleWhenForwarded: nil, action: .requestPeer(peerType: mappedPeerType, buttonId: buttonId, maxQuantity: maxQuantity), style: inputKeyboardButtonRequestPeerData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
        case let .keyboardButtonCopy(keyboardButtonCopyData):
            let (text, payload) = (keyboardButtonCopyData.text, keyboardButtonCopyData.copyText)
            self.init(title: text, titleWhenForwarded: nil, action: .copyText(payload: payload), style: keyboardButtonCopyData.style.flatMap(ReplyMarkupButton.Style.init(apiStyle:)))
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
                placeholder = apiPlaceholder
            case let .replyInlineMarkup(replyInlineMarkupData):
                let apiRows = replyInlineMarkupData.rows
                rows = apiRows.map { ReplyMarkupRow(apiRow: $0) }
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
