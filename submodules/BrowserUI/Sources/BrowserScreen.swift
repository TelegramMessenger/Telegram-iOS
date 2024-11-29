import Foundation
import UIKit
import SwiftSignalKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import AccountContext
import ContextUI
import ShareController
import UndoUI
import BundleIconComponent
import TelegramUIPreferences
import OpenInExternalAppUI
import MultilineTextComponent
import MinimizedContainer
import InstantPageUI
import NavigationStackComponent
import LottieComponent
import WebKit

private let settingsTag = GenericComponentViewTag()

private final class BrowserScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let contentState: BrowserContentState?
    let presentationState: BrowserPresentationState
    let canShare: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    let performHoldAction: (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    let panelCollapseFraction: CGFloat
    
    init(
        context: AccountContext,
        contentState: BrowserContentState?,
        presentationState: BrowserPresentationState,
        canShare: Bool,
        performAction: ActionSlot<BrowserScreen.Action>,
        performHoldAction: @escaping (UIView, ContextGesture?, BrowserScreen.Action) -> Void,
        panelCollapseFraction: CGFloat
    ) {
        self.context = context
        self.contentState = contentState
        self.presentationState = presentationState
        self.canShare = canShare
        self.performAction = performAction
        self.performHoldAction = performHoldAction
        self.panelCollapseFraction = panelCollapseFraction
    }
    
    static func ==(lhs: BrowserScreenComponent, rhs: BrowserScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.contentState != rhs.contentState {
            return false
        }
        if lhs.presentationState != rhs.presentationState {
            return false
        }
        if lhs.canShare != rhs.canShare {
            return false
        }
        if lhs.panelCollapseFraction != rhs.panelCollapseFraction {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let navigationBar = Child(BrowserNavigationBarComponent.self)
        let toolbar = Child(BrowserToolbarComponent.self)
        let addressList = Child(BrowserAddressListComponent.self)
        
        let navigationBarExternalState = BrowserNavigationBarComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let performAction = context.component.performAction
            let performHoldAction = context.component.performHoldAction
            
            let isTablet = environment.metrics.isTablet
            let canOpenIn = !(context.component.contentState?.url.hasPrefix("tonsite") ?? false)
            
            let navigationContent: AnyComponentWithIdentity<BrowserNavigationBarEnvironment>?
            var navigationLeftItems: [AnyComponentWithIdentity<Empty>]
            var navigationRightItems: [AnyComponentWithIdentity<Empty>]
            if context.component.presentationState.isSearching {
                navigationContent = AnyComponentWithIdentity(
                    id: "search",
                    component: AnyComponent(
                        SearchBarContentComponent(
                            theme: environment.theme,
                            strings: environment.strings,
                            performAction: performAction
                        )
                    )
                )
                navigationLeftItems = []
                navigationRightItems = []
            } else {
                let contentType = context.component.contentState?.contentType ?? .instantPage
                switch contentType {
                case .webPage:
                    navigationContent = AnyComponentWithIdentity(
                        id: "addressBar",
                        component: AnyComponent(
                            AddressBarContentComponent(
                                theme: environment.theme,
                                strings: environment.strings,
                                metrics: environment.metrics,
                                url: context.component.contentState?.url ?? "",
                                isSecure: context.component.contentState?.isSecure ?? false,
                                isExpanded: context.component.presentationState.addressFocused,
                                performAction: performAction
                            )
                        )
                    )
                case .instantPage, .document:
                    let title = context.component.contentState?.title ?? ""
                    navigationContent = AnyComponentWithIdentity(
                        id: "titleBar_\(title)",
                        component: AnyComponent(
                            TitleBarContentComponent(
                                theme: environment.theme,
                                title: title
                            )
                        )
                    )
                }
               
                if context.component.presentationState.addressFocused && !isTablet {
                    navigationLeftItems = []
                    navigationRightItems = []
                } else {
                    navigationLeftItems = [
                        AnyComponentWithIdentity(
                            id: "close",
                            component: AnyComponent(
                                Button(
                                    content: AnyComponent(
                                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.WebBrowser_Done, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.accentTextColor, paragraphAlignment: .center)), horizontalAlignment: .left, maximumNumberOfLines: 1)
                                    ),
                                    action: {
                                        performAction.invoke(.close)
                                    }
                                )
                            )
                        )
                    ]
                                        
                    if isTablet {
                        #if DEBUG
                        navigationLeftItems.append(
                            AnyComponentWithIdentity(
                                id: "minimize",
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            BundleIconComponent(
                                                name: "Media Gallery/PictureInPictureButton",
                                                tintColor: environment.theme.rootController.navigationBar.accentTextColor
                                            )
                                        ),
                                        action: {
                                            performAction.invoke(.close)
                                        }
                                    )
                                )
                            )
                        )
                        #endif
                        
                        let canGoBack = context.component.contentState?.canGoBack ?? false
                        let canGoForward = context.component.contentState?.canGoForward ?? false
                        
                        navigationLeftItems.append(
                            AnyComponentWithIdentity(
                                id: "back",
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            BundleIconComponent(
                                                name: "Instant View/Back",
                                                tintColor: environment.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(canGoBack ? 1.0 : 0.4)
                                            )
                                        ),
                                        action: {
                                            performAction.invoke(.navigateBack)
                                        }
                                    )
                                )
                            )
                        )
                        
                        navigationLeftItems.append(
                            AnyComponentWithIdentity(
                                id: "forward",
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            BundleIconComponent(
                                                name: "Instant View/Forward",
                                                tintColor: environment.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(canGoForward ? 1.0 : 0.4)
                                            )
                                        ),
                                        action: {
                                            performAction.invoke(.navigateForward)
                                        }
                                    )
                                )
                            )
                        )
                    }
                    
                    navigationRightItems = [
                        AnyComponentWithIdentity(
                            id: "settings",
                            component: AnyComponent(
                                ReferenceButtonComponent(
                                    content: AnyComponent(
                                        LottieComponent(
                                            content: LottieComponent.AppBundleContent(
                                                name: "anim_moredots"
                                            ),
                                            color: environment.theme.rootController.navigationBar.accentTextColor,
                                            size: CGSize(width: 30.0, height: 30.0)
                                        )
                                    ),
                                    tag: settingsTag,
                                    action: {
                                        performAction.invoke(.openSettings)
                                    }
                                )
                            )
                        )
                    ]
                    
                    if isTablet {
                        navigationRightItems.insert(
                            AnyComponentWithIdentity(
                                id: "bookmarks",
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            BundleIconComponent(
                                                name: "Instant View/Bookmark",
                                                tintColor: environment.theme.rootController.navigationBar.accentTextColor
                                            )
                                        ),
                                        action: {
                                            performAction.invoke(.openBookmarks)
                                        }
                                    )
                                )
                            ),
                            at: 0
                        )
                        if context.component.canShare {
                            navigationRightItems.insert(
                                AnyComponentWithIdentity(
                                    id: "share",
                                    component: AnyComponent(
                                        Button(
                                            content: AnyComponent(
                                                BundleIconComponent(
                                                    name: "Chat List/NavigationShare",
                                                    tintColor: environment.theme.rootController.navigationBar.accentTextColor
                                                )
                                            ),
                                            action: {
                                                performAction.invoke(.share)
                                            }
                                        )
                                    )
                                ),
                                at: 0
                            )
                        }
                        if canOpenIn {
                            navigationRightItems.append(
                                AnyComponentWithIdentity(
                                    id: "openIn",
                                    component: AnyComponent(
                                        Button(
                                            content: AnyComponent(
                                                BundleIconComponent(
                                                    name: "Instant View/Browser",
                                                    tintColor: environment.theme.rootController.navigationBar.accentTextColor
                                                )
                                            ),
                                            action: {
                                                performAction.invoke(.openIn)
                                            }
                                        )
                                    )
                                )
                            )
                        }
                    }
                }
            }
            
            let collapseFraction = context.component.presentationState.isSearching ? 0.0 : context.component.panelCollapseFraction
            
            let navigationBar = navigationBar.update(
                component: BrowserNavigationBarComponent(
                    backgroundColor: environment.theme.rootController.navigationBar.blurredBackgroundColor,
                    separatorColor: environment.theme.rootController.navigationBar.separatorColor,
                    textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                    progressColor: environment.theme.rootController.navigationBar.segmentedBackgroundColor,
                    accentColor: environment.theme.rootController.navigationBar.accentTextColor,
                    topInset: environment.statusBarHeight,
                    height: environment.navigationHeight - environment.statusBarHeight,
                    sideInset: environment.safeInsets.left,
                    metrics: environment.metrics,
                    externalState: navigationBarExternalState,
                    leftItems: navigationLeftItems,
                    rightItems: navigationRightItems,
                    centerItem: navigationContent,
                    readingProgress: context.component.contentState?.readingProgress ?? 0.0,
                    loadingProgress: context.component.contentState?.estimatedProgress,
                    collapseFraction: collapseFraction,
                    activate: {
                        performAction.invoke(.expand)
                    }
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(navigationBar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigationBar.size.height / 2.0))
            )
            
            let toolbarContent: AnyComponentWithIdentity<Empty>?
            if context.component.presentationState.isSearching {
                toolbarContent = AnyComponentWithIdentity(
                    id: "search",
                    component: AnyComponent(
                        SearchToolbarContentComponent(
                            strings: environment.strings,
                            textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                            index: context.component.presentationState.searchResultIndex,
                            count: context.component.presentationState.searchResultCount,
                            isEmpty: context.component.presentationState.searchQueryIsEmpty,
                            performAction: performAction
                        )
                    )
                )
            } else {
                toolbarContent = AnyComponentWithIdentity(
                    id: "navigation",
                    component: AnyComponent(
                        NavigationToolbarContentComponent(
                            accentColor: environment.theme.rootController.navigationBar.accentTextColor,
                            textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                            canGoBack: context.component.contentState?.canGoBack ?? false,
                            canGoForward: context.component.contentState?.canGoForward ?? false,
                            canOpenIn: canOpenIn,
                            canShare: context.component.canShare,
                            isDocument: context.component.contentState?.contentType == .document,
                            performAction: performAction,
                            performHoldAction: performHoldAction
                        )
                    )
                )
            }
            
            let toolbarBottomInset: CGFloat
            if context.component.presentationState.isSearching && environment.inputHeight > 0.0 {
                toolbarBottomInset = environment.inputHeight
            } else {
                toolbarBottomInset = environment.safeInsets.bottom
            }
            
            var toolbarSize: CGFloat = 0.0
            if isTablet && !context.component.presentationState.isSearching {
                
            } else {
                let toolbar = toolbar.update(
                    component: BrowserToolbarComponent(
                        backgroundColor: environment.theme.rootController.navigationBar.blurredBackgroundColor,
                        separatorColor: environment.theme.rootController.navigationBar.separatorColor,
                        textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                        bottomInset: toolbarBottomInset,
                        sideInset: environment.safeInsets.left,
                        item: toolbarContent,
                        collapseFraction: 0.0
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(toolbar
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - toolbar.size.height / 2.0 + toolbar.size.height * collapseFraction))
                    .appear(ComponentTransition.Appear { _, view, transition in
                        transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: view.frame.height), to: CGPoint(), additive: true)
                    })
                    .disappear(ComponentTransition.Disappear { view, transition, completion in
                        transition.animatePosition(view: view, from: CGPoint(), to: CGPoint(x: 0.0, y: view.frame.height), additive: true, completion: { _ in
                            completion()
                        })
                    })
                )
                toolbarSize = toolbar.size.height
            }
            
            if context.component.presentationState.addressFocused {
                let addressListSize: CGSize
                if isTablet {
                    addressListSize = context.availableSize
                } else {
                    addressListSize = CGSize(width: context.availableSize.width, height: context.availableSize.height - navigationBar.size.height - toolbarSize)
                }
                let controller = environment.controller
                let addressList = addressList.update(
                    component: BrowserAddressListComponent(
                        context: context.component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                        metrics: environment.metrics,
                        addressBarFrame: navigationBarExternalState.centerItemFrame,
                        performAction: performAction,
                        presentInGlobalOverlay: { c in
                            controller()?.presentInGlobalOverlay(c)
                        }
                    ),
                    availableSize: addressListSize,
                    transition: context.transition
                )
                
                if isTablet {
                    context.add(addressList
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                } else {
                    context.add(addressList
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: navigationBar.size.height + addressList.size.height / 2.0))
                        .clipsToBounds(true)
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                }
            }
            
            return context.availableSize
        }
    }
}

