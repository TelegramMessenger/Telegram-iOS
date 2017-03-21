import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct SettingsItemArguments {
    let account: Account
    let accountManager: AccountManager
    
    let openPrivacyAndSecurity: () -> Void
    let pushController: (ViewController) -> Void
    let presentController: (ViewController) -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let saveEditingState: () -> Void
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
    case userInfo(Peer?, CachedPeerData?, ItemListAvatarAndNameInfoItemState)
    case setProfilePhoto
    
    case notificationsAndSounds
    case privacyAndSecurity
    case dataAndStorage
    case stickers
    case phoneNumber(String)
    case username(String)
    case askAQuestion(Bool)
    case faq
    case debug
    case logOut
    
    var section: ItemListSectionId {
        switch self {
            case .userInfo, .setProfilePhoto:
                return SettingsSection.info.rawValue
            case .notificationsAndSounds, .privacyAndSecurity, .dataAndStorage, .stickers:
                return SettingsSection.generalSettings.rawValue
            case .phoneNumber, .username:
                return SettingsSection.accountSettings.rawValue
            case .askAQuestion, .faq, .debug:
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
            case .phoneNumber:
                return 6
            case .username:
                return 7
            case .askAQuestion:
                return 8
            case .faq:
                return 9
            case .debug:
                return 10
            case .logOut:
                return 11
        }
    }
    
    static func ==(lhs: SettingsEntry, rhs: SettingsEntry) -> Bool {
        switch lhs {
            case let .userInfo(lhsPeer, lhsCachedData, lhsEditingState):
                if case let .userInfo(rhsPeer, rhsCachedData, rhsEditingState) = rhs {
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
                    return true
                } else {
                    return false
                }
            case .setProfilePhoto:
                if case .setProfilePhoto = rhs {
                    return true
                } else {
                    return false
                }
            case .notificationsAndSounds:
                if case .notificationsAndSounds = rhs {
                    return true
                } else {
                    return false
                }
            case .privacyAndSecurity:
                if case .privacyAndSecurity = rhs {
                    return true
                } else {
                    return false
                }
            case .dataAndStorage:
                if case .dataAndStorage = rhs {
                    return true
                } else {
                    return false
                }
            case .stickers:
                if case .stickers = rhs {
                    return true
                } else {
                    return false
                }
            case let .phoneNumber(number):
                if case .phoneNumber(number) = rhs {
                    return true
                } else {
                    return false
                }
            case let .username(address):
                if case .username(address) = rhs {
                    return true
                } else {
                    return false
                }
            case let .askAQuestion(loading):
                if case .askAQuestion(loading) = rhs {
                    return true
                } else {
                    return false
                }
            case .faq:
                if case .faq = rhs {
                    return true
                } else {
                    return false
                }
            case .debug:
                if case .debug = rhs {
                    return true
                } else {
                    return false
                }
            case .logOut:
                if case .logOut = rhs {
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
            case let .userInfo(peer, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max)), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case .setProfilePhoto:
                return ItemListActionItem(title: "Set Profile Photo", kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                })
            case .notificationsAndSounds:
                return ItemListDisclosureItem(title: "Notifications and Sounds", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(notificationsAndSoundsController(account: arguments.account))
                })
            case .privacyAndSecurity:
                return ItemListDisclosureItem(title: "Privacy and Security", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openPrivacyAndSecurity()
                })
            case .dataAndStorage:
                return ItemListDisclosureItem(title: "Data and Storage", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    
                })
            case .stickers:
                return ItemListDisclosureItem(title: "Stickers", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(installedStickerPacksController(account: arguments.account, mode: .general))
                })
            case let .phoneNumber(number):
                return ItemListDisclosureItem(title: "Phone Number", label: number, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(ChangePhoneNumberIntroController(account: arguments.account, phoneNumber: number))
                })
            case let .username(address):
                return ItemListDisclosureItem(title: "Username", label: address, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.presentController(usernameSetupController(account: arguments.account))
                })
            case let .askAQuestion(askAQuestion):
                return ItemListDisclosureItem(title: "Ask a Question", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openSupport()
                })
            case .faq:
                return ItemListDisclosureItem(title: "Telegram FAQ", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.openFaq()
                })
            case .debug:
                return ItemListDisclosureItem(title: "Debug", label: "", sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(debugController(account: arguments.account, accountManager: arguments.accountManager))
                })
            case .logOut:
                return ItemListActionItem(title: "Log Out", kind: .destructive, alignment: .center, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
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
    let editingState: SettingsEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let loadingSupportPeer: Bool
    
    func withUpdatedEditingState(_ editingState: SettingsEditingState?) -> SettingsState {
        return SettingsState(editingState: editingState, updatingName: self.updatingName, loadingSupportPeer: self.loadingSupportPeer)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> SettingsState {
        return SettingsState(editingState: self.editingState, updatingName: updatingName, loadingSupportPeer: self.loadingSupportPeer)
    }
    
    func withUpdatedLoadingSupportPeer(_ loadingSupportPeer: Bool) -> SettingsState {
        return SettingsState(editingState: self.editingState, updatingName: self.updatingName, loadingSupportPeer: loadingSupportPeer)
    }
    
    static func ==(lhs: SettingsState, rhs: SettingsState) -> Bool {
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

private func settingsEntries(state: SettingsState, view: PeerView) -> [SettingsEntry] {
    var entries: [SettingsEntry] = []
    
    if let peer = peerViewMainPeer(view) as? TelegramUser {
        let userInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingState?.editingName, updatingName: state.updatingName)
        entries.append(.userInfo(peer, view.cachedData, userInfoState))
        entries.append(.setProfilePhoto)
        
        entries.append(.notificationsAndSounds)
        entries.append(.privacyAndSecurity)
        entries.append(.dataAndStorage)
        entries.append(.stickers)
        
        if let phone = peer.phone {
            entries.append(.phoneNumber(formatPhoneNumber(phone)))
        }
        entries.append(.username(peer.addressName == nil ? "" : ("@" + peer.addressName!)))
        
        entries.append(.askAQuestion(state.loadingSupportPeer))
        entries.append(.faq)
        entries.append(.debug)
        
        if let _ = state.editingState {
            entries.append(.logOut)
        }
    }
    
    return entries
}

public func settingsController(account: Account, accountManager: AccountManager) -> ViewController {
    let statePromise = ValuePromise(SettingsState(editingState: nil, updatingName: nil, loadingSupportPeer: false), ignoreRepeated: true)
    let stateValue = Atomic(value: SettingsState(editingState: nil, updatingName: nil, loadingSupportPeer: false))
    let updateState: ((SettingsState) -> SettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let supportPeerDisposable = MetaDisposable()
    actionsDisposable.add(supportPeerDisposable)
    
    //let privacySettings = Promise<AccountPrivacySettings?>()
    //privacySettings.set(.single(nil) |> then(requestAccountPrivacySettings(account: account) |> map { Optional($0) }))
    
    let arguments = SettingsItemArguments(account: account, accountManager: accountManager, openPrivacyAndSecurity: {
        pushControllerImpl?(privacyAndSecurityController(account: account, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: account) |> map { Optional($0) })))
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller in
        presentControllerImpl?(controller)
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
            applicationContext.openUrl(faqUrl)
        }
    }, logout: {
        let alertController = standardTextAlertController(title: NSLocalizedString("Settings.LogoutConfirmationTitle", comment: ""), text: NSLocalizedString("Settings.LogoutConfirmationText", comment: ""), actions: [
            TextAlertAction(type: .genericAction, title: "Cancel", action: {
            }),
            TextAlertAction(type: .defaultAction, title: "OK", action: {
                let _ = logoutFromAccount(id: account.id, accountManager: accountManager).start()
            })
            ])
        presentControllerImpl?(alertController)
    })
    
    let peerView = account.viewTracker.peerView(account.peerId)
    
    let signal = combineLatest(statePromise.get(), peerView)
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            let rightNavigationButton: ItemListNavigationButton
            if let _ = state.editingState {
                rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
                    arguments.saveEditingState()
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                    if let peer = peer as? TelegramUser {
                        updateState { state in
                            return state.withUpdatedEditingState(SettingsEditingState(editingName: ItemListAvatarAndNameInfoItemName(peer.indexName)))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(title: "Settings", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: settingsEntries(state: state, view: view), style: .blocks)
            
            return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    controller.tabBarItem.title = "Settings"
    controller.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconSettings")?.precomposed()
    controller.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconSettingsSelected")?.precomposed()
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value in
        controller?.present(value, in: .window, with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    return controller
}
