import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import ContextUI
import AccountContext
import ShareController
import OpenInExternalAppUI

private final class InstantPageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = false
    
    private weak var navigationBar: BrowserNavigationBar?
    
    init(navigationBar: BrowserNavigationBar) {
        self.navigationBar = navigationBar
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let navigationBar = self.navigationBar else {
            return nil
        }
        return ContextControllerTakeViewInfo(contentContainingNode: navigationBar.contextSourceNode, contentAreaInScreenSpace: navigationBar.convert(navigationBar.contextSourceNode.frame.offsetBy(dx: 0.0, dy: 40.0), to: nil))
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let navigationBar = self.navigationBar else {
            return nil
        }
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: navigationBar.convert(navigationBar.contextSourceNode.frame.offsetBy(dx: 0.0, dy: 40.0), to: nil))
    }
}

public enum BrowserSubject {
//    case instantPage(TelegramMediaWebpage, String)
    case webPage(String)
    
    var isInstant: Bool {
        return false
//        if case .instantPage = self {
//            return true
//        } else {
//            return false
//        }
    }
}

public final class BrowserScreen: ViewController {
    private let context: AccountContext
    private let subject: BrowserSubject
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, subject: BrowserSubject) {
        self.context = context
        self.subject = subject
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modal
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.presentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.presentationData = presentationData
            (strongSelf.displayNode as! BrowserScreenNode).updatePresentationData(presentationData)
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = BrowserScreenNode(context: self.context, presentationData: self.presentationData, subject: self.subject, titleUpdated: { [weak self] title in
            self?.title = title
        })
        (self.displayNode as! BrowserScreenNode).present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }
        (self.displayNode as! BrowserScreenNode).minimize = {
//            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
//                navigationController.minimizeViewController(strongSelf, animated: true)
//            }
        }
        (self.displayNode as! BrowserScreenNode).close = { [weak self] in
            self?.dismiss()
        }
        self.displayNodeDidLoad()
        
        self._ready.set(.single(true))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat
        if case .modal = self.navigationPresentation {
            navigationHeight = 56.0
        } else {
            navigationHeight = 44.0
        }
        
        (self.displayNode as! BrowserScreenNode).containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: transition)
    }
}

struct BrowserSearchState {
    var query: String
    var results: (Int, Int)?
    
    func withUpdatedQuery(_ query: String) -> BrowserSearchState {
        return BrowserSearchState(query: query, results: self.results)
    }
    
    func withUpdatedResults(_ results: (Int, Int)?) -> BrowserSearchState {
        return BrowserSearchState(query: self.query, results: results)
    }
}

struct BrowserPresentationState {
    let fontSize: CGFloat
    let forceSerif: Bool
    
    func withUpdatedFontSize(_ fontSize: CGFloat) -> BrowserPresentationState {
        return BrowserPresentationState(fontSize: fontSize, forceSerif: self.forceSerif)
    }
    
    func withUpdatedForceSerif(_ forceSerif: Bool) -> BrowserPresentationState {
        return BrowserPresentationState(fontSize: self.fontSize, forceSerif: forceSerif)
    }
}

final class BrowserState {
    let content: BrowserContentState?
    let presentation: BrowserPresentationState
    let search: BrowserSearchState?
    
    init(content: BrowserContentState? = nil, presentation: BrowserPresentationState, search: BrowserSearchState? = nil) {
        self.content = content
        self.presentation = presentation
        self.search = search
    }
    
    func withUpdatedContent(_ content: BrowserContentState) -> BrowserState {
        return BrowserState(content: content, presentation: self.presentation, search: self.search)
    }
    
    func withUpdatedPresentation(_ presentation: BrowserPresentationState) -> BrowserState {
        return BrowserState(content: content, presentation: presentation, search: self.search)
    }
    
    func withUpdatedSearch(_ search: BrowserSearchState?) -> BrowserState {
        return BrowserState(content: self.content, presentation: self.presentation, search: search)
    }
}

private final class BrowserTheme {
    let backgroundColor: UIColor
    let navigationBar: BrowserNavigationBarTheme
    let toolbar: BrowserToolbarTheme
    
