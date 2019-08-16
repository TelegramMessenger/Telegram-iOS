import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import AccountContext
import GalleryUI
import LegacyUI
import ItemListAvatarAndNameInfoItem
import WebSearchUI
import PeerAvatarGalleryUI
import MapResourceToAvatarSizes

private struct EditSettingsItemArguments {
    let context: AccountContext
    let accountManager: AccountManager
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    
    let avatarTapAction: () -> Void
    
    let pushController: (ViewController) -> Void
    let presentController: (ViewController) -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateBioText: (String, String) -> Void
    let saveEditingState: () -> Void
    let addAccount: () -> Void
    let logout: () -> Void
}

private enum SettingsSection: Int32 {
    case info
    case bio
    case personalData
    case addAccount
    case logOut
}

public enum EditSettingsEntryTag: ItemListItemTag {
    case bio
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? EditSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}


private enum SettingsEntry: ItemListNodeEntry {
    case userInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, CachedPeerData?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case userInfoNotice(PresentationTheme, String)
    
    case bioText(PresentationTheme, String, String)
    case bioInfo(PresentationTheme, String)
    
    case phoneNumber(PresentationTheme, String, String)
    case username(PresentationTheme, String, String)
    
    case addAccount(PresentationTheme, String)
    case logOut(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .userInfo, .userInfoNotice:
                return SettingsSection.info.rawValue
            case .bioText, .bioInfo:
                return SettingsSection.bio.rawValue
            case .phoneNumber, .username:
                return SettingsSection.personalData.rawValue
            case .addAccount:
                return SettingsSection.addAccount.rawValue
            case .logOut:
                return SettingsSection.logOut.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .userInfo:
                return 0
            case .userInfoNotice:
                return 1
            case .bioText:
                return 2
            case .bioInfo:
                return 3
            case .phoneNumber:
                return 4
            case .username:
                return 5
            case .addAccount:
                return 6
            case .logOut:
                return 7
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
            case let .userInfoNotice(lhsTheme, lhsText):
                if case let .userInfoNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .bioText(lhsTheme, lhsCurrentText, lhsText):
                if case let .bioText(rhsTheme, rhsCurrentText, rhsText) = rhs, lhsTheme === rhsTheme, lhsCurrentText == rhsCurrentText, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .bioInfo(lhsTheme, lhsText):
                if case let .bioInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .addAccount(lhsTheme, lhsText):
                if case let .addAccount(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
    
    func item(_ arguments: EditSettingsItemArguments) -> ListViewItem {
        switch self {
            case let .userInfo(theme, strings, dateTimeFormat, peer, cachedData, state, updatingImage):
                return ItemListAvatarAndNameInfoItem(account: arguments.context.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .editSettings, peer: peer, presence: TelegramUserPresence(status: .present(until: Int32.max), lastActivity: 0), cachedData: cachedData, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.avatarTapAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingImage)
            case let .userInfoNotice(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .bioText(theme, currentText, placeholder):
                return ItemListMultilineInputItem(theme: theme, text: currentText, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: 70, display: true), sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateBioText(currentText, updatedText)
                }, tag: EditSettingsEntryTag.bio, action: {
                })
            case let .bioInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .phoneNumber(theme, text, number):
                return ItemListDisclosureItem(theme: theme, title: text, label: number, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.pushController(ChangePhoneNumberIntroController(context: arguments.context, phoneNumber: number))
                })
            case let .username(theme, text, address):
                return ItemListDisclosureItem(theme: theme, title: text, label: address, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.presentController(usernameSetupController(context: arguments.context))
                })
            case let .addAccount(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .center, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.addAccount()
                })
            case let .logOut(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .center, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.logout()
                })
        }
    }
}

private struct EditSettingsState: Equatable {
    let updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let editingName: ItemListAvatarAndNameInfoItemName
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let editingBioText: String
    let updatingBioText: Bool
    
