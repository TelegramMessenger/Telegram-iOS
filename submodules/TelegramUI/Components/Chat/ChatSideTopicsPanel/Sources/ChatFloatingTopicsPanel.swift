import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import TelegramCore
import GlassBackgroundComponent

public final class ChatFloatingTopicsPanel: Component {
    public typealias EnvironmentType = ChatSidePanelEnvironment
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let preferClearGlass: Bool
    public let strings: PresentationStrings
    public let location: ChatSideTopicsPanel.Location
    public let peerId: EnginePeer.Id
    public let kind: ChatSideTopicsPanel.Kind
    public let topicId: Int64?
    public let controller: () -> ViewController?
    public let togglePanel: () -> Void
    public let updateTopicId: (Int64?, ChatControllerAnimateInnerChatSwitchDirection) -> Void
    public let openDeletePeer: (Int64) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        preferClearGlass: Bool,
        strings: PresentationStrings,
        location: ChatSideTopicsPanel.Location,
        peerId: EnginePeer.Id,
        kind: ChatSideTopicsPanel.Kind,
        topicId: Int64?,
        controller: @escaping () -> ViewController?,
        togglePanel: @escaping () -> Void,
        updateTopicId: @escaping (Int64?, ChatControllerAnimateInnerChatSwitchDirection) -> Void,
        openDeletePeer: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.strings = strings
        self.location = location
        self.peerId = peerId
        self.kind = kind
        self.topicId = topicId
        self.controller = controller
        self.togglePanel = togglePanel
        self.updateTopicId = updateTopicId
        self.openDeletePeer = openDeletePeer
    }
    
    public static func ==(lhs: ChatFloatingTopicsPanel, rhs: ChatFloatingTopicsPanel) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.preferClearGlass != rhs.preferClearGlass {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.kind != rhs.kind {
            return false
        }
        if lhs.topicId != rhs.topicId {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let containerView: GlassBackgroundContainerView
        
        private var sharedPanelBackgroundView: GlassBackgroundView?
        private var sidePanel: ComponentView<ChatSidePanelEnvironment>?
        private var topPanel: ComponentView<ChatSidePanelEnvironment>?
        
        private var component: ChatFloatingTopicsPanel?
        
        override public init(frame: CGRect) {
            self.containerView = GlassBackgroundContainerView()
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result === self || result === self.containerView.contentView {
                return nil
            }
            return result
        }
        
        func update(component: ChatFloatingTopicsPanel, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChatSidePanelEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ChatSidePanelEnvironment.self].value
            
            var currentPanelBackgroundFrame: CGRect?
            
            if case .side = component.location {
                let sidePanel: ComponentView<ChatSidePanelEnvironment>
                var sidePanelTransition = transition
                if let current = self.sidePanel {
                    sidePanel = current
                } else {
                    sidePanelTransition = sidePanelTransition.withAnimation(.none)
                    sidePanel = ComponentView()
                    self.sidePanel = sidePanel
                }
                let sidePanelSize = sidePanel.update(
                    transition: sidePanelTransition,
                    component: AnyComponent(ChatSideTopicsPanel(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        location: .side,
                        peerId: component.peerId,
                        kind: component.kind,
                        topicId: component.topicId,
                        controller: component.controller,
                        togglePanel: component.togglePanel,
                        updateTopicId: { [weak self] threadId, direction in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateTopicId(threadId, direction ? .down : .up)
                        },
                        openDeletePeer: component.openDeletePeer
                    )),
                    environment: {
                        ChatSidePanelEnvironment(insets: UIEdgeInsets(
                            top: 0.0,
                            left: 0.0,
                            bottom: environment.insets.bottom,
                            right: 0.0
                        ))
                    },
                    containerSize: CGSize(width: 72.0 + 8.0, height: availableSize.height)
                )
                let sidePanelFrame = CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: 16.0 + 80.0, height: availableSize.height - 8.0 - environment.insets.bottom))
                let sidePanelBackgroundFrame = CGRect(origin: CGPoint(x: 16.0, y: 8.0), size: CGSize(width: 80.0, height: availableSize.height - 8.0 - 8.0 - environment.insets.bottom))
                currentPanelBackgroundFrame = sidePanelBackgroundFrame
                if let sidePanelView = sidePanel.view as? ChatSideTopicsPanel.View {
                    if sidePanelView.superview == nil {
                        sidePanelView.layer.cornerRadius = 20.0
                        sidePanelView.clipsToBounds = true
                        self.addSubview(sidePanelView)
                        
                        sidePanelView.frame = CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: sidePanelSize.height, height: 8.0 + 40.0))
                    }
                    transition.setFrame(view: sidePanelView, frame: sidePanelFrame)
                }
            } else if let sidePanel = self.sidePanel {
                self.sidePanel = nil
                if let sidePanelView = sidePanel.view as? ChatSideTopicsPanel.View {
                    sidePanelView.clipsToBounds = true
                    transition.setFrame(view: sidePanelView, frame: CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: sidePanelView.bounds.width, height: 8.0 + 40.0)), completion: { [weak sidePanelView] _ in
                        sidePanelView?.removeFromSuperview()
                    })
                }
            }
            
            if case .top = component.location {
                let topPanel: ComponentView<ChatSidePanelEnvironment>
                var topPanelTransition = transition
                if let current = self.topPanel {
                    topPanel = current
                } else {
                    topPanelTransition = topPanelTransition.withAnimation(.none)
                    topPanel = ComponentView()
                    self.topPanel = topPanel
                }
                let _ = topPanel.update(
                    transition: topPanelTransition,
                    component: AnyComponent(ChatSideTopicsPanel(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        location: .top,
                        peerId: component.peerId,
                        kind: component.kind,
                        topicId: component.topicId,
                        controller: component.controller,
                        togglePanel: component.togglePanel,
                        updateTopicId: { [weak self] threadId, direction in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateTopicId(threadId, direction ? .right : .left)
                        },
                        openDeletePeer: component.openDeletePeer
                    )),
                    environment: {
                        ChatSidePanelEnvironment(insets: UIEdgeInsets(
                            top: 0.0,
                            left: 0.0,
                            bottom: 0.0,
                            right: 0.0
                        ))
                    },
                    containerSize: CGSize(width: availableSize.width - 16.0, height: 8.0 + 40.0)
                )
                let topPanelFrame = CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: availableSize.width - 16.0, height: 8.0 + 40.0))
                let topPanelBackgroundFrame = CGRect(origin: CGPoint(x: 16.0, y: 8.0), size: CGSize(width: availableSize.width - 16.0 - 16.0, height: 40.0))
                currentPanelBackgroundFrame = topPanelBackgroundFrame
                if let topPanelView = topPanel.view as? ChatSideTopicsPanel.View {
                    if topPanelView.superview == nil {
                        topPanelView.clipsToBounds = true
                        topPanelView.layer.cornerRadius = 20.0
                        self.addSubview(topPanelView)
                        topPanelView.frame = CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: 80.0 + 16.0, height: topPanelFrame.height))
                    }
                    transition.setFrame(view: topPanelView, frame: topPanelFrame)
                }
            } else if let topPanel = self.topPanel {
                self.topPanel = nil
                if let topPanelView = topPanel.view as? ChatSideTopicsPanel.View {
                    topPanelView.clipsToBounds = true
                    transition.setFrame(view: topPanelView, frame: CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: 16.0 + 72.0, height: topPanelView.bounds.height)), completion: { [weak topPanelView] _ in
                        topPanelView?.removeFromSuperview()
                    })
                }
            }
            
            if let currentPanelBackgroundFrame {
                let sharedPanelBackgroundView: GlassBackgroundView
                if let current = self.sharedPanelBackgroundView {
                    sharedPanelBackgroundView = current
                } else {
                    sharedPanelBackgroundView = GlassBackgroundView()
                    self.sharedPanelBackgroundView = sharedPanelBackgroundView
                    self.containerView.contentView.insertSubview(sharedPanelBackgroundView, at: 0)
                }
                
                transition.setFrame(view: sharedPanelBackgroundView, frame: currentPanelBackgroundFrame)
                
                let defaultGlassTintColor: GlassBackgroundView.TintColor
                if component.preferClearGlass {
                    defaultGlassTintColor = .init(kind: .clear)
                } else {
                    defaultGlassTintColor = .init(kind: .panel)
                }
                
                sharedPanelBackgroundView.update(size: currentPanelBackgroundFrame.size, cornerRadius: 20.0, isDark: component.theme.overallDarkAppearance, tintColor: defaultGlassTintColor, transition: transition)
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.containerView.update(size: availableSize, isDark: component.theme.overallDarkAppearance, transition: transition)
            
            return availableSize
        }
        
        public func topicIndex(threadId: Int64?) -> Int? {
            if let sidePanelView = self.sidePanel?.view as? ChatSideTopicsPanel.View {
                return sidePanelView.topicIndex(threadId: threadId)
            } else if let topPanelView = self.topPanel?.view as? ChatSideTopicsPanel.View {
                return topPanelView.topicIndex(threadId: threadId)
            } else {
                return nil
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChatSidePanelEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
