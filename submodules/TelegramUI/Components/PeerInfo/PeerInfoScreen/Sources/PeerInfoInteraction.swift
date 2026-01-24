import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import StatisticsUI

final class PeerInfoInteraction {
    let openChat: (EnginePeer.Id?) -> Void
    let openUsername: (String, Bool, Promise<Bool>?) -> Void
    let openPhone: (String, ASDisplayNode, ContextGesture?, Promise<Bool>?) -> Void
    let editingOpenNotificationSettings: () -> Void
    let editingOpenSoundSettings: () -> Void
    let editingToggleShowMessageText: (Bool) -> Void
    let requestDeleteContact: () -> Void
    let suggestBirthdate: () -> Void
    let suggestPhoto: () -> Void
    let setCustomPhoto: () -> Void
    let resetCustomPhoto: () -> Void
    let openAddContact: () -> Void
    let updateBlocked: (Bool) -> Void
    let openReport: (PeerInfoReportType) -> Void
    let openShareBot: () -> Void
    let openAddBotToGroup: () -> Void
    let performBotCommand: (PeerInfoBotCommand) -> Void
    let editingOpenPublicLinkSetup: () -> Void
    let editingOpenNameColorSetup: () -> Void
    let editingOpenInviteLinksSetup: () -> Void
    let editingOpenDiscussionGroupSetup: () -> Void
    let editingOpenPostSuggestionsSetup: () -> Void
    let editingOpenRevenue: () -> Void
    let editingOpenStars: () -> Void
    let openParticipantsSection: (PeerInfoParticipantsSection) -> Void
    let openRecentActions: () -> Void
    let openChannelMessages: () -> Void
    let openStats: (ChannelStatsSection) -> Void
    let editingOpenPreHistorySetup: () -> Void
    let editingOpenAutoremoveMesages: () -> Void
    let openPermissions: () -> Void
    let openLocation: () -> Void
    let editingOpenSetupLocation: () -> Void
    let openPeerInfo: (Peer, Bool) -> Void
    let performMemberAction: (PeerInfoMember, PeerInfoMemberAction) -> Void
    let openPeerInfoContextMenu: (PeerInfoContextSubject, ASDisplayNode, CGRect?) -> Void
    let performBioLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let requestLayout: (Bool) -> Void
    let openEncryptionKey: () -> Void
    let openSettings: (PeerInfoSettingsSection) -> Void
    let openPaymentMethod: () -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let logoutAccount: (AccountRecordId) -> Void
    let accountContextMenu: (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void
    let updateBio: (String) -> Void
    let updateNote: (NSAttributedString) -> Void
    let openDeletePeer: () -> Void
    let openFaq: (String?) -> Void
    let openAddMember: () -> Void
    let openQrCode: () -> Void
    let editingOpenReactionsSetup: () -> Void
    let dismissInput: () -> Void
    let openForumSettings: () -> Void
    let displayTopicsLimited: (TopicsLimitedReason) -> Void
    let openPeerMention: (String, ChatControllerInteractionNavigateToPeer) -> Void
    let openBotApp: (AttachMenuBot) -> Void
    let openEditing: () -> Void
    let updateBirthdate: (TelegramBirthday??) -> Void
    let updateIsEditingBirthdate: (Bool) -> Void
    let openBioPrivacy: () -> Void
    let openBirthdatePrivacy: () -> Void
    let openPremiumGift: () -> Void
    let editingOpenPersonalChannel: () -> Void
    let openUsernameContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBioContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openNoteContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openWorkingHoursContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBusinessLocationContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBirthdayContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let editingOpenAffiliateProgram: () -> Void
    let editingOpenVerifyAccounts: () -> Void
    let editingToggleAutoTranslate: (Bool) -> Void
    let displayAutoTranslateLocked: () -> Void
    let getController: () -> ViewController?
    
    init(
        openUsername: @escaping (String, Bool, Promise<Bool>?) -> Void,
        openPhone: @escaping (String, ASDisplayNode, ContextGesture?, Promise<Bool>?) -> Void,
        editingOpenNotificationSettings: @escaping () -> Void,
        editingOpenSoundSettings: @escaping () -> Void,
        editingToggleShowMessageText: @escaping (Bool) -> Void,
        requestDeleteContact: @escaping () -> Void,
        suggestBirthdate: @escaping () -> Void,
        suggestPhoto: @escaping () -> Void,
        setCustomPhoto: @escaping () -> Void,
        resetCustomPhoto: @escaping () -> Void,
        openChat: @escaping (EnginePeer.Id?) -> Void,
        openAddContact: @escaping () -> Void,
        updateBlocked: @escaping (Bool) -> Void,
        openReport: @escaping (PeerInfoReportType) -> Void,
        openShareBot: @escaping () -> Void,
        openAddBotToGroup: @escaping () -> Void,
        performBotCommand: @escaping (PeerInfoBotCommand) -> Void,
        editingOpenPublicLinkSetup: @escaping () -> Void,
        editingOpenNameColorSetup: @escaping () -> Void,
        editingOpenInviteLinksSetup: @escaping () -> Void,
        editingOpenDiscussionGroupSetup: @escaping () -> Void,
        editingOpenPostSuggestionsSetup: @escaping () -> Void,
        editingOpenRevenue: @escaping () -> Void,
        editingOpenStars: @escaping () -> Void,
        openParticipantsSection: @escaping (PeerInfoParticipantsSection) -> Void,
        openRecentActions: @escaping () -> Void,
        openChannelMessages: @escaping () -> Void,
        openStats: @escaping (ChannelStatsSection) -> Void,
        editingOpenPreHistorySetup: @escaping () -> Void,
        editingOpenAutoremoveMesages: @escaping () -> Void,
        openPermissions: @escaping () -> Void,
        openLocation: @escaping () -> Void,
        editingOpenSetupLocation: @escaping () -> Void,
        openPeerInfo: @escaping (Peer, Bool) -> Void,
        performMemberAction: @escaping (PeerInfoMember, PeerInfoMemberAction) -> Void,
        openPeerInfoContextMenu: @escaping (PeerInfoContextSubject, ASDisplayNode, CGRect?) -> Void,
        performBioLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void,
        requestLayout: @escaping (Bool) -> Void,
        openEncryptionKey: @escaping () -> Void,
        openSettings: @escaping (PeerInfoSettingsSection) -> Void,
        openPaymentMethod: @escaping () -> Void,
        switchToAccount: @escaping (AccountRecordId) -> Void,
        logoutAccount: @escaping (AccountRecordId) -> Void,
        accountContextMenu: @escaping (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void,
        updateBio: @escaping (String) -> Void,
        updateNote: @escaping (NSAttributedString) -> Void,
        openDeletePeer: @escaping () -> Void,
        openFaq: @escaping (String?) -> Void,
        openAddMember: @escaping () -> Void,
        openQrCode: @escaping () -> Void,
        editingOpenReactionsSetup: @escaping () -> Void,
        dismissInput: @escaping () -> Void,
        openForumSettings: @escaping () -> Void,
        displayTopicsLimited: @escaping (TopicsLimitedReason) -> Void,
        openPeerMention: @escaping (String, ChatControllerInteractionNavigateToPeer) -> Void,
        openBotApp: @escaping (AttachMenuBot) -> Void,
        openEditing: @escaping () -> Void,
        updateBirthdate: @escaping (TelegramBirthday??) -> Void,
        updateIsEditingBirthdate: @escaping (Bool) -> Void,
        openBioPrivacy: @escaping () -> Void,
        openBirthdatePrivacy: @escaping () -> Void,
        openPremiumGift: @escaping () -> Void,
        editingOpenPersonalChannel: @escaping () -> Void,
        openUsernameContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBioContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openNoteContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openWorkingHoursContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBusinessLocationContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBirthdayContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        editingOpenAffiliateProgram: @escaping () -> Void,
        editingOpenVerifyAccounts: @escaping () -> Void,
        editingToggleAutoTranslate: @escaping (Bool) -> Void,
        displayAutoTranslateLocked: @escaping () -> Void,
        getController: @escaping () -> ViewController?
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
        self.editingOpenNotificationSettings = editingOpenNotificationSettings
        self.editingOpenSoundSettings = editingOpenSoundSettings
        self.editingToggleShowMessageText = editingToggleShowMessageText
        self.requestDeleteContact = requestDeleteContact
        self.suggestBirthdate = suggestBirthdate
        self.suggestPhoto = suggestPhoto
        self.setCustomPhoto = setCustomPhoto
        self.resetCustomPhoto = resetCustomPhoto
        self.openChat = openChat
        self.openAddContact = openAddContact
        self.updateBlocked = updateBlocked
        self.openReport = openReport
        self.openShareBot = openShareBot
        self.openAddBotToGroup = openAddBotToGroup
        self.performBotCommand = performBotCommand
        self.editingOpenPublicLinkSetup = editingOpenPublicLinkSetup
        self.editingOpenNameColorSetup = editingOpenNameColorSetup
        self.editingOpenInviteLinksSetup = editingOpenInviteLinksSetup
        self.editingOpenDiscussionGroupSetup = editingOpenDiscussionGroupSetup
        self.editingOpenPostSuggestionsSetup = editingOpenPostSuggestionsSetup
        self.editingOpenRevenue = editingOpenRevenue
        self.editingOpenStars = editingOpenStars
        self.openParticipantsSection = openParticipantsSection
        self.openRecentActions = openRecentActions
        self.openChannelMessages = openChannelMessages
        self.openStats = openStats
        self.editingOpenPreHistorySetup = editingOpenPreHistorySetup
        self.editingOpenAutoremoveMesages = editingOpenAutoremoveMesages
        self.openPermissions = openPermissions
        self.openLocation = openLocation
        self.editingOpenSetupLocation = editingOpenSetupLocation
        self.openPeerInfo = openPeerInfo
        self.performMemberAction = performMemberAction
        self.openPeerInfoContextMenu = openPeerInfoContextMenu
        self.performBioLinkAction = performBioLinkAction
        self.requestLayout = requestLayout
        self.openEncryptionKey = openEncryptionKey
        self.openSettings = openSettings
        self.openPaymentMethod = openPaymentMethod
        self.switchToAccount = switchToAccount
        self.logoutAccount = logoutAccount
        self.accountContextMenu = accountContextMenu
        self.updateBio = updateBio
        self.updateNote = updateNote
        self.openDeletePeer = openDeletePeer
        self.openFaq = openFaq
        self.openAddMember = openAddMember
        self.openQrCode = openQrCode
        self.editingOpenReactionsSetup = editingOpenReactionsSetup
        self.dismissInput = dismissInput
        self.openForumSettings = openForumSettings
        self.displayTopicsLimited = displayTopicsLimited
        self.openPeerMention = openPeerMention
        self.openBotApp = openBotApp
        self.openEditing = openEditing
        self.updateBirthdate = updateBirthdate
        self.updateIsEditingBirthdate = updateIsEditingBirthdate
        self.openBioPrivacy = openBioPrivacy
        self.openBirthdatePrivacy = openBirthdatePrivacy
        self.openPremiumGift = openPremiumGift
        self.editingOpenPersonalChannel = editingOpenPersonalChannel
        self.openUsernameContextMenu = openUsernameContextMenu
        self.openBioContextMenu = openBioContextMenu
        self.openNoteContextMenu = openNoteContextMenu
        self.openWorkingHoursContextMenu = openWorkingHoursContextMenu
        self.openBusinessLocationContextMenu = openBusinessLocationContextMenu
        self.openBirthdayContextMenu = openBirthdayContextMenu
        self.editingOpenAffiliateProgram = editingOpenAffiliateProgram
        self.editingOpenVerifyAccounts = editingOpenVerifyAccounts
        self.editingToggleAutoTranslate = editingToggleAutoTranslate
        self.displayAutoTranslateLocked = displayAutoTranslateLocked
        self.getController = getController
    }
}
