import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess

private let maximumNumberOfAccounts = 3

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 13.0)!

private enum SettingsEntryTag: Equatable, ItemListItemTag {
    case account(AccountRecordId)
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? SettingsEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private struct SettingsItemArguments {
    let accountManager: AccountManager
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    
    let avatarTapAction: () -> Void
    
    let changeProfilePhoto: () -> Void
    let openUsername: () -> Void
    let openProxy: () -> Void
    let openSavedMessages: () -> Void
    let openRecentCalls: () -> Void
    let openPrivacyAndSecurity: (AccountPrivacySettings?) -> Void
    let openDataAndStorage: () -> Void
    let openStickerPacks: ([ArchivedStickerPackItem]?) -> Void
    let openNotificationsAndSounds: (NotificationExceptionsList?) -> Void
    let openThemes: () -> Void
    let pushController: (ViewController) -> Void
    let openLanguage: () -> Void
    let openPassport: () -> Void
    let openWatch: () -> Void
    let openSupport: () -> Void
    let openFaq: (String?) -> Void
    let openEditing: () -> Void
    let displayCopyContextMenu: () -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let addAccount: () -> Void
    let setAccountIdWithRevealedOptions: (AccountRecordId?, AccountRecordId?) -> Void
    let removeAccount: (AccountRecordId) -> Void
    let keepPhone: () -> Void
    let openPhoneNumberChange: () -> Void
}

private enum SettingsSection: Int32 {
    case info
    case phone
    case accounts
    case proxy
    case media
    case generalSettings
    case advanced
    case help
}

private enum SettingsEntry: ItemListNodeEntry {
    case userInfo(Account, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, CachedPeerData?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setProfilePhoto(PresentationTheme, String)
    case setUsername(PresentationTheme, String)
    
    case phoneInfo(PresentationTheme, String, String)
    case keepPhone(PresentationTheme, String)
    case changePhone(PresentationTheme, String)
    
    case account(Int, Account, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, Int32, Bool)
    case addAccount(PresentationTheme, String)
    
    case proxy(PresentationTheme, UIImage?, String, String)
    
    case savedMessages(PresentationTheme, UIImage?, String)
    case recentCalls(PresentationTheme, UIImage?, String)
    case stickers(PresentationTheme, UIImage?, String, String, [ArchivedStickerPackItem]?)
    
    case notificationsAndSounds(PresentationTheme, UIImage?, String, NotificationExceptionsList?, Bool)
    case privacyAndSecurity(PresentationTheme, UIImage?, String, AccountPrivacySettings?)
    case dataAndStorage(PresentationTheme, UIImage?, String)
    case themes(PresentationTheme, UIImage?, String)
    case language(PresentationTheme, UIImage?, String, String)
    case passport(PresentationTheme, UIImage?, String, String)
    case watch(PresentationTheme, UIImage?, String, String)
    
    case askAQuestion(PresentationTheme, UIImage?, String)
    case faq(PresentationTheme, UIImage?, String)
    
    var section: ItemListSectionId {
        switch self {
            case .userInfo, .setProfilePhoto, .setUsername:
                return SettingsSection.info.rawValue
            case .phoneInfo, .keepPhone, .changePhone:
                return SettingsSection.phone.rawValue
            case .account, .addAccount:
                return SettingsSection.accounts.rawValue
            case .proxy:
                return SettingsSection.proxy.rawValue
            case .savedMessages, .recentCalls, .stickers:
                return SettingsSection.media.rawValue
            case .notificationsAndSounds, .privacyAndSecurity, .dataAndStorage, .themes, .language:
                return SettingsSection.generalSettings.rawValue
            case .passport, .watch :
                return SettingsSection.advanced.rawValue
            case .askAQuestion, .faq:
                return SettingsSection.help.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .userInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case .setUsername:
                return 2
            case .phoneInfo:
                return 3
            case .keepPhone:
                return 4
            case .changePhone:
                return 5
            case let .account(account):
                return 6 + Int32(account.0)
            case .addAccount:
                return 1002
            case .proxy:
                return 1003
            case .savedMessages:
                return 1004
            case .recentCalls:
                return 1005
            case .stickers:
                return 1006
            case .notificationsAndSounds:
                return 1007
            case .privacyAndSecurity:
                return 1008
            case .dataAndStorage:
                return 1009
            case .themes:
                return 1010
            case .language:
                return 1011
            case .passport:
                return 1012
            case .watch:
                return 1013
            case .askAQuestion:
                return 1014
            case .faq:
                return 1015
        }
    }
    
    static func ==(lhs: SettingsEntry, rhs: SettingsEntry) -> Bool {
        switch lhs {
            case let .userInfo(lhsAccount, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsCachedData, lhsEditingState, lhsUpdatingImage):
                if case let .userInfo(rhsAccount, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsCachedData, rhsEditingState, rhsUpdatingImage) = rhs {
                    if lhsAccount !== rhsAccount {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                        if !lhsCachedData.isEqual(to: rhsCachedData) {
                            return false
                        }
                    } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                        return false
                    }
                    if lhsEditingState != rhsEditingState {
                        return false
                    }
                    if lhsUpdatingImage != rhsUpdatingImage {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .account(lhsIndex, lhsAccount, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsBadgeCount, lhsRevealed):
                if case let .account(rhsIndex, rhsAccount, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsBadgeCount, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsAccount === rhsAccount, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsPeer.isEqual(rhsPeer), lhsBadgeCount == rhsBadgeCount, lhsRevealed == rhsRevealed {
                    return true
                } else {
                    return false
                }
            case let .phoneInfo(lhsTheme, lhsTitle, lhsText):
                if case let .phoneInfo(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .keepPhone(lhsTheme, lhsText):
                if case let .keepPhone(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .changePhone(lhsTheme, lhsText):
                if case let .changePhone(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addAccount(lhsTheme, lhsText):
                if case let .addAccount(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .setProfilePhoto(lhsTheme, lhsText):
                if case let .setProfilePhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .setUsername(lhsTheme, lhsText):
                if case let .setUsername(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .proxy(lhsTheme, lhsImage, lhsText, lhsValue):
                if case let .proxy(rhsTheme, rhsImage, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .savedMessages(lhsTheme, lhsImage, lhsText):
                if case let .savedMessages(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .recentCalls(lhsTheme, lhsImage, lhsText):
                if case let .recentCalls(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .stickers(lhsTheme, lhsImage, lhsText, lhsValue, _):
                if case let .stickers(rhsTheme, rhsImage, rhsText, rhsValue, _) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .notificationsAndSounds(lhsTheme, lhsImage, lhsText, lhsExceptionsList, lhsWarning):
                if case let .notificationsAndSounds(rhsTheme, rhsImage, rhsText, rhsExceptionsList, rhsWarning) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsExceptionsList == rhsExceptionsList, lhsWarning == rhsWarning {
                    return true
                } else {
                    return false
                }
            case let .privacyAndSecurity(lhsTheme, lhsImage, lhsText, lhsSettings):
                if case let .privacyAndSecurity(rhsTheme, rhsImage, rhsText, rhsSettings) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsSettings == rhsSettings {
                    return true
                } else {
                    return false
                }
            case let .dataAndStorage(lhsTheme, lhsImage, lhsText):
                if case let .dataAndStorage(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themes(lhsTheme, lhsImage, lhsText):
                if case let .themes(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .language(lhsTheme, lhsImage, lhsText, lhsValue):
                if case let .language(rhsTheme, rhsImage, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .passport(lhsTheme, lhsImage, lhsText, lhsValue):
                if case let .passport(rhsTheme, rhsImage, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .watch(lhsTheme, lhsImage, lhsText, lhsValue):
                if case let .watch(rhsTheme, rhsImage, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .askAQuestion(lhsTheme, lhsImage, lhsText):
                if case let .askAQuestion(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .faq(lhsTheme, lhsImage, lhsText):
                if case let .faq(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: SettingsEntry, rhs: SettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: SettingsItemArguments) -> ListViewItem {
        switch self {
            case let .userInfo(account, theme, strings, dateTimeFormat, peer, cachedData, state, updatingImage):
                return ItemListAvatarAndNameInfoItem(account: account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .settings, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max), lastActivity: 0), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { _ in
                }, avatarTapped: {
                    arguments.avatarTapAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingImage, action: {
                    arguments.openEditing()
                }, longTapAction: {
                    arguments.displayCopyContextMenu()
                })
            case let .setProfilePhoto(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .setUsername(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openUsername()
                })
            case let .phoneInfo(theme, title, text):
                return ItemListInfoItem(theme: theme, title: title, text: .markdown(text), style: .blocks, sectionId: self.section, linkAction: { action in
                    if case .tap = action {
                        arguments.openFaq("q-i-have-a-new-phone-number-what-do-i-do")
                    }
                }, closeAction: nil)
            case let .keepPhone(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.keepPhone()
                })
            case let .changePhone(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPhoneNumberChange()
                })
            case let .account(_, account, theme, strings, dateTimeFormat, peer, badgeCount, revealed):
                var label: ItemListPeerItemLabel = .none
                if badgeCount > 0 {
                    label = .badge(compactNumericCountString(Int(badgeCount), decimalSeparator: dateTimeFormat.decimalSeparator))
                }
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .dayFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: ""), nameDisplayOrder: .firstLast, account: account, peer: peer, aliasHandling: .standard, nameStyle: .plain, presence: nil, text: .none, label: label, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.switchToAccount(account.id)
                }, setPeerIdWithRevealedOptions: { lhs, rhs in
                    var lhsAccountId: AccountRecordId?
                    if lhs == peer.id {
                        lhsAccountId = account.id
                    }
                    var rhsAccountId: AccountRecordId?
                    if rhs == peer.id {
                        rhsAccountId = account.id
                    }
                    arguments.setAccountIdWithRevealedOptions(lhsAccountId, rhsAccountId)
                }, removePeer: { _ in
                    arguments.removeAccount(account.id)
                }, tag: SettingsEntryTag.account(account.id))
            case let .addAccount(theme, text):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                    arguments.addAccount()
                })
            case let .proxy(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openProxy()
                }, clearHighlightAutomatically: false)
            case let .savedMessages(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSavedMessages()
                }, clearHighlightAutomatically: false)
            case let .recentCalls(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openRecentCalls()
                }, clearHighlightAutomatically: false)
            case let .stickers(theme, image, text, value, archivedPacks):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, labelStyle: .badge(theme.list.itemAccentColor), sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openStickerPacks(archivedPacks)
                }, clearHighlightAutomatically: false)
            case let .notificationsAndSounds(theme, image, text, exceptionsList, warning):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: warning ? "!" : "", labelStyle: warning ? .badge(theme.list.itemDestructiveColor) : .text, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openNotificationsAndSounds(exceptionsList)
                }, clearHighlightAutomatically: false)
            case let .privacyAndSecurity(theme, image, text, privacySettings):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPrivacyAndSecurity(privacySettings)
                }, clearHighlightAutomatically: false)
            case let .dataAndStorage(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openDataAndStorage()
                }, clearHighlightAutomatically: false)
            case let .themes(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openThemes()
                }, clearHighlightAutomatically: false)
            case let .language(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openLanguage()
                }, clearHighlightAutomatically: false)
            case let .passport(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPassport()
                })
            case let .watch(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openWatch()
                }, clearHighlightAutomatically: false)
            case let .askAQuestion(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSupport()
                })
            case let .faq(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openFaq(nil)
                }, clearHighlightAutomatically: false)
        }
    }
}

