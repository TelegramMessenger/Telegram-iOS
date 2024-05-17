import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ComponentFlow
import TelegramCore
import PeerInfoVisualMediaPaneNode
import ViewControllerComponent
import ChatListHeaderComponent
import ContextUI
import ChatTitleView
import BottomButtonPanelComponent
import UndoUI
import MoreHeaderButton
import MediaEditorScreen
import SaveToCameraRoll

final class StorySearchGridScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let searchQuery: String

    init(
        context: AccountContext,
        searchQuery: String
    ) {
        self.context = context
        self.searchQuery = searchQuery
    }

    static func ==(lhs: StorySearchGridScreenComponent, rhs: StorySearchGridScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.searchQuery != rhs.searchQuery {
            return false
        }

        return true
    }
    
    final class View: UIView {
        private var component: StorySearchGridScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private(set) var paneNode: PeerInfoStoryPaneNode?
        private var paneStatusDisposable: Disposable?
        private(set) var paneStatusText: String?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.paneStatusDisposable?.dispose()
        }
        
        func scrollToTop() {
            guard let paneNode = self.paneNode else {
                return
            }
            let _ = paneNode.scrollToTop()
        }
        
        private var isUpdating = false
        func update(component: StorySearchGridScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 14.0
            let _ = sideInset
            
            let environment = environment[EnvironmentType.self].value
            
            let themeUpdated = self.environment?.theme !== environment.theme
            
            self.environment = environment
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            let bottomInset: CGFloat = environment.safeInsets.bottom
            
            let paneNode: PeerInfoStoryPaneNode
            if let current = self.paneNode {
                paneNode = current
            } else {
                paneNode = PeerInfoStoryPaneNode(
                    context: component.context,
                    peerId: nil,
                    searchQuery: component.searchQuery,
                    contentType: .photoOrVideo,
                    captureProtected: false,
                    isSaved: false,
                    isArchive: false,
                    isProfileEmbedded: false,
                    canManageStories: false,
                    navigationController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.environment?.controller()?.navigationController as? NavigationController
                    },
                    listContext: nil
                )
                paneNode.isEmptyUpdated = { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                }
                self.paneNode = paneNode
                self.addSubview(paneNode.view)
                
                self.paneStatusDisposable = (paneNode.status
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    guard let self else {
                        return
                    }
                    if self.paneStatusText != status?.text {
                        self.paneStatusText = status?.text
                        (self.environment?.controller() as? StorySearchGridScreen)?.updateTitle()
                    }
                })
            }
            
            paneNode.update(
                size: availableSize,
                topInset: environment.navigationHeight,
                sideInset: environment.safeInsets.left,
                bottomInset: bottomInset,
                deviceMetrics: environment.deviceMetrics,
                visibleHeight: availableSize.height,
                isScrollingLockedAtTop: false,
                expandProgress: 1.0,
                navigationHeight: 0.0,
                presentationData: component.context.sharedContext.currentPresentationData.with({ $0 }),
                synchronous: false,
                transition: transition.containedViewLayoutTransition
            )
            transition.setFrame(view: paneNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StorySearchGridScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let searchQuery: String
    private var isDismissed: Bool = false
    
    private var titleView: ChatTitleView?
    
    public init(
        context: AccountContext,
        searchQuery: String
    ) {
        self.context = context
        self.searchQuery = searchQuery
        
        super.init(context: context, component: StorySearchGridScreenComponent(
            context: context,
            searchQuery: searchQuery
        ), navigationBarAppearance: .default, theme: .default)
        
        let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
        
        self.titleView = ChatTitleView(
            context: context, theme:
                presentationData.theme,
            strings: presentationData.strings,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer
        )
        self.titleView?.disableAnimations = true
        
        self.navigationItem.titleView = self.titleView
        
        self.updateTitle()
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? StorySearchGridScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    func updateTitle() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let _ = presentationData
        
        guard let componentView = self.node.hostView.componentView as? StorySearchGridScreenComponent.View, let paneNode = componentView.paneNode else {
            return
        }
        let _ = paneNode
        
        let title: String?
        if let paneStatusText = componentView.paneStatusText, !paneStatusText.isEmpty {
            title = paneStatusText
        } else {
            title = nil
        }
        //TODO:localize
        self.titleView?.titleContent = .custom("\(self.searchQuery)", title, false)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.titleView?.layout = layout
    }
}

private final class PeerInfoContextReferenceContentSource: ContextReferenceContentSource {
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
