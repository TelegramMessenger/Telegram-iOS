//
//  Usernames.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes usernames assigned to a user, a supergroup, or a channel
public struct Usernames: Codable, Equatable, Hashable {

    /// List of active usernames; the first one must be shown as the primary username. The order of active usernames can be changed with reorderActiveUsernames, reorderBotActiveUsernames or reorderSupergroupActiveUsernames
    public let activeUsernames: [String]

    /// Collectible usernames that were purchased at https://fragment.com and can be passed to getCollectibleItemInfo for more details
    public let collectibleUsernames: [String]

    /// List of currently disabled usernames; the username can be activated with toggleUsernameIsActive, toggleBotUsernameIsActive, or toggleSupergroupUsernameIsActive
    public let disabledUsernames: [String]

    /// Active or disabled username, which may be changed with setUsername or setSupergroupUsername
    public let editableUsername: String


    public init(
        activeUsernames: [String],
        collectibleUsernames: [String],
        disabledUsernames: [String],
        editableUsername: String
    ) {
        self.activeUsernames = activeUsernames
        self.collectibleUsernames = collectibleUsernames
        self.disabledUsernames = disabledUsernames
        self.editableUsername = editableUsername
    }
}