private struct SettingsState: Equatable {
    var updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    var accountIdWithRevealedOptions: AccountRecordId?
    var isSearching: Bool
}

private func settingsEntries(account: Account, presentationData: PresentationData, state: SettingsState, view: PeerView, proxySettings: ProxySettings, notifyExceptions: NotificationExceptionsList?, notificationsAuthorizationStatus: AccessType, notificationsWarningSuppressed: Bool, unreadTrendingStickerPacks: Int, archivedPacks: [ArchivedStickerPackItem]?, privacySettings: AccountPrivacySettings?, hasPassport: Bool, hasWatchApp: Bool, accountsAndPeers: [(Account, Peer, Int32)], inAppNotificationSettings: InAppNotificationSettings, displayPhoneNumberConfirmation: Bool) -> [SettingsEntry] {
    var entries: [SettingsEntry] = []
    
    if let peer = peerViewMainPeer(view) as? TelegramUser {
        let userInfoState = ItemListAvatarAndNameInfoItemState(editingName: nil, updatingName: nil)
        entries.append(.userInfo(account, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, view.cachedData, userInfoState, state.updatingAvatar))
        if peer.photo.isEmpty {
            entries.append(.setProfilePhoto(presentationData.theme, presentationData.strings.Settings_SetProfilePhoto))
        }
        if peer.addressName == nil {
            entries.append(.setUsername(presentationData.theme, presentationData.strings.Settings_SetUsername))
        }
        
        if displayPhoneNumberConfirmation {
            let phoneNumber = formatPhoneNumber(peer.phone ?? "")
            entries.append(.phoneInfo(presentationData.theme, presentationData.strings.Settings_CheckPhoneNumberTitle(phoneNumber).0, presentationData.strings.Settings_CheckPhoneNumberText))
            entries.append(.keepPhone(presentationData.theme, presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).0))
            entries.append(.changePhone(presentationData.theme, presentationData.strings.Settings_ChangePhoneNumber))
        }
        
        if !accountsAndPeers.isEmpty {
            var index = 0
            for (peerAccount, peer, badgeCount) in accountsAndPeers {
                entries.append(.account(index, peerAccount, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, inAppNotificationSettings.displayNotificationsFromAllAccounts ? badgeCount : 0, state.accountIdWithRevealedOptions == peerAccount.id))
                index += 1
            }
            if accountsAndPeers.count + 1 < maximumNumberOfAccounts {
                entries.append(.addAccount(presentationData.theme, presentationData.strings.Settings_AddAccount))
            }
        }
        
        if !proxySettings.servers.isEmpty {
            let valueString: String
            if proxySettings.enabled, let activeServer = proxySettings.activeServer {
                switch activeServer.connection {
                    case .mtp:
                        valueString = presentationData.strings.SocksProxySetup_ProxyTelegram
                    case .socks5:
                        valueString = presentationData.strings.SocksProxySetup_ProxySocks5
                }
            } else {
                valueString = presentationData.strings.Settings_ProxyDisabled
            }
            entries.append(.proxy(presentationData.theme, PresentationResourcesSettings.proxy, presentationData.strings.Settings_Proxy, valueString))
        }
        
        entries.append(.savedMessages(presentationData.theme, PresentationResourcesSettings.savedMessages, presentationData.strings.Settings_SavedMessages))
        entries.append(.recentCalls(presentationData.theme, PresentationResourcesSettings.recentCalls, presentationData.strings.CallSettings_RecentCalls))
        entries.append(.stickers(presentationData.theme, PresentationResourcesSettings.stickers, presentationData.strings.ChatSettings_Stickers, unreadTrendingStickerPacks == 0 ? "" : "\(unreadTrendingStickerPacks)", archivedPacks))
        
        let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
        entries.append(.notificationsAndSounds(presentationData.theme, PresentationResourcesSettings.notifications, presentationData.strings.Settings_NotificationsAndSounds, notifyExceptions, notificationsWarning))
        entries.append(.privacyAndSecurity(presentationData.theme, PresentationResourcesSettings.security, presentationData.strings.Settings_PrivacySettings, privacySettings))
        entries.append(.dataAndStorage(presentationData.theme, PresentationResourcesSettings.dataAndStorage, presentationData.strings.Settings_ChatSettings))
        entries.append(.themes(presentationData.theme, PresentationResourcesSettings.appearance, presentationData.strings.Settings_Appearance))
        let languageName = presentationData.strings.primaryComponent.localizedName
        entries.append(.language(presentationData.theme, PresentationResourcesSettings.language, presentationData.strings.Settings_AppLanguage, languageName.isEmpty ? presentationData.strings.Localization_LanguageName : languageName))
        
        if hasPassport {
            entries.append(.passport(presentationData.theme, PresentationResourcesSettings.passport, presentationData.strings.Settings_Passport, ""))
        }
        if hasWatchApp {
            entries.append(.watch(presentationData.theme, PresentationResourcesSettings.watch, presentationData.strings.Settings_AppleWatch, ""))
        }
        
        entries.append(.askAQuestion(presentationData.theme, PresentationResourcesSettings.support, presentationData.strings.Settings_Support))
        entries.append(.faq(presentationData.theme, PresentationResourcesSettings.faq, presentationData.strings.Settings_FAQ))
    }
    
    return entries
}

