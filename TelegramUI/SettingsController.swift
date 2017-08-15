import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

private struct SettingsItemArguments {
    let account: Account
    let accountManager: AccountManager
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    
    let avatarTapAction: () -> Void
    
    let changeProfilePhoto: () -> Void
    let openPrivacyAndSecurity: () -> Void
    let openDataAndStorage: () -> Void
    let openThemes: () -> Void
    let openTheme: (TelegramWallpaper) -> Void
    let pushController: (ViewController) -> Void
    let presentController: (ViewController) -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let saveEditingState: () -> Void
    let openLanguage: () -> Void
    let openSupport: () -> Void
    let openFaq: () -> Void
    let logout: () -> Void
}

private enum SettingsSection: Int32 {
    case info
    case generalSettings
    case accountSettings
    case help
    case logOut
}

private enum SettingsEntry: ItemListNodeEntry {
    case userInfo(PresentationTheme, PresentationStrings, Peer?, CachedPeerData?, ItemListAvatarAndNameInfoItemState, TelegramMediaImageRepresentation?)
    case setProfilePhoto(PresentationTheme, String)
    
    case notificationsAndSounds(PresentationTheme, String)
    case privacyAndSecurity(PresentationTheme, String)
    case dataAndStorage(PresentationTheme, String)
    case stickers(PresentationTheme, String)
    case themes(PresentationTheme, String, [TelegramWallpaper])
    case phoneNumber(PresentationTheme, String, String)
    case username(PresentationTheme, String, String)
    case language(PresentationTheme, String, String)
    case askAQuestion(PresentationTheme, String, Bool)
    case faq(PresentationTheme, String)
    case debug(PresentationTheme, String)
    case logOut(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .userInfo, .setProfilePhoto:
                return SettingsSection.info.rawValue
            case .notificationsAndSounds, .privacyAndSecurity, .dataAndStorage, .stickers, .themes:
                return SettingsSection.generalSettings.rawValue
            case .phoneNumber, .username:
                return SettingsSection.accountSettings.rawValue
            case .language, .askAQuestion, .faq, .debug:
                return SettingsSection.help.rawValue
            case .logOut:
                return SettingsSection.logOut.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .userInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case .notificationsAndSounds:
                return 2
            case .privacyAndSecurity:
                return 3
            case .dataAndStorage:
                return 4
            case .stickers:
                return 5
            case .themes:
                return 6
            case .phoneNumber:
                return 7
            case .username:
                return 8
            case .askAQuestion:
                return 9
            case .language:
                return 10
            case .faq:
                return 11
            case .debug:
                return 12
            case .logOut:
                return 13
        }
    }
    
    static func ==(lhs: SettingsEntry, rhs: SettingsEntry) -> Bool {
        switch lhs {
            case let .userInfo(lhsTheme, lhsStrings, lhsPeer, lhsCachedData, lhsEditingState, lhsUpdatingImage):
                if case let .userInfo(rhsTheme, rhsStrings, rhsPeer, rhsCachedData, rhsEditingState, rhsUpdatingImage) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
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
            case let .notificationsAndSounds(lhsTheme, lhsText):
                if case let .notificationsAndSounds(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privacyAndSecurity(lhsTheme, lhsText):
                if case let .privacyAndSecurity(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .dataAndStorage(lhsTheme, lhsText):
                if case let .dataAndStorage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .stickers(lhsTheme, lhsText):
                if case let .stickers(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themes(lhsTheme, lhsText, lhsWallpapers):
                if case let .themes(rhsTheme, rhsText, rhsWallpapers) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsWallpapers == rhsWallpapers {
                    return true
                } else {
                    return false
                }
            case let .phoneNumber(lhsTheme, lhsText, lhsNumber):
                if case let .phoneNumber(rhsTheme, rhsText, rhsNumber) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsNumber == rhsNumber {
                    return true
                } else {
                    return false
                }
            case let .username(lhsTheme, lhsText, lhsAddress):
                if case let .username(rhsTheme, rhsText, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAddress == rhsAddress {
                    return true
                } else {
                    return false
                }
            case let .language(lhsTheme, lhsText, lhsValue):
                if case let .language(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .askAQuestion(lhsTheme, lhsText, lhsLoading):
                if case let .askAQuestion(rhsTheme, rhsText, rhsLoading) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLoading == rhsLoading {
                    return true
                } else {
                    return false
                }
            case let .faq(lhsTheme, lhsText):
                if case let .faq(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .debug(lhsTheme, lhsText):
                if case let .debug(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .logOut(lhsTheme, lhsText):
                if case let .logOut(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .userInfo(theme, strings, peer, cachedData, state, updatingImage):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max)), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.avatarTapAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingImage)
            case let .setProfilePhoto(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .notificationsAndSounds(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(notificationsAndSoundsController(account: arguments.account))
                })
            case let .privacyAndSecurity(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPrivacyAndSecurity()
                })
            case let .dataAndStorage(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openDataAndStorage()
                })
            case let .stickers(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(installedStickerPacksController(account: arguments.account, mode: .general))
                })
            case let .themes(theme, text, wallpapers):
                return SettingsThemesItem(account: arguments.account, theme: theme, title: text, sectionId: self.section, action: {
                    arguments.openThemes()
                }, openWallpaper: { wallpaper in
                    arguments.openTheme(wallpaper)
                }, wallpapers: wallpapers)
            case let .phoneNumber(theme, text, number):
                return ItemListDisclosureItem(theme: theme, title: text, label: number, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(ChangePhoneNumberIntroController(account: arguments.account, phoneNumber: number))
                })
            case let .username(theme, text, address):
                return ItemListDisclosureItem(theme: theme, title: text, label: address, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.presentController(usernameSetupController(account: arguments.account))
                })
            case let .language(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openLanguage()
                })
            case let .askAQuestion(theme, text, loading):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSupport()
                })
            case let .faq(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openFaq()
                })
            case let .debug(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(debugController(account: arguments.account, accountManager: arguments.accountManager))
                })
            case let .logOut(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .center, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.logout()
                })
        }
    }
}

