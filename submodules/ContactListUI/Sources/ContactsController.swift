import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramPermissions
import TelegramNotices
import ContactsPeerItem
import SearchUI
import TelegramPermissionsUI
import AppBundle
import StickerResources
import ContextUI
import QrCodeUI
import StoryContainerScreen
import ChatListHeaderComponent
import TelegramIntents
import UndoUI
import ShareController
import SearchBarNode

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

public class ContactsController: ViewController {
    private let context: AccountContext
    
    /// The contact list draws its own header (no Display bar); it takes part in navigation transitions itself.
    override public var navigationBarTransitionSource: NavigationBarTransitionSource? {
        guard self.isNodeLoaded else {
            return nil
        }
        return self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View
    }

    private var contactsNode: ContactsControllerNode {
        return self.displayNode as! ContactsControllerNode
    }
    private var validLayout: ContainerViewLayout?
    
    private let index: PresentationPersonNameOrder = .lastFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var selectionDisposable: Disposable?
    private var actionDisposable = MetaDisposable()
    private let sortOrderPromise = Promise<ContactsSortOrder>()
    private let isInVoiceOver = ValuePromise<Bool>(false)
    
    public override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isNodeLoaded {
            self.contactsNode.contactListNode.updateSelectedChatLocation(data as? ChatLocation, progress: progress, transition: transition)
        }
    }
    
    /// Run once the screen has appeared (`performWhenAppeared`).
    private var hasAppeared = false
    private var appearActions: [(ContactsController) -> Void] = []
    
    /// The Contacts screen, pushed over Settings (Settings ▸ Contacts, `tg://contacts`): the header has a back button,
    /// Sort and Add.
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Contacts_Title
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
        
        // The contacts-access warning is Settings ▸ Contacts' (`contactsPermissionWarning` in PeerInfoScreen).
        self.sortOrderPromise.set(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings])
        |> map { sharedData -> ContactsSortOrder in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
            return settings?.sortOrder ?? .presence
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.actionDisposable.dispose()
        self.selectionDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Contacts_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        let sortOrderSignal: Signal<ContactsSortOrder, NoError> = combineLatest(self.sortOrderPromise.get(), self.isInVoiceOver.get())
        |> map { sortOrder, isInVoiceOver in
            if isInVoiceOver {
                return .natural
            } else {
                return sortOrder
            }
        }
        self.displayNode = ContactsControllerNode(context: self.context, sortOrder: sortOrderSignal |> distinctUntilChanged, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, controller: self)
        self._ready.set(combineLatest(queue: .mainQueue(),
            self.contactsNode.contactListNode.ready,
            self.contactsNode.storiesReady.get()
        )
        |> filter { a, b in
            return a && b
        }
        |> take(1)
        |> map { _ -> Bool in true })
        
        let openPeer: (ContactListPeer, Bool) -> Void = { [weak self] peer, fromSearch in
            if let strongSelf = self {
                switch peer {
                    case let .peer(peer, _, _):
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            var scrollToEndIfExists = false
                            if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                                scrollToEndIfExists = true
                            }
                            
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), purposefulAction: { [weak self] in
                                if fromSearch {
                                    self?.deactivateSearch(animated: false)
                                }
                                }, scrollToEndIfExists: scrollToEndIfExists, options: [.removeOnMasterDetails], completion: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                                }
                            }))
                        }
                    case let .deviceContact(id, _):
                        let _ = ((strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { value in
                            guard let strongSelf = self, let value = value else {
                                return
                            }
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .vcard(nil, id, value), completed: nil, cancelled: nil), completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                                }
                            })
                        })
                }
            }
        }
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { peer in
            openPeer(peer, true)
        }
        
        self.contactsNode.contactListNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://telegram.org/privacy", forceExternal: true, presentationData: strongSelf.presentationData, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {})
            }
        }
        
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                })
            }
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer, _, _, _ in
            guard let self else {
                return
            }
            if let _ = self.contactsNode.contactListNode.selectionState {
                self.contactsNode.contactListNode.updateSelectionState({ current in
                    if let updatedState = current?.withToggledPeerId(peer.id), !updatedState.selectedPeerIndices.isEmpty {
                        return updatedState
                    } else {
                        return nil
                    }
                })
            } else {
                openPeer(peer, false)
            }
        }
        
        self.contactsNode.requestAddContact = { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, peer: nil, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    (self?.navigationController as? NavigationController)?.pushViewController(controller)
                }, completed: {
                    self?.deactivateSearch(animated: false)
                })
            }
        }
        
        self.contactsNode.openInvite = { [weak self] in
            let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
            |> take(1)
            |> deliverOnMainQueue).start(next: { value in
                guard let strongSelf = self else {
                    return
                }
                switch value {
                    case .allowed:
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(InviteContactsController(context: strongSelf.context), completion: {
                            if let strongSelf = self {
                                strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                            }
                        })
                    case .notDetermined:
                        DeviceAccess.authorizeAccess(to: .contacts)
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    default:
                        let presentationData = strongSelf.presentationData
                        strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            self?.context.sharedContext.applicationBindings.openSettings()
                        })]), in: .window(.root))
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                }
            })
        }
        
        self.contactsNode.openQrScan = { [weak self] in
            if let strongSelf = self {
                let context = strongSelf.context
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                DeviceAccess.authorizeAccess(to: .camera(.qrCode), presentationData: presentationData, present: { c, a in
                    c.presentationArguments = a
                    context.sharedContext.mainWindow?.present(c, on: .root)
                }, openSettings: {
                    context.sharedContext.applicationBindings.openSettings()
                }, { [weak self] granted in
                    guard let strongSelf = self else {
                        return
                    }
                    guard granted else {
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                        return
                    }
                    let controller = QrCodeScanScreen(context: strongSelf.context, subject: .peer)
                    controller.showMyCode = { [weak self, weak controller] in
                        if let strongSelf = self {
                            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.context.account.peerId))
                            |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                                if let peer {
                                    return .single(peer)
                                } else {
                                    return .never()
                                }
                            }
                            |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                                if let strongSelf = self, let controller = controller {
                                    controller.present(strongSelf.context.sharedContext.makeChatQrCodeScreen(context: strongSelf.context, peer: peer, threadId: nil, temporary: false), in: .window(.root))
                                }
                            })
                        }
                    }
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(controller, completion: {
                        if let strongSelf = self {
                            strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                        }
                    })
                })
            }
        }
        
        let previousToolbarValue = Atomic<Toolbar?>(value: nil)
        self.selectionDisposable = (self.contactsNode.contactListNode.selectionStateSignal
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self, let layout = self.validLayout else {
                return
            }
            
            let toolbar: Toolbar?
            if let state, state.selectedPeerIndices.count > 0 {
                toolbar = Toolbar(leftAction: nil, rightAction: nil, middleAction: ToolbarAction(title: self.presentationData.strings.ContactList_DeleteConfirmation(Int32(state.selectedPeerIndices.count)), isEnabled: true, color: .custom(self.presentationData.theme.actionSheet.destructiveActionTextColor)))
            } else {
                toolbar = nil
            }
            
            let _ = self.contactsNode.updateNavigationBar(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
            
            var transition: ContainedViewLayoutTransition = .immediate
            let previousToolbar = previousToolbarValue.swap(toolbar)
            if (previousToolbar == nil) != (toolbar == nil) {
                transition = .animated(duration: 0.4, curve: .spring)
            }
            self.setToolbar(toolbar, transition: transition)
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func toolbarActionSelected(action: ToolbarActionOption) {
        guard case .middle = action, let selectionState = self.contactsNode.contactListNode.selectionState else {
            return
        }
        var peerIds: [EnginePeer.Id] = []
        for contactPeerId in selectionState.selectedPeerIndices.keys {
            if case let .peer(peerId) = contactPeerId {
                peerIds.append(peerId)
            }
        }
        self.requestDeleteContacts(peerIds: peerIds)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.didAppear = true
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.hasAppeared = true
        let actions = self.appearActions
        self.appearActions.removeAll()
        for action in actions {
            action(self)
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    private func searchContentNode() -> NavigationBarSearchContentNode? {
        if let navigationBarView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View {
            return navigationBarView.searchContentNode
        }
        return nil
    }
    
    private func chatListHeaderView() -> ChatListHeaderComponent.View? {
        if let navigationBarView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View {
            if let componentView = navigationBarView.headerContent.view as? ChatListHeaderComponent.View {
                return componentView
            }
        }
        return nil
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.isInVoiceOver.set(layout.inVoiceOver)
        
        self.validLayout = layout
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        self.contactsNode.openStories = { [weak self] peer, sourceNode in
            guard let self else {
                return
            }
            
            if let itemNode = sourceNode as? ContactsPeerItemNode {
                StoryContainerScreen.openPeerStories(context: self.context, peerId: peer.id, parentController: self, avatarNode: itemNode.avatarNode)
            }
        }
    }
    
    /// Opens the sort menu from the header's Sort button (`tg://contacts/sort`). Right after the push the button is
    /// still out of the window (the bar's push transition hands it back a moment later): the menu waits for it, for a
    /// second at most, rather than open anchored nowhere.
    public func sortPressed() {
        self.presentSortMenuFromHeader(attemptsLeft: 20)
    }
    
    private func presentSortMenuFromHeader(attemptsLeft: Int) {
        guard let navigationBarView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View, let headerContentView = navigationBarView.headerContent.view as? ChatListHeaderComponent.View, let sortButtonView = headerContentView.rightButtonViews["sort"] else {
            return
        }
        if sortButtonView.window == nil {
            if attemptsLeft > 0 {
                Queue.mainQueue().after(0.05, { [weak self] in
                    self?.presentSortMenuFromHeader(attemptsLeft: attemptsLeft - 1)
                })
            }
            return
        }
        self.presentSortMenu(sourceView: sortButtonView, gesture: nil)
    }
    
    /// Runs `action` once the screen is on screen: at once if it already is. A deep link that pushes the screen acts
    /// on its header only after the push has landed.
    public func performWhenAppeared(_ action: @escaping (ContactsController) -> Void) {
        if self.hasAppeared {
            action(self)
        } else {
            self.appearActions.append(action)
        }
    }
    
    private func activateSearch() {
        self.contactsNode.activateSearch(placeholderNode: self.searchContentNode()?.placeholderNode)
        (self.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.5, curve: .spring))
        self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
    }
    
    private func deactivateSearch(animated: Bool) {
        // The search bar animates back into the placeholder's frame as it is when the search deactivates, so the
        // bar is laid out without the active search first (beside iPhone Duo's status island the active search's
        // placeholder is narrower), as the chat list does.
        let completion = self.contactsNode.deactivateSearch(placeholderNode: self.searchContentNode()?.placeholderNode, animated: animated)
        (self.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.5, curve: .spring))
        self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
        completion?()
    }
    
    func presentSortMenu(sourceView: UIView, gesture: ContextGesture?) {
        // The choice is written to the contact settings, which `sortOrderPromise` follows.
        let items = contactsSortMenuItems(context: self.context, presentationData: self.presentationData)
        
        var sourceView = sourceView
        if let navigationBarComponentView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View, let headerContentView = navigationBarComponentView.headerContent.view as? ChatListHeaderComponent.View, let value = headerContentView.navigationButtonContextContainer(sourceView: sourceView) {
            sourceView = value
        }
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    public func beginSelection(peerId: EnginePeer.Id) {
        self.contactsNode.contactListNode.updateSelectionState { _ in
            return ContactListNodeGroupSelectionState().withToggledPeerId(.peer(peerId))
        }
    }
    
    public func requestDeleteContacts(peerIds: [EnginePeer.Id]) {
        guard !peerIds.isEmpty else {
            return
        }
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        let actionTitle: String
        if peerIds.count > 1 {
            actionTitle = self.presentationData.strings.ContactList_DeleteConfirmation(Int32(peerIds.count))
        } else {
            actionTitle = self.presentationData.strings.ContactList_DeleteConfirmationSingle
        }
        
        items.append(ActionSheetButtonItem(title: actionTitle, color: .destructive, action: { [weak self, weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            guard let self else {
                return
            }
            
            self.contactsNode.contactListNode.updateSelectionState { _ in
                return nil
            }
            
            self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                var state = state
                for peerId in peerIds {
                    state.insert(peerId)
                }
                return state
            }
            
            let text = self.presentationData.strings.ContactList_DeletedContacts(Int32(peerIds.count))
            
            self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: self.context, title: NSAttributedString(string: text), text: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                guard let self else {
                    return false
                }
                if value == .commit {
                    let deleteContactsFromDevice: Signal<Never, NoError>
                    if let contactDataManager = self.context.sharedContext.contactDataManager {
                        deleteContactsFromDevice = combineLatest(peerIds.map { contactDataManager.deleteContactWithAppSpecificReference(peerId: $0) }
                        )
                        |> ignoreValues
                    } else {
                        deleteContactsFromDevice = .complete()
                    }
                    
                    let deleteSignal = self.context.engine.contacts.deleteContacts(peerIds: peerIds)
                    |> then(deleteContactsFromDevice)
                    
                    for peerId in peerIds {
                        deleteSendMessageIntents(peerId: peerId)
                    }
                    
                    self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                        var state = state
                        for peerId in peerIds {
                            state.remove(peerId)
                        }
                        return state
                    }
                    
                    let _ = deleteSignal.start()
                    
                    return true
                } else if value == .undo {
                    self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                        var state = state
                        for peerId in peerIds {
                            state.remove(peerId)
                        }
                        return state
                    }
                    return true
                }
                return false
            }), in: .current)
        }))
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.present(actionSheet, in: .window(.root))
    }
    
    @objc func addPressed() {
        let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            
            switch status {
                case .allowed:
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                        let controller = strongSelf.context.sharedContext.makeNewContactScreen(
                            context: strongSelf.context,
                            peer: nil,
                            firstName: nil,
                            lastName: nil,
                            phoneNumber: nil,
                            shareViaException: false,
                            completion: { [weak self] peer, stableId, contactData in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let peer {
                                    Queue.mainQueue().async {
                                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                            if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                                navigationController.pushViewController(infoController)
                                            }
                                        }
                                    }
                                } else if let stableId, let contactData {
                                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                        navigationController.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .vcard(nil, stableId, contactData), completed: nil, cancelled: nil))
                                    }
                                }
                            }
                        )
                        navigationController.pushViewController(controller)
                    }
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .contacts)
                default:
                    let presentationData = strongSelf.presentationData
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController, let topController = navigationController.topViewController as? ViewController {
                        topController.present(textAlertController(context: strongSelf.context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            self?.context.sharedContext.applicationBindings.openSettings()
                        })]), in: .window(.root))
                    }
            }
        })
    }
    
    override public func tabBarActivateSearch() {
        self.activateSearch()
    }

    override public func tabBarDeactivateSearch() {
        self.deactivateSearch(animated: true)
    }
}

private final class ChatListHeaderBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: mainWindowScreenBounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}
