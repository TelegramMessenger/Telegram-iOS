//
//  Gift.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a gift that can be sent to another user or channel chat
public struct Gift: Codable, Equatable, Hashable, Identifiable {

    /// Information about the auction on which the gift can be purchased; may be null if the gift can be purchased directly
    public let auctionInfo: GiftAuction?

    /// Background of the gift
    public let background: GiftBackground

    /// Number of Telegram Stars that can be claimed by the receiver instead of the regular gift by default. If the gift was paid with just bought Telegram Stars, then full value can be claimed
    public let defaultSellStarCount: Int64

    /// Point in time (Unix timestamp) when the gift was send for the first time; for sold out gifts only
    public let firstSendDate: Int

    /// True, if the gift can be used to customize the user's name, and backgrounds of profile photo, reply header, and link preview
    public let hasColors: Bool

    /// Unique identifier of the gift
    public let id: TdInt64

    /// True, if the gift is a birthday gift
    public let isForBirthday: Bool

    /// True, if the gift can be bought only by Telegram Premium subscribers
    public let isPremium: Bool

    /// Point in time (Unix timestamp) when the gift was send for the last time; for sold out gifts only
    public let lastSendDate: Int

    /// Point in time (Unix timestamp) when the gift can be sent next time by the current user; may be 0 or a date in the past. If the date is in the future, then call canSendGift to get the reason, why the gift can't be sent now
    public let nextSendDate: Int

    /// Number of times the gift can be purchased all users; may be null if not limited
    public let overallLimits: GiftPurchaseLimits?

    /// Identifier of the chat that published the gift; 0 if none
    public let publisherChatId: Int64

    /// Number of Telegram Stars that must be paid for the gift
    public let starCount: Int64

    /// The sticker representing the gift
    public let sticker: Sticker

    /// Number of Telegram Stars that must be paid to upgrade the gift; 0 if upgrade isn't possible
    public let upgradeStarCount: Int64

    /// Number of unique gift variants that are available for the upgraded gift; 0 if unknown
    public let upgradeVariantCount: Int

    /// Number of times the gift can be purchased by the current user; may be null if not limited
    public let userLimits: GiftPurchaseLimits?


    public init(
        auctionInfo: GiftAuction?,
        background: GiftBackground,
        defaultSellStarCount: Int64,
        firstSendDate: Int,
        hasColors: Bool,
        id: TdInt64,
        isForBirthday: Bool,
        isPremium: Bool,
        lastSendDate: Int,
        nextSendDate: Int,
        overallLimits: GiftPurchaseLimits?,
        publisherChatId: Int64,
        starCount: Int64,
        sticker: Sticker,
        upgradeStarCount: Int64,
        upgradeVariantCount: Int,
        userLimits: GiftPurchaseLimits?
    ) {
        self.auctionInfo = auctionInfo
        self.background = background
        self.defaultSellStarCount = defaultSellStarCount
        self.firstSendDate = firstSendDate
        self.hasColors = hasColors
        self.id = id
        self.isForBirthday = isForBirthday
        self.isPremium = isPremium
        self.lastSendDate = lastSendDate
        self.nextSendDate = nextSendDate
        self.overallLimits = overallLimits
        self.publisherChatId = publisherChatId
        self.starCount = starCount
        self.sticker = sticker
        self.upgradeStarCount = upgradeStarCount
        self.upgradeVariantCount = upgradeVariantCount
        self.userLimits = userLimits
    }
}

