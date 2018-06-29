import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class PrivacyAndSecurityControllerArguments {
    let account: Account
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: () -> Void
    let openActiveSessions: () -> Void
    let setupAccountAutoremove: () -> Void
    let clearPaymentInfo: () -> Void
    let updateSecretChatLinkPreviews: (Bool) -> Void
    let deleteContacts: () -> Void
    let updateSyncContacts: (Bool) -> Void
    let updateSuggestFrequentContacts: (Bool) -> Void
    
    init(account: Account, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping () -> Void, openActiveSessions: @escaping () -> Void, setupAccountAutoremove: @escaping () -> Void, clearPaymentInfo: @escaping () -> Void, updateSecretChatLinkPreviews: @escaping (Bool) -> Void, deleteContacts: @escaping () -> Void, updateSyncContacts: @escaping (Bool) -> Void, updateSuggestFrequentContacts: @escaping (Bool) -> Void) {
        self.account = account
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.setupAccountAutoremove = setupAccountAutoremove
        self.clearPaymentInfo = clearPaymentInfo
        self.updateSecretChatLinkPreviews = updateSecretChatLinkPreviews
        self.deleteContacts = deleteContacts
        self.updateSyncContacts = updateSyncContacts
        self.updateSuggestFrequentContacts = updateSuggestFrequentContacts
    }
}

private enum PrivacyAndSecuritySection: Int32 {
    case privacy
    case security
    case account
    case payment
    case secretChatLinkPreviews
    case contacts
    case frequentContacts
}