struct BrowserPresentationState: Equatable {
    struct FontState: Equatable {
        var size: Int32
        var isSerif: Bool
    }
    var fontState: FontState
    var isSearching: Bool
    var searchResultIndex: Int
    var searchResultCount: Int
    var searchQueryIsEmpty: Bool
    var addressFocused: Bool
}

public class BrowserScreen: ViewController, MinimizableController {
    enum Action {
        case close
        case reload
        case stop
        case navigateBack
        case navigateForward
        case share
        case minimize
        case openIn
        case openSettings
        case updateSearchActive(Bool)
        case updateSearchQuery(String)
        case scrollToPreviousSearchResult
        case scrollToNextSearchResult
        case decreaseFontSize
        case increaseFontSize
        case resetFontSize
        case updateFontIsSerif(Bool)
        case toggleInstantView(Bool)
        case addBookmark
        case openBookmarks
        case openAddressBar
        case closeAddressBar
        case navigateTo(String, Bool)
        case expand
        case saveToFiles
    }

    final class Node: ViewControllerTracingNode {
        private weak var controller: BrowserScreen?
        private let context: AccountContext
        
        private let contentContainerView = UIView()
        fileprivate let contentNavigationContainer = ComponentView<Empty>()
        private(set) var content: [BrowserContent] = []
        fileprivate var contentState: BrowserContentState?
        private var contentStateDisposable = MetaDisposable()
        