public protocol SettingsController: class {
    func updateContext(context: AccountContext)
}

private final class SettingsControllerImpl: ItemListController<SettingsEntry>, SettingsController, TabBarContainedController {
    let sharedContext: SharedAccountContext
    let contextValue: Promise<AccountContext>
    var accountsAndPeersValue: ((Account, Peer)?, [(Account, Peer, Int32)])?
    var accountsAndPeersDisposable: Disposable?
    
    var switchToAccount: ((AccountRecordId) -> Void)?
    var addAccount: (() -> Void)?
    
    weak var switchController: TabBarAccountSwitchController?
    
    override var navigationBarRequiresEntireLayoutUpdate: Bool {
        return false
    }

    init(currentContext: AccountContext, contextValue: Promise<AccountContext>, state: Signal<(ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?, accountsAndPeers: Signal<((Account, Peer)?, [(Account, Peer, Int32)]), NoError>) {
        self.sharedContext = currentContext.sharedContext
        self.contextValue = contextValue
        let presentationData = currentContext.sharedContext.currentPresentationData.with { $0 }
        
        self.contextValue.set(.single(currentContext))
        
        let updatedPresentationData = self.contextValue.get()
        |> mapToSignal { context -> Signal<(theme: PresentationTheme, strings: PresentationStrings), NoError> in
            return context.sharedContext.presentationData
            |> map { ($0.theme, $0.strings) }
        }
        
        super.init(theme: presentationData.theme, strings: presentationData.strings, updatedPresentationData: updatedPresentationData, state: state, tabBarItem: tabBarItem)
        
        self.accountsAndPeersDisposable = (accountsAndPeers
        |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.accountsAndPeersValue = value
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.accountsAndPeersDisposable?.dispose()
    }
    
    func updateContext(context: AccountContext) {
        //self.contextValue.set(.single(context))
    }
    
    func presentTabBarPreviewingController(sourceNodes: [ASDisplayNode]) {
        guard let (maybePrimary, other) = self.accountsAndPeersValue, let primary = maybePrimary else {
            return
        }
        let controller = TabBarAccountSwitchController(sharedContext: self.sharedContext, accounts: (primary, other), canAddAccounts: other.count + 1 < maximumNumberOfAccounts, switchToAccount: { [weak self] id in
            self?.switchToAccount?(id)
        }, addAccount: { [weak self] in
            self?.addAccount?()
        }, sourceNodes: sourceNodes)
        self.switchController = controller
        self.sharedContext.mainWindow?.present(controller, on: .root)
    }
    
    func updateTabBarPreviewingControllerPresentation(_ update: TabBarContainedControllerPresentationUpdate) {
    }
}

public func settingsController(context: AccountContext, accountManager: AccountManager) -> SettingsController & ViewController {
    let initialState = SettingsState(updatingAvatar: nil, accountIdWithRevealedOptions: nil, isSearching: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SettingsState) -> SettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var setDisplayNavigationBarImpl: ((Bool) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    
    let supportPeerDisposable = MetaDisposable()
    actionsDisposable.add(supportPeerDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let updatePassportDisposable = MetaDisposable()
    actionsDisposable.add(updatePassportDisposable)
    
    let openEditingDisposable = MetaDisposable()
    actionsDisposable.add(openEditingDisposable)
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    var changeProfilePhotoImpl: (() -> Void)?
    var openSavedMessagesImpl: (() -> Void)?
    var displayCopyContextMenuImpl: ((Peer) -> Void)?
    
    let archivedPacks = Promise<[ArchivedStickerPackItem]?>()
    
    let contextValue = Promise<AccountContext>()
    let accountsAndPeers = Promise<((Account, Peer)?, [(Account, Peer, Int32)])>()
    accountsAndPeers.set(activeAccountsAndPeers(context: context))
    
    let privacySettings = Promise<AccountPrivacySettings?>(nil)

    let openFaq: (Promise<ResolvedUrl>, String?) -> Void = { resolvedUrl, customAnchor in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            presentControllerImpl?(controller, nil)
            let _ = (resolvedUrl.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] resolvedUrl in
                controller?.dismiss()

                var resolvedUrl = resolvedUrl
                if case let .instantView(webPage, _) = resolvedUrl, let customAnchor = customAnchor {
                    resolvedUrl = .instantView(webPage, customAnchor)
                }
                openResolvedUrl(resolvedUrl, context: context, navigationController: getNavigationControllerImpl?(), openPeer: { peer, navigation in
                }, present: { controller, arguments in
                    pushControllerImpl?(controller)
                }, dismissInput: {})
            })
        })
    }
    
