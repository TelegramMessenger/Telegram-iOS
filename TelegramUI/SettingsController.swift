import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import MtProtoKitDynamic

private final class SettingsItemIcons {
    static let proxy = UIImage(bundleImageName: "Settings/MenuIcons/Proxy")?.precomposed()
    static let savedMessages = UIImage(bundleImageName: "Settings/MenuIcons/SavedMessages")?.precomposed()
    static let recentCalls = UIImage(bundleImageName: "Settings/MenuIcons/RecentCalls")?.precomposed()
    static let stickers = UIImage(bundleImageName: "Settings/MenuIcons/Stickers")?.precomposed()
    
    static let notifications = UIImage(bundleImageName: "Settings/MenuIcons/Notifications")?.precomposed()
    static let security = UIImage(bundleImageName: "Settings/MenuIcons/Security")?.precomposed()
    static let dataAndStorage = UIImage(bundleImageName: "Settings/MenuIcons/DataAndStorage")?.precomposed()
    static let appearance = UIImage(bundleImageName: "Settings/MenuIcons/Appearance")?.precomposed()
    static let language = UIImage(bundleImageName: "Settings/MenuIcons/Language")?.precomposed()
    
    static let passport = UIImage(bundleImageName: "Settings/MenuIcons/Passport")?.precomposed()
    static let watch = UIImage(bundleImageName: "Settings/MenuIcons/Watch")?.precomposed()
    
    static let support = UIImage(bundleImageName: "Settings/MenuIcons/Support")?.precomposed()
    static let faq = UIImage(bundleImageName: "Settings/MenuIcons/Faq")?.precomposed()
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
    let openPrivacyAndSecurity: () -> Void
    let openDataAndStorage: () -> Void
    let openStickerPacks: ([ArchivedStickerPackItem]?) -> Void
    let openNotificationsAndSounds: (NotificationExceptionsList?) -> Void
    let openThemes: () -> Void
    let pushController: (ViewController) -> Void
    let openLanguage: () -> Void
    let openPassport: () -> Void
    let openWatch: () -> Void
    let openSupport: () -> Void
    let openFaq: () -> Void
    let openEditing: () -> Void
    let displayCopyContextMenu: () -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let addAccount: () -> Void
}

private enum SettingsSection: Int32 {
    case info
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
    
    case account(Int, Account, PresentationTheme, PresentationStrings, Peer, Int32)
    case addAccount(PresentationTheme, String)
    
    case proxy(PresentationTheme, UIImage?, String, String)
    
    case savedMessages(PresentationTheme, UIImage?, String)
    case recentCalls(PresentationTheme, UIImage?, String)
    case stickers(PresentationTheme, UIImage?, String, String, [ArchivedStickerPackItem]?)
    
    case notificationsAndSounds(PresentationTheme, UIImage?, String, NotificationExceptionsList?, Bool)
    case privacyAndSecurity(PresentationTheme, UIImage?, String)
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
            case let .account(account):
                return 3 + Int32(account.0)
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
            case let .account(lhsIndex, lhsAccount, lhsTheme, lhsStrings, lhsPeer, lhsBadgeCount):
                if case let .account(rhsIndex, rhsAccount, rhsTheme, rhsStrings, rhsPeer, rhsBadgeCount) = rhs, lhsIndex == rhsIndex, lhsAccount === rhsAccount, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPeer.isEqual(rhsPeer), lhsBadgeCount == rhsBadgeCount {
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
            case let .privacyAndSecurity(lhsTheme, lhsImage, lhsText):
                if case let .privacyAndSecurity(rhsTheme, rhsImage, rhsText) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText {
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
                return ItemListAvatarAndNameInfoItem(account: account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .settings, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max), lastActivity: 0), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false), editingNameUpdated: { _ in
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
            case let .account(_, account, theme, strings, peer, badgeCount):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .dayFirst, dateSeparator: "."), nameDisplayOrder: .firstLast, account: account, peer: peer, aliasHandling: .standard, presence: nil, text: .none, label: .badge("\(badgeCount)"), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, sectionId: self.section, action: {
                    arguments.switchToAccount(account.id)
                }, setPeerIdWithRevealedOptions: { lhs, rhs in
                }, removePeer: { _ in
                })
            case let .addAccount(theme, text):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                    arguments.addAccount()
                })
            case let .proxy(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openProxy()
                })
            case let .savedMessages(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSavedMessages()
                })
            case let .recentCalls(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openRecentCalls()
                })
            case let .stickers(theme, image, text, value, archivedPacks):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, labelStyle: .badge(theme.list.itemAccentColor), sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openStickerPacks(archivedPacks)
                })
            case let .notificationsAndSounds(theme, image, text, exceptionsList, warning):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: warning ? "!" : "", labelStyle: warning ? .badge(theme.list.itemDestructiveColor) : .text, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openNotificationsAndSounds(exceptionsList)
                })
            case let .privacyAndSecurity(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPrivacyAndSecurity()
                })
            case let .dataAndStorage(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openDataAndStorage()
                })
            case let .themes(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openThemes()
                })
            case let .language(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openLanguage()
                })
            case let .passport(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPassport()
                })
            case let .watch(theme, image, text, value):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openWatch()
                })
            case let .askAQuestion(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSupport()
                })
            case let .faq(theme, image, text):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openFaq()
                })
        }
    }
}

