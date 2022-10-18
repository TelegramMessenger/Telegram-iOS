import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramCallsUI
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramNotices
import LocalAuth
import AppBundle
import PasswordSetupUI
import UndoUI
import PremiumUI
import AuthorizationUI
import AuthenticationServices

private final class PrivacyAndSecurityControllerArguments {
    let account: Account
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openProfilePhotoPrivacy: () -> Void
    let openForwardPrivacy: () -> Void
    let openPhoneNumberPrivacy: () -> Void
    let openVoiceMessagePrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: (TwoStepVerificationAccessConfiguration?) -> Void
    let openActiveSessions: () -> Void
    let toggleArchiveAndMuteNonContacts: (Bool) -> Void
    let setupAccountAutoremove: () -> Void
    let openDataSettings: () -> Void
    let openEmailSettings: (String?) -> Void
    
    init(account: Account, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openProfilePhotoPrivacy: @escaping () -> Void, openForwardPrivacy: @escaping () -> Void, openPhoneNumberPrivacy: @escaping () -> Void, openVoiceMessagePrivacy: @escaping () -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping (TwoStepVerificationAccessConfiguration?) -> Void, openActiveSessions: @escaping () -> Void, toggleArchiveAndMuteNonContacts: @escaping (Bool) -> Void, setupAccountAutoremove: @escaping () -> Void, openDataSettings: @escaping () -> Void, openEmailSettings: @escaping (String?) -> Void) {
        self.account = account
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openProfilePhotoPrivacy = openProfilePhotoPrivacy
        self.openForwardPrivacy = openForwardPrivacy
        self.openPhoneNumberPrivacy = openPhoneNumberPrivacy
        self.openVoiceMessagePrivacy = openVoiceMessagePrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.toggleArchiveAndMuteNonContacts = toggleArchiveAndMuteNonContacts
        self.setupAccountAutoremove = setupAccountAutoremove
        self.openDataSettings = openDataSettings
        self.openEmailSettings = openEmailSettings
    }
}

private enum PrivacyAndSecuritySection: Int32 {
    case general
    case privacy
    case autoArchive
    case account
    case dataSettings
}

