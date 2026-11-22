//
//  UpgradedGift.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an upgraded gift that can be transferred to another owner or transferred to the TON blockchain as an NFT
public struct UpgradedGift: Codable, Equatable, Hashable, Identifiable {

    /// Backdrop of the upgraded gift
    public let backdrop: UpgradedGiftBackdrop

    /// True, if an offer to purchase the gift can be sent using sendGiftPurchaseOffer
    public let canSendPurchaseOffer: Bool

    /// Colors that can be set for user's name, background of empty chat photo, replies to messages and link previews; may be null if none or unknown
    public let colors: UpgradedGiftColors?

    /// Probability that the gift adds to the chance of successful crafting of a new gift; 0 if the gift can't be used for crafting
    public let craftProbabilityPerMille: Int

    /// Address of the gift NFT in TON blockchain; may be empty if none. Append the address to getOption("ton_blockchain_explorer_url") to get a link with information about the address
    public let giftAddress: String

    /// Identifier of the user or the chat to which the upgraded gift was assigned from blockchain; may be null if none or unknown
    public let hostId: MessageSender?

    /// Unique identifier of the gift
    public let id: TdInt64

    /// True, if the gift was used to craft another gift
    public let isBurned: Bool

    /// True, if the gift was craft from another gifts
    public let isCrafted: Bool

    /// True, if the original gift could have been bought only by Telegram Premium subscribers
    public let isPremium: Bool

    /// True, if the gift can be used to set a theme in a chat
    public let isThemeAvailable: Bool

    /// The maximum number of gifts that can be upgraded from the same gift
    public let maxUpgradedCount: Int

    /// Model of the upgraded gift
    public let model: UpgradedGiftModel

    /// Unique name of the upgraded gift that can be used with internalLinkTypeUpgradedGift or sendResoldGift
    public let name: String

    /// Unique number of the upgraded gift among gifts upgraded from the same gift
    public let number: Int

    /// Information about the originally sent gift; may be null if unknown
    public let originalDetails: UpgradedGiftOriginalDetails?

    /// Address of the gift NFT owner in TON blockchain; may be empty if none. Append the address to getOption("ton_blockchain_explorer_url") to get a link with information about the address
    public let ownerAddress: String

    /// Identifier of the user or the chat that owns the upgraded gift; may be null if none or unknown
    public let ownerId: MessageSender?

    /// Name of the owner for the case when owner identifier and address aren't known
    public let ownerName: String

    /// Identifier of the chat that published the gift; 0 if none
    public let publisherChatId: Int64

    /// Unique identifier of the regular gift from which the gift was upgraded; may be 0 for short period of time for old gifts from database
    public let regularGiftId: TdInt64

    /// Resale parameters of the gift; may be null if resale isn't possible
    public let resaleParameters: GiftResaleParameters?

    /// Symbol of the upgraded gift
    public let symbol: UpgradedGiftSymbol

    /// The title of the upgraded gift
    public let title: String

    /// Total number of gifts that were upgraded from the same gift
    public let totalUpgradedCount: Int

    /// Identifier of the chat for which the gift is used to set a theme; 0 if none or the gift isn't owned by the current user
    public let usedThemeChatId: Int64

    /// Estimated value of the gift; in the smallest units of the currency; 0 if unavailable
    public let valueAmount: Int64

    /// ISO 4217 currency code of the currency in which value of the gift is represented; may be empty if unavailable
    public let valueCurrency: String

    /// Estimated value of the gift in USD; in USD cents; 0 if unavailable
    public let valueUsdAmount: Int64


    public init(
        backdrop: UpgradedGiftBackdrop,
        canSendPurchaseOffer: Bool,
        colors: UpgradedGiftColors?,
        craftProbabilityPerMille: Int,
        giftAddress: String,
        hostId: MessageSender?,
        id: TdInt64,
        isBurned: Bool,
        isCrafted: Bool,
        isPremium: Bool,
        isThemeAvailable: Bool,
        maxUpgradedCount: Int,
        model: UpgradedGiftModel,
        name: String,
        number: Int,
        originalDetails: UpgradedGiftOriginalDetails?,
        ownerAddress: String,
        ownerId: MessageSender?,
        ownerName: String,
        publisherChatId: Int64,
        regularGiftId: TdInt64,
        resaleParameters: GiftResaleParameters?,
        symbol: UpgradedGiftSymbol,
        title: String,
        totalUpgradedCount: Int,
        usedThemeChatId: Int64,
        valueAmount: Int64,
        valueCurrency: String,
        valueUsdAmount: Int64
    ) {
        self.backdrop = backdrop
        self.canSendPurchaseOffer = canSendPurchaseOffer
        self.colors = colors
        self.craftProbabilityPerMille = craftProbabilityPerMille
        self.giftAddress = giftAddress
        self.hostId = hostId
        self.id = id
        self.isBurned = isBurned
        self.isCrafted = isCrafted
        self.isPremium = isPremium
        self.isThemeAvailable = isThemeAvailable
        self.maxUpgradedCount = maxUpgradedCount
        self.model = model
        self.name = name
        self.number = number
        self.originalDetails = originalDetails
        self.ownerAddress = ownerAddress
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.publisherChatId = publisherChatId
        self.regularGiftId = regularGiftId
        self.resaleParameters = resaleParameters
        self.symbol = symbol
        self.title = title
        self.totalUpgradedCount = totalUpgradedCount
        self.usedThemeChatId = usedThemeChatId
        self.valueAmount = valueAmount
        self.valueCurrency = valueCurrency
        self.valueUsdAmount = valueUsdAmount
    }
}

