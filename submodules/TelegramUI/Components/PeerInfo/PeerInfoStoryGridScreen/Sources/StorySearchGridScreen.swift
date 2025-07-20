import Foundation
import UIKit
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
import SaveToCameraRoll
import ShareController
import OpenInExternalAppUI

final class StorySearchGridScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let scope: StorySearchControllerScope
    let listContext: SearchStoryListContext?

    init(
        context: AccountContext,
        scope: StorySearchControllerScope,
        listContext: SearchStoryListContext?
    ) {
        self.context = context
        self.scope = scope
        self.listContext = listContext
    }

    static func ==(lhs: StorySearchGridScreenComponent, rhs: StorySearchGridScreenComponent) -> Bool {
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
        func update(component: StorySearchGridScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
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
                let paneNodeScope: PeerInfoStoryPaneNode.Scope
                switch component.scope {
                case let .query(peer, query):
                    paneNodeScope = .search(peerId: peer?.id, query: query)
                case let .location(coordinates, venue):
                    paneNodeScope = .location(coordinates: coordinates, venue: venue)
                }
                
                paneNode = PeerInfoStoryPaneNode(
                    context: component.context,
                    scope: paneNodeScope,
                    captureProtected: false,
                    isProfileEmbedded: false,
                    canManageStories: false,
                    navigationController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.environment?.controller()?.navigationController as? NavigationController
                    },
                    listContext: component.listContext
                )
                paneNode.parentController = environment.controller()
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StorySearchGridScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let scope: StorySearchControllerScope
    private var isDismissed: Bool = false
    
    private var titleView: ChatTitleView?
    
    override public var additionalNavigationBarHeight: CGFloat {
        if let componentView = self.node.hostView.componentView as? StorySearchGridScreenComponent.View, let paneNode = componentView.paneNode {
            return paneNode.additionalNavigationHeight
        } else {
            return 0.0
        }
    }
    
    public init(
        context: AccountContext,
        scope: StorySearchControllerScope,
        listContext: SearchStoryListContext? = nil
    ) {
        self.context = context
        self.scope = scope
        
        super.init(context: context, component: StorySearchGridScreenComponent(
            context: context,
            scope: scope,
            listContext: listContext
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
        
        if case .location = scope {
            self.navigationItem.setRightBarButton(UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(presentationData.theme), style: .plain, target: self, action: #selector(self.sharePressed)), animated: true)
        }
        
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
    
    @objc private func sharePressed() {
        guard case let .location(_, venue) = self.scope else {
            return
        }
        let locationMap = TelegramMediaMap(latitude: venue.latitude, longitude: venue.longitude, heading: nil, accuracyRadius: nil, venue: nil, address: venue.address, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
        
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
        
        let shareAction = OpenInControllerAction(title: presentationData.strings.Conversation_ContextMenuShare, action: { [weak self] in
            guard let self else {
                return
            }
            self.present(ShareController(context: self.context, subject: .mapMedia(locationMap), externalShare: true), in: .window(.root), with: nil)
        })
        self.present(OpenInActionSheetController(context: self.context, updatedPresentationData: nil, item: .location(location: locationMap, directions: nil), additionalAction: shareAction, openUrl: { [weak self] url in
            guard let self else {
                return
            }
            self.context.sharedContext.applicationBindings.openUrl(url)
        }), in: .window(.root), with: nil)
    }
    
    func updateTitle() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
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
        switch self.scope {
        case let .query(peer, query):
            if let peer, let addressName = peer.addressName {
                self.titleView?.titleContent = .custom("\(query)@\(addressName)", title, false)
            } else {
                self.titleView?.titleContent = .custom("\(query)", title, false)
            }
        case .location:
            self.titleView?.titleContent = .custom(presentationData.strings.StoryGridScreen_TitleLocationSearch, nil, false)
        }
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