    init(updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar? = nil, editingName: ItemListAvatarAndNameInfoItemName, updatingName: ItemListAvatarAndNameInfoItemName? = nil, editingBioText: String, updatingBioText: Bool = false) {
        self.updatingAvatar = updatingAvatar
        self.editingName = editingName
        self.updatingName = updatingName
        self.editingBioText = editingBioText
        self.updatingBioText = updatingBioText
    }
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?) -> EditSettingsState {
        return EditSettingsState(updatingAvatar: updatingAvatar, editingName: self.editingName, updatingName: self.updatingName, editingBioText: self.editingBioText, updatingBioText: self.updatingBioText)
    }
    
    func withUpdatedEditingName(_ editingName: ItemListAvatarAndNameInfoItemName) -> EditSettingsState {
        return EditSettingsState(updatingAvatar: self.updatingAvatar, editingName: editingName, updatingName: self.updatingName, editingBioText: self.editingBioText, updatingBioText: self.updatingBioText)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> EditSettingsState {
        return EditSettingsState(updatingAvatar: self.updatingAvatar, editingName: self.editingName, updatingName: updatingName, editingBioText: self.editingBioText, updatingBioText: self.updatingBioText)
    }
    
    func withUpdatedEditingBioText(_ editingBioText: String) -> EditSettingsState {
        return EditSettingsState(updatingAvatar: self.updatingAvatar, editingName: self.editingName, updatingName: self.updatingName, editingBioText: editingBioText, updatingBioText: self.updatingBioText)
    }
    
    func withUpdatedUpdatingBioText(_ updatingBioText: Bool) -> EditSettingsState {
        return EditSettingsState(updatingAvatar: self.updatingAvatar, editingName: self.editingName, updatingName: self.updatingName, editingBioText: self.editingBioText, updatingBioText: updatingBioText)
    }
    
    static func ==(lhs: EditSettingsState, rhs: EditSettingsState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.editingBioText != rhs.editingBioText {
            return false
        }
        if lhs.updatingBioText != rhs.updatingBioText {
            return false
        }
        return true
    }
}

private func editSettingsEntries(presentationData: PresentationData, state: EditSettingsState, view: PeerView, canAddAccounts: Bool) -> [SettingsEntry] {
    var entries: [SettingsEntry] = []
    
    if let peer = peerViewMainPeer(view) as? TelegramUser {
        let userInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: state.updatingName)
        entries.append(.userInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, view.cachedData, userInfoState, state.updatingAvatar))
        entries.append(.userInfoNotice(presentationData.theme, presentationData.strings.EditProfile_NameAndPhotoHelp))
        
        entries.append(.bioText(presentationData.theme, state.editingBioText, presentationData.strings.UserInfo_About_Placeholder))
        entries.append(.bioInfo(presentationData.theme, presentationData.strings.Settings_About_Help))
        
        if let phone = peer.phone {
            entries.append(.phoneNumber(presentationData.theme, presentationData.strings.Settings_PhoneNumber, formatPhoneNumber(phone)))
        }
        entries.append(.username(presentationData.theme, presentationData.strings.Settings_Username, peer.addressName == nil ? "" : ("@" + peer.addressName!)))
        
        if canAddAccounts {
            entries.append(.addAccount(presentationData.theme, presentationData.strings.Settings_AddAccount))
        }
        entries.append(.logOut(presentationData.theme, presentationData.strings.Settings_Logout))
    }
    
    return entries
}

