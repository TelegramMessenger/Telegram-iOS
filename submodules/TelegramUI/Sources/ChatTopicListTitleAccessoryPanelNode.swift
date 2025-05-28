import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import TelegramCore
import Postbox
import EmojiStatusComponent
import SwiftSignalKit
import BundleIconComponent
import AvatarNode
import TextBadgeComponent
import ChatSideTopicsPanel
import ComponentDisplayAdapters

final class ChatTopicListTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, ChatControllerCustomNavigationPanelNode {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var interfaceState: ChatPresentationInterfaceState
        
        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.interfaceState = interfaceState
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.width != rhs.width {
                return false
            }
            if lhs.leftInset != rhs.leftInset {
                return false
            }
            if lhs.rightInset != rhs.rightInset {
                return false
            }
            if lhs.interfaceState != rhs.interfaceState {
                return false
            }
            return true
        }
    }
    
    private var params: Params?
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let isMonoforum: Bool
    private let panel = ComponentView<ChatSidePanelEnvironment>()
    
    init(context: AccountContext, peerId: EnginePeer.Id, isMonoforum: Bool) {
        self.context = context
        self.peerId = peerId
        self.isMonoforum = isMonoforum
        
        super.init()
        
        
    }
    
    deinit {
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            self.update(params: params, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, interfaceState: interfaceState)
        if self.params != params {
            self.params = params
            self.update(params: params, transition: transition)
        }
        
        let panelHeight: CGFloat = 44.0
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, chatController: ChatController) -> LayoutResult {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, transition: transition, interfaceState: (chatController as! ChatControllerImpl).presentationInterfaceState)
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        let panelHeight: CGFloat = 44.0
        
        let panelFrame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: panelHeight))
        let _ = self.panel.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(ChatSideTopicsPanel(
                context: self.context,
                theme: params.interfaceState.theme,
                strings: params.interfaceState.strings,
                location: .top,
                peerId: self.peerId,
                isMonoforum: self.isMonoforum,
                topicId: params.interfaceState.chatLocation.threadId,
                controller: { [weak self] in
                    return self?.interfaceInteraction?.chatController()
                },
                togglePanel: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak self] topicId, direction in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.updateChatLocationThread(topicId, direction ? .right : .left)
                }
            )),
            environment: {
                ChatSidePanelEnvironment(insets: UIEdgeInsets(
                    top: 0.0,
                    left: params.leftInset,
                    bottom: 0.0,
                    right: params.rightInset
                ))
            },
            containerSize: panelFrame.size
        )
        if let panelView = self.panel.view {
            if panelView.superview == nil {
                panelView.disablesInteractiveTransitionGestureRecognizer = true
                self.view.addSubview(panelView)
            }
            transition.updateFrame(view: panelView, frame: panelFrame)
        }
    }

    public func updateGlobalOffset(globalOffset: CGFloat, transition: ComponentTransition) {
        if let panelView = self.panel.view as? ChatSideTopicsPanel.View {
            panelView.updateGlobalOffset(globalOffset: globalOffset, transition: transition)
        }
    }
    
    public func topicIndex(threadId: Int64?) -> Int? {
        if let panelView = self.panel.view as? ChatSideTopicsPanel.View {
            return panelView.topicIndex(threadId: threadId)
        } else {
            return nil
        }
    }
}