private struct SettingsEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName
    
    static func ==(lhs: SettingsEditingState, rhs: SettingsEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        
        return true
    }
}

private struct SettingsState: Equatable {
    let updatingAvatar: TelegramMediaImageRepresentation?
    let editingState: SettingsEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let loadingSupportPeer: Bool
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: TelegramMediaImageRepresentation?) -> SettingsState {
        return SettingsState(updatingAvatar: updatingAvatar, editingState: editingState, updatingName: self.updatingName, loadingSupportPeer: self.loadingSupportPeer)
    }
    
    func withUpdatedEditingState(_ editingState: SettingsEditingState?) -> SettingsState {
        return SettingsState(updatingAvatar: self.updatingAvatar, editingState: editingState, updatingName: self.updatingName, loadingSupportPeer: self.loadingSupportPeer)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> SettingsState {
        return SettingsState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: updatingName, loadingSupportPeer: self.loadingSupportPeer)
    }
    
    func withUpdatedLoadingSupportPeer(_ loadingSupportPeer: Bool) -> SettingsState {
        return SettingsState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, loadingSupportPeer: loadingSupportPeer)
    }
    
    static func ==(lhs: SettingsState, rhs: SettingsState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.loadingSupportPeer != rhs.loadingSupportPeer {
            return false
        }
        return true
    }
}

