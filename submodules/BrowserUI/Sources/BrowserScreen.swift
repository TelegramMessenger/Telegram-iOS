import Foundation
import UIKit
import SwiftSignalKit
import Display
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

private let settingsTag = GenericComponentViewTag()

private final class BrowserScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let contentState: BrowserContentState?
    let presentationState: BrowserPresentationState
    let performAction: ActionSlot<BrowserScreen.Action>
    let panelCollapseFraction: CGFloat
    
    init(
        context: AccountContext,
        contentState: BrowserContentState?,
        presentationState: BrowserPresentationState,
        performAction: ActionSlot<BrowserScreen.Action>,
        panelCollapseFraction: CGFloat
    ) {
        self.context = context
        self.contentState = contentState
        self.presentationState = presentationState
        self.performAction = performAction
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
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let performAction = context.component.performAction
            
            let navigationContent: AnyComponentWithIdentity<Empty>?
            let navigationLeftItems: [AnyComponentWithIdentity<Empty>]
            let navigationRightItems: [AnyComponentWithIdentity<Empty>]
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
                navigationContent = AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: context.component.contentState?.title ?? "", font: Font.bold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor, paragraphAlignment: .center)), horizontalAlignment: .center, maximumNumberOfLines: 1)
                    )
                )
                navigationLeftItems = [
                    AnyComponentWithIdentity(
                        id: "close",
                        component: AnyComponent(
                            Button(
                                content: AnyComponent(
                                    BundleIconComponent(
                                        name: "Instant View/Close",
                                        tintColor: environment.theme.rootController.navigationBar.primaryTextColor
                                    )
                                ),
                                action: {
                                    performAction.invoke(.close)
                                }
                            )
                        )
                    )
                ]
                navigationRightItems = [
                    AnyComponentWithIdentity(
                        id: "close",
                        component: AnyComponent(
                            ReferenceButtonComponent(
                                content: AnyComponent(
                                    BundleIconComponent(
                                        name: "Instant View/Settings",
                                        tintColor: environment.theme.rootController.navigationBar.primaryTextColor
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
                    leftItems: navigationLeftItems,
                    rightItems: navigationRightItems,
                    centerItem: navigationContent,
                    readingProgress: 0.0,
                    loadingProgress: context.component.contentState?.estimatedProgress,
                    collapseFraction: collapseFraction
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
                            textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                            canGoBack: context.component.contentState?.canGoBack ?? false,
                            canGoForward: context.component.contentState?.canGoForward ?? false,
                            performAction: performAction
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
            
            let toolbar = toolbar.update(
                component: BrowserToolbarComponent(
                    backgroundColor: environment.theme.rootController.navigationBar.blurredBackgroundColor,
                    separatorColor: environment.theme.rootController.navigationBar.separatorColor,
                    textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                    bottomInset: toolbarBottomInset,
                    sideInset: environment.safeInsets.left,
                    item: toolbarContent,
                    collapseFraction: collapseFraction
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(toolbar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - toolbar.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

struct BrowserPresentationState: Equatable {
    var fontSize: Int32
    var fontIsSerif: Bool
    var isSearching: Bool
    var searchResultIndex: Int
    var searchResultCount: Int
    var searchQueryIsEmpty: Bool
}

public class BrowserScreen: ViewController {
    enum Action {
        case close
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
    }

    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: BrowserScreen?
        private let context: AccountContext
        
        private let contentContainerView: UIView
        fileprivate var content: BrowserContent?
        
        private var contentState: BrowserContentState?
        private var contentStateDisposable: Disposable?
        
        private var presentationState: BrowserPresentationState
        
        private let performAction: ActionSlot<BrowserScreen.Action>
        
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        
        private var presentationData: PresentationData
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: BrowserScreen) {
            self.context = controller.context
            self.controller = controller
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.presentationState = BrowserPresentationState(fontSize: 100, fontIsSerif: false, isSearching: false, searchResultIndex: 0, searchResultCount: 0, searchQueryIsEmpty: true)
            
            self.performAction = ActionSlot()

            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
                        
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            super.init()
            
            let content: BrowserContent
            switch controller.subject {
            case let .webPage(url):
                content = BrowserWebContent(url: url)
            }
            
            self.content = content
            self.contentStateDisposable = (content.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.contentState = state
                strongSelf.requestLayout(transition: .immediate)
            })
            
            self.content?.onScrollingUpdate = { [weak self] update in
                self?.onContentScrollingUpdate(update)
            }
            
            self.performAction.connect { [weak self] action in
                guard let self, let content = self.content, let url = self.contentState?.url else {
                    return
                }
                switch action {
                case .close:
                    self.controller?.dismiss()
                case .navigateBack:
                    content.navigateBack()
                case .navigateForward:
                    content.navigateForward()
                case .share:
                    let presentationData = self.presentationData
                    let shareController = ShareController(context: self.context, subject: .url(url))
                    shareController.actionCompleted = { [weak self] in
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                    self.controller?.present(shareController, in: .window(.root))
                case .minimize:
                    break
                case .openIn:
                    self.context.sharedContext.applicationBindings.openUrl(url)
                case .openSettings:
                    self.openSettings()
                case let .updateSearchActive(active):
                    self.updatePresentationState(animated: true, { state in
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
                    content.scrollToPreviousSearchResult(completion: { [weak self] index, count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = index
                            updatedState.searchResultCount = count
                            return updatedState
                        })
                    })
                case .scrollToNextSearchResult:
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
                        switch state.fontSize {
                        case 150:
                            updatedState.fontSize = 125
                        case 125:
                            updatedState.fontSize = 115
                        case 115:
                            updatedState.fontSize = 100
                        case 100:
                            updatedState.fontSize = 85
                        case 85:
                            updatedState.fontSize = 75
                        case 75:
                            updatedState.fontSize = 50
                        default:
                            updatedState.fontSize = 50
                        }
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case .increaseFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        switch state.fontSize {
                        case 125:
                            updatedState.fontSize = 150
                        case 115:
                            updatedState.fontSize = 125
                        case 100:
                            updatedState.fontSize = 115
                        case 85:
                            updatedState.fontSize = 100
                        case 75:
                            updatedState.fontSize = 85
                        case 50:
                            updatedState.fontSize = 75
                        default:
                            updatedState.fontSize = 150
                        }
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case .resetFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontSize = 100
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case let .updateFontIsSerif(value):
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontIsSerif = value
                        return updatedState
                    })
                    content.setForceSerif(value)
                }
            }
        }
        
        deinit {
            self.contentStateDisposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.addSubview(self.contentContainerView)
            if let content = self.content {
                self.contentContainerView.addSubview(content)
            }
        }
        
        func updatePresentationState(animated: Bool = false, _ f: (BrowserPresentationState) -> BrowserPresentationState) {
            self.presentationState = f(self.presentationState)
            self.requestLayout(transition: animated ? .easeInOut(duration: 0.2) : .immediate)
        }
        
        func openSettings() {
            guard let referenceView = self.componentHost.findTaggedView(tag: settingsTag) as? ReferenceButtonComponent.View else {
                return
            }

            self.view.endEditing(true)
            
            let checkIcon: (PresentationTheme) -> UIImage? = { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Check"), color: theme.contextMenu.primaryColor) }
            let emptyIcon: (PresentationTheme) -> UIImage? = { _ in
                return nil
            }
            
            let settings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings])
            |> take(1)
            |> map { sharedData -> WebBrowserSettings in
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) {
                    return current
                } else {
                    return WebBrowserSettings.defaultSettings
                }
            }
            
            let _ = (settings
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self, let controller = self.controller else {
                    return
                }
                
                let source: ContextContentSource = .reference(BrowserReferenceContentSource(controller: controller, sourceView: referenceView.referenceNode.view))
                
                let performAction = self.performAction
                
                let forceIsSerif = self.presentationState.fontIsSerif
                let fontItem = BrowserFontSizeContextMenuItem(
                    value: self.presentationState.fontSize,
                    decrease: { [weak self] in
                        performAction.invoke(.decreaseFontSize)
                        if let self {
                            return self.presentationState.fontSize
                        } else {
                            return 100
                        }
                    }, increase: { [weak self] in
                        performAction.invoke(.increaseFontSize)
                        if let self {
                            return self.presentationState.fontSize
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
                
                let url = self.contentState?.url ?? ""
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
                
                let items: [ContextMenuItem] = [
                    .custom(fontItem, false),
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_FontSanFrancisco, icon: forceIsSerif ? emptyIcon : checkIcon, action: { (controller, action) in
                        performAction.invoke(.updateFontIsSerif(false))
                        action(.default)
                    })), .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_FontNewYork, textFont: .custom(font: Font.with(size: 17.0, design: .serif, traits: []), height: nil, verticalOffset: nil), icon: forceIsSerif ? checkIcon : emptyIcon, action: { (controller, action) in
                        performAction.invoke(.updateFontIsSerif(true))
                        action(.default)
                    })),
                    .separator,
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_Search, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Search"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.updateSearchActive(true))
                        action(.default)
                    })),
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_OpenInBrowser(openInTitle).string, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] (controller, action) in
                        if let self {
                            self.context.sharedContext.applicationBindings.openUrl(openInUrl)
                        }
                        action(.default)
                    }))]
                
                let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))))
                self.controller?.present(contextController, in: .window(.root))
            })
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view, let content = self.content {
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
                
                if scrollingPanelOffsetFraction != self.scrollingPanelOffsetFraction {
                    self.scrollingPanelOffsetFraction = scrollingPanelOffsetFraction
                    self.requestLayout(transition: transition)
                }
            }
        }
        
        func requestLayout(transition: Transition) {
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: Transition) {
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
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    BrowserScreenComponent(
                        context: self.context,
                        contentState: self.contentState,
                        presentationState: self.presentationState,
                        performAction: self.performAction,
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
            if let content = self.content {
                let collapsedHeight: CGFloat = 24.0
                let topInset: CGFloat = environment.statusBarHeight + navigationBarHeight * (1.0 - self.scrollingPanelOffsetFraction) + collapsedHeight * self.scrollingPanelOffsetFraction
                let bottomInset = layout.intrinsicInsets.bottom
                content.updateLayout(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: bottomInset, right: layout.safeInsets.right), transition: transition)
                transition.setFrame(view: content, frame: CGRect(origin: .zero, size: layout.size))
            }
            
            self.navigationBarHeight = environment.navigationHeight
            self.toolbarHeight = 49.0
        }
    }
    
    public enum Subject {
        case webPage(url: String)
    }
    
    private let context: AccountContext
    private let subject: Subject
    
    public init(context: AccountContext, subject: Subject) {
        self.context = context
        self.subject = subject
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modal
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        
        self.scrollToTop = { [weak self] in
            (self?.displayNode as? Node)?.content?.scrollToTop()
        }
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.height, transition: Transition(transition))
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