        private var presentationState: BrowserPresentationState
        
        private let performAction = ActionSlot<BrowserScreen.Action>()
        
        fileprivate let componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
        
        private var presentationData: PresentationData
        private var presentationDataDisposable: Disposable?
        private var validLayout: (ContainerViewLayout, CGFloat)?
                
        init(controller: BrowserScreen) {
            self.context = controller.context
            self.controller = controller
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.presentationState = BrowserPresentationState(
                fontState: BrowserPresentationState.FontState(size: 100, isSerif: false),
                isSearching: false, 
                searchResultIndex: 0,
                searchResultCount: 0,
                searchQueryIsEmpty: true,
                addressFocused: false
            )
                                                
            super.init()
            
            self.pushContent(controller.subject, transition: .immediate)
            if let content = self.content.last {
                content.addToRecentlyVisited()
            }
            
            self.performAction.connect { [weak self] action in
                guard let self, let content = self.content.last, let url = self.contentState?.url else {
                    return
                }
                switch action {
                case .close:
                    self.controller?.dismiss()
                case .reload:
                    content.reload()
                case .stop:
                    content.stop()
                case .navigateBack:
                    if content.currentState.canGoBack {
                        content.navigateBack()
                    } else {
                        self.popContent(transition: .spring(duration: 0.4))
                    }
                case .navigateForward:
                    content.navigateForward()
                case .share:
                    let presentationData = self.presentationData
                    let subject: ShareControllerSubject
                    var isDocument = false
                    if let content = self.content.last {
                        if let documentContent = content as? BrowserDocumentContent {
                            subject = .media(documentContent.file.abstract)
                            isDocument = true
                        } else if let documentContent = content as? BrowserPdfContent {
                            subject = .media(documentContent.file.abstract)
                            isDocument = true
                        } else {
                            subject = .url(url)
                        }
                    } else {
                        subject = .url(url)
                    }
                    let shareController = ShareController(context: self.context, subject: subject)
                    shareController.completed = { [weak self] peerIds in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = (strongSelf.context.engine.data.get(
                            EngineDataList(
                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                            )
                        )
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let peers = peerList.compactMap { $0 }
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            
                            let text: String
                            var savedMessages = false
                            if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId && !isDocument {
                                text = presentationData.strings.WebBrowser_LinkAddedToBookmarks
                                savedMessages = true
                            } else {
                                if peers.count == 1, let peer = peers.first {
                                    let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = isDocument ? presentationData.strings.WebBrowser_FileForwardTooltip_Chat_One(peerName).string : presentationData.strings.WebBrowser_LinkForwardTooltip_Chat_One(peerName).string
                                    savedMessages = peer.id == strongSelf.context.account.peerId
                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                    let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = isDocument ? presentationData.strings.WebBrowser_FileForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.WebBrowser_LinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                } else if let peer = peers.first {
                                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = isDocument ? presentationData.strings.WebBrowser_FileForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string : presentationData.strings.WebBrowser_LinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                } else {
                                    text = ""
                                }
                            }
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
                                if savedMessages, let self, action == .info {
                                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                             |> deliverOnMainQueue).start(next: { [weak self] peer in
                                        guard let self, let peer else {
                                            return
                                        }
                                        guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                            return
                                        }
                                        self.minimize()
                                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                    })
                                }
                                return false
                            }), in: .current)
                        })
                    }
                    shareController.actionCompleted = { [weak self] in
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                    self.controller?.present(shareController, in: .window(.root))
                case .minimize:
                    self.minimize()
                case .openIn:
                    var processed = false
                    if let controller = self.controller {
                        switch controller.subject {
                        case let .document(file, canShare), let .pdfDocument(file, canShare):
                            processed = true
                            controller.openDocument(file.media, canShare)
                        default:
                            break
                        }
                    }
                    if !processed {
                        self.context.sharedContext.applicationBindings.openUrl(url)
                    }
                case .openSettings:
                    self.openSettings()
                case let .updateSearchActive(active):
                    self.updatePresentationState(transition: .easeInOut(duration: 0.2), { state in
                        var updatedState = state
                        updatedState.isSearching = active
                        updatedState.searchQueryIsEmpty = true
                        return updatedState
                    })
                    if !active {
                        content.setSearch(nil, completion: nil)
                    }
                case let .updateSearchQuery(query):
                    content.setSearch(query, completion: { [weak self] count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = 0
                            updatedState.searchResultCount = count
                            updatedState.searchQueryIsEmpty = query.isEmpty
                            return updatedState
                        })
                    })
                case .scrollToPreviousSearchResult:
                    self.view.window?.endEditing(true)
                    content.scrollToPreviousSearchResult(completion: { [weak self] index, count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = index
                            updatedState.searchResultCount = count
                            return updatedState
                        })
                    })
                case .scrollToNextSearchResult:
                    self.view.window?.endEditing(true)
                    content.scrollToNextSearchResult(completion: { [weak self] index, count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = index
                            updatedState.searchResultCount = count
                            return updatedState
                        })
                    })
                case .decreaseFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        switch state.fontState.size {
                        case 150:
                            updatedState.fontState.size = 125
                        case 125:
                            updatedState.fontState.size = 115
                        case 115:
                            updatedState.fontState.size = 100
                        case 100:
                            updatedState.fontState.size = 85
                        case 85:
                            updatedState.fontState.size = 75
                        case 75:
                            updatedState.fontState.size = 50
                        default:
                            updatedState.fontState.size = 50
                        }
                        return updatedState
                    })
                    content.updateFontState(self.presentationState.fontState)
                case .increaseFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        switch state.fontState.size {
                        case 125:
                            updatedState.fontState.size = 150
                        case 115:
                            updatedState.fontState.size = 125
                        case 100:
                            updatedState.fontState.size = 115
                        case 85:
                            updatedState.fontState.size = 100
                        case 75:
                            updatedState.fontState.size = 85
                        case 50:
                            updatedState.fontState.size = 75
                        default:
                            updatedState.fontState.size = 150
                        }
                        return updatedState
                    })
                    content.updateFontState(self.presentationState.fontState)
                case .resetFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontState.size = 100
                        return updatedState
                    })
                    content.updateFontState(self.presentationState.fontState)
                case let .updateFontIsSerif(value):
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontState.isSerif = value
                        return updatedState
                    })
                    content.updateFontState(self.presentationState.fontState)
                case let .toggleInstantView(enabled):
                    content.toggleInstantView(enabled)
                case .addBookmark:
                    if let content = self.content.last {
                        self.addBookmark(content.currentState.url, showArrow: true)
                    }
                case .openBookmarks:
                    self.openBookmarks()
                case .openAddressBar:
                    self.updatePresentationState(transition: .spring(duration: 0.4), { state in
                        var updatedState = state
                        updatedState.addressFocused = true
                        return updatedState
                    })
                case .closeAddressBar:
                    self.updatePresentationState(transition: .spring(duration: 0.4), { state in
                        var updatedState = state
                        updatedState.addressFocused = false
                        return updatedState
                    })
                case let .navigateTo(address, addToRecent):
                    if let content = self.content.last as? BrowserWebContent {
                        content.navigateTo(address: address)
                        if addToRecent {
                            content.addToRecentlyVisited()
                        }
                    }
                    self.updatePresentationState(transition: .spring(duration: 0.4), { state in
                        var updatedState = state
                        updatedState.addressFocused = false
                        return updatedState
                    })
                case .expand:
                    if let content = self.content.last {
                        content.resetScrolling()
                    }
                case .saveToFiles:
                    if let content = self.content.last as? BrowserWebContent {
                        content.requestSaveToFiles()
                    }
                }
            }
            
            self.presentationDataDisposable = (controller.context.sharedContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                guard let self else {
                    return
                }
                self.presentationData = presentationData
                for content in self.content {
                    content.updatePresentationData(presentationData)
                }
                self.requestLayout(transition: .immediate)
            })
        }
        
        deinit {
            self.presentationDataDisposable?.dispose()
            self.contentStateDisposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.contentContainerView.clipsToBounds = true
            self.view.addSubview(self.contentContainerView)
        }
        
        func updatePresentationState(transition: ComponentTransition = .immediate, _ f: (BrowserPresentationState) -> BrowserPresentationState) {
            self.presentationState = f(self.presentationState)
            self.requestLayout(transition: transition)
        }
        
        func pushContent(_ content: BrowserScreen.Subject, additionalContent: BrowserContent? = nil, transition: ComponentTransition) {
            let browserContent: BrowserContent
            switch content {
            case let .webPage(url):
                let webContent = BrowserWebContent(context: self.context, presentationData: self.presentationData, url: url, preferredConfiguration: self.controller?.preferredConfiguration)
                webContent.cancelInteractiveTransitionGestures = { [weak self] in
                    if let self, let view = self.controller?.view {
                        cancelInteractiveTransitionGestures(view: view)
                    }
                }
                browserContent = webContent
                self.controller?.preferredConfiguration = nil
            case let .instantPage(webPage, anchor, sourceLocation, preloadedResouces):
                let instantPageContent = BrowserInstantPageContent(context: self.context, presentationData: self.presentationData, webPage: webPage, anchor: anchor, url: webPage.content.url ?? "", sourceLocation: sourceLocation, preloadedResouces: preloadedResouces, originalContent: additionalContent)
                instantPageContent.openPeer = { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.openPeer(peer)
                }
                instantPageContent.restoreContent = { [weak self, weak instantPageContent] content in
                    guard let self, let instantPageContent else {
                        return
                    }
                    self.pushBrowserContent(content, additionalContent: instantPageContent, transition: .easeInOut(duration: 0.3).withUserData(NavigationStackComponent<Empty>.CurlTransition.hide))
                }
                browserContent = instantPageContent
            case let .document(file, _):
                browserContent = BrowserDocumentContent(context: self.context, presentationData: self.presentationData, file: file)
            case let .pdfDocument(file, _):
                browserContent = BrowserPdfContent(context: self.context, presentationData: self.presentationData, file: file)
            }
            browserContent.pushContent = { [weak self] content, additionalContent in
                guard let self else {
                    return
                }
                var transition: ComponentTransition
                if let _ = additionalContent {
                    transition = .easeInOut(duration: 0.3).withUserData(NavigationStackComponent<Empty>.CurlTransition.show)
                } else {
                    transition = .spring(duration: 0.4)
                }
                self.pushContent(content, additionalContent: additionalContent, transition: transition)
            }
            browserContent.openAppUrl = { [weak self] url in
                guard let self else {
                    return
                }
                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: false, presentationData: self.presentationData, navigationController: self.controller?.navigationController as? NavigationController, dismissInput: { [weak self] in
                    self?.view.window?.endEditing(true)
                })
            }
            browserContent.present = { [weak self] c, a in
                guard let self, let controller = self.controller else {
                    return
                }
                controller.present(c, in: .window(.root), with: a)
            }
            browserContent.presentInGlobalOverlay = { [weak self] c in
                guard let self, let controller = self.controller else {
                    return
                }
                controller.presentInGlobalOverlay(c)
            }
            browserContent.getNavigationController = { [weak self] in
                return self?.controller?.navigationController as? NavigationController
            }
            browserContent.minimize = { [weak self] in
                guard let self else {
                    return
                }
                self.minimize()
            }
            browserContent.close = { [weak self] in
                guard let self, let controller = self.controller else {
                    return
                }
                if controller.isMinimized {
                    if let navigationController = controller.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                        minimizedContainer.removeController(controller)
                    }
                } else {
                    controller.dismiss()
                }
            }
            
            self.pushBrowserContent(browserContent, additionalContent: additionalContent, transition: transition)
        }
        
        func pushBrowserContent(_ browserContent: BrowserContent, additionalContent: BrowserContent? = nil, transition: ComponentTransition) {
            if let additionalContent, let index = self.content.firstIndex(where: { $0 === additionalContent }) {
                self.content[index] = browserContent
            } else {
                self.content.append(browserContent)
            }
            self.requestLayout(transition: transition)
            
            self.setupContentStateUpdates()
        }
        
        func popContent(transition: ComponentTransition) {
            self.content.removeLast()
            self.requestLayout(transition: transition)
            
            self.setupContentStateUpdates()
        }
        
        func openPeer(_ peer: EnginePeer) {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            self.minimize()
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), animated: true))
        }
        
        func addBookmark(_ url: String, showArrow: Bool) {
            let _ = enqueueMessages(
                account: self.context.account,
                peerId: self.context.account.peerId,
                messages: [.message(
                    text: url,
                    attributes: [],
                    inlineStickers: [:],
                    mediaReference: nil,
                    threadId: nil,
                    replyToMessageId: nil,
                    replyToStoryId: nil,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )]
            ).start()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let lastController = self.controller?.navigationController?.viewControllers.last as? ViewController
            lastController?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: presentationData.strings.WebBrowser_LinkAddedToBookmarks), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
                if let self, action == .info {
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let self, let peer else {
                            return
                        }
                        guard let navigationController = self.controller?.navigationController as? NavigationController else {
                            return
                        }
                        self.minimize()
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                    })
                }
                return false
            }), in: .current)
        }
        
        private func setupContentStateUpdates() {
            for content in self.content {
                content.onScrollingUpdate = { _ in }
            }
            
            guard let content = self.content.last else {
                self.controller?.title = ""
                self.contentState = nil
                self.contentStateDisposable.set(nil)
                self.requestLayout(transition: .easeInOut(duration: 0.25))
                return
            }
            
            var previousState = BrowserContentState(title: "", url: "", estimatedProgress: 1.0, readingProgress: 0.0, contentType: .webPage, canGoBack: false, canGoForward: false, backList: [], forwardList: [])
            if self.content.count > 1 {
                for content in self.content.prefix(upTo: self.content.count - 1) {
                    var backList = previousState.backList
                    backList.append(BrowserContentState.HistoryItem(url: content.currentState.url, title: content.currentState.title, uuid: content.uuid))
                    previousState = previousState.withUpdatedBackList(backList)
                }
            }
            
            self.contentStateDisposable.set((content.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                var backList = state.backList
                backList.insert(contentsOf: previousState.backList, at: 0)
                
                var canGoBack = state.canGoBack
                if !backList.isEmpty {
                    canGoBack = true
                }
                
                let previousState = self.contentState
                let state = state.withUpdatedCanGoBack(canGoBack).withUpdatedBackList(backList)
                self.controller?.title = state.title
                self.contentState = state
                
                if !self.isUpdating {
                    let transition: ComponentTransition
                    if let previousState, previousState.withUpdatedReadingProgress(state.readingProgress) == state {
                        transition = .immediate
                    } else {
                        transition = .easeInOut(duration: 0.25)
                    }
                    self.requestLayout(transition: transition)
                }
            }))
                        
            content.onScrollingUpdate = { [weak self] update in
                self?.onContentScrollingUpdate(update)
            }
        }
        
        func minimize(topEdgeOffset: CGFloat? = nil, damping: CGFloat? = nil, initialVelocity: CGFloat? = nil) {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            navigationController.minimizeViewController(controller, topEdgeOffset: topEdgeOffset, damping: damping, velocity: initialVelocity, beforeMaximize: { _, completion in
                completion()
            }, setupContainer: { [weak self] current in
                let minimizedContainer: MinimizedContainerImpl?
                if let current = current as? MinimizedContainerImpl {
                    minimizedContainer = current
                } else if let context = self?.controller?.context {
                    minimizedContainer = MinimizedContainerImpl(sharedContext: context.sharedContext)
                } else {
                    minimizedContainer = nil
                }
                return minimizedContainer
            }, animated: true)
        }
        
        func openBookmarks() {
            guard let url = self.contentState?.url else {
                return
            }
            let controller = BrowserBookmarksScreen(context: self.context, url: url, openUrl: { [weak self] url in
                if let self {
                    self.performAction.invoke(.navigateTo(url, true))
                }
            }, addBookmark: { [weak self] in
                self?.addBookmark(url, showArrow: false)
            })
            self.controller?.push(controller)
        }
        
        func openSettings() {
            guard let referenceView = self.componentHost.findTaggedView(tag: settingsTag) as? ReferenceButtonComponent.View else {
                return
            }
            
            guard let controller = self.controller, let content = self.content.last else {
                return
            }
            
            if let animationComponentView = referenceView.componentView.view as? LottieComponent.View {
                animationComponentView.playOnce()
            }
            
            if let webContent = content as? BrowserWebContent {
                webContent.requestInstantView()
            }

            self.view.endEditing(true)
            
            let settings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings])
            |> take(1)
            |> map { sharedData -> WebBrowserSettings in
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) {
                    return current
                } else {
                    return WebBrowserSettings.defaultSettings
                }
            }
            
            let source: ContextContentSource = .reference(BrowserReferenceContentSource(controller: controller, sourceView: referenceView.referenceNode.view))
            
            let items: Signal<ContextController.Items, NoError> = combineLatest(
                queue: Queue.mainQueue(),
                settings,
                content.state
            )
            |> map { [weak self] settings, contentState -> ContextController.Items in
                guard let self, let layout = self.validLayout?.0 else {
                    return ContextController.Items(content: .list([]))
                }
                
                let performAction = self.performAction
                let fontItem = BrowserFontSizeContextMenuItem(
                    value: self.presentationState.fontState.size,
                    decrease: { [weak self] in
                        performAction.invoke(.decreaseFontSize)
                        if let self {
                            return self.presentationState.fontState.size
                        } else {
                            return 100
                        }
                    }, increase: { [weak self] in
                        performAction.invoke(.increaseFontSize)
                        if let self {
                            return self.presentationState.fontState.size
                        } else {
                            return 100
                        }
                    }, reset: {
                        performAction.invoke(.resetFontSize)
                    }
                )
                
                var defaultWebBrowser: String? = settings.defaultWebBrowser
                if defaultWebBrowser == nil || defaultWebBrowser == "inAppSafari" {
                    defaultWebBrowser = "safari"
                }
                
                let url = contentState.url
                let openInOptions = availableOpenInOptions(context: self.context, item: .url(url: url))
                let openInTitle: String
                let openInUrl: String
                if let option = openInOptions.first(where: { $0.identifier == defaultWebBrowser }) {
                    openInTitle = option.title
                    if case let .openUrl(url) = option.action() {
                        openInUrl = url
                    } else {
                        openInUrl = url
                    }
                } else {
                    openInTitle = "Safari"
                    openInUrl = url
                }
                
                let canOpenIn = !(self.contentState?.url.hasPrefix("tonsite") ?? false)
                var canShare = true
                if let controller = self.controller {
                    switch controller.subject {
                    case let .document(_, canShareValue), let .pdfDocument(_, canShareValue):
                        canShare = canShareValue
                    default:
                        break
                    }
                }
                
                var items: [ContextMenuItem] = []
                if contentState.contentType == .document, contentState.title.lowercased().hasSuffix(".pdf") {
                    
                } else {
                    items.append(.custom(fontItem, false))

                    if case .webPage = contentState.contentType {
                        let isAvailable = contentState.hasInstantView
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebBrowser_ShowInstantView, textColor: isAvailable ? .primary : .disabled, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Boost"), color: isAvailable ? theme.contextMenu.primaryColor : theme.contextMenu.primaryColor.withAlphaComponent(0.3)) }, action: isAvailable ? { (controller, action) in
                            performAction.invoke(.toggleInstantView(true))
                            action(.default)
                        } : nil)))
                    } else if case .instantPage = contentState.contentType, contentState.isInnerInstantViewEnabled {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebBrowser_HideInstantView, textColor: .primary, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/InstantViewOff"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                            performAction.invoke(.toggleInstantView(false))
                            action(.default)
                        })))
                    }
                }
                
                if !items.isEmpty {
                    items.append(.separator)
                }
                
                if case .webPage = contentState.contentType {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebBrowser_Reload, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Reload"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.reload)
                        action(.default)
                    })))
                }
                if [.webPage, .document].contains(contentState.contentType) {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_Search, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Search"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.updateSearchActive(true))
                        action(.default)
                    })))
                }
                
                if canShare && !layout.metrics.isTablet {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebBrowser_Share, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.share)
                        action(.default)
                    })))
                }
                
                if [.webPage, .instantPage].contains(contentState.contentType) {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebBrowser_AddBookmark, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.addBookmark)
                        action(.default)
                    })))
                    
                    if contentState.contentType == .webPage {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_SaveToFiles, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                            performAction.invoke(.saveToFiles)
                            action(.default)
                        })))
                    }
                    
                    if !layout.metrics.isTablet && canOpenIn {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_OpenInBrowser(openInTitle).string, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] (controller, action) in
                            if let self {
                                self.context.sharedContext.applicationBindings.openUrl(openInUrl)
                            }
                            action(.default)
                        })))
                    }
                }
                return ContextController.Items(content: .list(items))
            }
            
            let contextController = ContextController(presentationData: self.presentationData, source: source, items: items)
            contextController.dismissed = { [weak content] in
                if let webContent = content as? BrowserWebContent {
                    webContent.releaseInstantView()
                }
            }
            self.controller?.present(contextController, in: .window(.root))
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view, let content = self.content.last {
                return content.hitTest(self.view.convert(point, to: content), with: event)
            }
            return result
        }
        
        private var scrollingPanelOffsetFraction: CGFloat = 0.0
        private var scrollingPanelOffsetToTopEdge: CGFloat = 0.0
        private var scrollingPanelOffsetToBottomEdge: CGFloat = .greatestFiniteMagnitude

        private var navigationBarHeight: CGFloat?
        private var toolbarHeight: CGFloat?
        func onContentScrollingUpdate(_ update: ContentScrollingUpdate) {
            var offsetDelta: CGFloat?
            offsetDelta = (update.absoluteOffsetToTopEdge ?? 0.0) - self.scrollingPanelOffsetToTopEdge
            if update.isReset {
                offsetDelta = 0.0
            }
            
            self.scrollingPanelOffsetToTopEdge = update.absoluteOffsetToTopEdge ?? 0.0
            self.scrollingPanelOffsetToBottomEdge = update.absoluteOffsetToBottomEdge ?? .greatestFiniteMagnitude
            
            if let topPanelHeight = self.navigationBarHeight, let bottomPanelHeight = self.toolbarHeight {
                var scrollingPanelOffsetFraction = self.scrollingPanelOffsetFraction
                
                if topPanelHeight > 0.0, let offsetDelta = offsetDelta {
                    let fractionDelta = -offsetDelta / topPanelHeight
                    scrollingPanelOffsetFraction = max(0.0, min(1.0, self.scrollingPanelOffsetFraction - fractionDelta))
                }
                
                if bottomPanelHeight > 0.0 && self.scrollingPanelOffsetToBottomEdge < bottomPanelHeight {
                    scrollingPanelOffsetFraction = min(scrollingPanelOffsetFraction, self.scrollingPanelOffsetToBottomEdge / bottomPanelHeight)
                } else if topPanelHeight > 0.0 && self.scrollingPanelOffsetToTopEdge < topPanelHeight {
                    scrollingPanelOffsetFraction = min(scrollingPanelOffsetFraction, self.scrollingPanelOffsetToTopEdge / topPanelHeight)
                }
                
                var transition = update.transition
                if !update.isInteracting {
                    if scrollingPanelOffsetFraction < 0.5 {
                        scrollingPanelOffsetFraction = 0.0
                    } else {
                        scrollingPanelOffsetFraction = 1.0
                    }
                    if case .none = transition.animation {
                    } else {
                        transition = transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
                    }
                }
                
                if update.isReset {
                    scrollingPanelOffsetFraction = 0.0
                }
                
                if scrollingPanelOffsetFraction != self.scrollingPanelOffsetFraction {
                    self.scrollingPanelOffsetFraction = scrollingPanelOffsetFraction
                    self.requestLayout(transition: transition)
                }
            }
        }
        
        func navigateTo(_ item: BrowserContentState.HistoryItem) {
            if let _ = item.webItem {
                if let last = self.content.last {
                    last.navigateTo(historyItem: item)
                }
            } else if let uuid = item.uuid {
                var newContent = self.content
                while newContent.last?.uuid != uuid {
                    newContent.removeLast()
                }
                self.content = newContent
                self.requestLayout(transition: .spring(duration: 0.4))
            }
        }
        
        func performHoldAction(view: UIView, gesture: ContextGesture?, action: BrowserScreen.Action) {
            guard let controller = self.controller, let contentState = self.contentState else {
                return
            }
            
            let source: ContextContentSource = .reference(BrowserReferenceContentSource(controller: controller, sourceView: view))
            var items: [ContextMenuItem] = []
            switch action {
            case .navigateBack:
                for item in contentState.backList {
                    items.append(.action(ContextMenuActionItem(text: item.title, textLayout: .secondLineWithValue(item.url), icon: { _ in return nil }, action: { [weak self] (_, action) in
                        self?.navigateTo(item)
                        action(.default)
                    })))
                }
            case .navigateForward:
                for item in contentState.forwardList {
                    items.append(.action(ContextMenuActionItem(text: item.title, textLayout: .secondLineWithValue(item.url), icon: { _ in return nil }, action: { [weak self] (_, action) in
                        self?.navigateTo(item)
                        action(.default)
                    })))
                }
            default:
                return
            }
            
            let contextController = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))))
            self.controller?.present(contextController, in: .window(.root))
        }
        
        private var isUpdating = false
        func requestLayout(transition: ComponentTransition) {
            if !self.isUpdating, let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ComponentTransition) {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.validLayout = (layout, navigationBarHeight)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: navigationBarHeight,
                safeInsets: UIEdgeInsets(
                    top: layout.intrinsicInsets.top + layout.safeInsets.top,
                    left: layout.safeInsets.left,
                    bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom,
                    right: layout.safeInsets.right
                ),
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: layout.metrics.orientation,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            
            var canShare = true
            if let controller = self.controller {
                switch controller.subject {
                case let .document(_, canShareValue), let .pdfDocument(_, canShareValue):
                    canShare = canShareValue
                default:
                    break
                }
            }

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    BrowserScreenComponent(
                        context: self.context,
                        contentState: self.contentState,
                        presentationState: self.presentationState,
                        canShare: canShare,
                        performAction: self.performAction,
                        performHoldAction: { [weak self] view, gesture, action in
                            if let self {
                                self.performHoldAction(view: view, gesture: gesture, action: action)
                            }
                        },
                        panelCollapseFraction: self.scrollingPanelOffsetFraction
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: false,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.addSubview(componentView)
                    componentView.clipsToBounds = true
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: .zero, size: componentSize))
            }
            transition.setFrame(view: self.contentContainerView, frame: CGRect(origin: .zero, size: layout.size))
                
            var items: [AnyComponentWithIdentity<Empty>] = []
            for content in self.content {
                items.append(
                    AnyComponentWithIdentity(id: content.uuid, component: AnyComponent(
                        BrowserContentComponent(
                            content: content,
                            insets: UIEdgeInsets(
                                top: layout.statusBarHeight ?? 0.0,
                                left: layout.safeInsets.left,
                                bottom: layout.intrinsicInsets.bottom,
                                right: layout.safeInsets.right
                            ),
                            navigationBarHeight: navigationBarHeight,
                            scrollingPanelOffsetFraction: self.scrollingPanelOffsetFraction,
                            hasBottomPanel: !layout.metrics.isTablet || self.presentationState.isSearching
                        )
                    ))
                )
            }
            
            let _ = self.contentNavigationContainer.update(
                transition: transition,
                component: AnyComponent(
                    NavigationStackComponent(
                        items: items,
                        requestPop: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.popContent(transition: .spring(duration: 0.4))
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            let navigationFrame = CGRect(origin: .zero, size: layout.size)
            if let view = self.contentNavigationContainer.view {
                if view.superview == nil {
                    self.contentContainerView.addSubview(view)
                }
                transition.setFrame(view: view, frame: navigationFrame)
            }
            
            self.navigationBarHeight = environment.navigationHeight
            self.toolbarHeight = 49.0
        }
    }
    
    public enum Subject {
        case webPage(url: String)
        case instantPage(webPage: TelegramMediaWebpage, anchor: String?, sourceLocation: InstantPageSourceLocation, preloadedResources: [Any]?)
        case document(file: FileMediaReference, canShare: Bool)
        case pdfDocument(file: FileMediaReference, canShare: Bool)
        
        public var fileId: MediaId? {
            switch self {
            case let .document(file, _), let .pdfDocument(file, _):
                return file.media.fileId
            default:
                return nil
            }
        }
    }
    
    private let context: AccountContext
    public let subject: Subject
    private var preferredConfiguration: WKWebViewConfiguration?
    private var openPreviousOnClose = false
    
    public var openDocument: (TelegramMediaFile, Bool) -> Void = { _, _ in }
    
    private var validLayout: ContainerViewLayout?
    
    public static let supportedDocumentMimeTypes: [String] = [
        "text/plain",
        "text/rtf",
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    ]
    
    public static let supportedDocumentExtensions: [String] = [
        "txt",
        "rtf",
        "pdf",
        "doc",
        "docx",
        "xls",
        "xlsx",
        "pptx"
    ]
    
    public init(context: AccountContext, subject: Subject, preferredConfiguration: WKWebViewConfiguration? = nil, openPreviousOnClose: Bool = false) {
        var subject = subject
        if case let .webPage(url) = subject, let parsedUrl = URL(string: url) {
            if parsedUrl.host?.hasSuffix(".ton") == true {
                var urlComponents = URLComponents(string: url)
                urlComponents?.scheme = "tonsite"
                if let updatedUrl = urlComponents?.url?.absoluteString {
                    subject = .webPage(url: updatedUrl)
                }
            }
        }
        self.context = context
        self.subject = subject
        self.preferredConfiguration = preferredConfiguration
        self.openPreviousOnClose = openPreviousOnClose
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modalInCompactLayout
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        
        self.scrollToTop = { [weak self] in
            self?.node.content.last?.scrollToTop()
        }
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        var navigationHeight = self.navigationLayout(layout: layout).navigationFrame.height
        if layout.metrics.isTablet, layout.size.width > layout.size.height {
            navigationHeight += 6.0
        }
        self.node.containerLayoutUpdated(layout: layout, navigationBarHeight: navigationHeight, transition: ComponentTransition(transition))
    }
    
    public func requestMinimize(topEdgeOffset: CGFloat?, initialVelocity: CGFloat?) {
        self.openPreviousOnClose = false
        self.node.minimize(topEdgeOffset: topEdgeOffset, damping: 180.0, initialVelocity: initialVelocity)
    }
    
    private var didPlayAppearanceAnimation = false
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.didPlayAppearanceAnimation, let layout = self.validLayout, layout.metrics.isTablet {
            self.node.layer.animatePosition(from: CGPoint(x: 0.0, y: layout.size.height), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        if let layout = self.validLayout, layout.metrics.isTablet {
            self.node.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: layout.size.height), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                super.dismiss(completion: completion)
            })
        } else {
            super.dismiss(completion: completion)
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.openPreviousOnClose, let navigationController = self.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer, let controller = minimizedContainer.controllers.last {
            navigationController.maximizeViewController(controller, animated: true)
        }
    }
    
    public var isMinimized = false {
        didSet {
            if let webContent = self.node.content.last as? BrowserWebContent {
                if !self.isMinimized {
                    webContent.webView.setNeedsLayout()
                }
            }
        }
    }
    public var isMinimizable = true
    
    public var minimizedIcon: UIImage? {
        if let contentState = self.node.contentState {
            switch contentState.contentType {
            case .webPage:
                return contentState.favicon
            case .instantPage:
                return UIImage(bundleImageName: "Chat/Message/AttachedContentInstantIcon")?.withRenderingMode(.alwaysTemplate)
            case .document:
                return nil
            }
        }
        return nil
    }
        
    public var minimizedProgress: Float? {
        if let contentState = self.node.contentState {
            return Float(contentState.readingProgress)
        }
        return nil
    }
    
    public func makeContentSnapshotView() -> UIView? {
        if let contentSnapshot = self.node.content.last?.makeContentSnapshotView(), let layout = self.validLayout {
            if let wrapperView = self.view.snapshotView(afterScreenUpdates: false) {
                contentSnapshot.frame = contentSnapshot.frame.offsetBy(dx: 0.0, dy: self.navigationLayout(layout: layout).navigationFrame.height)
                wrapperView.addSubview(contentSnapshot)
                return wrapperView
            } else {
                return contentSnapshot
            }
        } else {
            return self.view.snapshotView(afterScreenUpdates: false)
        }
    }
}

