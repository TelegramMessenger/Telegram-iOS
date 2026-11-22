//
//  InternalLinkType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an internal https://t.me or tg: link, which must be processed by the application in a special way
/// This Swift enum is recursive.
public indirect enum InternalLinkType: Codable, Equatable, Hashable {

    /// The link is a link to an attachment menu bot to be opened in the specified or a chosen chat. Process given target_chat to open the chat. Then, call searchPublicChat with the given bot username, check that the user is a bot and can be added to attachment menu. Then, use getAttachmentMenuBot to receive information about the bot. If the bot isn't added to attachment menu, then show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu. If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot. If the attachment menu bot can't be used in the opened chat, show an error to the user. If the bot is added to attachment menu and can be used in the chat, then use openWebApp with the given URL
    case internalLinkTypeAttachmentMenuBot(InternalLinkTypeAttachmentMenuBot)

    /// The link contains an authentication code. Call checkAuthenticationCode with the code if the current authorization state is authorizationStateWaitCode
    case internalLinkTypeAuthenticationCode(InternalLinkTypeAuthenticationCode)

    /// The link is a link to a background. Call searchBackground with the given background name to process the link. If background is found and the user wants to apply it, then call setDefaultBackground
    case internalLinkTypeBackground(InternalLinkTypeBackground)

    /// The link is a link to a Telegram bot, which is expected to be added to a channel chat as an administrator. Call searchPublicChat with the given bot username and check that the user is a bot, ask the current user to select a channel chat to add the bot to as an administrator. Then, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator, check that the current user can edit its administrator rights and combine received rights with the requested administrator rights. Then, show confirmation box to the user, and call setChatMemberStatus with the chosen chat and confirmed rights
    case internalLinkTypeBotAddToChannel(InternalLinkTypeBotAddToChannel)

    /// The link is a link to a chat with a Telegram bot. Call searchPublicChat with the given bot username, check that the user is a bot, show START button in the chat with the bot, and then call sendBotStartMessage with the given start parameter after the button is pressed
    case internalLinkTypeBotStart(InternalLinkTypeBotStart)

    /// The link is a link to a Telegram bot, which is expected to be added to a group chat. Call searchPublicChat with the given bot username, check that the user is a bot and can be added to groups, ask the current user to select a basic group or a supergroup chat to add the bot to, taking into account that bots can be added to a public supergroup only by administrators of the supergroup. If administrator rights are provided by the link, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator, check that the current user can edit its administrator rights, combine received rights with the requested administrator rights, show confirmation box to the user, and call setChatMemberStatus with the chosen chat and confirmed administrator rights. Before call to setChatMemberStatus it may be required to upgrade the chosen basic group chat to a supergroup chat. Then, if start_parameter isn't empty, call sendBotStartMessage with the given start parameter and the chosen chat; otherwise, just send /start message with bot's username added to the chat
    case internalLinkTypeBotStartInGroup(InternalLinkTypeBotStartInGroup)

    /// The link is a link to a business chat. Use getBusinessChatLinkInfo with the provided link name to get information about the link, then open received private chat and replace chat draft with the provided text
    case internalLinkTypeBusinessChat(InternalLinkTypeBusinessChat)

    /// The link is a link to the Call tab or page
    case internalLinkTypeCallsPage(InternalLinkTypeCallsPage)

    /// The link is an affiliate program link. Call searchChatAffiliateProgram with the given username and referrer to process the link
    case internalLinkTypeChatAffiliateProgram(InternalLinkTypeChatAffiliateProgram)

    /// The link is a link to boost a Telegram chat. Call getChatBoostLinkInfo with the given URL to process the link. If the chat is found, then call getChatBoostStatus and getAvailableChatBoostSlots to get the current boost status and check whether the chat can be boosted. If the user wants to boost the chat and the chat can be boosted, then call boostChat
    case internalLinkTypeChatBoost(InternalLinkTypeChatBoost)

    /// The link is an invite link to a chat folder. Call checkChatFolderInviteLink with the given invite link to process the link. If the link is valid and the user wants to join the chat folder, then call addChatFolderByInviteLink
    case internalLinkTypeChatFolderInvite(InternalLinkTypeChatFolderInvite)

    /// The link is a chat invite link. Call checkChatInviteLink with the given invite link to process the link. If the link is valid and the user wants to join the chat, then call joinChatByInviteLink
    case internalLinkTypeChatInvite(InternalLinkTypeChatInvite)

    /// The link is a link that allows to select some chats
    case internalLinkTypeChatSelection

    /// The link is a link to the Contacts tab or page
    case internalLinkTypeContactsPage(InternalLinkTypeContactsPage)

    /// The link is a link to a channel direct messages chat by username of the channel. Call searchPublicChat with the given chat username to process the link. If the chat is found and is channel, open the direct messages chat of the channel
    case internalLinkTypeDirectMessagesChat(InternalLinkTypeDirectMessagesChat)

    /// The link is a link to a game. Call searchPublicChat with the given bot username, check that the user is a bot, ask the current user to select a chat to send the game, and then call sendMessage with inputMessageGame
    case internalLinkTypeGame(InternalLinkTypeGame)

    /// The link is a link to a gift auction. Call getGiftAuctionState with the given auction identifier to process the link
    case internalLinkTypeGiftAuction(InternalLinkTypeGiftAuction)

    /// The link is a link to a gift collection. Call searchPublicChat with the given username, then call getReceivedGifts with the received gift owner identifier and the given collection identifier, then show the collection if received
    case internalLinkTypeGiftCollection(InternalLinkTypeGiftCollection)

    /// The link is a link to a group call that isn't bound to a chat. Use getGroupCallParticipants to get the list of group call participants and show them on the join group call screen. Call joinGroupCall with the given invite_link to join the call
    case internalLinkTypeGroupCall(InternalLinkTypeGroupCall)

    /// The link must be opened in an Instant View. Call getWebPageInstantView with the given URL to process the link. If Instant View is found, then show it, otherwise, open the fallback URL in an external browser
    case internalLinkTypeInstantView(InternalLinkTypeInstantView)

    /// The link is a link to an invoice. Call getPaymentForm with the given invoice name to process the link
    case internalLinkTypeInvoice(InternalLinkTypeInvoice)

    /// The link is a link to a language pack. Call getLanguagePackInfo with the given language pack identifier to process the link. If the language pack is found and the user wants to apply it, then call setOption for the option "language_pack_id"
    case internalLinkTypeLanguagePack(InternalLinkTypeLanguagePack)

    /// The link is a link to a live story. Call searchPublicChat with the given chat username, then getChatActiveStories to get active stories in the chat, then find a live story among active stories of the chat, and then joinLiveStory to join the live story
    case internalLinkTypeLiveStory(InternalLinkTypeLiveStory)

    /// The link is a link to the main Web App of a bot. Call searchPublicChat with the given bot username, check that the user is a bot and has the main Web App. If the bot can be added to attachment menu, then use getAttachmentMenuBot to receive information about the bot, then if the bot isn't added to side menu, show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu, then if the user accepts the terms and confirms adding, use toggleBotIsAddedToAttachmentMenu to add the bot. Then, use getMainWebApp with the given start parameter and mode and open the returned URL as a Web App
    case internalLinkTypeMainWebApp(InternalLinkTypeMainWebApp)

    /// The link is a link to a Telegram message or a forum topic. Call getMessageLinkInfo with the given URL to process the link, and then open received forum topic or chat and show the message there
    case internalLinkTypeMessage(InternalLinkTypeMessage)

    /// The link contains a message draft text. A share screen needs to be shown to the user, then the chosen chat must be opened and the text is added to the input field
    case internalLinkTypeMessageDraft(InternalLinkTypeMessageDraft)

    /// The link is a link to the My Profile application page
    case internalLinkTypeMyProfilePage(InternalLinkTypeMyProfilePage)

    /// The link is a link to the screen for creating a new channel chat
    case internalLinkTypeNewChannelChat

    /// The link is a link to the screen for creating a new group chat
    case internalLinkTypeNewGroupChat

    /// The link is a link to the screen for creating a new private chat with a contact
    case internalLinkTypeNewPrivateChat

    /// The link is a link to open the story posting interface
    case internalLinkTypeNewStory(InternalLinkTypeNewStory)

    /// The link is an OAuth link. Call getOauthLinkInfo with the given URL to process the link if the link was received from outside of the application; otherwise, ignore it. After getOauthLinkInfo, show the user confirmation dialog and process it with checkOauthRequestMatchCode, acceptOauthRequest or declineOauthRequest
    case internalLinkTypeOauth(InternalLinkTypeOauth)

    /// The link contains a request of Telegram passport data. Call getPassportAuthorizationForm with the given parameters to process the link if the link was received from outside of the application; otherwise, ignore it
    case internalLinkTypePassportDataRequest(InternalLinkTypePassportDataRequest)

    /// The link can be used to confirm ownership of a phone number to prevent account deletion. Call sendPhoneNumberCode with the given phone number and with phoneNumberCodeTypeConfirmOwnership with the given hash to process the link. If succeeded, call checkPhoneNumberCode to check entered by the user code, or resendPhoneNumberCode to resend it
    case internalLinkTypePhoneNumberConfirmation(InternalLinkTypePhoneNumberConfirmation)

    /// The link is a link to the Premium features screen of the application from which the user can subscribe to Telegram Premium. Call getPremiumFeatures with the given referrer to process the link
    case internalLinkTypePremiumFeaturesPage(InternalLinkTypePremiumFeaturesPage)

    /// The link is a link with a Telegram Premium gift code. Call checkPremiumGiftCode with the given code to process the link. If the code is valid and the user wants to apply it, then call applyPremiumGiftCode
    case internalLinkTypePremiumGiftCode(InternalLinkTypePremiumGiftCode)

    /// The link is a link to the screen for gifting Telegram Premium subscriptions to friends via inputInvoiceTelegram with telegramPaymentPurposePremiumGift payments or in-store purchases
    case internalLinkTypePremiumGiftPurchase(InternalLinkTypePremiumGiftPurchase)

    /// The link is a link to a proxy. Call addProxy with the given parameters to process the link and add the proxy
    case internalLinkTypeProxy(InternalLinkTypeProxy)

    /// The link is a link to a chat by its username. Call searchPublicChat with the given chat username to process the link. If the chat is found, open its profile information screen or the chat itself. If draft text isn't empty and the chat is a private chat with a regular user, then put the draft text in the input field
    case internalLinkTypePublicChat(InternalLinkTypePublicChat)

    /// The link can be used to login the current user on another device, but it must be scanned from QR-code using in-app camera. An alert similar to "This code can be used to allow someone to log in to your Telegram account. To confirm Telegram login, please go to Settings > Devices > Scan QR and scan the code" needs to be shown
    case internalLinkTypeQrCodeAuthentication

    /// The link is a link to a dialog for creating of a managed bot. Call searchPublicChat with the given manager bot username. If the chat is found, the chat is a chat with a bot and the bot has can_manage_bots == true, then show bot creation confirmation dialog with the given suggested_bot_username and suggested_bot_name. If user agrees, call createBot with via_link == true to create the bot
    case internalLinkTypeRequestManagedBot(InternalLinkTypeRequestManagedBot)

    /// The link forces restore of App Store purchases when opened. For official iOS application only
    case internalLinkTypeRestorePurchases

    /// The link is a link to the Saved Messages chat. Call createPrivateChat with getOption("my_id") and open the chat
    case internalLinkTypeSavedMessages

    /// The link is a link to the global chat and messages search field
    case internalLinkTypeSearch

    /// The link is a link to application settings
    case internalLinkTypeSettings(InternalLinkTypeSettings)

    /// The link is a link to the Telegram Star purchase section of the application
    case internalLinkTypeStarPurchase(InternalLinkTypeStarPurchase)

    /// The link is a link to a sticker set. Call searchStickerSet with the given sticker set name to process the link and show the sticker set. If the sticker set is found and the user wants to add it, then call changeStickerSet
    case internalLinkTypeStickerSet(InternalLinkTypeStickerSet)

    /// The link is a link to a story. Call searchPublicChat with the given poster username, then call getStory with the received chat identifier and the given story identifier, then show the story if received
    case internalLinkTypeStory(InternalLinkTypeStory)

    /// The link is a link to an album of stories. Call searchPublicChat with the given username, then call getStoryAlbumStories with the received chat identifier and the given story album identifier, then show the story album if received
    case internalLinkTypeStoryAlbum(InternalLinkTypeStoryAlbum)

    /// The link is a link to a text composition style. Call searchTextCompositionStyle with the given style name to get information about the style. If the style is found and the user wants to add it, then call addTextCompositionStyle
    case internalLinkTypeTextCompositionStyle(InternalLinkTypeTextCompositionStyle)

    /// The link is a link to a cloud theme. TDLib has no theme support yet
    case internalLinkTypeTheme(InternalLinkTypeTheme)

    /// The link is an unknown tg: link. Call getDeepLinkInfo to process the link
    case internalLinkTypeUnknownDeepLink(InternalLinkTypeUnknownDeepLink)

    /// The link is a link to an upgraded gift. Call getUpgradedGift with the given name to process the link
    case internalLinkTypeUpgradedGift(InternalLinkTypeUpgradedGift)

    /// The link is a link to a user by its phone number. Call searchUserByPhoneNumber with the given phone number to process the link. If the user is found, then call createPrivateChat and open user's profile information screen or the chat itself. If draft text isn't empty, then put the draft text in the input field
    case internalLinkTypeUserPhoneNumber(InternalLinkTypeUserPhoneNumber)

    /// The link is a link to a user by a temporary token. Call searchUserByToken with the given token to process the link. If the user is found, then call createPrivateChat and open the chat
    case internalLinkTypeUserToken(InternalLinkTypeUserToken)

    /// The link is a link to a video chat. Call searchPublicChat with the given chat username, and then joinVideoChat with the given invite hash to process the link
    case internalLinkTypeVideoChat(InternalLinkTypeVideoChat)

    /// The link is a link to a Web App. Call searchPublicChat with the given bot username, check that the user is a bot. If the bot is restricted for the current user, then show an error message. Otherwise, call searchWebApp with the received bot and the given web_app_short_name. Process received foundWebApp by showing a confirmation dialog if needed. If the bot can be added to attachment or side menu, but isn't added yet, then show a disclaimer about Mini Apps being third-party applications instead of the dialog and ask the user to accept their Terms of service. If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot. Then, call getWebAppLinkUrl and open the returned URL as a Web App
    case internalLinkTypeWebApp(InternalLinkTypeWebApp)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case internalLinkTypeAttachmentMenuBot
        case internalLinkTypeAuthenticationCode
        case internalLinkTypeBackground
        case internalLinkTypeBotAddToChannel
        case internalLinkTypeBotStart
        case internalLinkTypeBotStartInGroup
        case internalLinkTypeBusinessChat
        case internalLinkTypeCallsPage
        case internalLinkTypeChatAffiliateProgram
        case internalLinkTypeChatBoost
        case internalLinkTypeChatFolderInvite
        case internalLinkTypeChatInvite
        case internalLinkTypeChatSelection
        case internalLinkTypeContactsPage
        case internalLinkTypeDirectMessagesChat
        case internalLinkTypeGame
        case internalLinkTypeGiftAuction
        case internalLinkTypeGiftCollection
        case internalLinkTypeGroupCall
        case internalLinkTypeInstantView
        case internalLinkTypeInvoice
        case internalLinkTypeLanguagePack
        case internalLinkTypeLiveStory
        case internalLinkTypeMainWebApp
        case internalLinkTypeMessage
        case internalLinkTypeMessageDraft
        case internalLinkTypeMyProfilePage
        case internalLinkTypeNewChannelChat
        case internalLinkTypeNewGroupChat
        case internalLinkTypeNewPrivateChat
        case internalLinkTypeNewStory
        case internalLinkTypeOauth
        case internalLinkTypePassportDataRequest
        case internalLinkTypePhoneNumberConfirmation
        case internalLinkTypePremiumFeaturesPage
        case internalLinkTypePremiumGiftCode
        case internalLinkTypePremiumGiftPurchase
        case internalLinkTypeProxy
        case internalLinkTypePublicChat
        case internalLinkTypeQrCodeAuthentication
        case internalLinkTypeRequestManagedBot
        case internalLinkTypeRestorePurchases
        case internalLinkTypeSavedMessages
        case internalLinkTypeSearch
        case internalLinkTypeSettings
        case internalLinkTypeStarPurchase
        case internalLinkTypeStickerSet
        case internalLinkTypeStory
        case internalLinkTypeStoryAlbum
        case internalLinkTypeTextCompositionStyle
        case internalLinkTypeTheme
        case internalLinkTypeUnknownDeepLink
        case internalLinkTypeUpgradedGift
        case internalLinkTypeUserPhoneNumber
        case internalLinkTypeUserToken
        case internalLinkTypeVideoChat
        case internalLinkTypeWebApp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .internalLinkTypeAttachmentMenuBot:
            let value = try InternalLinkTypeAttachmentMenuBot(from: decoder)
            self = .internalLinkTypeAttachmentMenuBot(value)
        case .internalLinkTypeAuthenticationCode:
            let value = try InternalLinkTypeAuthenticationCode(from: decoder)
            self = .internalLinkTypeAuthenticationCode(value)
        case .internalLinkTypeBackground:
            let value = try InternalLinkTypeBackground(from: decoder)
            self = .internalLinkTypeBackground(value)
        case .internalLinkTypeBotAddToChannel:
            let value = try InternalLinkTypeBotAddToChannel(from: decoder)
            self = .internalLinkTypeBotAddToChannel(value)
        case .internalLinkTypeBotStart:
            let value = try InternalLinkTypeBotStart(from: decoder)
            self = .internalLinkTypeBotStart(value)
        case .internalLinkTypeBotStartInGroup:
            let value = try InternalLinkTypeBotStartInGroup(from: decoder)
            self = .internalLinkTypeBotStartInGroup(value)
        case .internalLinkTypeBusinessChat:
            let value = try InternalLinkTypeBusinessChat(from: decoder)
            self = .internalLinkTypeBusinessChat(value)
        case .internalLinkTypeCallsPage:
            let value = try InternalLinkTypeCallsPage(from: decoder)
            self = .internalLinkTypeCallsPage(value)
        case .internalLinkTypeChatAffiliateProgram:
            let value = try InternalLinkTypeChatAffiliateProgram(from: decoder)
            self = .internalLinkTypeChatAffiliateProgram(value)
        case .internalLinkTypeChatBoost:
            let value = try InternalLinkTypeChatBoost(from: decoder)
            self = .internalLinkTypeChatBoost(value)
        case .internalLinkTypeChatFolderInvite:
            let value = try InternalLinkTypeChatFolderInvite(from: decoder)
            self = .internalLinkTypeChatFolderInvite(value)
        case .internalLinkTypeChatInvite:
            let value = try InternalLinkTypeChatInvite(from: decoder)
            self = .internalLinkTypeChatInvite(value)
        case .internalLinkTypeChatSelection:
            self = .internalLinkTypeChatSelection
        case .internalLinkTypeContactsPage:
            let value = try InternalLinkTypeContactsPage(from: decoder)
            self = .internalLinkTypeContactsPage(value)
        case .internalLinkTypeDirectMessagesChat:
            let value = try InternalLinkTypeDirectMessagesChat(from: decoder)
            self = .internalLinkTypeDirectMessagesChat(value)
        case .internalLinkTypeGame:
            let value = try InternalLinkTypeGame(from: decoder)
            self = .internalLinkTypeGame(value)
        case .internalLinkTypeGiftAuction:
            let value = try InternalLinkTypeGiftAuction(from: decoder)
            self = .internalLinkTypeGiftAuction(value)
        case .internalLinkTypeGiftCollection:
            let value = try InternalLinkTypeGiftCollection(from: decoder)
            self = .internalLinkTypeGiftCollection(value)
        case .internalLinkTypeGroupCall:
            let value = try InternalLinkTypeGroupCall(from: decoder)
            self = .internalLinkTypeGroupCall(value)
        case .internalLinkTypeInstantView:
            let value = try InternalLinkTypeInstantView(from: decoder)
            self = .internalLinkTypeInstantView(value)
        case .internalLinkTypeInvoice:
            let value = try InternalLinkTypeInvoice(from: decoder)
            self = .internalLinkTypeInvoice(value)
        case .internalLinkTypeLanguagePack:
            let value = try InternalLinkTypeLanguagePack(from: decoder)
            self = .internalLinkTypeLanguagePack(value)
        case .internalLinkTypeLiveStory:
            let value = try InternalLinkTypeLiveStory(from: decoder)
            self = .internalLinkTypeLiveStory(value)
        case .internalLinkTypeMainWebApp:
            let value = try InternalLinkTypeMainWebApp(from: decoder)
            self = .internalLinkTypeMainWebApp(value)
        case .internalLinkTypeMessage:
            let value = try InternalLinkTypeMessage(from: decoder)
            self = .internalLinkTypeMessage(value)
        case .internalLinkTypeMessageDraft:
            let value = try InternalLinkTypeMessageDraft(from: decoder)
            self = .internalLinkTypeMessageDraft(value)
        case .internalLinkTypeMyProfilePage:
            let value = try InternalLinkTypeMyProfilePage(from: decoder)
            self = .internalLinkTypeMyProfilePage(value)
        case .internalLinkTypeNewChannelChat:
            self = .internalLinkTypeNewChannelChat
        case .internalLinkTypeNewGroupChat:
            self = .internalLinkTypeNewGroupChat
        case .internalLinkTypeNewPrivateChat:
            self = .internalLinkTypeNewPrivateChat
        case .internalLinkTypeNewStory:
            let value = try InternalLinkTypeNewStory(from: decoder)
            self = .internalLinkTypeNewStory(value)
        case .internalLinkTypeOauth:
            let value = try InternalLinkTypeOauth(from: decoder)
            self = .internalLinkTypeOauth(value)
        case .internalLinkTypePassportDataRequest:
            let value = try InternalLinkTypePassportDataRequest(from: decoder)
            self = .internalLinkTypePassportDataRequest(value)
        case .internalLinkTypePhoneNumberConfirmation:
            let value = try InternalLinkTypePhoneNumberConfirmation(from: decoder)
            self = .internalLinkTypePhoneNumberConfirmation(value)
        case .internalLinkTypePremiumFeaturesPage:
            let value = try InternalLinkTypePremiumFeaturesPage(from: decoder)
            self = .internalLinkTypePremiumFeaturesPage(value)
        case .internalLinkTypePremiumGiftCode:
            let value = try InternalLinkTypePremiumGiftCode(from: decoder)
            self = .internalLinkTypePremiumGiftCode(value)
        case .internalLinkTypePremiumGiftPurchase:
            let value = try InternalLinkTypePremiumGiftPurchase(from: decoder)
            self = .internalLinkTypePremiumGiftPurchase(value)
        case .internalLinkTypeProxy:
            let value = try InternalLinkTypeProxy(from: decoder)
            self = .internalLinkTypeProxy(value)
        case .internalLinkTypePublicChat:
            let value = try InternalLinkTypePublicChat(from: decoder)
            self = .internalLinkTypePublicChat(value)
        case .internalLinkTypeQrCodeAuthentication:
            self = .internalLinkTypeQrCodeAuthentication
        case .internalLinkTypeRequestManagedBot:
            let value = try InternalLinkTypeRequestManagedBot(from: decoder)
            self = .internalLinkTypeRequestManagedBot(value)
        case .internalLinkTypeRestorePurchases:
            self = .internalLinkTypeRestorePurchases
        case .internalLinkTypeSavedMessages:
            self = .internalLinkTypeSavedMessages
        case .internalLinkTypeSearch:
            self = .internalLinkTypeSearch
        case .internalLinkTypeSettings:
            let value = try InternalLinkTypeSettings(from: decoder)
            self = .internalLinkTypeSettings(value)
        case .internalLinkTypeStarPurchase:
            let value = try InternalLinkTypeStarPurchase(from: decoder)
            self = .internalLinkTypeStarPurchase(value)
        case .internalLinkTypeStickerSet:
            let value = try InternalLinkTypeStickerSet(from: decoder)
            self = .internalLinkTypeStickerSet(value)
        case .internalLinkTypeStory:
            let value = try InternalLinkTypeStory(from: decoder)
            self = .internalLinkTypeStory(value)
        case .internalLinkTypeStoryAlbum:
            let value = try InternalLinkTypeStoryAlbum(from: decoder)
            self = .internalLinkTypeStoryAlbum(value)
        case .internalLinkTypeTextCompositionStyle:
            let value = try InternalLinkTypeTextCompositionStyle(from: decoder)
            self = .internalLinkTypeTextCompositionStyle(value)
        case .internalLinkTypeTheme:
            let value = try InternalLinkTypeTheme(from: decoder)
            self = .internalLinkTypeTheme(value)
        case .internalLinkTypeUnknownDeepLink:
            let value = try InternalLinkTypeUnknownDeepLink(from: decoder)
            self = .internalLinkTypeUnknownDeepLink(value)
        case .internalLinkTypeUpgradedGift:
            let value = try InternalLinkTypeUpgradedGift(from: decoder)
            self = .internalLinkTypeUpgradedGift(value)
        case .internalLinkTypeUserPhoneNumber:
            let value = try InternalLinkTypeUserPhoneNumber(from: decoder)
            self = .internalLinkTypeUserPhoneNumber(value)
        case .internalLinkTypeUserToken:
            let value = try InternalLinkTypeUserToken(from: decoder)
            self = .internalLinkTypeUserToken(value)
        case .internalLinkTypeVideoChat:
            let value = try InternalLinkTypeVideoChat(from: decoder)
            self = .internalLinkTypeVideoChat(value)
        case .internalLinkTypeWebApp:
            let value = try InternalLinkTypeWebApp(from: decoder)
            self = .internalLinkTypeWebApp(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .internalLinkTypeAttachmentMenuBot(let value):
            try container.encode(Kind.internalLinkTypeAttachmentMenuBot, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeAuthenticationCode(let value):
            try container.encode(Kind.internalLinkTypeAuthenticationCode, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeBackground(let value):
            try container.encode(Kind.internalLinkTypeBackground, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeBotAddToChannel(let value):
            try container.encode(Kind.internalLinkTypeBotAddToChannel, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeBotStart(let value):
            try container.encode(Kind.internalLinkTypeBotStart, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeBotStartInGroup(let value):
            try container.encode(Kind.internalLinkTypeBotStartInGroup, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeBusinessChat(let value):
            try container.encode(Kind.internalLinkTypeBusinessChat, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeCallsPage(let value):
            try container.encode(Kind.internalLinkTypeCallsPage, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeChatAffiliateProgram(let value):
            try container.encode(Kind.internalLinkTypeChatAffiliateProgram, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeChatBoost(let value):
            try container.encode(Kind.internalLinkTypeChatBoost, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeChatFolderInvite(let value):
            try container.encode(Kind.internalLinkTypeChatFolderInvite, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeChatInvite(let value):
            try container.encode(Kind.internalLinkTypeChatInvite, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeChatSelection:
            try container.encode(Kind.internalLinkTypeChatSelection, forKey: .type)
        case .internalLinkTypeContactsPage(let value):
            try container.encode(Kind.internalLinkTypeContactsPage, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeDirectMessagesChat(let value):
            try container.encode(Kind.internalLinkTypeDirectMessagesChat, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeGame(let value):
            try container.encode(Kind.internalLinkTypeGame, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeGiftAuction(let value):
            try container.encode(Kind.internalLinkTypeGiftAuction, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeGiftCollection(let value):
            try container.encode(Kind.internalLinkTypeGiftCollection, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeGroupCall(let value):
            try container.encode(Kind.internalLinkTypeGroupCall, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeInstantView(let value):
            try container.encode(Kind.internalLinkTypeInstantView, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeInvoice(let value):
            try container.encode(Kind.internalLinkTypeInvoice, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeLanguagePack(let value):
            try container.encode(Kind.internalLinkTypeLanguagePack, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeLiveStory(let value):
            try container.encode(Kind.internalLinkTypeLiveStory, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeMainWebApp(let value):
            try container.encode(Kind.internalLinkTypeMainWebApp, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeMessage(let value):
            try container.encode(Kind.internalLinkTypeMessage, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeMessageDraft(let value):
            try container.encode(Kind.internalLinkTypeMessageDraft, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeMyProfilePage(let value):
            try container.encode(Kind.internalLinkTypeMyProfilePage, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeNewChannelChat:
            try container.encode(Kind.internalLinkTypeNewChannelChat, forKey: .type)
        case .internalLinkTypeNewGroupChat:
            try container.encode(Kind.internalLinkTypeNewGroupChat, forKey: .type)
        case .internalLinkTypeNewPrivateChat:
            try container.encode(Kind.internalLinkTypeNewPrivateChat, forKey: .type)
        case .internalLinkTypeNewStory(let value):
            try container.encode(Kind.internalLinkTypeNewStory, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeOauth(let value):
            try container.encode(Kind.internalLinkTypeOauth, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePassportDataRequest(let value):
            try container.encode(Kind.internalLinkTypePassportDataRequest, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePhoneNumberConfirmation(let value):
            try container.encode(Kind.internalLinkTypePhoneNumberConfirmation, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePremiumFeaturesPage(let value):
            try container.encode(Kind.internalLinkTypePremiumFeaturesPage, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePremiumGiftCode(let value):
            try container.encode(Kind.internalLinkTypePremiumGiftCode, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePremiumGiftPurchase(let value):
            try container.encode(Kind.internalLinkTypePremiumGiftPurchase, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeProxy(let value):
            try container.encode(Kind.internalLinkTypeProxy, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypePublicChat(let value):
            try container.encode(Kind.internalLinkTypePublicChat, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeQrCodeAuthentication:
            try container.encode(Kind.internalLinkTypeQrCodeAuthentication, forKey: .type)
        case .internalLinkTypeRequestManagedBot(let value):
            try container.encode(Kind.internalLinkTypeRequestManagedBot, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeRestorePurchases:
            try container.encode(Kind.internalLinkTypeRestorePurchases, forKey: .type)
        case .internalLinkTypeSavedMessages:
            try container.encode(Kind.internalLinkTypeSavedMessages, forKey: .type)
        case .internalLinkTypeSearch:
            try container.encode(Kind.internalLinkTypeSearch, forKey: .type)
        case .internalLinkTypeSettings(let value):
            try container.encode(Kind.internalLinkTypeSettings, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeStarPurchase(let value):
            try container.encode(Kind.internalLinkTypeStarPurchase, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeStickerSet(let value):
            try container.encode(Kind.internalLinkTypeStickerSet, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeStory(let value):
            try container.encode(Kind.internalLinkTypeStory, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeStoryAlbum(let value):
            try container.encode(Kind.internalLinkTypeStoryAlbum, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeTextCompositionStyle(let value):
            try container.encode(Kind.internalLinkTypeTextCompositionStyle, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeTheme(let value):
            try container.encode(Kind.internalLinkTypeTheme, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeUnknownDeepLink(let value):
            try container.encode(Kind.internalLinkTypeUnknownDeepLink, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeUpgradedGift(let value):
            try container.encode(Kind.internalLinkTypeUpgradedGift, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeUserPhoneNumber(let value):
            try container.encode(Kind.internalLinkTypeUserPhoneNumber, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeUserToken(let value):
            try container.encode(Kind.internalLinkTypeUserToken, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeVideoChat(let value):
            try container.encode(Kind.internalLinkTypeVideoChat, forKey: .type)
            try value.encode(to: encoder)
        case .internalLinkTypeWebApp(let value):
            try container.encode(Kind.internalLinkTypeWebApp, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The link is a link to an attachment menu bot to be opened in the specified or a chosen chat. Process given target_chat to open the chat. Then, call searchPublicChat with the given bot username, check that the user is a bot and can be added to attachment menu. Then, use getAttachmentMenuBot to receive information about the bot. If the bot isn't added to attachment menu, then show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu. If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot. If the attachment menu bot can't be used in the opened chat, show an error to the user. If the bot is added to attachment menu and can be used in the chat, then use openWebApp with the given URL
public struct InternalLinkTypeAttachmentMenuBot: Codable, Equatable, Hashable {

    /// Username of the bot
    public let botUsername: String

    /// Target chat to be opened
    public let targetChat: TargetChat

    /// URL to be passed to openWebApp
    public let url: String


    public init(
        botUsername: String,
        targetChat: TargetChat,
        url: String
    ) {
        self.botUsername = botUsername
        self.targetChat = targetChat
        self.url = url
    }
}

/// The link contains an authentication code. Call checkAuthenticationCode with the code if the current authorization state is authorizationStateWaitCode
public struct InternalLinkTypeAuthenticationCode: Codable, Equatable, Hashable {

    /// The authentication code
    public let code: String


    public init(code: String) {
        self.code = code
    }
}

/// The link is a link to a background. Call searchBackground with the given background name to process the link. If background is found and the user wants to apply it, then call setDefaultBackground
public struct InternalLinkTypeBackground: Codable, Equatable, Hashable {

    /// Name of the background
    public let backgroundName: String


    public init(backgroundName: String) {
        self.backgroundName = backgroundName
    }
}

/// The link is a link to a Telegram bot, which is expected to be added to a channel chat as an administrator. Call searchPublicChat with the given bot username and check that the user is a bot, ask the current user to select a channel chat to add the bot to as an administrator. Then, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator, check that the current user can edit its administrator rights and combine received rights with the requested administrator rights. Then, show confirmation box to the user, and call setChatMemberStatus with the chosen chat and confirmed rights
public struct InternalLinkTypeBotAddToChannel: Codable, Equatable, Hashable {

    /// Expected administrator rights for the bot
    public let administratorRights: ChatAdministratorRights

    /// Username of the bot
    public let botUsername: String


    public init(
        administratorRights: ChatAdministratorRights,
        botUsername: String
    ) {
        self.administratorRights = administratorRights
        self.botUsername = botUsername
    }
}

/// The link is a link to a chat with a Telegram bot. Call searchPublicChat with the given bot username, check that the user is a bot, show START button in the chat with the bot, and then call sendBotStartMessage with the given start parameter after the button is pressed
public struct InternalLinkTypeBotStart: Codable, Equatable, Hashable {

    /// True, if sendBotStartMessage must be called automatically without showing the START button
    public let autostart: Bool

    /// Username of the bot
    public let botUsername: String

    /// The parameter to be passed to sendBotStartMessage
    public let startParameter: String


    public init(
        autostart: Bool,
        botUsername: String,
        startParameter: String
    ) {
        self.autostart = autostart
        self.botUsername = botUsername
        self.startParameter = startParameter
    }
}

/// The link is a link to a Telegram bot, which is expected to be added to a group chat. Call searchPublicChat with the given bot username, check that the user is a bot and can be added to groups, ask the current user to select a basic group or a supergroup chat to add the bot to, taking into account that bots can be added to a public supergroup only by administrators of the supergroup. If administrator rights are provided by the link, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator, check that the current user can edit its administrator rights, combine received rights with the requested administrator rights, show confirmation box to the user, and call setChatMemberStatus with the chosen chat and confirmed administrator rights. Before call to setChatMemberStatus it may be required to upgrade the chosen basic group chat to a supergroup chat. Then, if start_parameter isn't empty, call sendBotStartMessage with the given start parameter and the chosen chat; otherwise, just send /start message with bot's username added to the chat
public struct InternalLinkTypeBotStartInGroup: Codable, Equatable, Hashable {

    /// Expected administrator rights for the bot; may be null
    public let administratorRights: ChatAdministratorRights?

    /// Username of the bot
    public let botUsername: String

    /// The parameter to be passed to sendBotStartMessage
    public let startParameter: String


    public init(
        administratorRights: ChatAdministratorRights?,
        botUsername: String,
        startParameter: String
    ) {
        self.administratorRights = administratorRights
        self.botUsername = botUsername
        self.startParameter = startParameter
    }
}

/// The link is a link to a business chat. Use getBusinessChatLinkInfo with the provided link name to get information about the link, then open received private chat and replace chat draft with the provided text
public struct InternalLinkTypeBusinessChat: Codable, Equatable, Hashable {

    /// Name of the link
    public let linkName: String


    public init(linkName: String) {
        self.linkName = linkName
    }
}

/// The link is a link to the Call tab or page
public struct InternalLinkTypeCallsPage: Codable, Equatable, Hashable {

    /// Section of the page; may be one of "", "all", "missed", "edit", "show-tab", "start-call"
    public let section: String


    public init(section: String) {
        self.section = section
    }
}

/// The link is an affiliate program link. Call searchChatAffiliateProgram with the given username and referrer to process the link
public struct InternalLinkTypeChatAffiliateProgram: Codable, Equatable, Hashable {

    /// Referrer to be passed to searchChatAffiliateProgram
    public let referrer: String

    /// Username to be passed to searchChatAffiliateProgram
    public let username: String


    public init(
        referrer: String,
        username: String
    ) {
        self.referrer = referrer
        self.username = username
    }
}

/// The link is a link to boost a Telegram chat. Call getChatBoostLinkInfo with the given URL to process the link. If the chat is found, then call getChatBoostStatus and getAvailableChatBoostSlots to get the current boost status and check whether the chat can be boosted. If the user wants to boost the chat and the chat can be boosted, then call boostChat
public struct InternalLinkTypeChatBoost: Codable, Equatable, Hashable {

    /// URL to be passed to getChatBoostLinkInfo
    public let url: String


    public init(url: String) {
        self.url = url
    }
}

/// The link is an invite link to a chat folder. Call checkChatFolderInviteLink with the given invite link to process the link. If the link is valid and the user wants to join the chat folder, then call addChatFolderByInviteLink
public struct InternalLinkTypeChatFolderInvite: Codable, Equatable, Hashable {

    /// Internal representation of the invite link
    public let inviteLink: String


    public init(inviteLink: String) {
        self.inviteLink = inviteLink
    }
}

/// The link is a chat invite link. Call checkChatInviteLink with the given invite link to process the link. If the link is valid and the user wants to join the chat, then call joinChatByInviteLink
public struct InternalLinkTypeChatInvite: Codable, Equatable, Hashable {

    /// Internal representation of the invite link
    public let inviteLink: String


    public init(inviteLink: String) {
        self.inviteLink = inviteLink
    }
}

/// The link is a link to the Contacts tab or page
public struct InternalLinkTypeContactsPage: Codable, Equatable, Hashable {

    /// Section of the page; may be one of "", "search", "sort", "new", "invite", "manage"
    public let section: String


    public init(section: String) {
        self.section = section
    }
}

/// The link is a link to a channel direct messages chat by username of the channel. Call searchPublicChat with the given chat username to process the link. If the chat is found and is channel, open the direct messages chat of the channel
public struct InternalLinkTypeDirectMessagesChat: Codable, Equatable, Hashable {

    /// Username of the channel
    public let channelUsername: String


    public init(channelUsername: String) {
        self.channelUsername = channelUsername
    }
}

/// The link is a link to a game. Call searchPublicChat with the given bot username, check that the user is a bot, ask the current user to select a chat to send the game, and then call sendMessage with inputMessageGame
public struct InternalLinkTypeGame: Codable, Equatable, Hashable {

    /// Username of the bot that owns the game
    public let botUsername: String

    /// Short name of the game
    public let gameShortName: String


    public init(
        botUsername: String,
        gameShortName: String
    ) {
        self.botUsername = botUsername
        self.gameShortName = gameShortName
    }
}

/// The link is a link to a gift auction. Call getGiftAuctionState with the given auction identifier to process the link
public struct InternalLinkTypeGiftAuction: Codable, Equatable, Hashable {

    /// Unique identifier of the auction
    public let auctionId: String


    public init(auctionId: String) {
        self.auctionId = auctionId
    }
}

/// The link is a link to a gift collection. Call searchPublicChat with the given username, then call getReceivedGifts with the received gift owner identifier and the given collection identifier, then show the collection if received
public struct InternalLinkTypeGiftCollection: Codable, Equatable, Hashable {

    /// Gift collection identifier
    public let collectionId: Int

    /// Username of the owner of the gift collection
    public let giftOwnerUsername: String


    public init(
        collectionId: Int,
        giftOwnerUsername: String
    ) {
        self.collectionId = collectionId
        self.giftOwnerUsername = giftOwnerUsername
    }
}

/// The link is a link to a group call that isn't bound to a chat. Use getGroupCallParticipants to get the list of group call participants and show them on the join group call screen. Call joinGroupCall with the given invite_link to join the call
public struct InternalLinkTypeGroupCall: Codable, Equatable, Hashable {

    /// Internal representation of the invite link
    public let inviteLink: String


    public init(inviteLink: String) {
        self.inviteLink = inviteLink
    }
}

/// The link must be opened in an Instant View. Call getWebPageInstantView with the given URL to process the link. If Instant View is found, then show it, otherwise, open the fallback URL in an external browser
public struct InternalLinkTypeInstantView: Codable, Equatable, Hashable {

    /// An URL to open if getWebPageInstantView fails
    public let fallbackUrl: String

    /// URL to be passed to getWebPageInstantView
    public let url: String


    public init(
        fallbackUrl: String,
        url: String
    ) {
        self.fallbackUrl = fallbackUrl
        self.url = url
    }
}

/// The link is a link to an invoice. Call getPaymentForm with the given invoice name to process the link
public struct InternalLinkTypeInvoice: Codable, Equatable, Hashable {

    /// Name of the invoice
    public let invoiceName: String


    public init(invoiceName: String) {
        self.invoiceName = invoiceName
    }
}

/// The link is a link to a language pack. Call getLanguagePackInfo with the given language pack identifier to process the link. If the language pack is found and the user wants to apply it, then call setOption for the option "language_pack_id"
public struct InternalLinkTypeLanguagePack: Codable, Equatable, Hashable {

    /// Language pack identifier
    public let languagePackId: String


    public init(languagePackId: String) {
        self.languagePackId = languagePackId
    }
}

/// The link is a link to a live story. Call searchPublicChat with the given chat username, then getChatActiveStories to get active stories in the chat, then find a live story among active stories of the chat, and then joinLiveStory to join the live story
public struct InternalLinkTypeLiveStory: Codable, Equatable, Hashable {

    /// Username of the poster of the story
    public let storyPosterUsername: String


    public init(storyPosterUsername: String) {
        self.storyPosterUsername = storyPosterUsername
    }
}

/// The link is a link to the main Web App of a bot. Call searchPublicChat with the given bot username, check that the user is a bot and has the main Web App. If the bot can be added to attachment menu, then use getAttachmentMenuBot to receive information about the bot, then if the bot isn't added to side menu, show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu, then if the user accepts the terms and confirms adding, use toggleBotIsAddedToAttachmentMenu to add the bot. Then, use getMainWebApp with the given start parameter and mode and open the returned URL as a Web App
public struct InternalLinkTypeMainWebApp: Codable, Equatable, Hashable {

    /// Username of the bot
    public let botUsername: String

    /// The mode to be passed to getMainWebApp
    public let mode: WebAppOpenMode

    /// Start parameter to be passed to getMainWebApp
    public let startParameter: String


    public init(
        botUsername: String,
        mode: WebAppOpenMode,
        startParameter: String
    ) {
        self.botUsername = botUsername
        self.mode = mode
        self.startParameter = startParameter
    }
}

/// The link is a link to a Telegram message or a forum topic. Call getMessageLinkInfo with the given URL to process the link, and then open received forum topic or chat and show the message there
public struct InternalLinkTypeMessage: Codable, Equatable, Hashable {

    /// URL to be passed to getMessageLinkInfo
    public let url: String


    public init(url: String) {
        self.url = url
    }
}

/// The link contains a message draft text. A share screen needs to be shown to the user, then the chosen chat must be opened and the text is added to the input field
public struct InternalLinkTypeMessageDraft: Codable, Equatable, Hashable {

    /// True, if the first line of the text contains a link. If true, the input field needs to be focused and the text after the link must be selected
    public let containsLink: Bool

    /// Message draft text
    public let text: FormattedText


    public init(
        containsLink: Bool,
        text: FormattedText
    ) {
        self.containsLink = containsLink
        self.text = text
    }
}

/// The link is a link to the My Profile application page
public struct InternalLinkTypeMyProfilePage: Codable, Equatable, Hashable {

    /// Section of the page; may be one of "", "posts", "posts/all-stories", "posts/add-album", "gifts", "archived-posts"
    public let section: String


    public init(section: String) {
        self.section = section
    }
}

/// The link is a link to open the story posting interface
public struct InternalLinkTypeNewStory: Codable, Equatable, Hashable {

    /// The type of the content of the story to post; may be null if unspecified
    public let contentType: StoryContentType?


    public init(contentType: StoryContentType?) {
        self.contentType = contentType
    }
}

/// The link is an OAuth link. Call getOauthLinkInfo with the given URL to process the link if the link was received from outside of the application; otherwise, ignore it. After getOauthLinkInfo, show the user confirmation dialog and process it with checkOauthRequestMatchCode, acceptOauthRequest or declineOauthRequest
public struct InternalLinkTypeOauth: Codable, Equatable, Hashable {

    /// URL to be passed to getOauthLinkInfo
    public let url: String


    public init(url: String) {
        self.url = url
    }
}

/// The link contains a request of Telegram passport data. Call getPassportAuthorizationForm with the given parameters to process the link if the link was received from outside of the application; otherwise, ignore it
public struct InternalLinkTypePassportDataRequest: Codable, Equatable, Hashable {

    /// User identifier of the service's bot; the corresponding user may be unknown yet
    public let botUserId: Int64

    /// An HTTP URL to open once the request is finished, canceled, or failed with the parameters tg_passport=success, tg_passport=cancel, or tg_passport=error&error=... respectively. If empty, then onActivityResult method must be used to return response on Android, or the link tgbot{bot_user_id}://passport/success or tgbot{bot_user_id}://passport/cancel must be opened otherwise
    public let callbackUrl: String

    /// Unique request identifier provided by the service
    public let nonce: String

    /// Service's public key
    public let publicKey: String

    /// Telegram Passport element types requested by the service
    public let scope: String


    public init(
        botUserId: Int64,
        callbackUrl: String,
        nonce: String,
        publicKey: String,
        scope: String
    ) {
        self.botUserId = botUserId
        self.callbackUrl = callbackUrl
        self.nonce = nonce
        self.publicKey = publicKey
        self.scope = scope
    }
}

/// The link can be used to confirm ownership of a phone number to prevent account deletion. Call sendPhoneNumberCode with the given phone number and with phoneNumberCodeTypeConfirmOwnership with the given hash to process the link. If succeeded, call checkPhoneNumberCode to check entered by the user code, or resendPhoneNumberCode to resend it
public struct InternalLinkTypePhoneNumberConfirmation: Codable, Equatable, Hashable {

    /// Hash value from the link
    public let hash: String

    /// Phone number value from the link
    public let phoneNumber: String


    public init(
        hash: String,
        phoneNumber: String
    ) {
        self.hash = hash
        self.phoneNumber = phoneNumber
    }
}

/// The link is a link to the Premium features screen of the application from which the user can subscribe to Telegram Premium. Call getPremiumFeatures with the given referrer to process the link
public struct InternalLinkTypePremiumFeaturesPage: Codable, Equatable, Hashable {

    /// Referrer specified in the link
    public let referrer: String


    public init(referrer: String) {
        self.referrer = referrer
    }
}

/// The link is a link with a Telegram Premium gift code. Call checkPremiumGiftCode with the given code to process the link. If the code is valid and the user wants to apply it, then call applyPremiumGiftCode
public struct InternalLinkTypePremiumGiftCode: Codable, Equatable, Hashable {

    /// The Telegram Premium gift code
    public let code: String


    public init(code: String) {
        self.code = code
    }
}

/// The link is a link to the screen for gifting Telegram Premium subscriptions to friends via inputInvoiceTelegram with telegramPaymentPurposePremiumGift payments or in-store purchases
public struct InternalLinkTypePremiumGiftPurchase: Codable, Equatable, Hashable {

    /// Referrer specified in the link
    public let referrer: String


    public init(referrer: String) {
        self.referrer = referrer
    }
}

/// The link is a link to a proxy. Call addProxy with the given parameters to process the link and add the proxy
public struct InternalLinkTypeProxy: Codable, Equatable, Hashable {

    /// The proxy; may be null if the proxy is unsupported, in which case an alert can be shown to the user
    public let proxy: Proxy?


    public init(proxy: Proxy?) {
        self.proxy = proxy
    }
}

/// The link is a link to a chat by its username. Call searchPublicChat with the given chat username to process the link. If the chat is found, open its profile information screen or the chat itself. If draft text isn't empty and the chat is a private chat with a regular user, then put the draft text in the input field
public struct InternalLinkTypePublicChat: Codable, Equatable, Hashable {

    /// Username of the chat
    public let chatUsername: String

    /// Draft text for message to send in the chat
    public let draftText: String

    /// True, if chat profile information screen must be opened; otherwise, the chat itself must be opened
    public let openProfile: Bool


    public init(
        chatUsername: String,
        draftText: String,
        openProfile: Bool
    ) {
        self.chatUsername = chatUsername
        self.draftText = draftText
        self.openProfile = openProfile
    }
}

/// The link is a link to a dialog for creating of a managed bot. Call searchPublicChat with the given manager bot username. If the chat is found, the chat is a chat with a bot and the bot has can_manage_bots == true, then show bot creation confirmation dialog with the given suggested_bot_username and suggested_bot_name. If user agrees, call createBot with via_link == true to create the bot
public struct InternalLinkTypeRequestManagedBot: Codable, Equatable, Hashable {

    /// Username of the bot which will manage the new bot
    public let managerBotUsername: String

    /// Suggested name for the bot; may be empty if not specified
    public let suggestedBotName: String

    /// Suggested username for the bot; always ends with "bot" case-insensitive
    public let suggestedBotUsername: String


    public init(
        managerBotUsername: String,
        suggestedBotName: String,
        suggestedBotUsername: String
    ) {
        self.managerBotUsername = managerBotUsername
        self.suggestedBotName = suggestedBotName
        self.suggestedBotUsername = suggestedBotUsername
    }
}

/// The link is a link to application settings
public struct InternalLinkTypeSettings: Codable, Equatable, Hashable {

    /// Section of the application settings to open; may be null if none
    public let section: SettingsSection?


    public init(section: SettingsSection?) {
        self.section = section
    }
}

/// The link is a link to the Telegram Star purchase section of the application
public struct InternalLinkTypeStarPurchase: Codable, Equatable, Hashable {

    /// Purpose of Telegram Star purchase. Arbitrary string specified by the server, for example, "subs" if the Telegram Stars are required to extend channel subscriptions
    public let purpose: String

    /// The number of Telegram Stars that must be owned by the user
    public let starCount: Int64


    public init(
        purpose: String,
        starCount: Int64
    ) {
        self.purpose = purpose
        self.starCount = starCount
    }
}

/// The link is a link to a sticker set. Call searchStickerSet with the given sticker set name to process the link and show the sticker set. If the sticker set is found and the user wants to add it, then call changeStickerSet
public struct InternalLinkTypeStickerSet: Codable, Equatable, Hashable {

    /// True, if the sticker set is expected to contain custom emoji
    public let expectCustomEmoji: Bool

    /// Name of the sticker set
    public let stickerSetName: String


    public init(
        expectCustomEmoji: Bool,
        stickerSetName: String
    ) {
        self.expectCustomEmoji = expectCustomEmoji
        self.stickerSetName = stickerSetName
    }
}

/// The link is a link to a story. Call searchPublicChat with the given poster username, then call getStory with the received chat identifier and the given story identifier, then show the story if received
public struct InternalLinkTypeStory: Codable, Equatable, Hashable {

    /// Story identifier
    public let storyId: Int

    /// Username of the poster of the story
    public let storyPosterUsername: String


    public init(
        storyId: Int,
        storyPosterUsername: String
    ) {
        self.storyId = storyId
        self.storyPosterUsername = storyPosterUsername
    }
}

/// The link is a link to an album of stories. Call searchPublicChat with the given username, then call getStoryAlbumStories with the received chat identifier and the given story album identifier, then show the story album if received
public struct InternalLinkTypeStoryAlbum: Codable, Equatable, Hashable {

    /// Story album identifier
    public let storyAlbumId: Int

    /// Username of the owner of the story album
    public let storyAlbumOwnerUsername: String


    public init(
        storyAlbumId: Int,
        storyAlbumOwnerUsername: String
    ) {
        self.storyAlbumId = storyAlbumId
        self.storyAlbumOwnerUsername = storyAlbumOwnerUsername
    }
}

/// The link is a link to a text composition style. Call searchTextCompositionStyle with the given style name to get information about the style. If the style is found and the user wants to add it, then call addTextCompositionStyle
public struct InternalLinkTypeTextCompositionStyle: Codable, Equatable, Hashable {

    /// Name of the style
    public let styleName: String


    public init(styleName: String) {
        self.styleName = styleName
    }
}

/// The link is a link to a cloud theme. TDLib has no theme support yet
public struct InternalLinkTypeTheme: Codable, Equatable, Hashable {

    /// Name of the theme
    public let themeName: String


    public init(themeName: String) {
        self.themeName = themeName
    }
}

/// The link is an unknown tg: link. Call getDeepLinkInfo to process the link
public struct InternalLinkTypeUnknownDeepLink: Codable, Equatable, Hashable {

    /// Link to be passed to getDeepLinkInfo
    public let link: String


    public init(link: String) {
        self.link = link
    }
}

/// The link is a link to an upgraded gift. Call getUpgradedGift with the given name to process the link
public struct InternalLinkTypeUpgradedGift: Codable, Equatable, Hashable {

    /// Name of the unique gift
    public let name: String


    public init(name: String) {
        self.name = name
    }
}

/// The link is a link to a user by its phone number. Call searchUserByPhoneNumber with the given phone number to process the link. If the user is found, then call createPrivateChat and open user's profile information screen or the chat itself. If draft text isn't empty, then put the draft text in the input field
public struct InternalLinkTypeUserPhoneNumber: Codable, Equatable, Hashable {

    /// Draft text for message to send in the chat
    public let draftText: String

    /// True, if user's profile information screen must be opened; otherwise, the chat itself must be opened
    public let openProfile: Bool

    /// Phone number of the user
    public let phoneNumber: String


    public init(
        draftText: String,
        openProfile: Bool,
        phoneNumber: String
    ) {
        self.draftText = draftText
        self.openProfile = openProfile
        self.phoneNumber = phoneNumber
    }
}

/// The link is a link to a user by a temporary token. Call searchUserByToken with the given token to process the link. If the user is found, then call createPrivateChat and open the chat
public struct InternalLinkTypeUserToken: Codable, Equatable, Hashable {

    /// The token
    public let token: String


    public init(token: String) {
        self.token = token
    }
}

/// The link is a link to a video chat. Call searchPublicChat with the given chat username, and then joinVideoChat with the given invite hash to process the link
public struct InternalLinkTypeVideoChat: Codable, Equatable, Hashable {

    /// Username of the chat with the video chat
    public let chatUsername: String

    /// If non-empty, invite hash to be used to join the video chat without being muted by administrators
    public let inviteHash: String

    /// True, if the video chat is expected to be a live stream in a channel or a broadcast group
    public let isLiveStream: Bool


    public init(
        chatUsername: String,
        inviteHash: String,
        isLiveStream: Bool
    ) {
        self.chatUsername = chatUsername
        self.inviteHash = inviteHash
        self.isLiveStream = isLiveStream
    }
}

/// The link is a link to a Web App. Call searchPublicChat with the given bot username, check that the user is a bot. If the bot is restricted for the current user, then show an error message. Otherwise, call searchWebApp with the received bot and the given web_app_short_name. Process received foundWebApp by showing a confirmation dialog if needed. If the bot can be added to attachment or side menu, but isn't added yet, then show a disclaimer about Mini Apps being third-party applications instead of the dialog and ask the user to accept their Terms of service. If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot. Then, call getWebAppLinkUrl and open the returned URL as a Web App
public struct InternalLinkTypeWebApp: Codable, Equatable, Hashable {

    /// Username of the bot that owns the Web App
    public let botUsername: String

    /// The mode in which the Web App must be opened
    public let mode: WebAppOpenMode

    /// Start parameter to be passed to getWebAppLinkUrl
    public let startParameter: String

    /// Short name of the Web App
    public let webAppShortName: String


    public init(
        botUsername: String,
        mode: WebAppOpenMode,
        startParameter: String,
        webAppShortName: String
    ) {
        self.botUsername = botUsername
        self.mode = mode
        self.startParameter = startParameter
        self.webAppShortName = webAppShortName
    }
}

