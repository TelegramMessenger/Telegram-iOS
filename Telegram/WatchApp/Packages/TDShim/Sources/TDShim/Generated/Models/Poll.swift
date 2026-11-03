//
//  Poll.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a poll
public struct Poll: Codable, Equatable, Hashable, Identifiable {

    /// True, if multiple answer options can be chosen simultaneously
    public let allowsMultipleAnswers: Bool

    /// True, if the poll can be answered multiple times
    public let allowsRevoting: Bool

    /// True, if the current user can get voters in the poll using getPollVoters
    public let canGetVoters: Bool

    /// Point in time (Unix timestamp) when the poll will automatically be closed
    public let closeDate: Int

    /// The list of two-letter ISO 3166-1 alpha-2 codes of countries, users from which will be able to vote. If empty, then all users can participate in the poll
    public let countryCodes: [String]

    /// Unique poll identifier
    public let id: TdInt64

    /// True, if the poll is anonymous
    public let isAnonymous: Bool

    /// True, if the poll is closed
    public let isClosed: Bool

    /// True, if only the users that are members of the chat for more than a day will be able to vote
    public let membersOnly: Bool

    /// Amount of time the poll will be active after creation, in seconds
    public let openPeriod: Int

    /// The list of 0-based poll identifiers in which the options of the poll must be shown; empty if the order of options must not be changed
    public let optionOrder: [Int]

    /// List of poll answer options
    public let options: [PollOption]

    /// Poll question; 1-300 characters; may contain only custom emoji entities
    public let question: FormattedText

    /// Identifiers of recent voters, if the poll is non-anonymous and poll results are available
    public let recentVoterIds: [MessageSender]

    /// Total number of voters, participating in the poll
    public let totalVoterCount: Int

    /// Type of the poll
    public let type: PollType

    /// The reason describing, why the current user can't vote in the poll; may be null if the user can vote in the poll
    public let voteRestrictionReason: PollVoteRestrictionReason?


    public init(
        allowsMultipleAnswers: Bool,
        allowsRevoting: Bool,
        canGetVoters: Bool,
        closeDate: Int,
        countryCodes: [String],
        id: TdInt64,
        isAnonymous: Bool,
        isClosed: Bool,
        membersOnly: Bool,
        openPeriod: Int,
        optionOrder: [Int],
        options: [PollOption],
        question: FormattedText,
        recentVoterIds: [MessageSender],
        totalVoterCount: Int,
        type: PollType,
        voteRestrictionReason: PollVoteRestrictionReason?
    ) {
        self.allowsMultipleAnswers = allowsMultipleAnswers
        self.allowsRevoting = allowsRevoting
        self.canGetVoters = canGetVoters
        self.closeDate = closeDate
        self.countryCodes = countryCodes
        self.id = id
        self.isAnonymous = isAnonymous
        self.isClosed = isClosed
        self.membersOnly = membersOnly
        self.openPeriod = openPeriod
        self.optionOrder = optionOrder
        self.options = options
        self.question = question
        self.recentVoterIds = recentVoterIds
        self.totalVoterCount = totalVoterCount
        self.type = type
        self.voteRestrictionReason = voteRestrictionReason
    }
}