private struct SettingsState: Equatable {
    let updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    
    init(updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar? = nil) {
        self.updatingAvatar = updatingAvatar
    }
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?) -> SettingsState {
        return SettingsState(updatingAvatar: updatingAvatar)
    }
    
    static func ==(lhs: SettingsState, rhs: SettingsState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        return true
    }
}

private func settingsEntries(account: Account, presentationData: PresentationData, state: SettingsState, view: PeerView, proxySettings: ProxySettings, notifyExceptions: NotificationExceptionsList?, notificationsAuthorizationStatus: AccessType, notificationsWarningSuppressed: Bool, unreadTrendingStickerPacks: Int, archivedPacks: [ArchivedStickerPackItem]?, hasPassport: Bool, hasWatchApp: Bool, accountsAndPeers: [(Account, Peer, Int32)]) -> [SettingsEntry] {
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
        
        if !accountsAndPeers.isEmpty {
            var index = 0
            for (peerAccount, peer, badgeCount) in accountsAndPeers {
                entries.append(.account(index, peerAccount, presentationData.theme, presentationData.strings, peer, badgeCount))
                index += 1
            }
            entries.append(.addAccount(presentationData.theme, presentationData.strings.Settings_AddAccount))
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
            entries.append(.proxy(presentationData.theme, SettingsItemIcons.proxy, presentationData.strings.Settings_Proxy, valueString))
        }
        
        entries.append(.savedMessages(presentationData.theme, SettingsItemIcons.savedMessages, presentationData.strings.Settings_SavedMessages))
        entries.append(.recentCalls(presentationData.theme, SettingsItemIcons.recentCalls, presentationData.strings.CallSettings_RecentCalls))
        entries.append(.stickers(presentationData.theme, SettingsItemIcons.stickers, presentationData.strings.ChatSettings_Stickers, unreadTrendingStickerPacks == 0 ? "" : "\(unreadTrendingStickerPacks)", archivedPacks))
        
        let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
        entries.append(.notificationsAndSounds(presentationData.theme, SettingsItemIcons.notifications, presentationData.strings.Settings_NotificationsAndSounds, notifyExceptions, notificationsWarning))
        entries.append(.privacyAndSecurity(presentationData.theme, SettingsItemIcons.security, presentationData.strings.Settings_PrivacySettings))
        entries.append(.dataAndStorage(presentationData.theme, SettingsItemIcons.dataAndStorage, presentationData.strings.Settings_ChatSettings))
        entries.append(.themes(presentationData.theme, SettingsItemIcons.appearance, presentationData.strings.Settings_Appearance))
        let languageName = presentationData.strings.primaryComponent.localizedName
        entries.append(.language(presentationData.theme, SettingsItemIcons.language, presentationData.strings.Settings_AppLanguage, languageName.isEmpty ? presentationData.strings.Localization_LanguageName : languageName))
        
        if hasPassport {
            entries.append(.passport(presentationData.theme, SettingsItemIcons.passport, presentationData.strings.Settings_Passport, ""))
        }
        if hasWatchApp {
            entries.append(.watch(presentationData.theme, SettingsItemIcons.watch, presentationData.strings.Settings_AppleWatch, ""))
        }
        
        entries.append(.askAQuestion(presentationData.theme, SettingsItemIcons.support, presentationData.strings.Settings_Support))
        entries.append(.faq(presentationData.theme, SettingsItemIcons.faq, presentationData.strings.Settings_FAQ))
    }
    
    return entries
}

public protocol SettingsController: class {
    func updateContext(context: AccountContext)
}

private final class SettingsControllerImpl: ItemListController<SettingsEntry>, SettingsController {
    let contextValue: Promise<AccountContext>
    
