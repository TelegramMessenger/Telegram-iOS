//
//  ChatAdministratorRights.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes rights of the administrator
public struct ChatAdministratorRights: Codable, Equatable, Hashable {

    /// True, if the administrator can change the chat title, photo, and other settings
    public let canChangeInfo: Bool

    /// True, if the administrator can delete messages of other users
    public let canDeleteMessages: Bool

    /// True, if the administrator can delete stories posted by other users; applicable to supergroups and channels only
    public let canDeleteStories: Bool

    /// True, if the administrator can edit messages of other users and pin messages; applicable to channels only
    public let canEditMessages: Bool

    /// True, if the administrator can edit stories posted by other users, post stories to the chat page, pin chat stories, and access story archive; applicable to supergroups and channels only
    public let canEditStories: Bool

    /// True, if the administrator can invite new users to the chat
    public let canInviteUsers: Bool

    /// True, if the administrator can access the chat event log, get boost list, see hidden supergroup and channel members, report supergroup spam messages, ignore slow mode, and send messages to the chat without paying Telegram Stars. Implied by any other privilege; applicable to supergroups and channels only
    public let canManageChat: Bool

    /// True, if the administrator can answer to channel direct messages; applicable to channels only
    public let canManageDirectMessages: Bool

    /// True, if the administrator can change tags of other users; applicable to basic groups and supergroups only
    public let canManageTags: Bool

    /// True, if the administrator can create, rename, close, reopen, hide, and unhide forum topics; applicable to forum supergroups only
    public let canManageTopics: Bool

    /// True, if the administrator can manage video chats
    public let canManageVideoChats: Bool

    /// True, if the administrator can pin messages; applicable to basic groups and supergroups only
    public let canPinMessages: Bool

    /// True, if the administrator can create channel posts, approve suggested channel posts, or view channel statistics; applicable to channels only
    public let canPostMessages: Bool

    /// True, if the administrator can create new chat stories, or edit and delete posted stories; applicable to supergroups and channels only
    public let canPostStories: Bool

    /// True, if the administrator can add new administrators with a subset of their own privileges or demote administrators that were directly or indirectly promoted by them
    public let canPromoteMembers: Bool

    /// True, if the administrator can restrict, ban, or unban chat members or view supergroup statistics
    public let canRestrictMembers: Bool

    /// True, if the administrator isn't shown in the chat member list and sends messages anonymously; applicable to supergroups only
    public let isAnonymous: Bool


    public init(
        canChangeInfo: Bool,
        canDeleteMessages: Bool,
        canDeleteStories: Bool,
        canEditMessages: Bool,
        canEditStories: Bool,
        canInviteUsers: Bool,
        canManageChat: Bool,
        canManageDirectMessages: Bool,
        canManageTags: Bool,
        canManageTopics: Bool,
        canManageVideoChats: Bool,
        canPinMessages: Bool,
        canPostMessages: Bool,
        canPostStories: Bool,
        canPromoteMembers: Bool,
        canRestrictMembers: Bool,
        isAnonymous: Bool
    ) {
        self.canChangeInfo = canChangeInfo
        self.canDeleteMessages = canDeleteMessages
        self.canDeleteStories = canDeleteStories
        self.canEditMessages = canEditMessages
        self.canEditStories = canEditStories
        self.canInviteUsers = canInviteUsers
        self.canManageChat = canManageChat
        self.canManageDirectMessages = canManageDirectMessages
        self.canManageTags = canManageTags
        self.canManageTopics = canManageTopics
        self.canManageVideoChats = canManageVideoChats
        self.canPinMessages = canPinMessages
        self.canPostMessages = canPostMessages
        self.canPostStories = canPostStories
        self.canPromoteMembers = canPromoteMembers
        self.canRestrictMembers = canRestrictMembers
        self.isAnonymous = isAnonymous
    }
}