public enum PrivacyAndSecurityEntryTag: ItemListItemTag {
    case accountTimeout
    case autoArchive
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PrivacyAndSecurityEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum PrivacyAndSecurityEntry: ItemListNodeEntry {
    case privacyHeader(PresentationTheme, String)
    case blockedPeers(PresentationTheme, String, String)
    case phoneNumberPrivacy(PresentationTheme, String, String)
    case lastSeenPrivacy(PresentationTheme, String, String)
    case profilePhotoPrivacy(PresentationTheme, String, String)
    case voiceCallPrivacy(PresentationTheme, String, String)
    case forwardPrivacy(PresentationTheme, String, String)
    case groupPrivacy(PresentationTheme, String, String)
    case voiceMessagePrivacy(PresentationTheme, String, String, Bool)
    case selectivePrivacyInfo(PresentationTheme, String)
    case passcode(PresentationTheme, String, Bool, String)
    case twoStepVerification(PresentationTheme, String, String, TwoStepVerificationAccessConfiguration?)
    case loginEmail(PresentationTheme, String, String?)
    case loginEmailInfo(PresentationTheme, String)
    case activeSessions(PresentationTheme, String, String)
    case autoArchiveHeader(String)
    case autoArchive(String, Bool)
    case autoArchiveInfo(String)
    case accountHeader(PresentationTheme, String)
    case accountTimeout(PresentationTheme, String, String)
    case accountInfo(PresentationTheme, String)
    case dataSettings(PresentationTheme, String)
    case dataSettingsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .blockedPeers, .activeSessions, .passcode, .twoStepVerification, .loginEmail, .loginEmailInfo:
                return PrivacyAndSecuritySection.general.rawValue
            case .privacyHeader, .phoneNumberPrivacy, .lastSeenPrivacy, .profilePhotoPrivacy, .forwardPrivacy, .groupPrivacy, .voiceCallPrivacy, .voiceMessagePrivacy, .selectivePrivacyInfo:
                return PrivacyAndSecuritySection.privacy.rawValue
            case .autoArchiveHeader, .autoArchive, .autoArchiveInfo:
                return PrivacyAndSecuritySection.autoArchive.rawValue
            case .accountHeader, .accountTimeout, .accountInfo:
                return PrivacyAndSecuritySection.account.rawValue
            case .dataSettings, .dataSettingsInfo:
                return PrivacyAndSecuritySection.dataSettings.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .blockedPeers:
                return 1
            case .activeSessions:
                return 2
            case .passcode:
                return 3
            case .twoStepVerification:
                return 4
            case .loginEmail:
                return 5
            case .loginEmailInfo:
                return 6
            case .privacyHeader:
                return 7
            case .phoneNumberPrivacy:
                return 8
            case .lastSeenPrivacy:
                return 9
            case .profilePhotoPrivacy:
                return 10
            case .voiceCallPrivacy:
                return 11
            case .voiceMessagePrivacy:
                return 12
            case .forwardPrivacy:
                return 13
            case .groupPrivacy:
                return 14
            case .selectivePrivacyInfo:
                return 15
            case .autoArchiveHeader:
                return 16
            case .autoArchive:
                return 17
            case .autoArchiveInfo:
                return 18
            case .accountHeader:
                return 19
            case .accountTimeout:
                return 20
            case .accountInfo:
                return 21
            case .dataSettings:
                return 22
            case .dataSettingsInfo:
                return 23
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
            case let .blockedPeers(lhsTheme, lhsText, lhsValue):
                if case let .blockedPeers(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .phoneNumberPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .phoneNumberPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .profilePhotoPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .profilePhotoPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .forwardPrivacy(lhsTheme, lhsText, lhsValue):
                if case let .forwardPrivacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .voiceMessagePrivacy(lhsTheme, lhsText, lhsValue, lhsLocked):
                if case let .voiceMessagePrivacy(rhsTheme, rhsText, rhsValue, rhsLocked) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsLocked == rhsLocked {
                    return true
                } else {
                    return false
                }
            case let .selectivePrivacyInfo(lhsTheme, lhsText):
                if case let .selectivePrivacyInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passcode(lhsTheme, lhsText, lhsHasFaceId, lhsValue):
                if case let .passcode(rhsTheme, rhsText, rhsHasFaceId, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsHasFaceId == rhsHasFaceId, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .twoStepVerification(lhsTheme, lhsText, lhsValue, lhsData):
                if case let .twoStepVerification(rhsTheme, rhsText, rhsValue, rhsData) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsData == rhsData {
                    return true
                } else {
                    return false
                }
            case let .loginEmail(lhsTheme, lhsText, lhsEmailPattern):
                if case let .loginEmail(rhsTheme, rhsText, rhsEmailPattern) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEmailPattern == rhsEmailPattern {
                    return true
                } else {
                    return false
                }
            case let .loginEmailInfo(lhsTheme, lhsText):
                if case let .loginEmailInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .activeSessions(lhsTheme, lhsText, lhsValue):
                if case let .activeSessions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .autoArchiveHeader(text):
                if case .autoArchiveHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoArchive(text, value):
                if case .autoArchive(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoArchiveInfo(text):
                if case .autoArchiveInfo(text) = rhs {
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
            case let .dataSettings(lhsTheme, lhsText):
                if case let .dataSettings(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .dataSettingsInfo(lhsTheme, lhsText):
                if case let .dataSettingsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PrivacyAndSecurityControllerArguments
        switch self {
            case let .privacyHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .blockedPeers(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Blocked")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openBlockedUsers()
                })
            case let .phoneNumberPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openPhoneNumberPrivacy()
                })
            case let .lastSeenPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openLastSeenPrivacy()
                })
            case let .profilePhotoPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openProfilePhotoPrivacy()
                })
            case let .forwardPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openForwardPrivacy()
                })
            case let .groupPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openGroupsPrivacy()
                })
            case let .voiceMessagePrivacy(_, text, value, locked):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: locked ? .textWithIcon(UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon")!.precomposed()) : .text, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceMessagePrivacy()
                })
            case let .selectivePrivacyInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .voiceCallPrivacy(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceCallPrivacy()
                })
            case let .passcode(_, text, hasFaceId, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: hasFaceId ? "Settings/Menu/FaceId" : "Settings/Menu/TouchId")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openPasscode()
                })
            case let .twoStepVerification(_, text, value, data):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/TwoStepAuth")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openTwoStepVerification(data)
                })
            case let .loginEmail(_, text, emailPattern):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/LoginEmail")?.precomposed(), title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openEmailSettings(emailPattern)
                })
            case let .loginEmailInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .activeSessions(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Websites")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openActiveSessions()
                })
            case let .autoArchiveHeader(text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .autoArchive(text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleArchiveAndMuteNonContacts(value)
                }, tag: PrivacyAndSecurityEntryTag.autoArchive)
            case let .autoArchiveInfo(text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .accountHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .accountTimeout(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.setupAccountAutoremove()
                }, tag: PrivacyAndSecurityEntryTag.accountTimeout)
            case let .accountInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .dataSettings(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openDataSettings()
                })
            case let .dataSettingsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    var updatingAccountTimeoutValue: Int32? = nil
    var updatingAutomaticallyArchiveAndMuteNonContacts: Bool? = nil
}