    let resolvedUrl = contextValue.get()
    |> deliverOnMainQueue
    |> mapToSignal { context -> Signal<ResolvedUrl, NoError> in
        return cachedFaqInstantPage(context: context)
    }
    
    var switchToAccountImpl: ((AccountRecordId) -> Void)?
    
    let displayPhoneNumberConfirmation = ValuePromise<Bool>(false)
    
    let arguments = SettingsItemArguments(accountManager: accountManager, avatarAndNameInfoContext: avatarAndNameInfoContext, avatarTapAction: {
        var updating = false
        updateState {
            updating = $0.updatingAvatar != nil
            return $0
        }
        
        if updating {
            return
        }
        
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let _ = (context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { peer in
                if peer.smallProfileImage != nil {
                    let galleryController = AvatarGalleryController(context: context, peer: peer, replaceRootController: { controller, ready in
                        
                    })
                    hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                        avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first?.representation
                        updateHiddenAvatarImpl?()
                    }))
                    presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                        return avatarGalleryTransitionArguments?(entry)
                    }))
                } else {
                    changeProfilePhotoImpl?()
                }
            })
        })
    }, changeProfilePhoto: {
        changeProfilePhotoImpl?()
    }, openUsername: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            presentControllerImpl?(usernameSetupController(context: context), nil)
        })
    }, openProxy: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(proxySettingsController(context: context))
        })
    }, openSavedMessages: {
        openSavedMessagesImpl?()
    }, openRecentCalls: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(CallListController(context: context, mode: .navigation))
        })
    }, openPrivacyAndSecurity: { privacySettingsValue in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(privacyAndSecurityController(context: context, initialSettings: privacySettingsValue, updatedSettings: { settings in
                privacySettings.set(.single(settings))
            }))
        })
    }, openDataAndStorage: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(dataAndStorageController(context: context))
        })
    }, openStickerPacks: { archivedPacksValue in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(installedStickerPacksController(context: context, mode: .general, archivedPacks: archivedPacksValue, updatedPacks: { packs in
                archivedPacks.set(.single(packs))
            }))
        })
    }, openNotificationsAndSounds: { exceptionsList in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(notificationsAndSoundsController(context: context, exceptionsList: exceptionsList))
        })
    }, openThemes: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(themeSettingsController(context: context))
        })
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, openLanguage: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(LocalizationListController(context: context))
        })
    }, openPassport: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            presentControllerImpl?(SecureIdAuthController(context: context, mode: .list), nil)
        })
    }, openWatch: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(watchSettingsController(context: context))
        })
    }, openSupport: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let supportPeer = Promise<PeerId?>()
            supportPeer.set(supportPeerId(account: context.account))
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let resolvedUrlPromise = Promise<ResolvedUrl>()
            resolvedUrlPromise.set(resolvedUrl)
            
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Settings_FAQ_Intro, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: {
                openFaq(resolvedUrlPromise, nil)
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).start(next: { peerId in
                    if let peerId = peerId {
                        pushControllerImpl?(ChatController(context: context, chatLocation: .peer(peerId)))
                    }
                }))
            })]), nil)
        })
    }, openFaq: { anchor in
        let resolvedUrlPromise = Promise<ResolvedUrl>()
        resolvedUrlPromise.set(resolvedUrl)
        openFaq(resolvedUrlPromise, anchor)
    }, openEditing: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            if let presentControllerImpl = presentControllerImpl, let pushControllerImpl = pushControllerImpl {
                openEditingDisposable.set(openEditSettings(context: context, accountsAndPeers: accountsAndPeers.get(), presentController: presentControllerImpl, pushController: pushControllerImpl))
            }
        })
    }, displayCopyContextMenu: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let _ = (context.account.postbox.transaction { transaction -> (Peer?) in
                return transaction.getPeer(context.account.peerId)
            }
            |> deliverOnMainQueue).start(next: { peer in
                if let peer = peer {
                    displayCopyContextMenuImpl?(peer)
                }
            })
        })
    }, switchToAccount: { id in
        switchToAccountImpl?(id)
    }, addAccount: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let isTestingEnvironment = context.account.testingEnvironment
            let _ = accountManager.transaction({ transaction -> Void in
                let _ = transaction.createAuth([AccountEnvironmentAttribute(environment: isTestingEnvironment ? .test : .production)])
            }).start()
        })
    }, setAccountIdWithRevealedOptions: { accountId, fromAccountId in
        updateState { state in
            var state = state
            if (accountId == nil && fromAccountId == state.accountIdWithRevealedOptions) || (accountId != nil && fromAccountId == nil) {
                state.accountIdWithRevealedOptions = accountId
            }
            return state
        }
    }, removeAccount: { id in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = ActionSheetController(presentationTheme: presentationData.theme)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: presentationData.strings.Settings_LogoutConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)))
            items.append(ActionSheetButtonItem(title: presentationData.strings.Settings_Logout, color: .destructive, action: {
                dismissAction()
                let _ = logoutFromAccount(id: id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
            }))
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, keepPhone: {
        displayPhoneNumberConfirmation.set(false)
    }, openPhoneNumberChange: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let _ = (context.account.postbox.transaction { transaction -> String in
            return (transaction.getPeer(context.account.peerId) as? TelegramUser)?.phone ?? ""
            }
            |> deliverOnMainQueue).start(next: { phoneNumber in
                pushControllerImpl?(ChangePhoneNumberIntroController(context: context, phoneNumber: formatPhoneNumber(phoneNumber)))
            })
        })
    })
    
    changeProfilePhotoImpl = {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let _ = (context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
                return (transaction.getPeer(context.account.peerId), currentSearchBotsConfiguration(transaction: transaction))
            }
            |> deliverOnMainQueue).start(next: { peer, searchBotsConfiguration in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
                legacyController.statusBar.statusBarStyle = .Ignore
                
                let emptyController = LegacyEmptyController(context: legacyController.context)!
                let navigationController = makeLegacyNavigationController(rootController: emptyController)
                navigationController.setNavigationBarHidden(true, animated: false)
                navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
                
                legacyController.bind(controller: navigationController)
                
                presentControllerImpl?(legacyController, nil)
                
                var hasPhotos = false
                if let peer = peer, !peer.profileImageRepresentations.isEmpty {
                    hasPhotos = true
                }
                
                let completedImpl: (UIImage) -> Void = { image in
                    if let data = UIImageJPEGRepresentation(image, 0.6) {
                        let resource = LocalFileMediaResource(fileId: arc4random64())
                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                        let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                        updateState { state in
                            var state = state
                            state.updatingAvatar = .image(representation, true)
                            return state
                        }
                        updateAvatarDisposable.set((updateAccountPhoto(account: context.account, resource: resource, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        }) |> deliverOnMainQueue).start(next: { result in
                            switch result {
                            case .complete:
                                updateState { state in
                                    var state = state
                                    state.updatingAvatar = nil
                                    return state
                                }
                            case .progress:
                                break
                            }
                        }))
                    }
                }
                
                let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos, hasViewButton: false, personalPhoto: true, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
                let _ = currentAvatarMixin.swap(mixin)
                mixin.requestSearchController = { assetsController in
                    let controller = WebSearchController(context: context, peer: peer, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: nil, completion: { result in
                        assetsController?.dismiss()
                        completedImpl(result)
                    }))
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
                mixin.didFinishWithImage = { image in
                    if let image = image {
                       completedImpl(image)
                    }
                }
                mixin.didFinishWithDelete = {
                    let _ = currentAvatarMixin.swap(nil)
                    updateState { state in
                        var state = state
                        if let profileImage = peer?.smallProfileImage {
                            state.updatingAvatar = .image(profileImage, false)
                        } else {
                            state.updatingAvatar = .none
                        }
                        return state
                    }
                    updateAvatarDisposable.set((updateAccountPhoto(account: context.account, resource: nil, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    }) |> deliverOnMainQueue).start(next: { result in
                        switch result {
                        case .complete:
                            updateState { state in
                                var state = state
                                state.updatingAvatar = nil
                                return state
                            }
                        case .progress:
                            break
                        }
                    }))
                }
                mixin.didDismiss = { [weak legacyController] in
                    let _ = currentAvatarMixin.swap(nil)
                    legacyController?.dismiss()
                }
                let menuController = mixin.present()
                if let menuController = menuController {
                    menuController.customRemoveFromParentViewController = { [weak legacyController] in
                        legacyController?.dismiss()
                    }
                }
            })
        })
    }
    
    let peerView = contextValue.get()
    |> mapToSignal { context -> Signal<PeerView, NoError> in
        return context.account.viewTracker.peerView(context.account.peerId, updateData: true)
    }
    
    archivedPacks.set(
        .single(nil)
        |> then(
            contextValue.get()
            |> mapToSignal { context -> Signal<[ArchivedStickerPackItem]?, NoError> in
                archivedStickerPacks(account: context.account)
                |> map(Optional.init)
            }
        )
    )
    
    let hasPassport = ValuePromise<Bool>(false)
    let updatePassport: () -> Void = {
        updatePassportDisposable.set((
        contextValue.get()
        |> take(1)
        |> mapToSignal { context -> Signal<Bool, NoError> in
            return twoStepAuthData(context.account.network)
            |> map { value -> Bool in
                return value.hasSecretValues
            }
            |> `catch` { _ -> Signal<Bool, NoError> in
                return .single(false)
            }
        }
        |> deliverOnMainQueue).start(next: { value in
            hasPassport.set(value)
        }))
    }
    updatePassport()
    
    let notificationsAuthorizationStatus = Promise<AccessType>(.allowed)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsAuthorizationStatus.set(
            .single(.allowed)
            |> then(
                contextValue.get()
                |> mapToSignal { context -> Signal<AccessType, NoError> in
                    return DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications)
                }
            )
        )
    }
    
    let notificationsWarningSuppressed = Promise<Bool>(true)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsWarningSuppressed.set(
            .single(true)
            |> then(
                contextValue.get()
                |> mapToSignal { context -> Signal<Bool, NoError> in
                    return context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
                    |> map { noticeView -> Bool in
                        let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                        if let timestamp = timestamp, timestamp > 0 {
                            return true
                        } else {
                            return false
                        }
                    }
                }
            )
        )
    }
    
    let notifyExceptions = Promise<NotificationExceptionsList?>(NotificationExceptionsList(peers: [:], settings: [:]))
    let updateNotifyExceptions: () -> Void = {
        notifyExceptions.set(
            contextValue.get()
            |> take(1)
            |> mapToSignal { context -> Signal<NotificationExceptionsList?, NoError> in
                return .single(NotificationExceptionsList(peers: [:], settings: [:]))
                |> then(
                    notificationExceptionsList(postbox: context.account.postbox, network: context.account.network)
                    |> map(Optional.init)
                )
            }
        )
    }
    
    privacySettings.set(
    .single(nil)
    |> then(
        contextValue.get()
        |> mapToSignal { context -> Signal<AccountPrivacySettings?, NoError> in
            requestAccountPrivacySettings(account: context.account)
            |> map(Optional.init)
            }
        )
    )
    
    let hasWatchApp = Promise<Bool>(false)
    hasWatchApp.set(
        contextValue.get()
        |> mapToSignal { context -> Signal<Bool, NoError> in
            if let watchManager = context.watchManager {
                return watchManager.watchAppInstalled
            } else {
                return .single(false)
            }
        }
    )
    
    let updatedPresentationData = contextValue.get()
    |> mapToSignal { context -> Signal<PresentationData, NoError> in
        return context.sharedContext.presentationData
    }
    
    let preferences = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings, ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
    
    let featuredStickerPacks = contextValue.get()
    |> mapToSignal { context in
        return context.account.viewTracker.featuredStickerPacks()
    }
    
    let signal = combineLatest(queue: Queue.mainQueue(), contextValue.get(), updatedPresentationData, statePromise.get(), peerView, combineLatest(queue: Queue.mainQueue(), preferences, notifyExceptions.get(), notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), privacySettings.get(), displayPhoneNumberConfirmation.get()), combineLatest(featuredStickerPacks, archivedPacks.get()), combineLatest(hasPassport.get(), hasWatchApp.get()), accountsAndPeers.get())
    |> map { context, presentationData, state, view, preferencesAndExceptions, featuredAndArchived, hasPassportAndWatch, accountsAndPeers -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
        let proxySettings: ProxySettings = preferencesAndExceptions.0.entries[SharedDataKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
        let inAppNotificationSettings: InAppNotificationSettings = preferencesAndExceptions.0.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
    
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
            arguments.openEditing()
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Settings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        
        var unreadTrendingStickerPacks = 0
        for item in featuredAndArchived.0 {
            if item.unread {
                unreadTrendingStickerPacks += 1
            }
        }
        
        let searchItem = SettingsSearchItem(context: context, theme: presentationData.theme, placeholder: presentationData.strings.Common_Search, activated: state.isSearching, updateActivated: { value in
            if !value {
                setDisplayNavigationBarImpl?(true)
            }
            updateState { state in
                var state = state
                state.isSearching = value
                return state
            }
            if value {
                setDisplayNavigationBarImpl?(false)
            }
        }, presentController: { c, a in
            dismissInputImpl?()
            presentControllerImpl?(c, a)
        }, pushController: { c in
            pushControllerImpl?(c)
        }, getNavigationController: getNavigationControllerImpl, exceptionsList: notifyExceptions.get(), archivedStickerPacks: archivedPacks.get(), privacySettings: privacySettings.get())
        
        let (hasPassport, hasWatchApp) = hasPassportAndWatch
        let listState = ItemListNodeState(entries: settingsEntries(account: context.account, presentationData: presentationData, state: state, view: view, proxySettings: proxySettings, notifyExceptions: preferencesAndExceptions.1, notificationsAuthorizationStatus: preferencesAndExceptions.2, notificationsWarningSuppressed: preferencesAndExceptions.3, unreadTrendingStickerPacks: unreadTrendingStickerPacks, archivedPacks: featuredAndArchived.1, privacySettings: preferencesAndExceptions.4, hasPassport: hasPassport, hasWatchApp: hasWatchApp, accountsAndPeers: accountsAndPeers.1, inAppNotificationSettings: inAppNotificationSettings, displayPhoneNumberConfirmation: preferencesAndExceptions.5), style: .blocks, searchItem: searchItem, initialScrollToItem: ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: 0.0), directionHint: .Up))
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let icon: UIImage?
    if (useSpecialTabBarIcons()) {
        icon = UIImage(bundleImageName: "Chat List/Tabs/NY/IconSettings")
    } else {
        icon = UIImage(bundleImageName: "Chat List/Tabs/IconSettings")
    }
    
    let notificationsFromAllAccounts = accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
    |> map { sharedData -> Bool in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
        return settings.displayNotificationsFromAllAccounts
    }
    |> distinctUntilChanged
    
    let accountTabBarAvatarBadge: Signal<Int32, NoError> = combineLatest(notificationsFromAllAccounts, accountsAndPeers.get())
    |> map { notificationsFromAllAccounts, primaryAndOther -> Int32 in
        if !notificationsFromAllAccounts {
            return 0
        }
        let (primary, other) = primaryAndOther
        if let _ = primary, !other.isEmpty {
            return other.reduce(into: 0, { (result, next) in
                result += next.2
            })
        } else {
            return 0
        }
    }
    |> distinctUntilChanged
    
    let accountTabBarAvatar: Signal<UIImage?, NoError> = accountsAndPeers.get()
    |> map { primary, other -> (Account, Peer)? in
        if let primary = primary, !other.isEmpty {
            return (primary.0, primary.1)
        } else {
            return nil
        }
    }
    |> distinctUntilChanged(isEqual: { $0?.0 === $1?.0 && arePeersEqual($0?.1, $1?.1) })
    |> mapToSignal { primary -> Signal<UIImage?, NoError> in
        if let primary = primary {
            if let signal = peerAvatarImage(account: primary.0, peer: primary.1, authorOfMessage: nil, representation: primary.1.profileImageRepresentations.first, displayDimensions: CGSize(width: 25.0, height: 25.0), emptyColor: nil, synchronousLoad: false) {
                return signal
                |> map { image -> UIImage? in
                    return image.flatMap { image -> UIImage in
                        return image.withRenderingMode(.alwaysOriginal)
                    }
                }
            } else {
                return Signal { subscriber in
                    let size = CGSize(width: 25.0, height: 25.0)
                    let image = generateImage(size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        drawPeerAvatarLetters(context: context, size: size, font: avatarFont, letters: primary.1.displayLetters, accountPeerId: primary.1.id, peerId: primary.1.id)
                    })?.withRenderingMode(.alwaysOriginal)
                    subscriber.putNext(image)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                |> runOn(.concurrentDefaultQueue())
            }
        } else {
            return .single(nil)
        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        if lhs !== rhs {
            return false
        }
        return true
    })
    
    let tabBarItem: Signal<ItemListControllerTabBarItem, NoError> = combineLatest(queue: .mainQueue(), updatedPresentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), accountTabBarAvatar, accountTabBarAvatarBadge)
    |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed, accountTabBarAvatar, accountTabBarAvatarBadge -> ItemListControllerTabBarItem in
        let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
        var otherAccountsBadge: String?
        if accountTabBarAvatarBadge > 0 {
            otherAccountsBadge = compactNumericCountString(Int(accountTabBarAvatarBadge), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
        }
        return ItemListControllerTabBarItem(title: presentationData.strings.Settings_Title, image: accountTabBarAvatar ?? icon, selectedImage: accountTabBarAvatar ?? icon, tintImages: accountTabBarAvatar == nil, badgeValue: notificationsWarning ? "!" : otherAccountsBadge)
    }
    
    let controller = SettingsControllerImpl(currentContext: context, contextValue: contextValue, state: signal, tabBarItem: tabBarItem, accountsAndPeers: accountsAndPeers.get())
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true, animationOptions: [.removeOnMasterDetails])
    }
    presentControllerImpl = { [weak controller] value, arguments in
        controller?.present(value, in: .window(.root), with: arguments ?? ViewControllerPresentationArguments(presentationAnimation: .modalSheet), blockInteraction: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.window?.endEditing(true)
    }
    getNavigationControllerImpl = { [weak controller] in
        return (controller?.navigationController as? NavigationController)
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: ((ASDisplayNode, () -> (UIView?, UIView?)), CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, addToTransitionSurface: { _ in
                })
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    openSavedMessagesImpl = { [weak controller] in
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(context.account.peerId))
            }
        })
    }
    controller.tabBarItemDebugTapAction = {
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { accountContext in
            pushControllerImpl?(debugController(sharedContext: accountContext.sharedContext, context: accountContext))
        })
    }
    
    displayCopyContextMenuImpl = { [weak controller] peer in
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            if let strongController = controller {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var resultItemNode: ListViewItemNode?
                let _ = strongController.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                        resultItemNode = itemNode
                        return true
                    }
                    return false
                })
                if let resultItemNode = resultItemNode, let user = peer as? TelegramUser {
                    var actions: [ContextMenuAction] = []
                    
                    if let phone = user.phone, !phone.isEmpty {
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Settings_CopyPhoneNumber, accessibilityLabel: presentationData.strings.Settings_CopyPhoneNumber), action: {
                            UIPasteboard.general.string = formatPhoneNumber(phone)
                        }))
                    }
                    
                    if let username = user.username, !username.isEmpty {
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Settings_CopyUsername, accessibilityLabel: presentationData.strings.Settings_CopyUsername), action: {
                            UIPasteboard.general.string = username
                        }))
                    }
                    
                    let contextMenuController = ContextMenuController(actions: actions)
                    strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                        if let strongController = controller, let resultItemNode = resultItemNode {
                            return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                        } else {
                            return nil
                        }
                    }))
                }
            }
        })
    }
    switchToAccountImpl = { id in
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            accountsAndPeers.set(.never())
            context.sharedContext.switchToAccount(id: id)
        })
    }
    controller.didAppear = { _ in
        updatePassport()
        updateNotifyExceptions()
    }
    controller.previewItemWithTag = { tag in
        if let tag = tag as? SettingsEntryTag, case let .account(id) = tag {
            var selectedAccount: Account?
            let _ = (accountsAndPeers.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { accountsAndPeers in
                for (account, _, _) in accountsAndPeers.1 {
                    if account.id == id {
                        selectedAccount = account
                        break
                    }
                }
            })
            var sharedContext: SharedAccountContext?
            let _ = (contextValue.get()
            |> deliverOnMainQueue
            |> take(1)).start(next: { context in
                sharedContext = context.sharedContext
            })
            if let selectedAccount = selectedAccount, let sharedContext = sharedContext {
                let accountContext = AccountContext(sharedContext: sharedContext, account: selectedAccount, limitsConfiguration: LimitsConfiguration.defaultValue)
                let chatListController = ChatListController(context: accountContext, groupId: .root, controlsHistoryPreload: false, hideNetworkActivityStatus: true)
                return chatListController
                    
            }
        }
        return nil
    }
    controller.commitPreview = { previewController in
        if let chatListController = previewController as? ChatListController {
            let _ = (contextValue.get()
            |> deliverOnMainQueue
            |> take(1)).start(next: { context in
                context.sharedContext.switchToAccount(id: chatListController.context.account.id, withChatListController: chatListController)
            })
        }
    }
    controller.switchToAccount = { id in
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            context.sharedContext.switchToAccount(id: id)
        })
    }
    controller.addAccount = {
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            context.sharedContext.beginNewAuth(testingEnvironment: false)
        })
    }
    
    controller.contentOffsetChanged = { [weak controller] offset, inVoiceOver in
        if let controller = controller, let navigationBar = controller.navigationBar, let searchContentNode = navigationBar.contentNode as? NavigationBarSearchContentNode {
            var offset = offset
            if inVoiceOver {
                offset = .known(0.0)
            }
            searchContentNode.updateListVisibleContentOffset(offset)
        }
    }
    
    controller.contentScrollingEnded = { [weak controller] listNode in
        if let controller = controller, let navigationBar = controller.navigationBar, let searchContentNode = navigationBar.contentNode as? NavigationBarSearchContentNode {
            return fixNavigationSearchableListNodeScrolling(listNode, searchNode: searchContentNode)
        }
        return false
    }
    
    controller.willScrollToTop = { [weak controller] in
         if let controller = controller, let navigationBar = controller.navigationBar, let searchContentNode = navigationBar.contentNode as? NavigationBarSearchContentNode {
            searchContentNode.updateExpansionProgress(1.0, animated: true)
        }
    }
    
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
        setDisplayNavigationBarImpl?(true)
        updateState { state in
            var state = state
            state.isSearching = false
            return state
        }
    }

    setDisplayNavigationBarImpl = { [weak controller] display in
        controller?.setDisplayNavigationBar(display, transition: .animated(duration: 0.5, curve: .spring))
    }
    return controller
}