    init(backgroundColor: UIColor, navigationBar: BrowserNavigationBarTheme, toolbar: BrowserToolbarTheme) {
        self.backgroundColor = backgroundColor
        self.navigationBar = navigationBar
        self.toolbar = toolbar
    }
}

extension BrowserTheme {
    convenience init(presentationTheme: PresentationTheme) {
        self.init(backgroundColor: presentationTheme.list.plainBackgroundColor,
                  navigationBar: BrowserNavigationBarTheme(
                    backgroundColor: presentationTheme.rootController.navigationBar.opaqueBackgroundColor,
                    separatorColor: presentationTheme.rootController.navigationBar.separatorColor,
                    primaryTextColor: presentationTheme.rootController.navigationBar.primaryTextColor,
                    loadingProgressColor: presentationTheme.rootController.navigationBar.accentTextColor,
                    readingProgressColor: presentationTheme.rootController.navigationBar.segmentedBackgroundColor,
                    buttonColor: presentationTheme.rootController.navigationBar.primaryTextColor,
                    disabledButtonColor: presentationTheme.chat.inputPanel.inputTextColor.withAlphaComponent(0.3),
                    searchBarFieldColor: presentationTheme.rootController.navigationSearchBar.inputFillColor,
                    searchBarTextColor: presentationTheme.rootController.navigationSearchBar.inputTextColor,
                    searchBarPlaceholderColor: presentationTheme.rootController.navigationSearchBar.inputPlaceholderTextColor,
                    searchBarIconColor: presentationTheme.rootController.navigationSearchBar.inputIconColor,
                    searchBarClearColor: presentationTheme.rootController.navigationSearchBar.inputClearButtonColor,
                    searchBarKeyboardColor: presentationTheme.rootController.keyboardColor
                    ),
                  toolbar: BrowserToolbarTheme(
                    backgroundColor: presentationTheme.chat.inputPanel.panelBackgroundColor,
                    separatorColor: presentationTheme.chat.inputPanel.panelSeparatorColor,
                    buttonColor: presentationTheme.chat.inputPanel.inputTextColor,
                    disabledButtonColor: presentationTheme.chat.inputPanel.inputTextColor.withAlphaComponent(0.3)))
    }
}

