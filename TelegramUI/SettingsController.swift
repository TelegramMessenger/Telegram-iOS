import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

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
    let account: Account
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
    let openThemes: () -> Void
    let pushController: (ViewController) -> Void
    let presentController: (ViewController) -> Void
    let openLanguage: () -> Void
    let openPassport: () -> Void
    let openWatch: () -> Void
    let openSupport: () -> Void
    let openFaq: () -> Void
    let openEditing: () -> Void
    let updateArchivedPacks: ([ArchivedStickerPackItem]?) -> Void
    let displayCopyContextMenu: () -> Void
}

private enum SettingsSection: Int32 {
    case info
    case proxy
    case media
    case generalSettings
    case advanced
    case help
}

private enum SettingsEntry: ItemListNodeEntry {
    case userInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, CachedPeerData?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setProfilePhoto(PresentationTheme, String)
    case setUsername(PresentationTheme, String)
    
    case proxy(PresentationTheme, UIImage?, String, String)
    
    case savedMessages(PresentationTheme, UIImage?, String)
    case recentCalls(PresentationTheme, UIImage?, String)
    case stickers(PresentationTheme, UIImage?, String, String, [ArchivedStickerPackItem]?)
    
    case notificationsAndSounds(PresentationTheme, UIImage?, String, NotificationExceptionsList?)
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
            case .proxy:
                return 3
            case .savedMessages:
                return 4
            case .recentCalls:
                return 5
            case .stickers:
                return 6
            case .notificationsAndSounds:
                return 7
            case .privacyAndSecurity:
                return 8
            case .dataAndStorage:
                return 9
            case .themes:
                return 10
            case .language:
                return 11
            case .passport:
                return 12
            case .watch:
                return 13
            case .askAQuestion:
                return 14
            case .faq:
                return 15
        }
    }
    
    static func ==(lhs: SettingsEntry, rhs: SettingsEntry) -> Bool {
        switch lhs {
            case let .userInfo(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsCachedData, lhsEditingState, lhsUpdatingImage):
                if case let .userInfo(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsCachedData, rhsEditingState, rhsUpdatingImage) = rhs {
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
            case let .notificationsAndSounds(lhsTheme, lhsImage, lhsText, lhsExceptionsList):
                if case let .notificationsAndSounds(rhsTheme, rhsImage, rhsText, rhsExceptionsList) = rhs, lhsTheme === rhsTheme, lhsImage === rhsImage, lhsText == rhsText, lhsExceptionsList == rhsExceptionsList {
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
            case let .userInfo(theme, strings, dateTimeFormat, peer, cachedData, state, updatingImage):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .settings, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max), lastActivity: 0), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false), editingNameUpdated: { _ in
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
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: value, labelStyle: .badge, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(installedStickerPacksController(account: arguments.account, mode: .general, archivedPacks: archivedPacks, updatedPacks: { packs in
                        arguments.updateArchivedPacks(packs)
                    }))
                })
            case let .notificationsAndSounds(theme, image, text, exceptionsList):
                return ItemListDisclosureItem(theme: theme, icon: image, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(notificationsAndSoundsController(account: arguments.account, exceptionsList: exceptionsList))
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

private func settingsEntries(presentationData: PresentationData, state: SettingsState, view: PeerView, proxySettings: ProxySettings, notifyExceptions: NotificationExceptionsList?, unreadTrendingStickerPacks: Int, archivedPacks: [ArchivedStickerPackItem]?, hasPassport: Bool, hasWatchApp: Bool) -> [SettingsEntry] {
    var entries: [SettingsEntry] = []
    
    if let peer = peerViewMainPeer(view) as? TelegramUser {
        let userInfoState = ItemListAvatarAndNameInfoItemState(editingName: nil, updatingName: nil)
        entries.append(.userInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, view.cachedData, userInfoState, state.updatingAvatar))
        if peer.photo.isEmpty {
            entries.append(.setProfilePhoto(presentationData.theme, presentationData.strings.Settings_SetProfilePhoto))
        }
        if peer.addressName == nil {
            entries.append(.setUsername(presentationData.theme, presentationData.strings.Settings_SetUsername))
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
        
        entries.append(.notificationsAndSounds(presentationData.theme, SettingsItemIcons.notifications, presentationData.strings.Settings_NotificationsAndSounds, notifyExceptions))
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

public func settingsController(account: Account, accountManager: AccountManager) -> ViewController {
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
    
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    var changeProfilePhotoImpl: (() -> Void)?
    var openSavedMessagesImpl: (() -> Void)?
    var displayCopyContextMenuImpl: ((Peer) -> Void)?
    
    let archivedPacks = Promise<[ArchivedStickerPackItem]?>()

    let openFaq: (Promise<ResolvedUrl>) -> Void = { resolvedUrl in
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
        presentControllerImpl?(controller, nil)
        let _ = (resolvedUrl.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] resolvedUrl in
                controller?.dismiss()
                
                openResolvedUrl(resolvedUrl, account: account, navigationController: getNavigationControllerImpl?(), openPeer: { peer, navigation in
                }, present: { controller, arguments in
                    pushControllerImpl?(controller)
                }, dismissInput: {})
        })
    }
    
    var faqUrl = account.telegramApplicationContext.currentPresentationData.with { $0 }.strings.Settings_FAQ_URL
    if faqUrl == "Settings.FAQ_URL" || faqUrl.isEmpty {
        faqUrl = "https://telegram.org/faq#general"
    }
    let resolvedUrl = resolveInstantViewUrl(account: account, url: faqUrl)
    
    let arguments = SettingsItemArguments(account: account, accountManager: accountManager, avatarAndNameInfoContext: avatarAndNameInfoContext, avatarTapAction: {
        var updating = false
        updateState {
            updating = $0.updatingAvatar != nil
            return $0
        }
        
        if updating {
            return
        }
        
        let _ = (account.postbox.loadedPeerWithId(account.peerId) |> take(1) |> deliverOnMainQueue).start(next: { peer in
            if peer.smallProfileImage != nil {
                let galleryController = AvatarGalleryController(account: account, peer: peer, replaceRootController: { controller, ready in
                    
                })
                hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                    avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                    updateHiddenAvatarImpl?()
                }))
                presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                    return avatarGalleryTransitionArguments?(entry)
                }))
            } else {
                changeProfilePhotoImpl?()
            }
        })
    }, changeProfilePhoto: {
        changeProfilePhotoImpl?()
    }, openUsername: {
        presentControllerImpl?(usernameSetupController(account: account), nil)
    }, openProxy: {
        pushControllerImpl?(proxySettingsController(account: account))
    }, openSavedMessages: {
        openSavedMessagesImpl?()
    }, openRecentCalls: {
        pushControllerImpl?(CallListController(account: account, mode: .navigation))
    }, openPrivacyAndSecurity: {
        pushControllerImpl?(privacyAndSecurityController(account: account, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: account) |> map(Optional.init))))
    }, openDataAndStorage: {
        pushControllerImpl?(dataAndStorageController(account: account))
    }, openThemes: {
        pushControllerImpl?(themeSettingsController(account: account))
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller in
        presentControllerImpl?(controller, nil)
    }, openLanguage: {
        //let controller = LanguageSelectionController(account: account)
        //presentControllerImpl?(controller, nil)
        pushControllerImpl?(LocalizationListController(account: account))
    }, openPassport: {
        let controller = SecureIdAuthController(account: account, mode: .list)
        presentControllerImpl?(controller, nil)
    }, openWatch: {
        let controller = watchSettingsController(account: account)
        pushControllerImpl?(controller)
    }, openSupport: {
        let supportPeer = Promise<PeerId?>()
        supportPeer.set(supportPeerId(account: account))
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
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
    }, openFaq: {
        let resolvedUrlPromise = Promise<ResolvedUrl>()
        resolvedUrlPromise.set(resolvedUrl)
        
        openFaq(resolvedUrlPromise)
    }, openEditing: {
        let _ = (account.postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
            return (transaction.getPeer(account.peerId), transaction.getPeerCachedData(peerId: account.peerId))
        } |> deliverOnMainQueue).start(next: { peer, cachedData in
            if let peer = peer as? TelegramUser, let cachedData = cachedData as? CachedUserData {
                pushControllerImpl?(editSettingsController(account: account, currentName: .personName(firstName: peer.firstName ?? "", lastName: peer.lastName ?? ""), currentBioText: cachedData.about ?? "", accountManager: accountManager))
            }
        })
    }, updateArchivedPacks: { packs in
        archivedPacks.set(.single(packs))
    }, displayCopyContextMenu: {
        let _ = (account.postbox.transaction { transaction -> (Peer?) in
            return transaction.getPeer(account.peerId)
            } |> deliverOnMainQueue).start(next: { peer in
                if let peer = peer {
                    displayCopyContextMenuImpl?(peer)
                }
            })
    })
    
    changeProfilePhotoImpl = {
        let _ = (account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(account.peerId)
            } |> deliverOnMainQueue).start(next: { peer in
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                
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
                
                let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasDeleteButton: hasPhotos, personalPhoto: true, saveEditedPhotos: false, saveCapturedMedia: false)!
                let _ = currentAvatarMixin.swap(mixin)
                mixin.didFinishWithImage = { image in
                    if let image = image {
                        if let data = UIImageJPEGRepresentation(image, 0.6) {
                            let resource = LocalFileMediaResource(fileId: arc4random64())
                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                            let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                            updateState {
                                $0.withUpdatedUpdatingAvatar(.image(representation))
                            }
                            updateAvatarDisposable.set((updateAccountPhoto(account: account, resource: resource) |> deliverOnMainQueue).start(next: { result in
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
                }
                mixin.didFinishWithDelete = {
                    let _ = currentAvatarMixin.swap(nil)
                    updateState {
                        if let profileImage = peer?.smallProfileImage {
                            return $0.withUpdatedUpdatingAvatar(.image(profileImage))
                        } else {
                            return $0.withUpdatedUpdatingAvatar(.none)
                        }
                    }
                    updateAvatarDisposable.set((updateAccountPhoto(account: account, resource: nil) |> deliverOnMainQueue).start(next: { result in
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
    }
    
    let peerView = account.viewTracker.peerView(account.peerId)
    
    archivedPacks.set(.single(nil) |> then(archivedStickerPacks(account: account) |> map(Optional.init)))
    
    let hasPassport = ValuePromise<Bool>(false)
    let updatePassport: () -> Void = {
        updatePassportDisposable.set((twoStepAuthData(account.network)
        |> deliverOnMainQueue).start(next: { value in
            hasPassport.set(value.hasSecretValues)
        }))
    }
    updatePassport()
    
    
    let notifyExceptions = Promise<NotificationExceptionsList?>(nil)
    let updateNotifyExceptions: () -> Void = {
        notifyExceptions.set(notificationExceptionsList(network: account.network) |> map(Optional.init))
    }
 //   updateNotifyExceptions()
    
    let hasWatchApp = Promise<Bool>(false)
    if let context = account.applicationContext as? TelegramApplicationContext, let watchManager = context.watchManager {
        hasWatchApp.set(watchManager.watchAppInstalled)
    }
    
    let signal = combineLatest(account.telegramApplicationContext.presentationData, statePromise.get(), peerView, combineLatest(account.postbox.preferencesView(keys: [PreferencesKeys.proxySettings]), notifyExceptions.get()), combineLatest(account.viewTracker.featuredStickerPacks(), archivedPacks.get()), combineLatest(hasPassport.get(), hasWatchApp.get()))
        |> map { presentationData, state, view, preferencesAndExceptions, featuredAndArchived, hasPassportAndWatch -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
            let proxySettings: ProxySettings = preferencesAndExceptions.0.values[PreferencesKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
            
            
            let peer = peerViewMainPeer(view)
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                if let _ = peer as? TelegramUser, let _ = view.cachedData as? CachedUserData {
                    arguments.openEditing()
                }
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Settings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            
            var unreadTrendingStickerPacks = 0
            for item in featuredAndArchived.0 {
                if item.unread {
                    unreadTrendingStickerPacks += 1
                }
            }
            
            let (hasPassport, hasWatchApp) = hasPassportAndWatch
            
            let listState = ItemListNodeState(entries: settingsEntries(presentationData: presentationData, state: state, view: view, proxySettings: proxySettings, notifyExceptions: preferencesAndExceptions.1, unreadTrendingStickerPacks: unreadTrendingStickerPacks, archivedPacks: featuredAndArchived.1, hasPassport: hasPassport, hasWatchApp: hasWatchApp), style: .blocks)
            
            return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let icon = UIImage(bundleImageName: "Chat List/Tabs/IconSettings")
    
    let controller = ItemListController(account: account, state: signal, tabBarItem: (account.applicationContext as! TelegramApplicationContext).presentationData |> map { presentationData in
        return ItemListControllerTabBarItem(title: presentationData.strings.Settings_Title, image: icon, selectedImage: icon)
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
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(account.peerId))
        }
    }
    controller.tabBarItemDebugTapAction = {
        pushControllerImpl?(debugController(account: account, accountManager: accountManager))
    }
    
    displayCopyContextMenuImpl = { [weak controller] peer in
        if let strongController = controller {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
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
    }
    
    controller.didAppear = { _ in
        updatePassport()
        updateNotifyExceptions()
    }
    return controller
}