private enum PrivacyAndSecurityEntry: ItemListNodeEntry {
    case privacyHeader(PresentationTheme, String)
    case blockedPeers(PresentationTheme, String)
    case lastSeenPrivacy(PresentationTheme, String, String)
    case groupPrivacy(PresentationTheme, String, String)
    case voiceCallPrivacy(PresentationTheme, String, String)
    case securityHeader(PresentationTheme, String)
    case passcode(PresentationTheme, String)
    case twoStepVerification(PresentationTheme, String)
    case activeSessions(PresentationTheme, String)
    case accountHeader(PresentationTheme, String)
    case accountTimeout(PresentationTheme, String, String)
    case accountInfo(PresentationTheme, String)
    case paymentHeader(PresentationTheme, String)
    case clearPaymentInfo(PresentationTheme, String, Bool)
    case paymentInfo(PresentationTheme, String)
    case secretChatLinkPreviewsHeader(PresentationTheme, String)
    case secretChatLinkPreviews(PresentationTheme, String, Bool)
    case secretChatLinkPreviewsInfo(PresentationTheme, String)
    case contactsHeader(PresentationTheme, String)
    case deleteContacts(PresentationTheme, String, Bool)
    case syncContacts(PresentationTheme, String, Bool)
    case syncContactsInfo(PresentationTheme, String)
    case frequentContactsHeader(PresentationTheme, String)
    case frequentContacts(PresentationTheme, String, Bool)
    case frequentContactsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .privacyHeader, .blockedPeers, .lastSeenPrivacy, .groupPrivacy, .voiceCallPrivacy:
                return PrivacyAndSecuritySection.privacy.rawValue
            case .securityHeader, .passcode, .twoStepVerification, .activeSessions:
                return PrivacyAndSecuritySection.security.rawValue
            case .accountHeader, .accountTimeout, .accountInfo:
                return PrivacyAndSecuritySection.account.rawValue
            case .paymentHeader, .clearPaymentInfo, .paymentInfo:
                return PrivacyAndSecuritySection.payment.rawValue
            case .secretChatLinkPreviewsHeader, .secretChatLinkPreviews, .secretChatLinkPreviewsInfo:
                return PrivacyAndSecuritySection.secretChatLinkPreviews.rawValue
            case .contactsHeader, .deleteContacts, .syncContacts, .syncContactsInfo:
                return PrivacyAndSecuritySection.contacts.rawValue
            case .frequentContactsHeader, .frequentContacts, .frequentContactsInfo:
                return PrivacyAndSecuritySection.frequentContacts.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .privacyHeader:
                return 0
            case .blockedPeers:
                return 1
            case .lastSeenPrivacy:
                return 2
            case .groupPrivacy:
                return 3
            case .voiceCallPrivacy:
                return 4
            case .securityHeader:
                return 5
            case .passcode:
                return 6
            case .twoStepVerification:
                return 7
            case .activeSessions:
                return 8
            case .accountHeader:
                return 9
            case .accountTimeout:
                return 10
            case .accountInfo:
                return 11
            case .paymentHeader:
                return 12
            case .clearPaymentInfo:
                return 13
            case .paymentInfo:
                return 14
            case .secretChatLinkPreviewsHeader:
                return 15
            case .secretChatLinkPreviews:
                return 16
            case .secretChatLinkPreviewsInfo:
                return 17
            case .contactsHeader:
                return 18
            case .deleteContacts:
                return 19
            case .syncContacts:
                return 20
            case .syncContactsInfo:
                return 21
            case .frequentContactsHeader:
                return 22
            case .frequentContacts:
                return 23
            case .frequentContactsInfo:
                return 24
        }
    }
    
    static func ==(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        switch lhs {
            case let .privacyHeader(lhsTheme, lhsText):
                if case let .privacyHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .blockedPeers(lhsTheme, lhsText):
                if case let .blockedPeers(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .lastSeenPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .lastSeenPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .groupPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .voiceCallPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .voiceCallPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .securityHeader(lhsTheme, lhsText):
                if case let .securityHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passcode(lhsTheme, lhsText):
                if case let .passcode(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .twoStepVerification(lhsTheme, lhsText):
                if case let .twoStepVerification(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .activeSessions(lhsTheme, lhsText):
                if case let .activeSessions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .accountHeader(lhsTheme, lhsText):
                if case let .accountHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .accountTimeout(lhsTheme, lhsText, lhsValue):
                if case let .accountTimeout(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .accountInfo(lhsTheme, lhsText):
                if case let .accountInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .paymentHeader(lhsTheme, lhsText):
                if case let .paymentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearPaymentInfo(lhsTheme, lhsText, lhsEnabled):
                if case let .clearPaymentInfo(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .paymentInfo(lhsTheme, lhsText):
                if case let .paymentInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviewsHeader(lhsTheme, lhsText):
                if case let .secretChatLinkPreviewsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviews(lhsTheme, lhsText, lhsEnabled):
                if case let .secretChatLinkPreviews(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviewsInfo(lhsTheme, lhsText):
                if case let .secretChatLinkPreviewsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .contactsHeader(lhsTheme, lhsText):
                if case let .contactsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .deleteContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .deleteContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .syncContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .syncContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .syncContactsInfo(lhsTheme, lhsText):
                if case let .syncContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .frequentContactsHeader(lhsTheme, lhsText):
                if case let .frequentContactsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .frequentContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .frequentContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .frequentContactsInfo(lhsTheme, lhsText):
                if case let .frequentContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: PrivacyAndSecurityControllerArguments) -> ListViewItem {
        switch self {
            case let .privacyHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .blockedPeers(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openBlockedUsers()
                })
            case let .lastSeenPrivacy(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openLastSeenPrivacy()
                })
            case let .groupPrivacy(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openGroupsPrivacy()
                })
            case let .voiceCallPrivacy(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceCallPrivacy()
                })
            case let .securityHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .passcode(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openPasscode()
                })
            case let .twoStepVerification(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openTwoStepVerification()
                })
            case let .activeSessions(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openActiveSessions()
                })
            case let .accountHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .accountTimeout(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.setupAccountAutoremove()
                })
            case let .accountInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .paymentHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .clearPaymentInfo(theme, text, enabled):
                return ItemListActionItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.clearPaymentInfo()
                })
            case let .paymentInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .secretChatLinkPreviewsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .secretChatLinkPreviews(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSecretChatLinkPreviews(updatedValue)
                })
            case let .secretChatLinkPreviewsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .contactsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .deleteContacts(theme, text, value):
                return ItemListActionItem(theme: theme, title: text, kind: value ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deleteContacts()
                })
            case let .syncContacts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSyncContacts(updatedValue)
                })
            case let .syncContactsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .frequentContactsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .frequentContacts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: !value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSuggestFrequentContacts(updatedValue)
                })
            case let .frequentContactsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    let updatingAccountTimeoutValue: Int32?
    let clearingPaymentInfo: Bool
    let clearedPaymentInfo: Bool
    let deletingContacts: Bool
    let updatedSuggestFrequentContacts: Bool?
    
    init(updatingAccountTimeoutValue: Int32? = nil, clearingPaymentInfo: Bool = false, clearedPaymentInfo: Bool = false, deletingContacts: Bool = false, updatedSuggestFrequentContacts: Bool? = nil) {
        self.updatingAccountTimeoutValue = updatingAccountTimeoutValue
        self.clearingPaymentInfo = clearingPaymentInfo
        self.clearedPaymentInfo = clearedPaymentInfo
        self.deletingContacts = deletingContacts
        self.updatedSuggestFrequentContacts = updatedSuggestFrequentContacts
    }
    
    static func ==(lhs: PrivacyAndSecurityControllerState, rhs: PrivacyAndSecurityControllerState) -> Bool {
        if lhs.updatingAccountTimeoutValue != rhs.updatingAccountTimeoutValue {
            return false
        }
        if lhs.clearingPaymentInfo != rhs.clearingPaymentInfo {
            return false
        }
        if lhs.clearedPaymentInfo != rhs.clearedPaymentInfo {
            return false
        }
        if lhs.deletingContacts != rhs.deletingContacts {
            return false
        }
        if lhs.updatedSuggestFrequentContacts != rhs.updatedSuggestFrequentContacts {
            return false
        }
        
        return true
    }
    
    func withUpdatedUpdatingAccountTimeoutValue(_ updatingAccountTimeoutValue: Int32?) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: updatingAccountTimeoutValue, clearingPaymentInfo: self.clearingPaymentInfo, clearedPaymentInfo: self.clearedPaymentInfo, deletingContacts: self.deletingContacts, updatedSuggestFrequentContacts: self.updatedSuggestFrequentContacts)
    }
    
    func withUpdatedClearingPaymentInfo(_ clearingPaymentInfo: Bool) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: self.updatingAccountTimeoutValue, clearingPaymentInfo: clearingPaymentInfo, clearedPaymentInfo: self.clearedPaymentInfo, deletingContacts: self.deletingContacts, updatedSuggestFrequentContacts: self.updatedSuggestFrequentContacts)
    }
    
    func withUpdatedClearedPaymentInfo(_ clearedPaymentInfo: Bool) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: self.updatingAccountTimeoutValue, clearingPaymentInfo: self.clearingPaymentInfo, clearedPaymentInfo: clearedPaymentInfo, deletingContacts: self.deletingContacts, updatedSuggestFrequentContacts: self.updatedSuggestFrequentContacts)
    }
    
    func withUpdatedDeletingContacts(_ deletingContacts: Bool) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: self.updatingAccountTimeoutValue, clearingPaymentInfo: self.clearingPaymentInfo, clearedPaymentInfo: self.clearedPaymentInfo, deletingContacts: deletingContacts, updatedSuggestFrequentContacts: self.updatedSuggestFrequentContacts)
    }
    
    func withUpdatedUpdatedSuggestFrequentContacts(_ updatedSuggestFrequentContacts: Bool?) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: self.updatingAccountTimeoutValue, clearingPaymentInfo: self.clearingPaymentInfo, clearedPaymentInfo: self.clearedPaymentInfo, deletingContacts: self.deletingContacts, updatedSuggestFrequentContacts: updatedSuggestFrequentContacts)
    }
}