private final class BrowserScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let subject: BrowserSubject
    
    private var interaction: BrowserInteraction?
    
    private var browserState: BrowserState
    private var browserStatePromise: Promise<BrowserState>
    private var stateDisposable: Disposable?
    
    private let navigationBar: BrowserNavigationBar
    private let toolbar: BrowserToolbar
    private let contentContainerNode: ASDisplayNode
    private var content: BrowserContent?
    private var contentStateDisposable: Disposable?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var present: ((ViewController, Any?) -> Void)?
    var minimize: (() -> Void)?
    var close: (() -> Void)?
    let titleUpdated: (String) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, subject: BrowserSubject, titleUpdated: @escaping ((String) -> Void)) {
        self.context = context
        self.presentationData = presentationData
        self.subject = subject
        self.titleUpdated = titleUpdated
        
        self.browserState = BrowserState(content: BrowserContentState(title: "", url: "", estimatedProgress: 0.0, isInstant: subject.isInstant), presentation: BrowserPresentationState(fontSize: 1.0, forceSerif: false))
        self.browserStatePromise = Promise<BrowserState>(self.browserState)
        
        let theme = BrowserTheme(presentationTheme: self.presentationData.theme)
        
        self.navigationBar = BrowserNavigationBar(theme: theme.navigationBar, strings: self.presentationData.strings, state: self.browserState)
        self.toolbar = BrowserToolbar(theme: theme.toolbar, strings: self.presentationData.strings, state: self.browserState)
        self.contentContainerNode = ASDisplayNode()
        
        super.init()
        
        self.backgroundColor = theme.backgroundColor
                
        self.addSubnode(self.contentContainerNode)
        self.addSubnode(self.toolbar)
        self.addSubnode(self.navigationBar)
        
        self.navigationBar.close = { [weak self] in
            self?.close?()
        }
        self.navigationBar.openSettings = { [weak self] in
            self?.openSettings()
        }
        self.navigationBar.scrollToTop = { [weak self] in
            self?.scrollToTop()
        }
        
        self.stateDisposable = (self.browserStatePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.titleUpdated(state.content?.title ?? "")
            
            strongSelf.navigationBar.updateState(state)
            strongSelf.toolbar.updateState(state)
            
            if let search = state.search, !search.query.isEmpty {
                strongSelf.content?.setSearch(search.query, completion: { [weak self] count in
                    if let strongSelf = self {
                        strongSelf.updateState { $0.withUpdatedSearch($0.search?.withUpdatedResults((0, count))) }
                    }
                })
            } else {
                strongSelf.content?.setSearch(nil, completion: nil)
            }
        })
        
        let content: BrowserContent
        switch self.subject {
            case let .webPage(url):
                content = BrowserWebContent(url: url)
//            case let .instantPage(webPage, url):
//                content = BrowserInstantPageContent(context: context, webPage: webPage, url: url)
        }
        
        self.contentContainerNode.addSubnode(content)
        self.content = content
        self.contentStateDisposable = (content.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.browserState = strongSelf.browserState.withUpdatedContent(state)
            strongSelf.browserStatePromise.set(.single(strongSelf.browserState))
            
            if strongSelf.isNodeLoaded {
                strongSelf.content?.view.disablesInteractiveTransitionGestureRecognizer = state.canGoBack
            }
        })
        
        self.interaction = BrowserInteraction(navigateBack: { [weak self] in
            self?.content?.navigateBack()
        }, navigateForward: { [weak self] in
            self?.content?.navigateForward()
        }, share: { [weak self] in
            if let strongSelf = self, let url = strongSelf.browserState.content?.url {
                let controller = ShareController(context: context, subject: .url(url))
                strongSelf.present?(controller, nil)
            }
        }, minimize: { [weak self] in
            self?.minimize?()
        }, openSearch: { [weak self] in
            self?.updateState { $0.withUpdatedSearch(BrowserSearchState(query: "", results: nil)) }
        }, updateSearchQuery: { [weak self] text in
            self?.updateState { $0.withUpdatedSearch(BrowserSearchState(query: text, results: nil)) }
        }, dismissSearch: { [weak self] in
            self?.updateState { $0.withUpdatedSearch(nil) }
        }, scrollToPreviousSearchResult: { [weak self] in
            self?.content?.scrollToPreviousSearchResult(completion: { [weak self] index, count in
                if let strongSelf = self {
                    strongSelf.updateState { $0.withUpdatedSearch($0.search?.withUpdatedResults((index, count))) }
                }
            })
        }, scrollToNextSearchResult: { [weak self] in
            self?.content?.scrollToNextSearchResult(completion: { [weak self] index, count in
                if let strongSelf = self {
                    strongSelf.updateState { $0.withUpdatedSearch($0.search?.withUpdatedResults((index, count))) }
                }
            })
        }, decreaseFontSize: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateState { $0.withUpdatedPresentation($0.presentation.withUpdatedFontSize(max(0.5, $0.presentation.fontSize - 0.25))) }
            
                strongSelf.content?.setFontSize(strongSelf.browserState.presentation.fontSize)
            }
        }, increaseFontSize: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateState { $0.withUpdatedPresentation($0.presentation.withUpdatedFontSize(min(2.0, $0.presentation.fontSize + 0.25))) }
                
                strongSelf.content?.setFontSize(strongSelf.browserState.presentation.fontSize)
            }
        }, resetFontSize: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateState { $0.withUpdatedPresentation($0.presentation.withUpdatedFontSize(1.0)) }
                
                strongSelf.content?.setFontSize(strongSelf.browserState.presentation.fontSize)
            }
        }, updateForceSerif: { [weak self] force in
            if let strongSelf = self {
                strongSelf.updateState { $0.withUpdatedPresentation($0.presentation.withUpdatedForceSerif(force)) }
                
                strongSelf.content?.setForceSerif(force)
            }
        })

        self.navigationBar.interaction = self.interaction
        self.toolbar.interaction = self.interaction
    }
    
    deinit {
        self.stateDisposable?.dispose()
        self.contentStateDisposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        let theme = BrowserTheme(presentationTheme: self.presentationData.theme)
        
        self.backgroundColor = theme.backgroundColor
        self.navigationBar.updateTheme(theme.navigationBar)
        self.toolbar.updateTheme(theme.toolbar)
    }
    
    func updateState(_ f: (BrowserState) -> BrowserState) {
        self.browserState = f(self.browserState)
        self.browserStatePromise.set(.single(self.browserState))
    }
    
    func openSettings() {
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
            guard let strongSelf = self else {
                return
            }
            
            let forceSerif = strongSelf.browserState.presentation.forceSerif
                  
            let source: ContextContentSource = .extracted(InstantPageContextExtractedContentSource(navigationBar: strongSelf.navigationBar))
            
            let fontItem = BrowserFontSizeContextMenuItem(value: strongSelf.browserState.presentation.fontSize, decrease: { [weak self] in
                self?.interaction?.decreaseFontSize()
                return self?.browserState.presentation.fontSize ?? 1.0
            }, increase: { [weak self] in
                self?.interaction?.increaseFontSize()
                return self?.browserState.presentation.fontSize ?? 1.0
            }, reset: { [weak self] in
                self?.interaction?.resetFontSize()
            })
            
            var defaultWebBrowser: String? = settings.defaultWebBrowser
            if defaultWebBrowser == nil || defaultWebBrowser == "inAppSafari" {
                defaultWebBrowser = "safari"
            }
        
            let url = strongSelf.browserState.content?.url ?? ""
            let openInOptions = availableOpenInOptions(context: strongSelf.context, item: .url(url: url))
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
                .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.InstantPage_FontSanFrancisco, icon: forceSerif ? emptyIcon : checkIcon, action: { [weak self] (controller, action) in
                    if let strongSelf = self {
                        strongSelf.interaction?.updateForceSerif(false)
                        action(.default)
                    }
                })), .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.InstantPage_FontNewYork, textFont: .custom(Font.with(size: 17.0, design: .serif, traits: [])), icon: forceSerif ? checkIcon : emptyIcon, action: { [weak self] (controller, action) in
                    if let strongSelf = self {
                        strongSelf.interaction?.updateForceSerif(true)
                        action(.default)
                    }
                })),
                     .separator,
                     .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.InstantPage_Search, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Search"), color: theme.contextMenu.primaryColor) }, action: { [weak self] (controller, action) in
                        if let strongSelf = self {
                            strongSelf.interaction?.openSearch()
                            action(.default)
                        }
                     })),
                     .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.InstantPage_OpenInBrowser(openInTitle).string, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] (controller, action) in
                        if let strongSelf = self {
                            strongSelf.context.sharedContext.applicationBindings.openUrl(openInUrl)
                        }
                        action(.default)
                     }))]
            
            let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))))
            strongSelf.present?(controller, nil)
        })
    }
    
    func scrollToTop() {
        self.content?.scrollToTop()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        self.updatePanelsLayout(transition: transition)
    }
    
    private func updatePanelsLayout(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationHeight) = self.validLayout else {
            return
        }
        
        var insets = layout.insets(options: .input)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        let navigationBarFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight))
        transition.updateFrame(node: self.navigationBar, frame: navigationBarFrame)
        self.navigationBar.updateLayout(size: navigationBarFrame.size, insets: insets, layoutMetrics: layout.metrics, readingProgress: 0.0, collapseTransition: 0.0, transition: transition)
        
        let toolbarSize = self.toolbar.updateLayout(width: layout.size.width, insets: insets, layoutMetrics: layout.metrics, collapseTransition: 0.0, transition: transition)
        let toolbarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarSize.height), size: toolbarSize)
        transition.updateFrame(node: self.toolbar, frame: toolbarFrame)
        
        let contentFrame = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        if let content = self.content {
            content.updateLayout(size: layout.size, insets: insets, transition: transition)
            transition.updateFrame(node: content, frame: contentFrame)
        }
    }
}
