//
//  ChatPermissions.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes actions that a user is allowed to take in a chat
public struct ChatPermissions: Codable, Equatable, Hashable {

    /// True, if the user may add a link preview to their messages
    public let canAddLinkPreviews: Bool

    /// True, if the user can change the chat title, photo, and other settings
    public let canChangeInfo: Bool

    /// True, if the user can create topics
    public let canCreateTopics: Bool

    /// True, if the user may change the tag of self
    public let canEditTag: Bool

    /// True, if the user can invite new users to the chat
    public let canInviteUsers: Bool

    /// True, if the user can pin messages
    public let canPinMessages: Bool

    /// True, if the user can react to messages
    public let canReactToMessages: Bool

    /// True, if the user can send music files
    public let canSendAudios: Bool

    /// True, if the user can send text messages, contacts, giveaways, giveaway winners, invoices, locations, and venues
    public let canSendBasicMessages: Bool

    /// True, if the user can send documents
    public let canSendDocuments: Bool

    /// True, if the user can send animations, games, stickers, and dice and use inline bots
    public let canSendOtherMessages: Bool

    /// True, if the user can send photos
    public let canSendPhotos: Bool

    /// True, if the user can send polls and checklists
    public let canSendPolls: Bool

    /// True, if the user can send video notes
    public let canSendVideoNotes: Bool

    /// True, if the user can send videos
    public let canSendVideos: Bool

    /// True, if the user can send voice notes
    public let canSendVoiceNotes: Bool


    public init(
        canAddLinkPreviews: Bool,
        canChangeInfo: Bool,
        canCreateTopics: Bool,
        canEditTag: Bool,
        canInviteUsers: Bool,
        canPinMessages: Bool,
        canReactToMessages: Bool,
        canSendAudios: Bool,
        canSendBasicMessages: Bool,
        canSendDocuments: Bool,
        canSendOtherMessages: Bool,
        canSendPhotos: Bool,
        canSendPolls: Bool,
        canSendVideoNotes: Bool,
        canSendVideos: Bool,
        canSendVoiceNotes: Bool
    ) {
        self.canAddLinkPreviews = canAddLinkPreviews
        self.canChangeInfo = canChangeInfo
        self.canCreateTopics = canCreateTopics
        self.canEditTag = canEditTag
        self.canInviteUsers = canInviteUsers
        self.canPinMessages = canPinMessages
        self.canReactToMessages = canReactToMessages
        self.canSendAudios = canSendAudios
        self.canSendBasicMessages = canSendBasicMessages
        self.canSendDocuments = canSendDocuments
        self.canSendOtherMessages = canSendOtherMessages
        self.canSendPhotos = canSendPhotos
        self.canSendPolls = canSendPolls
        self.canSendVideoNotes = canSendVideoNotes
        self.canSendVideos = canSendVideos
        self.canSendVoiceNotes = canSendVoiceNotes
    }
}

