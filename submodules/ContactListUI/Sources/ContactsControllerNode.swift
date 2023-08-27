import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import SearchBarNode
import SearchUI
import AppBundle
import ContextUI
import ChatListHeaderComponent
import ChatListTitleView
import ComponentFlow

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

final class ContactsControllerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    let contactListNode: ContactListNode
    
    private let context: AccountContext
    private(set) var searchDisplayController: SearchDisplayController?
    private var isSearchDisplayControllerActive: Bool = false
    private var storiesUnlocked: Bool = false
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    let navigationBarView = ComponentView<Empty>()
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((ContactListPeer) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var openPeopleNearby: (() -> Void)?
    var openInvite: (() -> Void)?
    var openQrScan: (() -> Void)?
    var openStories: ((EnginePeer, ASDisplayNode) -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let stringsPromise = Promise<PresentationStrings>()
        
    weak var controller: ContactsController?
    
    private var initialScrollingOffset: CGFloat?
    private var isSettingUpContentOffset: Bool = false
    private var didSetupContentOffset: Bool = false
    private var contentOffset: ListViewVisibleContentOffset?
    private var ignoreStoryInsetAdjustment: Bool = false
    var didAppear: Bool = false
    
    private(set) var storySubscriptions: EngineStorySubscriptions?
    private var storySubscriptionsDisposable: Disposable?
    
    let storiesReady = Promise<Bool>()
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    init(context: AccountContext, sortOrder: Signal<ContactsSortOrder, NoError>, present: @escaping (ViewController, Any?) -> Void, controller: ContactsController) {
        self.context = context
        self.controller = controller
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.stringsPromise.set(.single(self.presentationData.strings))
        
        var addNearbyImpl: (() -> Void)?
        var inviteImpl: (() -> Void)?
        
        let presentation = combineLatest(sortOrder, self.stringsPromise.get())
        |> map { sortOrder, strings -> ContactListPresentation in
            let options = [ContactListAdditionalOption(title: strings.Contacts_AddPeopleNearby, icon: .generic(UIImage(bundleImageName: "Contact List/PeopleNearbyIcon")!), action: {
                addNearbyImpl?()
            }), ContactListAdditionalOption(title: strings.Contacts_InviteFriends, icon: .generic(UIImage(bundleImageName: "Contact List/AddMemberIcon")!), action: {
                inviteImpl?()
            })]
            
            switch sortOrder {
                case .presence:
                    return .orderedByPresence(options: options)
                case .natural:
                    return .natural(options: options, includeChatList: false)
            }
        }
        
        var contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?, Bool) -> Void)?
        
        self.contactListNode = ContactListNode(context: context, presentation: presentation, displaySortOptions: true, contextAction: { peer, node, gesture, location, isStories in
            contextAction?(peer, node, gesture, location, isStories)
        })
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contactListNode)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousStrings.baseLanguageCode != presentationData.strings.baseLanguageCode {
                    strongSelf.stringsPromise.set(.single(presentationData.strings))
                }
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        addNearbyImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.openPeopleNearby?()
            }
        }
        
        inviteImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.openInvite?()
            }
        }
        
        contextAction = { [weak self] peer, node, gesture, location, isStories in
            self?.contextAction(peer: peer, node: node, gesture: gesture, location: location, isStories: isStories)
        }
        
        self.contactListNode.contentOffsetChanged = { [weak self] offset in
            guard let self else {
                return
            }
            if self.isSettingUpContentOffset {
                return
            }
            
            if !self.didSetupContentOffset, let initialScrollingOffset = self.initialScrollingOffset {
                self.initialScrollingOffset = nil
                self.didSetupContentOffset = true
                self.isSettingUpContentOffset = true
                
                let _ = self.contactListNode.listNode.scrollToOffsetFromTop(initialScrollingOffset, animated: false)
                
                let offset = self.contactListNode.listNode.visibleContentOffset()
                self.contentOffset = offset
                self.contentOffsetChanged(offset: offset)
                
                self.isSettingUpContentOffset = false
                return
            }
            self.contentOffset = offset
            self.contentOffsetChanged(offset: offset)
            
            /*if self.contactListNode.listNode.isTracking {
                if case let .known(value) = offset {
                    if !self.storiesUnlocked {
                        if value < -40.0 {
                            self.storiesUnlocked = true
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }
                                
                                HapticFeedback().impact()
                                
                                self.contactListNode.ignoreStoryInsetAdjustment = true
                                self.contactListNode.listNode.allowInsetFixWhileTracking = true
                                self.onStoriesLockedUpdated(isLocked: true)
                                self.contactListNode.ignoreStoryInsetAdjustment = false
                                self.contactListNode.listNode.allowInsetFixWhileTracking = false
                            }
                        }
                    }
                }
            } else if self.storiesUnlocked {
                switch offset {
                case let .known(value):
                    if value >= ChatListNavigationBar.storiesScrollHeight {
                        self.storiesUnlocked = false
                        
                        DispatchQueue.main.async { [weak self] in
                            self?.onStoriesLockedUpdated(isLocked: false)
                        }
                    }
                default:
                    break
                }
            }*/
        }
        
        self.contactListNode.contentScrollingEnded = { [weak self] listView in
            guard let self else {
                return false
            }
            return self.contentScrollingEnded(listView: listView)
        }
        
        self.contactListNode.storySubscriptions.set(.single(nil))
        self.storiesReady.set(.single(true))
        
        /*self.storySubscriptionsDisposable = (self.context.engine.messages.storySubscriptions(isHidden: true)
        |> deliverOnMainQueue).start(next: { [weak self] storySubscriptions in
            guard let self else {
                return
            }
            
            self.storySubscriptions = storySubscriptions
            self.contactListNode.storySubscriptions.set(.single(storySubscriptions))
            
            self.storiesReady.set(.single(true))
        })*/

        self.contactListNode.openStories = { [weak self] peer, sourceNode in
            guard let self else {
                return
            }
            self.openStories?(peer, sourceNode)
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.storySubscriptionsDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(self.presentationData)
    }
    
    func scrollToTop() {
        if let contentNode = self.searchDisplayController?.contentNode as? ContactsSearchContainerNode {
            contentNode.scrollToTop()
        } else {
            self.contactListNode.scrollToTop()
        }
    }
    
    private func onStoriesLockedUpdated(isLocked: Bool) {
        self.controller?.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
    }
    
    private func contentOffsetChanged(offset: ListViewVisibleContentOffset) {
        self.updateNavigationScrolling(transition: .immediate)
    }
    
    private func contentScrollingEnded(listView: ListView) -> Bool {
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            if let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
                if clippedScrollOffset > 0.0 && clippedScrollOffset < ChatListNavigationBar.searchScrollHeight {
                    if clippedScrollOffset < ChatListNavigationBar.searchScrollHeight * 0.5 {
                        let _ = listView.scrollToOffsetFromTop(0.0, animated: true)
                    } else {
                        let _ = listView.scrollToOffsetFromTop(ChatListNavigationBar.searchScrollHeight, animated: true)
                    }
                    return true
                }
            }
        }
        
        return false
    }
    
    private func updateNavigationBar(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> (navigationHeight: CGFloat, storiesInset: CGFloat) {
        let tabsNode: ASDisplayNode? = nil
        let tabsNodeIsSearch = false
        
        let primaryContent = ChatListHeaderComponent.Content(
            title: self.presentationData.strings.Contacts_Title,
            navigationBackTitle: nil,
            titleComponent: nil,
            chatListTitle: NetworkStatusTitle(text: self.presentationData.strings.Contacts_Title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false, peerStatus: nil),
            leftButton: AnyComponentWithIdentity(id: "sort", component: AnyComponent(NavigationButtonComponent(
                content: .text(title: self.presentationData.strings.Contacts_Sort, isBold: false),
                pressed: { [weak self] sourceView in
                    guard let self else {
                        return
                    }
                    
                    self.controller?.presentSortMenu(sourceView: sourceView, gesture: nil)
                }
            ))),
            rightButtons: [AnyComponentWithIdentity(id: "add", component: AnyComponent(NavigationButtonComponent(
                content: .icon(imageName: "Chat List/AddIcon"),
                pressed: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.controller?.addPressed()
                }
            )))],
            backTitle: nil,
            backPressed: nil
        )
        
        let navigationBarSize = self.navigationBarView.update(
            transition: Transition(transition),
            component: AnyComponent(ChatListNavigationBar(
                context: self.context,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                sideInset: layout.safeInsets.left,
                isSearchActive: self.isSearchDisplayControllerActive,
                primaryContent: primaryContent,
                secondaryContent: nil,
                secondaryTransition: 0.0,
                storySubscriptions: nil,
                storiesIncludeHidden: true,
                uploadProgress: nil,
                tabsNode: tabsNode,
                tabsNodeIsSearch: tabsNodeIsSearch,
                accessoryPanelContainer: nil,
                accessoryPanelContainerHeight: 0.0,
                activateSearch: { [weak self] searchContentNode in
                    guard let self else {
                        return
                    }
                    
                    self.contactListNode.activateSearch?()
                },
                openStatusSetup: { _ in
                },
                allowAutomaticOrder: {
                }
            )),
            environment: {},
            containerSize: layout.size
        )
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = true
            
            if navigationBarComponentView.superview == nil {
                self.view.addSubview(navigationBarComponentView)
            }
            transition.updateFrame(view: navigationBarComponentView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
            
            return (navigationBarSize.height, 0.0)
        } else {
            return (0.0, 0.0)
        }
    }
    
    private func getEffectiveNavigationScrollingOffset() -> CGFloat {
        let mainOffset: CGFloat
        if let contentOffset = self.contentOffset, case let .known(value) = contentOffset {
            mainOffset = value
        } else {
            mainOffset = 1000.0
        }
        
        return mainOffset
    }
    
    private func updateNavigationScrolling(transition: ContainedViewLayoutTransition) {
        var offset = self.getEffectiveNavigationScrollingOffset()
        if self.isSearchDisplayControllerActive {
            offset = 0.0
        }
        
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, transition: Transition(transition))
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let navigationBarLayout = self.updateNavigationBar(layout: layout, transition: transition)
        self.initialScrollingOffset = 0.0//ChatListNavigationBar.searchScrollHeight + navigationBarLayout.storiesInset
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarLayout.navigationHeight
    
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top = navigationBarLayout.navigationHeight - navigationBarLayout.storiesInset - ChatListNavigationBar.searchScrollHeight
        
        let innerLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(innerLayout, navigationBarHeight: navigationBarLayout.navigationHeight, transition: transition)
        }
        
        self.contactListNode.containerLayoutUpdated(innerLayout, headerInsets: headerInsets, storiesInset: navigationBarLayout.storiesInset, transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        self.updateNavigationScrolling(transition: transition)
        
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = false
            navigationBarComponentView.applyCurrentScroll(transition: Transition(transition))
        }
    }
    
    private func contextAction(peer: EnginePeer, node: ASDisplayNode?, gesture: ContextGesture?, location: CGPoint?, isStories: Bool) {
        guard let contactsController = self.controller else {
            return
        }
        
        let items = contactContextMenuItems(context: self.context, peerId: peer.id, contactsController: contactsController, isStories: isStories) |> map { ContextController.Items(content: .list($0)) }
        
        if isStories, let node = node?.subnodes?.first(where: { $0 is ContextExtractedContentContainingNode }) as? ContextExtractedContentContainingNode {
            let controller = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(ContactContextExtractedContentSource(sourceNode: node, shouldBeDismissed: .single(false))), items: items, recognizer: nil, gesture: gesture)
            contactsController.presentInGlobalOverlay(controller)
        } else {
            let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
            chatController.canReadHistory.set(false)
            let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: items, gesture: gesture)
            contactsController.presentInGlobalOverlay(contextController)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.isSearchDisplayControllerActive = true
        self.storiesUnlocked = false
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, contentNode: ContactsSearchContainerNode(context: self.context, onlyWriteable: false, categories: [.cloudContacts, .global, .deviceContacts], addContact: { [weak self] phoneNumber in
            if let requestAddContact = self?.requestAddContact {
                requestAddContact(phoneNumber)
            }
        }, openPeer: { [weak self] peer in
            if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                requestOpenPeerFromSearch(peer)
            }
        }, contextAction: { [weak self] peer, node, gesture, location in
            self?.contextAction(peer: peer, node: node, gesture: gesture, location: location, isStories: false)
        }), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            if let strongSelf = self {
                if isSearchBar {
                    if let navigationBarComponentView = strongSelf.navigationBarView.view as? ChatListNavigationBar.View {
                        navigationBarComponentView.addSubnode(subnode)
                    }
                } else {
                    strongSelf.insertSubnode(subnode, aboveSubnode: strongSelf.contactListNode)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        self.isSearchDisplayControllerActive = false
        if let searchDisplayController = self.searchDisplayController {
            let previousFrame = placeholderNode.frame
            placeholderNode.frame = previousFrame.offsetBy(dx: 0.0, dy: 54.0)
            
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
            
            placeholderNode.frame = previousFrame
        }
    }
}

private final class ContactContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    let shouldBeDismissed: Signal<Bool, NoError>
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode, shouldBeDismissed: Signal<Bool, NoError>? = nil) {
        self.sourceNode = sourceNode
        self.shouldBeDismissed = shouldBeDismissed ?? .single(false)
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