func editSettingsController(context: AccountContext, currentName: ItemListAvatarAndNameInfoItemName, currentBioText: String, accountManager: AccountManager, canAddAccounts: Bool, focusOnItemTag: EditSettingsEntryTag? = nil) -> ViewController {
    let initialState = EditSettingsState(editingName: currentName, editingBioText: currentBioText)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((EditSettingsState) -> EditSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    var errorImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateAvatarDisposable = MetaDisposable()
    //actionsDisposable.add(updateAvatarDisposable)
    
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
    var changeProfilePhotoImpl: (() -> Void)?
    
    var getNavigationController: (() -> NavigationController?)?
    
    let arguments = EditSettingsItemArguments(context: context, accountManager: accountManager, avatarAndNameInfoContext: avatarAndNameInfoContext, avatarTapAction: {
        var updating = false
        updateState {
            updating = $0.updatingAvatar != nil
            return $0
        }
        
        if updating {
            return
        }
        
        changeProfilePhotoImpl?()
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller in
        presentControllerImpl?(controller, nil)
    }, updateEditingName: { editingName in
        updateState { state in
            return state.withUpdatedEditingName(editingName)
        }
    }, updateBioText: { currentText, text in
        updateState { state in
            return state.withUpdatedEditingBioText(text)
        }
    }, saveEditingState: {
        var updateName: ItemListAvatarAndNameInfoItemName?
        var updateBio: String?
        var failed = false
        updateState { state in
            if state.editingName != currentName {
                updateName = state.editingName
            }
            if state.editingBioText != currentBioText {
                updateBio = state.editingBioText
            }
            
            if (updateBio?.count ?? 0) > 70 {
                failed = true
                return state
            }
            
            if updateName != nil || updateBio != nil {
                return state.withUpdatedUpdatingName(state.editingName).withUpdatedUpdatingBioText(true)
            } else {
                return state
            }
        }
        
        guard !failed else {
            errorImpl?()
            return
        }
        
        var updateNameSignal: Signal<Void, NoError> = .complete()
        if let updateName = updateName, case let .personName(firstName, lastName) = updateName {
            updateNameSignal = updateAccountPeerName(account: context.account, firstName: firstName, lastName: lastName)
        }
        var updateBioSignal: Signal<Void, NoError> = .complete()
        if let updateBio = updateBio {
            updateBioSignal = updateAbout(account: context.account, about: updateBio)
            |> `catch` { _ -> Signal<Void, NoError> in
                return .complete()
            }
        }
        updatePeerNameDisposable.set((combineLatest(updateNameSignal, updateBioSignal) |> deliverOnMainQueue).start(completed: {
            dismissImpl?()
        }))
    }, addAccount: {
        let isTestingEnvironment = context.account.testingEnvironment
        context.sharedContext.beginNewAuth(testingEnvironment: isTestingEnvironment)
    }, logout: {
        let _ = (context.account.postbox.transaction { transaction -> String in
            return (transaction.getPeer(context.account.peerId) as? TelegramUser)?.phone ?? ""
        }
        |> deliverOnMainQueue).start(next: { phoneNumber in
            if let navigationController = getNavigationController?() {
                presentControllerImpl?(logoutOptionsController(context: context, navigationController: navigationController, canAddAccounts: canAddAccounts, phoneNumber: phoneNumber), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    })
    
    let peerView = context.account.viewTracker.peerView(context.account.peerId)
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), peerView)
    |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState<SettingsEntry>, SettingsEntry.ItemGenerationArguments)) in
        let rightNavigationButton: ItemListNavigationButton
        if state.updatingName != nil || state.updatingBioText {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                arguments.saveEditingState()
            })
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.EditProfile_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: editSettingsEntries(presentationData: presentationData, state: state, view: view, canAddAccounts: canAddAccounts), style: .blocks, ensureVisibleItemTag: focusOnItemTag)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal, tabBarItem: nil)
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, arguments in
        controller?.present(value, in: .window(.root), with: arguments ?? ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
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
    changeProfilePhotoImpl = { [weak controller] in
        let _ = (context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
            return (transaction.getPeer(context.account.peerId), currentSearchBotsConfiguration(transaction: transaction))
        } |> deliverOnMainQueue).start(next: { peer, searchBotsConfiguration in
            controller?.view.endEditing(true)
            
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
                if let data = image.jpegData(compressionQuality: 0.6) {
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
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos, hasViewButton: hasPhotos, personalPhoto: true, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
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
            mixin.didFinishWithView = {
                let _ = currentAvatarMixin.swap(nil)
                
                let _ = (context.account.postbox.loadedPeerWithId(context.account.peerId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { peer in
                    if peer.smallProfileImage != nil {
                        let galleryController = AvatarGalleryController(context: context, peer: peer, replaceRootController: { controller, ready in
                        })
                        /*hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                            avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                            updateHiddenAvatarImpl?()
                        }))*/
                        presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                            return nil
                        }))
                    } else {
                        changeProfilePhotoImpl?()
                    }
                })
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
    
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListMultilineInputItemNode {
                itemNode.animateError()
            }
        }
    }
    
    getNavigationController = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    
    return controller
}

