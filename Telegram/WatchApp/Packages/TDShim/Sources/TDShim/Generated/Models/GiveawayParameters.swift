//
//  GiveawayParameters.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes parameters of a giveaway
public struct GiveawayParameters: Codable, Equatable, Hashable {

    /// Identifiers of other supergroup or channel chats that must be subscribed by the users to be eligible for the giveaway. There can be up to getOption("giveaway_additional_chat_count_max") additional chats
    public let additionalChatIds: [Int64]

    /// Identifier of the supergroup or channel chat, which will be automatically boosted by the winners of the giveaway for duration of the Telegram Premium subscription, or for the specified time. If the chat is a channel, then can_post_messages administrator right is required in the channel, otherwise, the user must be an administrator in the supergroup
    public let boostedChatId: Int64

    /// The list of two-letter ISO 3166-1 alpha-2 codes of countries, users from which will be eligible for the giveaway. If empty, then all users can participate in the giveaway. There can be up to getOption("giveaway_country_count_max") chosen countries. Users with phone number that was bought at https://fragment.com can participate in any giveaway and the country code "FT" must not be specified in the list
    public let countryCodes: [String]

    /// True, if the list of winners of the giveaway will be available to everyone
    public let hasPublicWinners: Bool

    /// True, if only new members of the chats will be eligible for the giveaway
    public let onlyNewMembers: Bool

    /// Additional description of the giveaway prize; 0-128 characters
    public let prizeDescription: String

    /// Point in time (Unix timestamp) when the giveaway is expected to be performed; must be 60-getOption("giveaway_duration_max") seconds in the future in scheduled giveaways
    public let winnersSelectionDate: Int


    public init(
        additionalChatIds: [Int64],
        boostedChatId: Int64,
        countryCodes: [String],
        hasPublicWinners: Bool,
        onlyNewMembers: Bool,
        prizeDescription: String,
        winnersSelectionDate: Int
    ) {
        self.additionalChatIds = additionalChatIds
        self.boostedChatId = boostedChatId
        self.countryCodes = countryCodes
        self.hasPublicWinners = hasPublicWinners
        self.onlyNewMembers = onlyNewMembers
        self.prizeDescription = prizeDescription
        self.winnersSelectionDate = winnersSelectionDate
    }
}

