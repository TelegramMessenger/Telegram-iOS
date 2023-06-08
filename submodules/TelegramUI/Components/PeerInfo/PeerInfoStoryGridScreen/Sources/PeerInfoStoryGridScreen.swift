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

final class PeerInfoStoryGridScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let scope: PeerInfoStoryGridScreen.Scope

    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        scope: PeerInfoStoryGridScreen.Scope
    ) {
        self.context = context
        self.peerId = peerId
        self.scope = scope
    }

    static func ==(lhs: PeerInfoStoryGridScreenComponent, rhs: PeerInfoStoryGridScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.scope != rhs.scope {
            return false
        }

        return true
    }
    
    final class View: UIView {
        private var component: PeerInfoStoryGridScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var paneNode: PeerInfoStoryPaneNode?
        
        private weak var mediaGalleryContextMenu: ContextController?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func morePressed(source: ContextReferenceContentNode) {
            guard let component = self.component, let controller = self.environment?.controller(), let pane = self.paneNode else {
                return
            }

            var items: [ContextMenuItem] = []
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings

            var recurseGenerateAction: ((Bool) -> ContextMenuActionItem)?
            let generateAction: (Bool) -> ContextMenuActionItem = { [weak pane] isZoomIn in
                let nextZoomLevel = isZoomIn ? pane?.availableZoomLevels().increment : pane?.availableZoomLevels().decrement
                let canZoom: Bool = nextZoomLevel != nil

                return ContextMenuActionItem(id: isZoomIn ? 0 : 1, text: isZoomIn ? strings.SharedMedia_ZoomIn : strings.SharedMedia_ZoomOut, textColor: canZoom ? .primary : .disabled, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isZoomIn ? "Chat/Context Menu/ZoomIn" : "Chat/Context Menu/ZoomOut"), color: canZoom ? theme.contextMenu.primaryColor : theme.contextMenu.primaryColor.withMultipliedAlpha(0.4))
                }, action: canZoom ? { action in
                    guard let pane = pane, let zoomLevel = isZoomIn ? pane.availableZoomLevels().increment : pane.availableZoomLevels().decrement else {
                        return
                    }
                    pane.updateZoomLevel(level: zoomLevel)
                    if let recurseGenerateAction = recurseGenerateAction {
                        action.updateAction(0, recurseGenerateAction(true))
                        action.updateAction(1, recurseGenerateAction(false))
                    }
                } : nil)
            }
            recurseGenerateAction = { isZoomIn in
                return generateAction(isZoomIn)
            }

            items.append(.action(generateAction(true)))
            items.append(.action(generateAction(false)))
            
            if component.peerId == component.context.account.peerId, case .saved = component.scope {
                var ignoreNextActions = false
                //TODO:localize
                items.append(.action(ContextMenuActionItem(text: "Show Archive", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/StoryArchive"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    self.environment?.controller()?.push(PeerInfoStoryGridScreen(context: component.context, peerId: component.peerId, scope: .archive))
                })))
            }

            /*if photoCount != 0 && videoCount != 0 {
                items.append(.separator)

                let showPhotos: Bool
                switch pane.contentType {
                case .photo, .photoOrVideo:
                    showPhotos = true
                default:
                    showPhotos = false
                }
                let showVideos: Bool
                switch pane.contentType {
                case .video, .photoOrVideo:
                    showVideos = true
                default:
                    showVideos = false
                }

                items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowPhotos, icon: { theme in
                    if !showPhotos {
                        return nil
                    }
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }, action: { [weak pane] _, a in
                    a(.default)

                    guard let pane = pane else {
                        return
                    }
                    let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                    switch pane.contentType {
                    case .photoOrVideo:
                        updatedContentType = .video
                    case .photo:
                        updatedContentType = .photo
                    case .video:
                        updatedContentType = .photoOrVideo
                    default:
                        updatedContentType = pane.contentType
                    }
                    pane.updateContentType(contentType: updatedContentType)
                })))
                items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowVideos, icon: { theme in
                    if !showVideos {
                        return nil
                    }
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }, action: { [weak pane] _, a in
                    a(.default)

                    guard let pane = pane else {
                        return
                    }
                    let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                    switch pane.contentType {
                    case .photoOrVideo:
                        updatedContentType = .photo
                    case .photo:
                        updatedContentType = .photoOrVideo
                    case .video:
                        updatedContentType = .video
                    default:
                        updatedContentType = pane.contentType
                    }
                    pane.updateContentType(contentType: updatedContentType)
                })))
            }*/

            let contextController = ContextController(account: component.context.account, presentationData: presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
            contextController.passthroughTouchEvent = { [weak self] sourceView, point in
                guard let self else {
                    return .ignore
                }

                let localPoint = self.convert(sourceView.convert(point, to: nil), from: nil)
                guard let localResult = self.hitTest(localPoint, with: nil) else {
                    return .dismiss(consume: true, result: nil)
                }

                var testView: UIView? = localResult
                while true {
                    if let testViewValue = testView {
                        if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                            node.brieflyDisableTouchActions()
                            return .dismiss(consume: false, result: nil)
                        } else {
                            testView = testViewValue.superview
                        }
                    } else {
                        break
                    }
                }

                return .dismiss(consume: true, result: nil)
            }
            self.mediaGalleryContextMenu = contextController
            controller.presentInGlobalOverlay(contextController)
        }
        
        func update(component: PeerInfoStoryGridScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[EnvironmentType.self].value
            
            let themeUpdated = self.environment?.theme !== environment.theme
            
            self.environment = environment
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            let paneNode: PeerInfoStoryPaneNode
            if let current = self.paneNode {
                paneNode = current
            } else {
                paneNode = PeerInfoStoryPaneNode(
                    context: component.context,
                    peerId: component.peerId,
                    chatLocation: .peer(id: component.peerId),
                    contentType: .photoOrVideo,
                    captureProtected: false,
                    isArchive: component.scope == .archive,
                    navigationController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.environment?.controller()?.navigationController as? NavigationController
                    }
                )
                self.paneNode = paneNode
                self.addSubview(paneNode.view)
            }
            
            paneNode.update(
                size: availableSize,
                topInset: environment.navigationHeight,
                sideInset: environment.safeInsets.left,
                bottomInset: environment.safeInsets.bottom,
                visibleHeight: availableSize.height,
                isScrollingLockedAtTop: false,
                expandProgress: 1.0,
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

public class PeerInfoStoryGridScreen: ViewControllerComponentContainer {
    public enum Scope {
        case saved
        case archive
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    private var moreBarButton: MoreHeaderButton?
    private var moreBarButtonItem: UIBarButtonItem?
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        scope: Scope
    ) {
        self.context = context
        
        super.init(context: context, component: PeerInfoStoryGridScreenComponent(
            context: context,
            peerId: peerId,
            scope: scope
        ), navigationBarAppearance: .default, theme: .default)
        
        //TODO:localize
        self.navigationItem.title = "My Stories"
        
        let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
        let moreBarButton = MoreHeaderButton(color: presentationData.theme.rootController.navigationBar.buttonColor)
        moreBarButton.isUserInteractionEnabled = true
        self.moreBarButton = moreBarButton
        
        moreBarButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: presentationData.theme.rootController.navigationBar.buttonColor)))
        let moreBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreBarButton)!
        self.moreBarButtonItem = moreBarButtonItem
        moreBarButton.contextAction = { [weak self] sourceNode, gesture in
            guard let self else {
                return
            }
            let _ = self
        }
        moreBarButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        
        self.navigationItem.setRightBarButton(moreBarButtonItem, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func morePressed() {
        guard let componentView = self.node.hostView.componentView as? PeerInfoStoryGridScreenComponent.View else {
            return
        }
        guard let moreBarButton = self.moreBarButton else {
            return
        }
        componentView.morePressed(source: moreBarButton.referenceNode)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
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