private func countForSelectivePeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> Int {
    var result = 0
    for (_, peer) in peers {
        result += peer.userCount
    }
    return result
}

private func stringForSelectiveSettings(strings: PresentationStrings, settings: SelectivePrivacySettings) -> String {
    switch settings {
        case let .disableEveryone(enableFor):
            if enableFor.isEmpty {
                return strings.PrivacySettings_LastSeenNobody
            } else {
                return strings.PrivacySettings_LastSeenNobodyPlus("\(countForSelectivePeers(enableFor))").string
            }
        case let .enableEveryone(disableFor):
            if disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenEverybody
            } else {
                return strings.PrivacySettings_LastSeenEverybodyMinus("\(countForSelectivePeers(disableFor))").string
            }
        case let .enableContacts(enableFor, disableFor):
            if !enableFor.isEmpty && !disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsMinusPlus("\(countForSelectivePeers(disableFor))", "\(countForSelectivePeers(enableFor))").string
            } else if !enableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsPlus("\(countForSelectivePeers(enableFor))").string
            } else if !disableFor.isEmpty {
                return strings.PrivacySettings_LastSeenContactsMinus("\(countForSelectivePeers(disableFor))").string
            } else {
                return strings.PrivacySettings_LastSeenContacts
            }
    }
}

private func privacyAndSecurityControllerEntries(
    presentationData: PresentationData,
    state: PrivacyAndSecurityControllerState,
    privacySettings: AccountPrivacySettings?,
    accessChallengeData: PostboxAccessChallengeData,
    blockedPeerCount: Int?,
    activeWebsitesCount: Int,
    hasTwoStepAuth: Bool?,
    twoStepAuthData: TwoStepVerificationAccessConfiguration?,
    canAutoarchive: Bool,
    isPremiumDisabled: Bool,
    isPremium: Bool,
    loginEmail: String?
) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    entries.append(.blockedPeers(presentationData.theme, presentationData.strings.Settings_BlockedUsers, blockedPeerCount == nil ? "" : (blockedPeerCount == 0 ? presentationData.strings.PrivacySettings_BlockedPeersEmpty : "\(blockedPeerCount!)")))
    if activeWebsitesCount != 0 {
        entries.append(.activeSessions(presentationData.theme, presentationData.strings.PrivacySettings_WebSessions, activeWebsitesCount == 0 ? "" : "\(activeWebsitesCount)"))
    }
    
    let passcodeValue: String
    switch accessChallengeData {
        case .none:
            passcodeValue = presentationData.strings.PrivacySettings_PasscodeOff
        default:
            passcodeValue = presentationData.strings.PrivacySettings_PasscodeOn
    }
    
    if let biometricAuthentication = LocalAuth.biometricAuthentication {
        switch biometricAuthentication {
            case .touchId:
                entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_PasscodeAndTouchId, false, passcodeValue))
            case .faceId:
                entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_PasscodeAndFaceId, true, passcodeValue))
        }
    } else {
        entries.append(.passcode(presentationData.theme, presentationData.strings.PrivacySettings_Passcode, false, passcodeValue))
    }
    var twoStepAuthString = ""
    if let hasTwoStepAuth = hasTwoStepAuth {
        twoStepAuthString = hasTwoStepAuth ? presentationData.strings.PrivacySettings_PasscodeOn : presentationData.strings.PrivacySettings_PasscodeOff
    }
    entries.append(.twoStepVerification(presentationData.theme, presentationData.strings.PrivacySettings_TwoStepAuth, twoStepAuthString, twoStepAuthData))
    
    if loginEmail != nil {
        entries.append(.loginEmail(presentationData.theme, presentationData.strings.PrivacySettings_LoginEmail, loginEmail))
        entries.append(.loginEmailInfo(presentationData.theme, presentationData.strings.PrivacySettings_LoginEmailInfo))
    }
    
    entries.append(.privacyHeader(presentationData.theme, presentationData.strings.PrivacySettings_PrivacyTitle))
    if let privacySettings = privacySettings {
        entries.append(.phoneNumberPrivacy(presentationData.theme, presentationData.strings.PrivacySettings_PhoneNumber, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.phoneNumber)))
        entries.append(.lastSeenPrivacy(presentationData.theme, presentationData.strings.PrivacySettings_LastSeen, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.presence)))
        entries.append(.profilePhotoPrivacy(presentationData.theme, presentationData.strings.Privacy_ProfilePhoto, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.profilePhoto)))
        entries.append(.voiceCallPrivacy(presentationData.theme, presentationData.strings.Privacy_Calls, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.voiceCalls)))
        if !isPremiumDisabled {
            entries.append(.voiceMessagePrivacy(presentationData.theme, presentationData.strings.Privacy_VoiceMessages, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.voiceMessages), !isPremium))
        }
        entries.append(.forwardPrivacy(presentationData.theme, presentationData.strings.Privacy_Forwards, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.forwards)))
        entries.append(.groupPrivacy(presentationData.theme, presentationData.strings.Privacy_GroupsAndChannels, stringForSelectiveSettings(strings: presentationData.strings, settings: privacySettings.groupInvitations)))
        
        entries.append(.selectivePrivacyInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_GroupsAndChannelsHelp))
    } else {
        entries.append(.lastSeenPrivacy(presentationData.theme, presentationData.strings.PrivacySettings_LastSeen, presentationData.strings.Channel_NotificationLoading))
        entries.append(.profilePhotoPrivacy(presentationData.theme, presentationData.strings.Privacy_ProfilePhoto, presentationData.strings.Channel_NotificationLoading))
        entries.append(.voiceCallPrivacy(presentationData.theme, presentationData.strings.Privacy_Calls, presentationData.strings.Channel_NotificationLoading))
        if !isPremiumDisabled {
            entries.append(.voiceMessagePrivacy(presentationData.theme, presentationData.strings.Privacy_VoiceMessages, presentationData.strings.Channel_NotificationLoading, !isPremium))
        }
        entries.append(.forwardPrivacy(presentationData.theme, presentationData.strings.Privacy_Forwards, presentationData.strings.Channel_NotificationLoading))
        entries.append(.groupPrivacy(presentationData.theme, presentationData.strings.Privacy_GroupsAndChannels, presentationData.strings.Channel_NotificationLoading))
        entries.append(.selectivePrivacyInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_GroupsAndChannelsHelp))
    }
    
    if canAutoarchive {
        entries.append(.autoArchiveHeader(presentationData.strings.PrivacySettings_AutoArchiveTitle.uppercased()))
        if let privacySettings = privacySettings {
            let automaticallyArchiveAndMuteNonContactsValue: Bool
            if let automaticallyArchiveAndMuteNonContacts = state.updatingAutomaticallyArchiveAndMuteNonContacts {
                automaticallyArchiveAndMuteNonContactsValue = automaticallyArchiveAndMuteNonContacts
            } else {
                automaticallyArchiveAndMuteNonContactsValue = privacySettings.automaticallyArchiveAndMuteNonContacts
            }
            
            entries.append(.autoArchive(presentationData.strings.PrivacySettings_AutoArchive, automaticallyArchiveAndMuteNonContactsValue))
        } else {
            entries.append(.autoArchive(presentationData.strings.PrivacySettings_AutoArchive, false))
        }
        entries.append(.autoArchiveInfo(presentationData.strings.PrivacySettings_AutoArchiveInfo))
    }
    
    entries.append(.accountHeader(presentationData.theme, presentationData.strings.PrivacySettings_DeleteAccountTitle.uppercased()))
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
    
    entries.append(.dataSettings(presentationData.theme, presentationData.strings.PrivacySettings_DataSettings))
    entries.append(.dataSettingsInfo(presentationData.theme, presentationData.strings.PrivacySettings_DataSettingsHelp))
    
    return entries
}