private func stringForSelectiveSettings(strings: PresentationStrings, settings: SelectivePrivacySettings) -> String {
    switch settings {
        case let .disableEveryone(enableFor):
            if enableFor.isEmpty {
                return strings.PrivacySettings_LastSeenNobody
            } else {
                return strings.PrivacySettings_LastSeenNobodyPlus("\(enableFor.count)").0
            }
        case let .enableEveryone(disableFor):
            if disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenEverybody
            } else {
                return strings.PrivacySettings_LastSeenEverybodyMinus("\(disableFor.count)").0
            }
        case let .enableContacts(enableFor, disableFor):
            if !enableFor.isEmpty && !disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsMinusPlus("\(enableFor.count)", "\(disableFor.count)").0
            } else if !enableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsPlus("\(enableFor.count)").0
            } else if !disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsMinus("\(disableFor.count)").0
            } else {
                return strings.PrivacySettings_LastSeenContacts
            }
    }
}

private func privacyAndSecurityControllerEntries(presentationData: PresentationData, state: PrivacyAndSecurityControllerState, privacySettings: AccountPrivacySettings?, secretChatLinkPreviews: Bool?, synchronizeDeviceContacts: Bool, frequentContacts: Bool) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    entries.append(.privacyHeader(presentationData.theme, presentationData.strings.PrivacySettings_PrivacyTitle))
    entries.append(.blockedPeers(presentationData.theme, presentationData.strings.Settings_BlockedUsers))
    if let privacySettings = privacySettings {
        entries.append(.lastSeenPrivacy(presentationData.theme, presentationData.strings.PrivacySettings_LastSeen, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.presence)))
        entries.append(.groupPrivacy(presentationData.theme, presentationData.strings.Privacy_GroupsAndChannels, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.groupInvitations)))
        entries.append(.voiceCallPrivacy(presentationData.theme, presentationData.strings.Privacy_Calls, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.voiceCalls)))
    } else {
        entries.append(.lastSeenPrivacy(presentationData.theme, presentationData.strings.PrivacySettings_LastSeen, presentationData.strings.Channel_NotificationLoading))
        entries.append(.groupPrivacy(presentationData.theme, presentationData.strings.Privacy_GroupsAndChannels, presentationData.strings.Channel_NotificationLoading))
        entries.append(.voiceCallPrivacy(presentationData.theme, presentationData.strings.Privacy_Calls, presentationData.strings.Channel_NotificationLoading))
    }
    
    entries.append(.securityHeader(presentationData.theme, presentationData.strings.PrivacySettings_SecurityTitle))
    if let biometricAuthentication = LocalAuth.biometricAuthentication {
        switch biometricAuthentication {
            case .touchId:
                entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_PasscodeAndTouchId))
            case .faceId:
                entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_PasscodeAndFaceId))
        }
    } else {
        entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_Passcode))
    }
    entries.append(.twoStepVerification(presentationData.theme, presentationData.strings.PrivacySettings_TwoStepAuth))
    entries.append(.activeSessions(presentationData.theme, presentationData.strings.PrivacySettings_AuthSessions))
    entries.append(.accountHeader(presentationData.theme, presentationData.strings.PrivacySettings_DeleteAccountTitle))
    if let privacySettings = privacySettings {
        let value: Int32
        if let updatingAccountTimeoutValue = state.updatingAccountTimeoutValue {
            value = updatingAccountTimeoutValue
        } else {
            value = privacySettings.accountRemovalTimeout
        }
        entries.append(.accountTimeout(presentationData.theme, presentationData.strings.PrivacySettings_DeleteAccountIfAwayFor, timeIntervalString(strings: presentationData.strings, value: value)))
    } else {
        entries.append(.accountTimeout(presentationData.theme, presentationData.strings.PrivacySettings_DeleteAccountIfAwayFor, presentationData.strings.Channel_NotificationLoading))
    }
    entries.append(.accountInfo(presentationData.theme, presentationData.strings.PrivacySettings_DeleteAccountHelp))
    
    entries.append(.paymentHeader(presentationData.theme, presentationData.strings.Privacy_PaymentsTitle))
    entries.append(.clearPaymentInfo(presentationData.theme, presentationData.strings.Privacy_PaymentsClearInfo, !state.clearingPaymentInfo && !state.clearedPaymentInfo))
    if state.clearedPaymentInfo {
        entries.append(.paymentInfo(presentationData.theme, presentationData.strings.Privacy_PaymentsClearInfoDoneHelp))
    } else {
        entries.append(.paymentInfo(presentationData.theme, presentationData.strings.Privacy_PaymentsClearInfoHelp))
    }
    
    entries.append(.secretChatLinkPreviewsHeader(presentationData.theme, presentationData.strings.PrivacySettings_SecretChats))
    entries.append(.secretChatLinkPreviews(presentationData.theme, presentationData.strings.PrivacySettings_LinkPreviews, secretChatLinkPreviews ?? true))
    entries.append(.secretChatLinkPreviewsInfo(presentationData.theme, presentationData.strings.PrivacySettings_LinkPreviewsInfo))
    
    entries.append(.contactsHeader(presentationData.theme, presentationData.strings.PrivacySettings_Contacts))
    entries.append(.deleteContacts(presentationData.theme, presentationData.strings.PrivacySettings_DeleteContacts, !state.deletingContacts))
    entries.append(.syncContacts(presentationData.theme, presentationData.strings.PrivacySettings_SyncContacts, synchronizeDeviceContacts))
    entries.append(.syncContactsInfo(presentationData.theme, presentationData.strings.PrivacySettings_SyncContactsInfo))
    
    entries.append(.frequentContactsHeader(presentationData.theme, presentationData.strings.PrivacySettings_FrequentContacts))
    entries.append(.frequentContacts(presentationData.theme, presentationData.strings.PrivacySettings_SuggestFrequentContacts, frequentContacts))
    entries.append(.frequentContactsInfo(presentationData.theme, presentationData.strings.PrivacySettings_SuggestFrequentContactsInfo))
    
    return entries
}