    init(currentContext: AccountContext, contextValue: Promise<AccountContext>, state: Signal<(ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?) {
        self.contextValue = contextValue
        let presentationData = currentContext.currentPresentationData.with { $0 }
        
        self.contextValue.set(.single(currentContext))
        
        let updatedPresentationData = self.contextValue.get()
        |> mapToSignal { context -> Signal<(theme: PresentationTheme, strings: PresentationStrings), NoError> in
            return context.presentationData
            |> map { ($0.theme, $0.strings) }
        }
        
        super.init(theme: presentationData.theme, strings: presentationData.strings, updatedPresentationData: updatedPresentationData, state: state, tabBarItem: tabBarItem)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateContext(context: AccountContext) {
        self.contextValue.set(.single(context))
    }
}

public func settingsController(context: AccountContext, accountManager: AccountManager) -> SettingsController & ViewController {
    let statePromise = ValuePromise(SettingsState(), ignoreRepeated: true)
    let stateValue = Atomic(value: SettingsState())
    let updateState: ((SettingsState) -> SettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
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
    
    let networkArguments = context.account.networkArguments
    let auxiliaryMethods = context.account.auxiliaryMethods
    let rootPath = rootPathForBasePath(context.applicationBindings.containerPath)
    
    let accountsAndPeers: Signal<[(Account, Peer, Int32)], NoError> = accountManager.accountRecords()
    |> map { view -> [AccountRecordId] in
        return view.records.compactMap { record -> AccountRecordId? in
            if record.attributes.contains(where: { $0 is LoggedOutAccountAttribute }) {
                return nil
            }
            return record.id
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { recordIds -> Signal<[(Account, Peer, Int32)], NoError> in
        return contextValue.get()
        |> mapToSignal { currentAccount -> Signal<[(Account, Peer, Int32)], NoError> in
            var accounts: [Signal<(Account, Peer, Int32)?, NoError>] = []
            func accountWithPeer(_ account: Signal<Account?, NoError>) -> Signal<(Account, Peer, Int32)?, NoError> {
                return account
                |> mapToSignal { account -> Signal<(Account, Peer, Int32)?, NoError> in
                    guard let account = account else {
                        return .single(nil)
                    }
                    return combineLatest(account.postbox.peerView(id: account.peerId), renderedTotalUnreadCount(postbox: account.postbox))
                    |> map { view, totalUnreadCount -> (Peer?, Int32) in
                        return (view.peers[view.peerId], totalUnreadCount.0)
                    }
                    |> distinctUntilChanged { lhs, rhs in
                        return arePeersEqual(lhs.0, rhs.0) && lhs.1 == rhs.1
                    }
                    |> map { peer, totalUnreadCount -> (Account, Peer, Int32)? in
                        if let peer = peer {
                            return (account, peer, totalUnreadCount)
                        } else {
                            return nil
                        }
                    }
                }
            }
            for id in recordIds {
                if id == currentAccount.id {
                    continue
                } else {
                    accounts.append(accountWithPeer(accountWithId(networkArguments: networkArguments, id: id, supplementary: true, rootPath: rootPath, beginWithTestingEnvironment: false, auxiliaryMethods: auxiliaryMethods)
                    |> map { result -> Account? in
                        if case let .authorized(account) = result {
                            return account
                        } else {
                            return nil
                        }
                    }))
                }
            }
            return combineLatest(accounts)
            |> map { accounts -> [(Account, Peer, Int32)] in
                return accounts.compactMap({ $0 })
            }
        }
    }

    let openFaq: (Promise<ResolvedUrl>) -> Void = { resolvedUrl in
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let presentationData = context.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            presentControllerImpl?(controller, nil)
            let _ = (resolvedUrl.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] resolvedUrl in
                controller?.dismiss()
                
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
        var faqUrl = context.currentPresentationData.with { $0 }.strings.Settings_FAQ_URL
        if faqUrl == "Settings.FAQ_URL" || faqUrl.isEmpty {
            faqUrl = "https://telegram.org/faq#general"
        }
        return resolveInstantViewUrl(account: context.account, url: faqUrl)
    }
    
    var switchToAccountImpl: ((AccountRecordId) -> Void)?
    
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
            let _ = (context.account.postbox.loadedPeerWithId(account.peerId)
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
        |> take(1)).start(next: { account in
            pushControllerImpl?(proxySettingsController(context: context))
        })
    }, openSavedMessages: {
        openSavedMessagesImpl?()
    }, openRecentCalls: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { account in
            pushControllerImpl?(CallListController(context: context, mode: .navigation))
        })
    }, openPrivacyAndSecurity: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            pushControllerImpl?(privacyAndSecurityController(context: context, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: context.account) |> map(Optional.init))))
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
            let controller = SecureIdAuthController(context: context, mode: .list)
            presentControllerImpl?(controller, nil)
        })
    }, openWatch: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let controller = watchSettingsController(context: context)
            pushControllerImpl?(controller)
        })
    }, openSupport: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            let supportPeer = Promise<PeerId?>()
            supportPeer.set(supportPeerId(account: context.account))
            let presentationData = context.currentPresentationData.with { $0 }
            
            let resolvedUrlPromise = Promise<ResolvedUrl>()
            resolvedUrlPromise.set(resolvedUrl)
            
            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Settings_FAQ_Intro, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: {
                    openFaq(resolvedUrlPromise)
                }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).start(next: { peerId in
                        if let peerId = peerId {
                            pushControllerImpl?(ChatController(account: account, chatLocation: .peer(peerId)))
                        }
                    }))
                })
            ]), nil)
        })
    }, openFaq: {
        let resolvedUrlPromise = Promise<ResolvedUrl>()
        resolvedUrlPromise.set(resolvedUrl)
        
        openFaq(resolvedUrlPromise)
    }, openEditing: {
        let _ = (contextValue.get()
        |> deliverOnMainQueue
        |> take(1)).start(next: { context in
            var cancelImpl: (() -> Void)?
            let presentationData = context.currentPresentationData.with { $0 }
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                presentControllerImpl?(controller, nil)
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            let peerKey: PostboxViewKey = .peer(peerId: context.account.peerId, components: [])
            let cachedDataKey: PostboxViewKey = .cachedPeerData(peerId: account.peerId)
            let signal = (context.account.postbox.combinedView(keys: [peerKey, cachedDataKey])
            |> mapToSignal { view -> Signal<(TelegramUser, CachedUserData), NoError> in
                guard let cachedDataView = view.views[cachedDataKey] as? CachedPeerDataView, let cachedData = cachedDataView.cachedPeerData as? CachedUserData else {
                    return .complete()
                }
                guard let peerView = view.views[peerKey] as? PeerView, let peer = peerView.peers[context.account.peerId] as? TelegramUser else {
                    return .complete()
                }
                return .single((peer, cachedData))
            }
            |> take(1))
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            cancelImpl = {
                openEditingDisposable.set(nil)
            }
            openEditingDisposable.set((signal
            |> deliverOnMainQueue).start(next: { peer, cachedData in
                pushControllerImpl?(editSettingsController(context: context, currentName: .personName(firstName: peer.firstName ?? "", lastName: peer.lastName ?? ""), currentBioText: cachedData.about ?? "", accountManager: accountManager))
            }))
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
                let id = transaction.createRecord([AccountEnvironmentAttribute(environment: isTestingEnvironment ? .test : .production)])
                transaction.setCurrentId(id)
            }).start()
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
                let presentationData = context.currentPresentationData.with { $0 }
                
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
                        updateState {
                            $0.withUpdatedUpdatingAvatar(.image(representation, true))
                        }
                        updateAvatarDisposable.set((updateAccountPhoto(account: context.account, resource: resource, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        }) |> deliverOnMainQueue).start(next: { result in
                            switch result {
                            case .complete:
                                updateState {
                                    $0.withUpdatedUpdatingAvatar(nil)
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
                    updateState {
                        if let profileImage = peer?.smallProfileImage {
                            return $0.withUpdatedUpdatingAvatar(.image(profileImage, false))
                        } else {
                            return $0.withUpdatedUpdatingAvatar(.none)
                        }
                    }
                    updateAvatarDisposable.set((updateAccountPhoto(account: context.account, resource: nil, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    }) |> deliverOnMainQueue).start(next: { result in
                        switch result {
                        case .complete:
                            updateState {
                                $0.withUpdatedUpdatingAvatar(nil)
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
        return context.account.viewTracker.peerView(context.account.peerId)
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
    if #available(iOSApplicationExtension 10.0, *) {
        notificationsAuthorizationStatus.set(
            .single(.allowed)
            |> then(
                contextValue.get()
                |> mapToSignal { context -> Signal<AccessType, NoError> in
                    return DeviceAccess.authorizationStatus(account: context.account, subject: .notifications)
                }
            )
        )
    }
    
    let notificationsWarningSuppressed = Promise<Bool>(true)
    if #available(iOSApplicationExtension 10.0, *) {
        let warningKey = PostboxViewKey.noticeEntry(ApplicationSpecificNotice.notificationsPermissionWarningKey())
        notificationsWarningSuppressed.set(
            .single(true)
            |> then(
                contextValue.get()
                |> mapToSignal { context -> Signal<Bool, NoError> in
                    return context.account.postbox.combinedView(keys: [warningKey])
                    |> map { combined -> Bool in
                        let timestamp = (combined.views[warningKey] as? NoticeEntryView)?.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
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
    
    let notifyExceptions = Promise<NotificationExceptionsList?>(nil)
    let updateNotifyExceptions: () -> Void = {
        notifyExceptions.set(
            contextValue.get()
            |> take(1)
            |> mapToSignal { context -> Signal<NotificationExceptionsList?, NoError> in
                return notificationExceptionsList(network: context.account.network)
                |> map(Optional.init)
            }
        )
    }
    
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
        return context.presentationData
    }
    
    let proxyPreferences = contextValue.get()
    |> mapToSignal { context in
        return context.account.postbox.preferencesView(keys: [PreferencesKeys.proxySettings])
    }
    
    let featuredStickerPacks = contextValue.get()
    |> mapToSignal { context in
        return context.account.viewTracker.featuredStickerPacks()
    }
    
    let signal = combineLatest(queue: Queue.mainQueue(), contextValue.get(), updatedPresentationData, statePromise.get(), peerView, combineLatest(queue: Queue.mainQueue(), proxyPreferences, notifyExceptions.get(), notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get()), combineLatest(featuredStickerPacks, archivedPacks.get()), combineLatest(hasPassport.get(), hasWatchApp.get()), accountsAndPeers)
    |> map { context, presentationData, state, view, preferencesAndExceptions, featuredAndArchived, hasPassportAndWatch, accountsAndPeers -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
        let proxySettings: ProxySettings = preferencesAndExceptions.0.values[PreferencesKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
    
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
        
        let (hasPassport, hasWatchApp) = hasPassportAndWatch
        let listState = ItemListNodeState(entries: settingsEntries(account: context.account, presentationData: presentationData, state: state, view: view, proxySettings: proxySettings, notifyExceptions: preferencesAndExceptions.1, notificationsAuthorizationStatus: preferencesAndExceptions.2, notificationsWarningSuppressed: preferencesAndExceptions.3, unreadTrendingStickerPacks: unreadTrendingStickerPacks, archivedPacks: featuredAndArchived.1, hasPassport: hasPassport, hasWatchApp: hasWatchApp, accountsAndPeers: accountsAndPeers), style: .blocks)
        
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
    
    let controller = SettingsControllerImpl(currentContext: context, contextValue: contextValue, state: signal, tabBarItem: combineLatest(updatedPresentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get()) |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed in
        let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
        return ItemListControllerTabBarItem(title: presentationData.strings.Settings_Title, image: icon, selectedImage: icon, badgeValue: notificationsWarning ? "!" : nil)
    })
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    presentControllerImpl = { [weak controller] value, arguments in
        controller?.present(value, in: .window(.root), with: arguments ?? ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    getNavigationControllerImpl = { [weak controller] in
        return (controller?.navigationController as? NavigationController)
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: ((ASDisplayNode, () -> UIView?), CGRect)?
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
        |> deliverOnMainQueue).start(next: { account in
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(account.peerId))
            }
        })
    }
    controller.tabBarItemDebugTapAction = {
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { account in
            pushControllerImpl?(debugController(account: account, accountManager: accountManager))
        })
    }
    
    displayCopyContextMenuImpl = { [weak controller] peer in
        let _ = (contextValue.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            if let strongController = controller {
                let presentationData = context.currentPresentationData.with { $0 }
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
                        actions.append(ContextMenuAction(content: .text(presentationData.strings.Settings_CopyPhoneNumber), action: {
                            UIPasteboard.general.string = formatPhoneNumber(phone)
                        }))
                    }
                    
                    if let username = user.username, !username.isEmpty {
                        actions.append(ContextMenuAction(content: .text(presentationData.strings.Settings_CopyUsername), action: {
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
    switchToAccountImpl = { [weak controller] id in
        AccountStore.switchToAccount(id: id, fromSettingsController: controller)
    }
    controller.didAppear = { _ in
        updatePassport()
        updateNotifyExceptions()
    }
    return controller
}