private final class BrowserReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class BrowserContentComponent: Component {
    let content: BrowserContent
    let insets: UIEdgeInsets
    let navigationBarHeight: CGFloat
    let scrollingPanelOffsetFraction: CGFloat
    let hasBottomPanel: Bool
    
    init(
        content: BrowserContent,
        insets: UIEdgeInsets,
        navigationBarHeight: CGFloat,
        scrollingPanelOffsetFraction: CGFloat,
        hasBottomPanel: Bool
    ) {
        self.content = content
        self.insets = insets
        self.navigationBarHeight = navigationBarHeight
        self.scrollingPanelOffsetFraction = scrollingPanelOffsetFraction
        self.hasBottomPanel = hasBottomPanel
    }
    
    static func ==(lhs: BrowserContentComponent, rhs: BrowserContentComponent) -> Bool {
        if lhs.content.uuid != rhs.content.uuid {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.navigationBarHeight != rhs.navigationBarHeight {
            return false
        }
        if lhs.scrollingPanelOffsetFraction != rhs.scrollingPanelOffsetFraction {
            return false
        }
        if lhs.hasBottomPanel != rhs.hasBottomPanel {
            return false
        }
        return true
    }

    final class View: UIView {
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BrowserContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if component.content.superview !== self {
                self.addSubview(component.content)
            }
            
            let collapsedHeight: CGFloat = 24.0
            let topInset: CGFloat = component.navigationBarHeight * (1.0 - component.scrollingPanelOffsetFraction) + (component.insets.top + collapsedHeight) * component.scrollingPanelOffsetFraction
            let bottomInset = component.hasBottomPanel ? (49.0 + component.insets.bottom) * (1.0 - component.scrollingPanelOffsetFraction) : 0.0
            let insets = UIEdgeInsets(top: topInset, left: component.insets.left, bottom: bottomInset, right: component.insets.right)
            let fullInsets = UIEdgeInsets(top: component.insets.top + component.navigationBarHeight, left: component.insets.left, bottom: component.hasBottomPanel ? 49.0 + component.insets.bottom : 0.0, right: component.insets.right)
                        
            component.content.updateLayout(size: availableSize, insets: insets, fullInsets: fullInsets, safeInsets: component.insets, transition: transition)
            transition.setFrame(view: component.content, frame: CGRect(origin: .zero, size: availableSize))
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private func cancelInteractiveTransitionGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? InteractiveTransitionGestureRecognizer {
                gesture.cancel()
            } else if let scrollView = gesture.view as? UIScrollView, gesture.isEnabled, scrollView.tag == 0x5C4011 {
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        }
    }
    if let superview = view.superview {
        cancelInteractiveTransitionGestures(view: superview)
    }
}