public func privacyAndSecurityController(account: Account, initialSettings: Signal<AccountPrivacySettings?, NoError>) -> ViewController {
    let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
    let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var pushControllerInstantImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentInfoDisposable = MetaDisposable()
    actionsDisposable.add(currentInfoDisposable)
    
    let updateAccountTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateAccountTimeoutDisposable)
    
    let clearPaymentInfoDisposable = MetaDisposable()
    actionsDisposable.add(clearPaymentInfoDisposable)
    
    let privacySettingsPromise = Promise<AccountPrivacySettings?>()
    privacySettingsPromise.set(initialSettings)
    
    let arguments = PrivacyAndSecurityControllerArguments(account: account, openBlockedUsers: {
        pushControllerImpl?(blockedPeersController(account: account))
    }, openLastSeenPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .presence, current: info.presence, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                            }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openGroupsPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .groupInvitations, current: info.groupInvitations, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openVoiceCallPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .voiceCalls, current: info.voiceCalls, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openPasscode: {
        let _ = passcodeOptionsAccessController(account: account, completion: { animated in
            if animated {
                pushControllerImpl?(passcodeOptionsController(account: account))
            } else {
                pushControllerInstantImpl?(passcodeOptionsController(account: account))
            }
        }).start(next: { controller in
            if let controller = controller {
                presentControllerImpl?(controller)
            }
        })
    }, openTwoStepVerification: {
        pushControllerImpl?(twoStepVerificationUnlockSettingsController(account: account, mode: .access))
    }, openActiveSessions: {
        pushControllerImpl?(recentSessionsController(account: account))
    }, setupAccountAutoremove: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable] privacySettingsValue in
            if let _ = privacySettingsValue {
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationTheme: presentationData.theme)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                let timeoutAction: (Int32) -> Void = { timeout in
                    if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                        updateState {
                            return $0.withUpdatedUpdatingAccountTimeoutValue(timeout)
                        }
                        let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: timeout)))
                                }
                                return .complete()
                            }
                        updateAccountTimeoutDisposable.set((updateAccountRemovalTimeout(account: account, timeout: timeout)
                            |> then(applyTimeout)
                            |> deliverOnMainQueue).start(completed: {
                                updateState {
                                    return $0.withUpdatedUpdatingAccountTimeoutValue(nil)
                                }
                            }))
                    }
                }
                let timeoutValues: [Int32] = [
                    1 * 30 * 24 * 60 * 60,
                    3 * 30 * 24 * 60 * 60,
                    6 * 30 * 24 * 60 * 60,
                    12 * 30 * 24 * 60 * 60
                ]
                let timeoutItems: [ActionSheetItem] = timeoutValues.map { value in
                    return ActionSheetButtonItem(title: timeIntervalString(strings: presentationData.strings, value: value), action: {
                        dismissAction()
                        timeoutAction(value)
                    })
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: timeoutItems),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller)
            }
        }))
    }, clearPaymentInfo: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Privacy_PaymentsClearInfo, color: .destructive, action: {
                    var clear = false
                    updateState { current in
                        if !current.clearingPaymentInfo && !current.clearedPaymentInfo {
                            clear = true
                            return current.withUpdatedClearingPaymentInfo(true)
                        } else {
                            return current
                        }
                    }
                    if clear {
                        clearPaymentInfoDisposable.set((clearBotPaymentInfo(network: account.network)
                            |> deliverOnMainQueue).start(completed: {
                                updateState { current in
                                    return current.withUpdatedClearingPaymentInfo(false).withUpdatedClearedPaymentInfo(true)
                                }
                            }))
                    }
                    dismissAction()
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller)
    }, updateSecretChatLinkPreviews: { value in
        let _ = ApplicationSpecificNotice.setSecretChatLinkPreviews(postbox: account.postbox, value: value).start()
    }, deleteContacts: {
        var canBegin = false
        updateState { state in
            if !state.deletingContacts {
                canBegin = true
            }
            return state
        }
        if canBegin {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: "This will remove your contacts from the Telegram servers.", actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                var begin = false
                updateState { state in
                    var state = state
                    if !state.deletingContacts {
                        state = state.withUpdatedDeletingContacts(true)
                        begin = true
                    }
                    return state
                }
                
                if !begin {
                    return
                }
                
                let _ = updateContactSynchronizationSettingsInteractively(postbox: account.postbox, { settings in
                    var settings = settings
                    settings.synchronizeDeviceContacts = false
                    return settings
                })
                
                actionsDisposable.add((deleteAllContacts(postbox: account.postbox, network: account.network)
                    |> deliverOnMainQueue).start(completed: {
                        updateState { state in
                            var state = state
                            state = state.withUpdatedDeletingContacts(false)
                            return state
                        }
                        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                        presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.PrivacySettings_DeleteContactsSuccess, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                    }))
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})]))
        }
    }, updateSyncContacts: { value in
        let _ = updateContactSynchronizationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.synchronizeDeviceContacts = value
            return settings
        }).start()
    }, updateSuggestFrequentContacts: { value in
        let apply: () -> Void = {
            updateState { state in
                return state.withUpdatedUpdatedSuggestFrequentContacts(value)
            }
            let _ = updateRecentPeersEnabled(postbox: account.postbox, network: account.network, enabled: value).start()
        }
        if !value {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.PrivacySettings_SuggestFrequentContactsDisableNotice, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                apply()
            })]))
        } else {
            apply()
        }
    })
    
    let previousState = Atomic<PrivacyAndSecurityControllerState?>(value: nil)
    
    let preferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.contactSynchronizationSettings]))
    
    actionsDisposable.add(managedUpdatedRecentPeers(postbox: account.postbox, network: account.network).start())
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get() |> deliverOnMainQueue, privacySettingsPromise.get(), account.postbox.combinedView(keys: [.noticeEntry(ApplicationSpecificNotice.secretChatLinkPreviewsKey()), preferencesKey]), recentPeers(account: account))
        |> map { presentationData, state, privacySettings, combined, recentPeers -> (ItemListControllerState, (ItemListNodeState<PrivacyAndSecurityEntry>, PrivacyAndSecurityEntry.ItemGenerationArguments)) in
            let secretChatLinkPreviews = (combined.views[.noticeEntry(ApplicationSpecificNotice.secretChatLinkPreviewsKey())] as? NoticeEntryView)?.value.flatMap({ ApplicationSpecificNotice.getSecretChatLinkPreviews($0) })
            
            let synchronizeDeviceContacts: Bool = ((combined.views[preferencesKey] as? PreferencesView)?.values[ApplicationSpecificPreferencesKeys.contactSynchronizationSettings] as? ContactSynchronizationSettings)?.synchronizeDeviceContacts ?? true
            
            let suggestRecentPeers: Bool
            if let updatedSuggestFrequentContacts = state.updatedSuggestFrequentContacts {
                suggestRecentPeers = updatedSuggestFrequentContacts
            } else {
                switch recentPeers {
                    case .peers:
                        suggestRecentPeers = true
                    case .disabled:
                        suggestRecentPeers = false
                }
            }
            
            var rightNavigationButton: ItemListNavigationButton?
            if privacySettings == nil || state.updatingAccountTimeoutValue != nil {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.PrivacySettings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            
            let previousStateValue = previousState.swap(state)
            var animateChanges = false
            if let previousStateValue = previousStateValue {
                if previousStateValue.clearedPaymentInfo != state.clearedPaymentInfo {
                    animateChanges = true
                }
            }
            
            let listState = ItemListNodeState(entries: privacyAndSecurityControllerEntries(presentationData: presentationData, state: state, privacySettings: privacySettings, secretChatLinkPreviews: secretChatLinkPreviews, synchronizeDeviceContacts: synchronizeDeviceContacts, frequentContacts: suggestRecentPeers), style: .blocks, animateChanges: animateChanges)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    pushControllerInstantImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c, animated: false)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    return controller
}