private func settingsEntries(presentationData: PresentationData, state: SettingsState, view: PeerView, wallpapers: [TelegramWallpaper]) -> [SettingsEntry] {
    var entries: [SettingsEntry] = []
    
    if let peer = peerViewMainPeer(view) as? TelegramUser {
        let userInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingState?.editingName, updatingName: state.updatingName)
        entries.append(.userInfo(presentationData.theme, presentationData.strings, peer, view.cachedData, userInfoState, state.updatingAvatar))
        entries.append(.setProfilePhoto(presentationData.theme, presentationData.strings.Settings_SetProfilePhoto))
        
        entries.append(.notificationsAndSounds(presentationData.theme, presentationData.strings.Settings_NotificationsAndSounds))
        entries.append(.privacyAndSecurity(presentationData.theme, presentationData.strings.Settings_PrivacySettings))
        entries.append(.dataAndStorage(presentationData.theme, presentationData.strings.Settings_ChatSettings))
        entries.append(.stickers(presentationData.theme, presentationData.strings.ChatSettings_Stickers))
        entries.append(.themes(presentationData.theme, presentationData.strings.Settings_ChatBackground, wallpapers))
        
        if let phone = peer.phone {
            entries.append(.phoneNumber(presentationData.theme, presentationData.strings.Settings_PhoneNumber, formatPhoneNumber(phone)))
        }
        entries.append(.username(presentationData.theme, presentationData.strings.Settings_Username, peer.addressName == nil ? "" : ("@" + peer.addressName!)))
        
        entries.append(.askAQuestion(presentationData.theme, presentationData.strings.Settings_Support, state.loadingSupportPeer))
        entries.append(.language(presentationData.theme, presentationData.strings.Settings_AppLanguage, presentationData.strings.Localization_LanguageName))
        entries.append(.faq(presentationData.theme, presentationData.strings.Settings_FAQ))
        entries.append(.debug(presentationData.theme, "Debug"))
        
        if let _ = state.editingState {
            entries.append(.logOut(presentationData.theme, presentationData.strings.Settings_Logout))
        }
    }
    
    return entries
}

