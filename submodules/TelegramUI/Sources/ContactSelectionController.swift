import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import ContactListUI
import SearchUI
import AttachmentUI
import SearchBarNode
import ChatSendAudioMessageContextPreview
import ChatSendMessageActionUI
import ContextUI

class ContactSelectionControllerImpl: ViewController, ContactSelectionController, PresentableController, AttachmentContainable {
    private let context: AccountContext
    private let mode: ContactSelectionControllerMode
    private let autoDismiss: Bool
    
    fileprivate var contactsNode: ContactSelectionControllerNode {
        return self.displayNode as! ContactSelectionControllerNode
    }
    
    var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if self.isNodeLoaded {
                    self.contactsNode.displayProgress = self.displayProgress
                }
            }
        }
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    private let titleProducer: (PresentationStrings) -> String
    private let options: Signal<[ContactListAdditionalOption], NoError>
    private let displayDeviceContacts: Bool
    private let displayCallIcons: Bool
    private let multipleSelection: Bool
    private let requirePhoneNumbers: Bool
    
    private let openProfile: ((EnginePeer) -> Void)?
    private let sendMessage: ((EnginePeer) -> Void)?
    
    private var _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    fileprivate var caption: NSAttributedString?
    
    private let _result = Promise<([ContactListPeer], ContactListAction, Bool, Int32?, NSAttributedString?, ChatSendMessageActionSheetController.SendParameters?)?>()
    var result: Signal<([ContactListPeer], ContactListAction, Bool, Int32?, NSAttributedString?, ChatSendMessageActionSheetController.SendParameters?)?, NoError> {
        return self._result.get()
    }
    
    private let confirmation: (ContactListPeer) -> Signal<Bool, NoError>
    var dismissed: (() -> Void)?
    
    var presentScheduleTimePicker: (@escaping (Int32) -> Void) -> Void = { _ in }
    
    private let createActionDisposable = MetaDisposable()
    private let confirmationDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarContentNode?
    
    var displayNavigationActivity: Bool = false {
        didSet {
            if self.displayNavigationActivity != oldValue {
                if self.displayNavigationActivity {
                    self.navigationItem.setRightBarButton(UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor)), animated: false)
                } else {
                    self.navigationItem.setRightBarButton(nil, animated: false)
                }
            }
        }
    }
    
    var requestAttachmentMenuExpansion: () -> Void = {}
    var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = {
        return nil
    }
    var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var cancelPanGesture: () -> Void = { }
    var isContainerPanning: () -> Bool = { return false }
    var isContainerExpanded: () -> Bool = { return false }
    var isMinimized: Bool = false
    
    var getCurrentSendMessageContextMediaPreview: (() -> ChatSendMessageContextScreenMediaPreview?)?
    
    init(_ params: ContactSelectionControllerParams) {
        self.context = params.context
        self.mode = params.mode
        self.autoDismiss = params.autoDismiss
        self.titleProducer = params.title
        self.options = params.options
        self.displayDeviceContacts = params.displayDeviceContacts
        self.displayCallIcons = params.displayCallIcons
        self.confirmation = params.confirmation
        self.multipleSelection = params.multipleSelection
        self.requirePhoneNumbers = params.requirePhoneNumbers
        
        self.openProfile = params.openProfile
        self.sendMessage = params.sendMessage
        
        self.presentationData = params.updatedPresentationData?.initial ?? params.context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.titleProducer(self.presentationData.strings)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode as? NavigationBarSearchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.contactsNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = ((params.updatedPresentationData?.signal ?? params.context.sharedContext.presentationData)
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        if !params.multipleSelection {
            self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
                self?.activateSearch()
            })
            self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
        }
        
        if params.multipleSelection {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.beginSearch))
        }
        
        self.getCurrentSendMessageContextMediaPreview = { [weak self] in
            guard let self else {
                return nil
            }
            
            let selectedPeers = self.contactsNode.contactListNode.selectedPeers
            if selectedPeers.isEmpty {
                return nil
            }
            
            return ChatSendContactMessageContextPreview(
                context: self.context,
                presentationData: self.presentationData,
                wallpaperBackgroundNode: nil,
                contactPeers: selectedPeers
            )
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.confirmationDisposable.dispose()
    }
    
    @objc private func beginSearch() {
        self.requestAttachmentMenuExpansion()
        self.activateSearch()
    }
    
    @objc private func beginSelection() {
        self.navigationItem.rightBarButtonItem = nil
        self.contactsNode.beginSelection()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        (self.searchContentNode as? NavigationBarSearchContentNode)?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = self.titleProducer(self.presentationData.strings)
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.contactsNode.updatePresentationData(self.presentationData)
    }
    
    @objc func cancelPressed() {
        self._result.set(.single(nil))
        
        self.dismiss()
    }
    
    override func loadDisplayNode() {
        self.displayNode = ContactSelectionControllerNode(context: self.context, mode: self.mode, presentationData: self.presentationData, options: self.options, displayDeviceContacts: self.displayDeviceContacts, displayCallIcons: self.displayCallIcons, multipleSelection: self.multipleSelection, requirePhoneNumbers: self.requirePhoneNumbers)
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peer in
            self?.openPeer(peer: peer, action: .generic, node: nil, gesture: nil)
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer, action, node, gesture in
            self?.openPeer(peer: peer, action: action, node: node, gesture: gesture)
        }
                
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                })
            }
        }
        
        self.contactsNode.cancelSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        
        self.contactsNode.contactListNode.contentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode as? NavigationBarSearchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.contactsNode.contactListNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode as? NavigationBarSearchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }

        self.contactsNode.requestMultipleAction = { [weak self] silent, scheduleTime, parameters in
            if let strongSelf = self {
                let selectedPeers = strongSelf.contactsNode.contactListNode.selectedPeers
                strongSelf._result.set(.single((selectedPeers, .generic, silent, scheduleTime, strongSelf.caption, parameters)))
                if strongSelf.autoDismiss {
                    strongSelf.dismiss()
                }
            }
        }
        
        self.displayNodeDidLoad()
        
        self.updateTabBarAlpha(1.0, .immediate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments {
            switch presentationArguments.presentationAnimation {
                case .modalSheet:
                    self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
                case .none:
                    break
            }
        }
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    func viewDidAppear(completion: @escaping () -> Void) {
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments {
            switch presentationArguments.presentationAnimation {
                case .modalSheet:
                    self.contactsNode.animateIn(completion: completion)
                case .none:
                    break
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY,  transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let searchContentNode = self.searchContentNode as? NavigationBarSearchContentNode {
                self.contactsNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
                self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
            } else if self.multipleSelection {
                let contentNode = ContactsSearchNavigationContentNode(presentationData: self.presentationData, dismissSearch: { [weak self] in
                    if let strongSelf = self, let navigationBar = strongSelf.navigationBar, let searchContentNode = strongSelf.searchContentNode as? ContactsSearchNavigationContentNode {
                        searchContentNode.deactivate()
                        strongSelf.searchContentNode = nil
                        navigationBar.setContentNode(nil, animated: true)
                        strongSelf.contactsNode.deactivateOverlaySearch()
                    }
                }, updateSearchQuery: { [weak self] query in
                    if let strongSelf = self {
                        strongSelf.contactsNode.searchContainerNode?.searchTextUpdated(text: query)
                    }
                })
                self.searchContentNode = contentNode
                self.navigationBar?.setContentNode(contentNode, animated: true)
                self.contactsNode.activateOverlaySearch()
                contentNode.activate()
            }
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.contactsNode.prepareDeactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode as? NavigationBarSearchContentNode {
                self.contactsNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        } else if let searchContentNode = self.searchContentNode as? ContactsSearchNavigationContentNode {
            searchContentNode.cancel()
        }
    }
    
    private func openPeer(peer: ContactListPeer, action: ContactListAction, node: ASDisplayNode?, gesture: ContextGesture?) {
        if case .more = action {
            guard case let .peer(peer, _, _) = peer, let node = node as? ContextReferenceContentNode else {
                return
            }
            
            let presentationData = self.presentationData
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Premium_Gift_ContactSelection_SendMessage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak self] _, a in
                a(.default)
              
                if let self {
                    self.sendMessage?(EnginePeer(peer))
                }
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Premium_Gift_ContactSelection_OpenProfile, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak self] _, a in
                a(.default)

                if let self {
                    self.openProfile?(EnginePeer(peer))
                }
            })))
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(ContactContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            self.present(contextController, in: .window(.root))
            return
        }
        
        self.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
        self.confirmationDisposable.set((self.confirmation(peer) |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    strongSelf._result.set(.single(([peer], action, false, nil, nil, nil)))
                    if strongSelf.autoDismiss {
                        strongSelf.dismiss()
                    }
                }
            }
        }))
    }
    
    func dismissSearch() {
        self.deactivateSearch()
    }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return ContactsPickerContext(controller: self)
    }
    
    public func prepareForReuse() {
        self.updateTabBarAlpha(1.0, .immediate)
    }
}