class PrivacyAndSecurityControllerImpl: ItemListController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var authorizationCompletion: ((Any) -> Void)?
    
    @available(iOS 13.0, *)
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        self.authorizationCompletion?(authorization.credential)
    }
    
    @available(iOS 13.0, *)
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}

public func privacyAndSecurityController(context: AccountContext, initialSettings: AccountPrivacySettings? = nil, updatedSettings: ((AccountPrivacySettings?) -> Void)? = nil, updatedBlockedPeers: ((BlockedPeersContext?) -> Void)? = nil, updatedHasTwoStepAuth: ((Bool) -> Void)? = nil, focusOnItemTag: PrivacyAndSecurityEntryTag? = nil, activeSessionsContext: ActiveSessionsContext? = nil, webSessionsContext: WebSessionsContext? = nil, blockedPeersContext: BlockedPeersContext? = nil, hasTwoStepAuth: Bool? = nil, loginEmailPattern: Signal<String?, NoError>? = nil, updatedTwoStepAuthData: (() -> Void)? = nil) -> ViewController {
    let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
    let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController, Bool) -> Void)?
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let actionsDisposable = DisposableSet()
    
    let currentInfoDisposable = MetaDisposable()
    actionsDisposable.add(currentInfoDisposable)
    
    let updateAccountTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateAccountTimeoutDisposable)
    
    let updateAutoArchiveDisposable = MetaDisposable()
    actionsDisposable.add(updateAutoArchiveDisposable)
    
    let privacySettingsPromise = Promise<AccountPrivacySettings?>()
    privacySettingsPromise.set(.single(initialSettings) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
        
    let blockedPeersContext = blockedPeersContext ?? BlockedPeersContext(account: context.account)
    let activeSessionsContext = activeSessionsContext ?? context.engine.privacy.activeSessions()
    let webSessionsContext = webSessionsContext ?? context.engine.privacy.webSessions()
    
    let blockedPeersState = Promise<BlockedPeersContextState>()
    blockedPeersState.set(blockedPeersContext.state)
    
    webSessionsContext.loadMore()
    
    let updateTwoStepAuthDisposable = MetaDisposable()
    actionsDisposable.add(updateTwoStepAuthDisposable)
    
    let twoStepAuthDataValue = Promise<TwoStepVerificationAccessConfiguration?>(nil)
    let hasTwoStepAuthDataValue = twoStepAuthDataValue.get()
    |> mapToSignal { data -> Signal<Bool?, NoError> in
        if let data = data {
            if case .set = data {
                return .single(true)
            } else {
                return .single(false)
            }
        } else {
            return .single(hasTwoStepAuth)
        }
    }
    
    let twoStepAuth = Promise<Bool?>()
    if let hasTwoStepAuth = hasTwoStepAuth {
        twoStepAuth.set(.single(hasTwoStepAuth) |> then(hasTwoStepAuthDataValue))
    } else {
        twoStepAuth.set(hasTwoStepAuthDataValue)
    }
    
    let loginEmail: Signal<String?, NoError>
    if let loginEmailPattern = loginEmailPattern {
        loginEmail = loginEmailPattern
    } else {
        loginEmail = .single(nil)
        |> then(
            context.engine.auth.twoStepAuthData()
            |> map(Optional.init)
            |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                return .single(nil)
            }
            |> map { data -> String? in
                return data?.loginEmailPattern
            }
        )
    }
    
    let updateHasTwoStepAuth: () -> Void = {
        let signal = context.engine.auth.twoStepVerificationConfiguration()
        |> map { value -> TwoStepVerificationAccessConfiguration? in
            return TwoStepVerificationAccessConfiguration(configuration: value, password: nil)
        }
        |> deliverOnMainQueue
        updateTwoStepAuthDisposable.set(
            signal.start(next: { value in
                twoStepAuthDataValue.set(.single(value))
                if let value = value {
                    if case .set = value {
                        updatedHasTwoStepAuth?(true)
                    } else {
                        updatedHasTwoStepAuth?(false)
                    }
                }
            })
        )
    }
    updateHasTwoStepAuth()
    
    var setupEmailImpl: ((String?) -> Void)?
    
    let arguments = PrivacyAndSecurityControllerArguments(account: context.account, openBlockedUsers: {
        pushControllerImpl?(blockedPeersController(context: context, blockedPeersContext: blockedPeersContext), true)
    }, openLastSeenPrivacy: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .presence, current: info.presence, updated: { updated, _, _ in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                            }
                            return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openGroupsPrivacy: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .groupInvitations, current: info.groupInvitations, updated: { updated, _, _ in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                            }
                            return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openVoiceCallPrivacy: {
        let privacySignal = privacySettingsPromise.get()
        |> take(1)
        
        let callsSignal = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration]))
        |> take(1)
        |> map { sharedData, view -> (VoiceCallSettings, VoipConfiguration) in
            let voiceCallSettings: VoiceCallSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
            let voipConfiguration = view.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
            
            return (voiceCallSettings, voipConfiguration)
        }
        
        currentInfoDisposable.set((combineLatest(privacySignal, callsSignal)
        |> deliverOnMainQueue).start(next: { [weak currentInfoDisposable] info, callSettings in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .voiceCalls, current: info.voiceCalls, callSettings: (info.voiceCallsP2P, callSettings.0), voipConfiguration: callSettings.1, callIntegrationAvailable: CallKitIntegration.isAvailable, updated: { updated, updatedCallSettings, _ in
                    if let currentInfoDisposable = currentInfoDisposable, let (updatedCallsPrivacy, updatedCallSettings) = updatedCallSettings  {
                        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
                            return updatedCallSettings
                        }).start()
                        
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, voiceCallsP2P: updatedCallsPrivacy, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                            }
                            return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openProfilePhotoPrivacy: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .profilePhoto, current: info.profilePhoto, updated: { updated, _, _ in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: updated, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                            }
                            return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openForwardPrivacy: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .forwards, current: info.forwards, updated: { updated, _, _ in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: updated, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openPhoneNumberPrivacy: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .phoneNumber, current: info.phoneNumber, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, updated: { updated, _, updatedDiscoveryEnabled in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: updated, phoneDiscoveryEnabled: updatedDiscoveryEnabled ?? value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                            }
                            return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }), true)
            }
        }))
    }, openVoiceMessagePrivacy: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let signal = combineLatest(
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
            privacySettingsPromise.get()
        )
        |> take(1)
        |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] peer, info in
            let isPremium = peer?.isPremium ?? false
            
            if isPremium {
                if let info = info {
                    pushControllerImpl?(selectivePrivacySettingsController(context: context, kind: .voiceMessages, current: info.voiceMessages, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: updated, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }), true)
                }
            } else {
                let hapticFeedback = HapticFeedback()
                hapticFeedback.impact()
                
                var alreadyPresented = false
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Privacy_VoiceMessages_Tooltip), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                    if action == .info {
                        if !alreadyPresented {
                            let controller = PremiumIntroScreen(context: context, source: .settings)
                            pushControllerImpl?(controller, true)
                            alreadyPresented = true
                        }
                        return true
                    }
                    return false
                }))
            }
        }))
    }, openPasscode: {
        let _ = passcodeOptionsAccessController(context: context, pushController: { controller in
            replaceTopControllerImpl?(controller)
        }, completion: { _ in
            replaceTopControllerImpl?(passcodeOptionsController(context: context))
        }).start(next: { controller in
            if let controller = controller {
                pushControllerImpl?(controller, true)
            }
        })
    }, openTwoStepVerification: { data in
        if let data = data {
            switch data {
            case .set:
                break
            case let .notSet(pendingEmail):
                if pendingEmail == nil {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
                        title: presentationData.strings.TwoFactorSetup_Intro_Title,
                        text: presentationData.strings.TwoFactorSetup_Intro_Text,
                        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
                        doneText: presentationData.strings.TwoFactorSetup_Done_Action
                    )))

                    pushControllerImpl?(controller, true)
                    return
                }
            }
        }

        let controller = twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: false, data: data.flatMap({ Signal<TwoStepVerificationUnlockSettingsControllerData, NoError>.single(.access(configuration: $0)) })))
        pushControllerImpl?(controller, true)
    }, openActiveSessions: {
        pushControllerImpl?(recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext, websitesOnly: true), true)
    }, toggleArchiveAndMuteNonContacts: { archiveValue in
        updateState { state in
            var state = state
            state.updatingAutomaticallyArchiveAndMuteNonContacts = archiveValue
            return state
        }
        let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { value -> Signal<Void, NoError> in
            if let value = value {
                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: archiveValue, accountRemovalTimeout: value.accountRemovalTimeout)))
            }
            return .complete()
        }
        
        updateAutoArchiveDisposable.set((context.engine.privacy.updateAccountAutoArchiveChats(value: archiveValue)
        |> mapToSignal { _ -> Signal<Void, NoError> in }
        |> then(applyTimeout)
        |> deliverOnMainQueue).start(completed: {
            updateState { state in
                var state = state
                state.updatingAutomaticallyArchiveAndMuteNonContacts = nil
                return state
            }
        }))
    }, setupAccountAutoremove: {
        let signal = privacySettingsPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable] privacySettingsValue in
            if let _ = privacySettingsValue {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                let timeoutAction: (Int32) -> Void = { timeout in
                    if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                        updateState { state in
                            var state = state
                            state.updatingAccountTimeoutValue = timeout
                            return state
                        }
                        let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { value -> Signal<Void, NoError> in
                            if let value = value {
                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: timeout)))
                            }
                            return .complete()
                        }
                        updateAccountTimeoutDisposable.set((context.engine.privacy.updateAccountRemovalTimeout(timeout: timeout)
                        |> then(applyTimeout)
                        |> deliverOnMainQueue).start(completed: {
                            updateState { state in
                                var state = state
                                state.updatingAccountTimeoutValue = nil
                                return state
                            }
                        }))
                    }
                }
                let timeoutValues: [Int32] = [
                    1 * 30 * 24 * 60 * 60,
                    3 * 30 * 24 * 60 * 60,
                    6 * 30 * 24 * 60 * 60,
                    365 * 24 * 60 * 60
                ]
                var timeoutItems: [ActionSheetItem] = timeoutValues.map { value in
                    return ActionSheetButtonItem(title: timeIntervalString(strings: presentationData.strings, value: value), action: {
                        dismissAction()
                        timeoutAction(value)
                    })
                }
                timeoutItems.append(ActionSheetButtonItem(title: presentationData.strings.PrivacySettings_DeleteAccountNow, color: .destructive, action: {
                    dismissAction()
                    
                    guard let navigationController = getNavigationControllerImpl?() else {
                        return
                    }
                    
                    let _ = (combineLatest(twoStepAuth.get(), twoStepAuthDataValue.get())
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { hasTwoStepAuth, twoStepAuthData in
                        let optionsController = deleteAccountOptionsController(context: context, navigationController: navigationController, hasTwoStepAuth: hasTwoStepAuth ?? false, twoStepAuthData: twoStepAuthData)
                        pushControllerImpl?(optionsController, true)
                    })
                }))
                controller.setItemGroups([
                    ActionSheetItemGroup(items: timeoutItems),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller)
            }
        }))
    }, openDataSettings: {
        pushControllerImpl?(dataPrivacyController(context: context), true)
    }, openEmailSettings: { emailPattern in
        if let emailPattern = emailPattern {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = textAlertController(
                context: context, title: emailPattern, text: presentationData.strings.PrivacySettings_LoginEmailAlertText, actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.PrivacySettings_LoginEmailAlertChange, action: {
                        setupEmailImpl?(emailPattern)
                    }),
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {
                                        
                    })
                ], actionLayout: .vertical
            )
            presentControllerImpl?(controller)
        } else {
            setupEmailImpl?(nil)
        }
    })
    
    actionsDisposable.add(context.engine.peers.managedUpdatedRecentPeers().start())

    actionsDisposable.add((privacySettingsPromise.get()
    |> deliverOnMainQueue).start(next: { settings in
        updatedSettings?(settings)
    }))
    
    actionsDisposable.add((blockedPeersState.get()
    |> deliverOnMainQueue).start(next: { _ in
        updatedBlockedPeers?(blockedPeersContext)
    }))
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        privacySettingsPromise.get(),
        context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.secretChatLinkPreviewsKey()),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]),
        context.engine.peers.recentPeers(),
        blockedPeersState.get(),
        webSessionsContext.state,
        context.sharedContext.accountManager.accessChallengeData(),
        combineLatest(twoStepAuth.get(), twoStepAuthDataValue.get()),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.App()),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
        loginEmail
    )
    |> map { presentationData, state, privacySettings, noticeView, sharedData, recentPeers, blockedPeersState, activeWebsitesState, accessChallengeData, twoStepAuth, appConfiguration, accountPeer, loginEmail -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var canAutoarchive = false
        if let data = appConfiguration.data, let hasAutoarchive = data["autoarchive_setting_available"] as? Bool {
            canAutoarchive = hasAutoarchive
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        if privacySettings == nil || state.updatingAccountTimeoutValue != nil {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PrivacySettings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let isPremium = accountPeer?.isPremium ?? false
        let isPremiumDisabled = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 }).isPremiumDisabled
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: privacyAndSecurityControllerEntries(presentationData: presentationData, state: state, privacySettings: privacySettings, accessChallengeData: accessChallengeData.data, blockedPeerCount: blockedPeersState.totalCount, activeWebsitesCount: activeWebsitesState.sessions.count, hasTwoStepAuth: twoStepAuth.0, twoStepAuthData: twoStepAuth.1, canAutoarchive: canAutoarchive, isPremiumDisabled: isPremiumDisabled, isPremium: isPremium, loginEmail: loginEmail), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = PrivacyAndSecurityControllerImpl(context: context, state: signal)
    pushControllerImpl = { [weak controller] c, animated in
        (controller?.navigationController as? NavigationController)?.pushViewController(c, animated: animated)
    }
    replaceTopControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: true)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: nil)
    }
    getNavigationControllerImpl = {  [weak controller] in
        return (controller?.navigationController as? NavigationController)
    }

    controller.didAppear = { _ in
        updateHasTwoStepAuth()
    }
    
    let emailChangeCompletion: (AuthorizationSequenceCodeEntryController?) -> Void = { codeController in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        codeController?.animateSuccess()
        
        updatedTwoStepAuthData?()
        
        Queue.mainQueue().after(0.75) {
            if let navigationController = getNavigationControllerImpl?() {
                let controllers = navigationController.viewControllers.filter { controller in
                    if controller is AuthorizationSequenceEmailEntryController || controller is AuthorizationSequenceCodeEntryController {
                        return false
                    } else {
                        return true
                    }
                }
                navigationController.setViewControllers(controllers, animated: true)
                
                Queue.mainQueue().after(0.5, {
                    navigationController.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .emoji(name: "IntroLetter", text: presentationData.strings.Login_EmailChanged), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return false
                    }))
                })
            }
        }
    }
    
    setupEmailImpl = { emailPattern in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var dismissEmailControllerImpl: (() -> Void)?
        var presentControllerImpl: ((ViewController) -> Void)?
        
        let emailController = AuthorizationSequenceEmailEntryController(presentationData: presentationData, mode: emailPattern != nil ? .change : .setup, back: {
            dismissEmailControllerImpl?()
        })
        emailController.proceedWithEmail = { [weak emailController] email in
            emailController?.inProgress = true
            
            actionsDisposable.add((sendLoginEmailChangeCode(account: context.account, email: email)
            |> deliverOnMainQueue).start(next: { data in
                var dismissCodeControllerImpl: (() -> Void)?
                var presentControllerImpl: ((ViewController) -> Void)?
                
                let codeController = AuthorizationSequenceCodeEntryController(presentationData: presentationData, openUrl: { _ in }, back: {
                    dismissCodeControllerImpl?()
                })
                
                presentControllerImpl = { [weak codeController] c in
                    codeController?.present(c, in: .window(.root), with: nil)
                }
                 
                codeController.loginWithCode = { [weak codeController] code in
                    actionsDisposable.add((verifyLoginEmailChange(account: context.account, code: .emailCode(code))
                    |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            codeController?.inProgress = false
                            
                            if case .invalidCode = error {
                                codeController?.animateError(text: presentationData.strings.Login_WrongCodeError)
                            } else {
                                var resetCode = false
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        resetCode = true
                                        text = presentationData.strings.Login_CodeFloodError
                                    case .invalidCode:
                                        resetCode = true
                                        text = presentationData.strings.Login_InvalidCodeError
                                    case .generic:
                                        text = presentationData.strings.Login_UnknownError
                                    case .codeExpired:
                                        text = presentationData.strings.Login_CodeExpired
                                    case .timeout:
                                        text = presentationData.strings.Login_NetworkError
                                    case .invalidEmailToken:
                                        text = presentationData.strings.Login_InvalidEmailTokenError
                                    case .emailNotAllowed:
                                        text = presentationData.strings.Login_EmailNotAllowedError
                                }
                                
                                if resetCode {
                                    codeController?.resetCode()
                                }
                                    
                                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                            }
                        }
                    }, completed: { [weak codeController] in
                       emailChangeCompletion(codeController)
                    }))
                }
                codeController.updateData(number: "", email: email, codeType: .email(emailPattern: "", length: data.length, nextPhoneLoginDate: nil, appleSignInAllowed: false, setup: true), nextType: nil, timeout: nil, termsOfService: nil)
                pushControllerImpl?(codeController, true)
                dismissCodeControllerImpl = { [weak codeController] in
                    codeController?.dismiss()
                }
            }, error: { [weak emailController] error in
                emailController?.inProgress = false
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Login_CodeFloodError
                    case .generic, .codeExpired:
                        text = presentationData.strings.Login_UnknownError
                    case .timeout:
                        text = presentationData.strings.Login_NetworkError
                    case .invalidEmail:
                        text = presentationData.strings.Login_InvalidEmailError
                    case .emailNotAllowed:
                        text = presentationData.strings.Login_EmailNotAllowedError
                }
                
                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
            }, completed: { [weak emailController] in
                emailController?.inProgress = false
            }))
        }
        emailController.signInWithApple = { [weak controller, weak emailController] in
            if #available(iOS 13.0, *) {
                let appleIdProvider = ASAuthorizationAppleIDProvider()
                let request = appleIdProvider.createRequest()
                request.requestedScopes = [.email]

                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                authorizationController.delegate = controller
                authorizationController.presentationContextProvider = controller
                authorizationController.performRequests()
                
                controller?.authorizationCompletion = { [weak controller, weak emailController] credential in
                    guard let credential = credential as? ASAuthorizationCredential else {
                        return
                    }
                    switch credential {
                        case let appleIdCredential as ASAuthorizationAppleIDCredential:
                            guard let tokenData = appleIdCredential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                                emailController?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                return
                            }
                            actionsDisposable.add((verifyLoginEmailChange(account: context.account, code: .appleToken(token))
                            |> deliverOnMainQueue).start(error: { error in
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = presentationData.strings.Login_CodeFloodError
                                    case .generic, .codeExpired:
                                        text = presentationData.strings.Login_UnknownError
                                    case .invalidCode:
                                        text = presentationData.strings.Login_InvalidCodeError
                                    case .timeout:
                                        text = presentationData.strings.Login_NetworkError
                                    case .invalidEmailToken:
                                        text = presentationData.strings.Login_InvalidEmailTokenError
                                    case .emailNotAllowed:
                                        text = presentationData.strings.Login_EmailNotAllowedError
                                }
                                emailController?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }, completed: { [weak controller] in
                                controller?.authorizationCompletion = nil
                                emailChangeCompletion(nil)
                            }))
                        default:
                            break
                    }
                }
            }
        }
        emailController.updateData(appleSignInAllowed: true)
        pushControllerImpl?(emailController, true)
        
        presentControllerImpl = { [weak emailController] c in
            emailController?.present(c, in: .window(.root), with: nil)
        }
        
        dismissEmailControllerImpl = { [weak emailController] in
            emailController?.dismiss()
        }
    }
    
    return controller
}