public func settingsController(account: Account, accountManager: AccountManager) -> ViewController {
    let statePromise = ValuePromise(SettingsState(updatingAvatar: nil, editingState: nil, updatingName: nil, loadingSupportPeer: false), ignoreRepeated: true)
    let stateValue = Atomic(value: SettingsState(updatingAvatar: nil, editingState: nil, updatingName: nil, loadingSupportPeer: false))
    let updateState: ((SettingsState) -> SettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let supportPeerDisposable = MetaDisposable()
    actionsDisposable.add(supportPeerDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    let wallpapersPromise = Promise<[TelegramWallpaper]>()
    wallpapersPromise.set(telegramWallpapers(account: account))
    
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
            let galleryController = AvatarGalleryController(account: account, peer: peer, replaceRootController: { controller, ready in
                
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, changeProfilePhoto: {
        let legacyController = LegacyController(presentation: .custom)
        legacyController.statusBar.statusBarStyle = .Ignore
        
        let emptyController = LegacyEmptyController(context: legacyController.context)!
        let navigationController = makeLegacyNavigationController(rootController: emptyController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
        
        legacyController.bind(controller: navigationController)
        
        presentControllerImpl?(legacyController, nil)
        
        let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasDeleteButton: false, personalPhoto: true, saveEditedPhotos: false, saveCapturedMedia: false)!
        let _ = currentAvatarMixin.swap(mixin)
        mixin.didFinishWithImage = { image in
            if let image = image {
                if let data = UIImageJPEGRepresentation(image, 0.6) {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                    updateState {
                        $0.withUpdatedUpdatingAvatar(representation)
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
    }, openPrivacyAndSecurity: {
        pushControllerImpl?(privacyAndSecurityController(account: account, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: account) |> map { Optional($0) })))
    }, openDataAndStorage: {
        pushControllerImpl?(dataAndStorageController(account: account))
    }, openThemes: {
        pushControllerImpl?(ThemeGridController(account: account))
    }, openTheme: { wallpaper in
        let _ = (wallpapersPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { wallpapers in
            let controller = ThemeGalleryController(account: account, wallpapers: wallpapers, at: wallpaper)
            presentControllerImpl?(controller, ThemePreviewControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
                return nil
            }))
        })
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller in
        presentControllerImpl?(controller, nil)
    }, updateEditingName: { editingName in
        updateState { state in
            if let _ = state.editingState {
                return state.withUpdatedEditingState(SettingsEditingState(editingName: editingName))
            } else {
                return state
            }
        }
    }, saveEditingState: {
        var updateName: ItemListAvatarAndNameInfoItemName?
        updateState { state in
            if let editingState = state.editingState {
                updateName = editingState.editingName
                return state.withUpdatedEditingState(nil).withUpdatedUpdatingName(editingState.editingName)
            } else {
                return state
            }
        }
        if let updateName = updateName, case let .personName(firstName, lastName) = updateName {
            updatePeerNameDisposable.set((updateAccountPeerName(account: account, firstName: firstName, lastName: lastName) |> afterDisposed {
                Queue.mainQueue().async {
                    updateState { state in
                        return state.withUpdatedUpdatingName(nil)
                    }
                }
            }).start())
        }
    }, openLanguage: {
        let controller = LanguageSelectionController(account: account)
        presentControllerImpl?(controller, nil)
    }, openSupport: {
        var load = false
        updateState { state in
            if !state.loadingSupportPeer {
                load = true
            }
            return state.withUpdatedLoadingSupportPeer(true)
        }
        if load {
            supportPeerDisposable.set((supportPeerId(account: account) |> deliverOnMainQueue).start(next: { peerId in
                updateState { state in
                    return state.withUpdatedLoadingSupportPeer(false)
                }
                if let peerId = peerId {
                    pushControllerImpl?(ChatController(account: account, peerId: peerId))
                }
            }))
        }
    }, openFaq: {
        var faqUrl = NSLocalizedString("Settings.FAQ_URL", comment: "")
        if faqUrl == "Settings.FAQ_URL" {
            faqUrl = "http://telegram.org/faq#general"
        }
        
        if let applicationContext = account.applicationContext as? TelegramApplicationContext {
            applicationContext.applicationBindings.openUrl(faqUrl)
        }
    }, logout: {
        let alertController = standardTextAlertController(title: NSLocalizedString("Settings.LogoutConfirmationTitle", comment: ""), text: NSLocalizedString("Settings.LogoutConfirmationText", comment: ""), actions: [
            TextAlertAction(type: .genericAction, title: "Cancel", action: {
            }),
            TextAlertAction(type: .defaultAction, title: "OK", action: {
                let _ = logoutFromAccount(id: account.id, accountManager: accountManager).start()
            })
            ])
        presentControllerImpl?(alertController, nil)
    })
    
    let peerView = account.viewTracker.peerView(account.peerId)
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peerView, wallpapersPromise.get())
        |> map { presentationData, state, view, wallpapers -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            let rightNavigationButton: ItemListNavigationButton
            if let _ = state.editingState {
                rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Done, style: .bold, enabled: true, action: {
                    arguments.saveEditingState()
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Edit, style: .regular, enabled: true, action: {
                    if let peer = peer as? TelegramUser {
                        updateState { state in
                            return state.withUpdatedEditingState(SettingsEditingState(editingName: ItemListAvatarAndNameInfoItemName(peer.indexName)))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Settings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: settingsEntries(presentationData: presentationData, state: state, view: view, wallpapers: wallpapers), style: .blocks)
            
            return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal, tabBarItem: (account.applicationContext as! TelegramApplicationContext).presentationData |> map { presentationData in
        return ItemListControllerTabBarItem(title: presentationData.strings.Settings_Title, image: PresentationResourcesRootController.tabSettingsIcon(presentationData.theme), selectedImage: PresentationResourcesRootController.tabSettingsSelectedIcon(presentationData.theme))
    })
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, arguments in
        controller?.present(value, in: .window(.root), with: arguments ?? ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: (ASDisplayNode, CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, transitionContainerNode: controller.displayNode, transitionBackgroundNode: controller.displayNode)
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
    return controller
}