private let searchBarFont = Font.regular(17.0)

final class ContactsSearchNavigationContentNode: NavigationBarContentNode {
    private var presentationData: PresentationData
    
    private let searchBar: SearchBarNode
    
    init(presentationData: PresentationData, dismissSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void) {
        self.presentationData = presentationData
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings, fieldStyle: .modern)
        self.searchBar.placeholderString = NSAttributedString(string: presentationData.strings.Common_Search, font: searchBarFont, textColor: presentationData.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            dismissSearch()
        }
        self.searchBar.textUpdated = { query, _ in
            updateSearchQuery(query)
        }
    }
    
    override var nominalHeight: CGFloat {
        return 56.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 56.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
    
    func cancel() {
        self.searchBar.cancel?()
    }
    
    func updateActivity(_ activity: Bool) {
        self.searchBar.activity = activity
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings)
    }
}

final class ContactsPickerContext: AttachmentMediaPickerContext {
    private weak var controller: ContactSelectionControllerImpl?
    
    var selectionCount: Signal<Int, NoError> {
        if let controller = self.controller {
            return controller.contactsNode.contactListNode.selectionStateSignal
            |> map { state in
                return state?.selectedPeerIndices.count ?? 0
            }
        } else {
            return .single(0)
        }
    }
        
    init(controller: ContactSelectionControllerImpl) {
        self.controller = controller
    }
    
    func setCaption(_ caption: NSAttributedString) {
        self.controller?.caption = caption
    }
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode, parameters: ChatSendMessageActionSheetController.SendParameters?) {
        self.controller?.contactsNode.requestMultipleAction?(mode == .silently, mode == .whenOnline ? scheduleWhenOnlineTimestamp : nil, parameters)
    }
    
    func schedule(parameters: ChatSendMessageActionSheetController.SendParameters?) {
        self.controller?.presentScheduleTimePicker ({ time in
            self.controller?.contactsNode.requestMultipleAction?(false, time, parameters)
        })
    }
    
    func mainButtonAction() {
    }
}

private final class ContactContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
