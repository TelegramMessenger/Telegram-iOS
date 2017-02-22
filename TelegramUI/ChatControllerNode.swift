import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private let backgroundImage = UIImage(bundleImageName: "Chat/Wallpapers/Builtin0")

private func shouldRequestLayoutOnPresentationInterfaceStateTransition(_ lhs: ChatPresentationInterfaceState, _ rhs: ChatPresentationInterfaceState) -> Bool {
    
    return false
}

class ChatControllerNode: ASDisplayNode {
    let account: Account
    let peerId: PeerId
    let controllerInteraction: ChatControllerInteraction
    
    let backgroundNode: ASDisplayNode
    let historyNode: ChatHistoryListNode
    
    private let inputPanelBackgroundNode: ASDisplayNode
    private let inputPanelBackgroundSeparatorNode: ASDisplayNode
    
    private let titleAccessoryPanelContainer: ChatControllerTitlePanelNodeContainer
    private var titleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
    
    private var inputPanelNode: ChatInputPanelNode?
    private var accessoryPanelNode: AccessoryPanelNode?
    private var inputContextPanelNode: ChatInputContextPanelNode?
    
    private var inputNode: ChatInputNode?
    
    private var textInputPanelNode: ChatTextInputPanelNode?
    private var inputMediaNode: ChatMediaInputNode?
    
    let navigateToLatestButton: ChatHistoryNavigationButtonNode
    
    private var ignoreUpdateHeight = false
    
    var chatPresentationInterfaceState = ChatPresentationInterfaceState()
    
    var requestUpdateChatInterfaceState: (Bool, (ChatInterfaceState) -> ChatInterfaceState) -> Void = { _ in }
    var displayAttachmentMenu: () -> Void = { }
    var setupSendActionOnViewUpdate: (@escaping () -> Void) -> Void = { _ in }
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private var containerLayoutAndNavigationBarHeight: (ContainerViewLayout, CGFloat)?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    init(account: Account, peerId: PeerId, messageId: MessageId?, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.contentMode = .scaleAspectFill
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.clipsToBounds = true
        
        self.titleAccessoryPanelContainer = ChatControllerTitlePanelNodeContainer()
        self.titleAccessoryPanelContainer.clipsToBounds = true
        
        self.historyNode = ChatHistoryListNode(account: account, peerId: peerId, tagMask: nil, messageId: messageId, controllerInteraction: controllerInteraction)
        
        self.inputPanelBackgroundNode = ASDisplayNode()
        self.inputPanelBackgroundNode.backgroundColor = UIColor(0xF5F6F8)
        self.inputPanelBackgroundNode.isLayerBacked = true
        
        self.inputPanelBackgroundSeparatorNode = ASDisplayNode()
        self.inputPanelBackgroundSeparatorNode.backgroundColor = UIColor(0xC9CDD1)
        self.inputPanelBackgroundSeparatorNode.isLayerBacked = true
        
        self.navigateToLatestButton = ChatHistoryNavigationButtonNode()
        self.navigateToLatestButton.alpha = 0.0
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor(0xdee3e9)
        self.backgroundNode.contents = backgroundImage?.cgImage
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.historyNode)
        
        self.addSubnode(self.titleAccessoryPanelContainer)
        
        self.addSubnode(self.inputPanelBackgroundNode)
        self.addSubnode(self.inputPanelBackgroundSeparatorNode)
        
        self.addSubnode(self.navigateToLatestButton)
        
        self.historyNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        self.textInputPanelNode = ChatTextInputPanelNode()
        self.textInputPanelNode?.updateHeight = { [weak self] in
            if let strongSelf = self, let _ = strongSelf.inputPanelNode as? ChatTextInputPanelNode, !strongSelf.ignoreUpdateHeight {
                strongSelf.requestLayout(.animated(duration: 0.1, curve: .easeInOut))
            }
        }
        self.textInputPanelNode?.sendMessage = { [weak self] in
            if let strongSelf = self, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                if textInputPanelNode.textInputNode?.isFirstResponder() ?? false {
                    applyKeyboardAutocorrection()
                }
                
                var effectivePresentationInterfaceState = strongSelf.chatPresentationInterfaceState
                if let textInputPanelNode = strongSelf.textInputPanelNode {
                    effectivePresentationInterfaceState = effectivePresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
                }
                
                if let editMessage = effectivePresentationInterfaceState.interfaceState.editMessage {
                    let text = editMessage.inputState.inputText
                    
                    if let interfaceInteraction = strongSelf.interfaceInteraction, !text.isEmpty {
                        interfaceInteraction.editMessage(editMessage.messageId, editMessage.inputState.inputText)
                    }
                } else {
                    let text = effectivePresentationInterfaceState.interfaceState.composeInputState.inputText
                    
                    if !text.isEmpty || strongSelf.chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil {
                        strongSelf.setupSendActionOnViewUpdate({ [weak strongSelf] in
                            if let strongSelf = strongSelf, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                                strongSelf.ignoreUpdateHeight = true
                                textInputPanelNode.text = ""
                                strongSelf.requestUpdateChatInterfaceState(false, { $0.withUpdatedReplyMessageId(nil).withUpdatedForwardMessageIds(nil) })
                                strongSelf.ignoreUpdateHeight = false
                            }
                        })
                        
                        var messages: [EnqueueMessage] = []
                        if !text.isEmpty {
                            var attributes: [MessageAttribute] = []
                            let entities = generateTextEntities(text)
                            if !entities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: entities))
                            }
                            messages.append(.message(text: text, attributes: attributes, media: nil, replyToMessageId: strongSelf.chatPresentationInterfaceState.interfaceState.replyMessageId))
                        }
                        if let forwardMessageIds = strongSelf.chatPresentationInterfaceState.interfaceState.forwardMessageIds {
                            for id in forwardMessageIds {
                                messages.append(.forward(source: id))
                            }
                        }
                        
                        let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: messages).start()
                    }
                }
            }
        }
        
        self.textInputPanelNode?.displayAttachmentMenu = { [weak self] in
            self?.displayAttachmentMenu()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, listViewTransaction: (ListViewUpdateSizeAndInsets) -> Void) {
        self.scheduledLayoutTransitionRequest = nil
        var previousInputHeight: CGFloat = 0.0
        if let (previousLayout, _) = self.containerLayoutAndNavigationBarHeight {
            previousInputHeight = previousLayout.insets(options: [.input]).bottom
        }
        if let inputNode = self.inputNode {
            previousInputHeight = inputNode.bounds.size.height
        }
        var previousInputPanelOrigin = CGPoint(x: 0.0, y: layout.size.height - previousInputHeight)
        if let inputPanelNode = self.inputPanelNode {
            previousInputPanelOrigin.y -= inputPanelNode.bounds.size.height
        }
        self.containerLayoutAndNavigationBarHeight = (layout, navigationBarHeight)
        
        var dismissedTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
        var immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = false
        if let titleAccessoryPanelNode = titlePanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.titleAccessoryPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if self.titleAccessoryPanelNode != titleAccessoryPanelNode {
                 dismissedTitleAccessoryPanelNode = self.titleAccessoryPanelNode
                self.titleAccessoryPanelNode = titleAccessoryPanelNode
                immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = true
                self.titleAccessoryPanelContainer.addSubnode(titleAccessoryPanelNode)
            }
        } else if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            dismissedTitleAccessoryPanelNode = titleAccessoryPanelNode
            self.titleAccessoryPanelNode = nil
        }
        
        var dismissedInputNode: ChatInputNode?
        var immediatelyLayoutInputNodeAndAnimateAppearance = false
        var inputNodeHeight: CGFloat?
        if let inputNode = inputNodeForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentNode: self.inputNode, interfaceInteraction: self.interfaceInteraction, inputMediaNode: self.inputMediaNode, controllerInteraction: self.controllerInteraction) {
            if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                inputTextPanelNode.ensureUnfocused()
            }
            if let inputMediaNode = inputNode as? ChatMediaInputNode, self.inputMediaNode == nil {
                self.inputMediaNode = inputMediaNode
            }
            if self.inputNode != inputNode {
                dismissedInputNode = self.inputNode
                self.inputNode = inputNode
                immediatelyLayoutInputNodeAndAnimateAppearance = true
                self.insertSubnode(inputNode, belowSubnode: self.inputPanelBackgroundNode)
            }
            inputNodeHeight = inputNode.updateLayout(width: layout.size.width, transition: immediatelyLayoutInputNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
        } else if let inputNode = self.inputNode {
            dismissedInputNode = inputNode
            self.inputNode = nil
        }
        
        if let inputMediaNode = self.inputMediaNode, inputMediaNode != self.inputNode {
            let _ = inputMediaNode.updateLayout(width: layout.size.width, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
        }
        
        var insets: UIEdgeInsets
        if let inputNodeHeight = inputNodeHeight {
            insets = layout.insets(options: [])
            insets.bottom += inputNodeHeight
        } else {
            insets = layout.insets(options: [.input])
        }
        insets.top += navigationBarHeight
        
        transition.updateFrame(node: self.titleAccessoryPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: 44.0)))
        
        var titleAccessoryPanelFrame: CGRect?
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            let panelHeight = titleAccessoryPanelNode.updateLayout(width: layout.size.width, transition: immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
            titleAccessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
        }
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        self.backgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        self.historyNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.historyNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        var dismissedInputPanelNode: ASDisplayNode?
        var dismissedAccessoryPanelNode: ASDisplayNode?
        var dismissedInputContextPanelNode: ChatInputContextPanelNode?
        
        var inputPanelSize: CGSize?
        var immediatelyLayoutInputPanelAndAnimateAppearance = false
        if let inputPanelNode = inputPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputPanelNode, textInputPanelNode: self.textInputPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if inputPanelNode !== self.inputPanelNode {
                if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                    inputTextPanelNode.ensureUnfocused()
                }
                dismissedInputPanelNode = self.inputPanelNode
                immediatelyLayoutInputPanelAndAnimateAppearance = true
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
                self.inputPanelNode = inputPanelNode
                self.insertSubnode(inputPanelNode, belowSubnode: self.navigateToLatestButton)
            } else {
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, transition: transition, interfaceState: self.chatPresentationInterfaceState)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
            }
        } else {
            dismissedInputPanelNode = self.inputPanelNode
            self.inputPanelNode = nil
        }
        
        var accessoryPanelSize: CGSize?
        var immediatelyLayoutAccessoryPanelAndAnimateAppearance = false
        if let accessoryPanelNode = accessoryPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.accessoryPanelNode, interfaceInteraction: self.interfaceInteraction) {
            accessoryPanelSize = accessoryPanelNode.measure(CGSize(width: layout.size.width, height: layout.size.height))
            
            if accessoryPanelNode !== self.accessoryPanelNode {
                dismissedAccessoryPanelNode = self.accessoryPanelNode
                self.accessoryPanelNode = accessoryPanelNode
                
                if let inputPanelNode = self.inputPanelNode {
                    self.insertSubnode(accessoryPanelNode, belowSubnode: inputPanelNode)
                } else {
                    self.insertSubnode(accessoryPanelNode, belowSubnode: self.navigateToLatestButton)
                }
                
                accessoryPanelNode.dismiss = { [weak self, weak accessoryPanelNode] in
                    if let strongSelf = self, let accessoryPanelNode = accessoryPanelNode, strongSelf.accessoryPanelNode === accessoryPanelNode {
                        if let _ = accessoryPanelNode as? ReplyAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedReplyMessageId(nil) })
                        } else if let _ = accessoryPanelNode as? ForwardAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedForwardMessageIds(nil) })
                        } else if let _ = accessoryPanelNode as? EditAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedEditMessage(nil) })
                        }
                    }
                }
                
                immediatelyLayoutAccessoryPanelAndAnimateAppearance = true
            }
        } else if let accessoryPanelNode = self.accessoryPanelNode {
            dismissedAccessoryPanelNode = accessoryPanelNode
            self.accessoryPanelNode = nil
        }
        
        var immediatelyLayoutInputContextPanelAndAnimateAppearance = false
        if let inputContextPanelNode = inputContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputContextPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if inputContextPanelNode !== self.inputContextPanelNode {
                dismissedInputContextPanelNode = self.inputContextPanelNode
                self.inputContextPanelNode = inputContextPanelNode
                
                self.addSubnode(inputContextPanelNode)
                immediatelyLayoutInputContextPanelAndAnimateAppearance = true
                
            }
        } else if let inputContextPanelNode = self.inputContextPanelNode {
            dismissedInputContextPanelNode = inputContextPanelNode
            self.inputContextPanelNode = nil
        }
        
        var inputPanelsHeight: CGFloat = 0.0
        
        var inputPanelFrame: CGRect?
        if self.inputPanelNode != nil {
            assert(inputPanelSize != nil)
            inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - inputPanelSize!.height), size: CGSize(width: layout.size.width, height: inputPanelSize!.height))
            inputPanelsHeight += inputPanelSize!.height
        }
        
        var accessoryPanelFrame: CGRect?
        if self.accessoryPanelNode != nil {
            assert(accessoryPanelSize != nil)
            accessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - accessoryPanelSize!.height), size: CGSize(width: layout.size.width, height: accessoryPanelSize!.height))
            inputPanelsHeight += accessoryPanelSize!.height
        }
        
        let inputBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight), size: CGSize(width: layout.size.width, height: inputPanelsHeight))
        
        listViewTransaction(ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.bottom + inputPanelsHeight + 4.0, left: insets.right, bottom: insets.top, right: insets.left), duration: duration, curve: listViewCurve))
        
        let navigateToLatestButtonSize = self.navigateToLatestButton.bounds.size
        let navigateToLatestButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - navigateToLatestButtonSize.width - 6.0, y: layout.size.height - insets.bottom - inputPanelsHeight - navigateToLatestButtonSize.height - 6.0), size: navigateToLatestButtonSize)
        
        transition.updateFrame(node: self.inputPanelBackgroundNode, frame: inputBackgroundFrame)
        transition.updateFrame(node: self.inputPanelBackgroundSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: inputBackgroundFrame.origin.y - UIScreenPixel), size: CGSize(width: inputBackgroundFrame.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.navigateToLatestButton, frame: navigateToLatestButtonFrame)
        
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode, let titleAccessoryPanelFrame = titleAccessoryPanelFrame, !titleAccessoryPanelNode.frame.equalTo(titleAccessoryPanelFrame) {
            if immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance {
                titleAccessoryPanelNode.frame = titleAccessoryPanelFrame.offsetBy(dx: 0.0, dy: -titleAccessoryPanelFrame.size.height)
            }
            transition.updateFrame(node: titleAccessoryPanelNode, frame: titleAccessoryPanelFrame)
        }
        
        if let inputPanelNode = self.inputPanelNode, let inputPanelFrame = inputPanelFrame, !inputPanelNode.frame.equalTo(inputPanelFrame) {
            if immediatelyLayoutInputPanelAndAnimateAppearance {
                inputPanelNode.frame = inputPanelFrame.offsetBy(dx: 0.0, dy: inputPanelFrame.size.height)
                inputPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: inputPanelNode, frame: inputPanelFrame)
            transition.updateAlpha(node: inputPanelNode, alpha: 1.0)
        }
        
        if let accessoryPanelNode = self.accessoryPanelNode, let accessoryPanelFrame = accessoryPanelFrame, !accessoryPanelNode.frame.equalTo(accessoryPanelFrame) {
            if immediatelyLayoutAccessoryPanelAndAnimateAppearance {
                var startAccessoryPanelFrame = accessoryPanelFrame
                startAccessoryPanelFrame.origin.y = previousInputPanelOrigin.y
                accessoryPanelNode.frame = startAccessoryPanelFrame
                accessoryPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: accessoryPanelNode, frame: accessoryPanelFrame)
            transition.updateAlpha(node: accessoryPanelNode, alpha: 1.0)
        }
        
        let inputContextPanelsFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - inputPanelsHeight - insets.top - UIScreenPixel)))
        
        if let inputContextPanelNode = self.inputContextPanelNode {
            if immediatelyLayoutInputContextPanelAndAnimateAppearance {
                inputContextPanelNode.frame = inputContextPanelsFrame
                inputContextPanelNode.updateLayout(size: inputContextPanelsFrame.size, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            } else if !inputContextPanelNode.frame.equalTo(inputContextPanelsFrame) {
                transition.updateFrame(node: inputContextPanelNode, frame: inputContextPanelsFrame)
                inputContextPanelNode.updateLayout(size: inputContextPanelsFrame.size, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            }
        }
        
        if let inputNode = self.inputNode, let inputNodeHeight = inputNodeHeight {
            let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - inputNodeHeight), size: CGSize(width: layout.size.width, height: inputNodeHeight))
            if immediatelyLayoutInputNodeAndAnimateAppearance {
                var adjustedForPreviousInputHeightFrame = inputNodeFrame
                let heightDifference = inputNodeHeight - previousInputHeight
                adjustedForPreviousInputHeightFrame.origin.y += heightDifference
                inputNode.frame = adjustedForPreviousInputHeightFrame
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
            } else {
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
            }
        }
        
        if let dismissedTitleAccessoryPanelNode = dismissedTitleAccessoryPanelNode {
            var dismissedPanelFrame = dismissedTitleAccessoryPanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateFrame(node: dismissedTitleAccessoryPanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedTitleAccessoryPanelNode] _ in
                dismissedTitleAccessoryPanelNode?.removeFromSupernode()
            })
        }
        
        if let dismissedInputPanelNode = dismissedInputPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak self, weak dismissedInputPanelNode] in
                if let strongSelf = self, let dismissedInputPanelNode = dismissedInputPanelNode, strongSelf.inputPanelNode === dismissedInputPanelNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedInputPanelNode?.removeFromSupernode()
                }
            }
            let transitionTargetY = layout.size.height - insets.bottom
            transition.updateFrame(node: dismissedInputPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedInputPanelNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedInputPanelNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
        }
        
        if let dismissedAccessoryPanelNode = dismissedAccessoryPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak dismissedAccessoryPanelNode] in
                if frameCompleted && alphaCompleted {
                    dismissedAccessoryPanelNode?.removeFromSupernode()
                }
            }
            var transitionTargetY = layout.size.height - insets.bottom
            if let inputPanelFrame = inputPanelFrame {
                transitionTargetY = inputPanelFrame.minY
            }
            transition.updateFrame(node: dismissedAccessoryPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedAccessoryPanelNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedAccessoryPanelNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
        }
        
        if let dismissedInputContextPanelNode = dismissedInputContextPanelNode {
            var frameCompleted = false
            var animationCompleted = false
            let completed = { [weak dismissedInputContextPanelNode] in
                if let dismissedInputContextPanelNode = dismissedInputContextPanelNode, frameCompleted, animationCompleted {
                    dismissedInputContextPanelNode.removeFromSupernode()
                }
            }
            if !dismissedInputContextPanelNode.frame.equalTo(inputContextPanelsFrame) {
                transition.updateFrame(node: dismissedInputContextPanelNode, frame: inputContextPanelsFrame, completion: { _ in
                    frameCompleted = true
                    completed()
                })
            } else {
                frameCompleted = true
            }
            
            dismissedInputContextPanelNode.animateOut(completion: {
                animationCompleted = true
                completed()
            })
        }
        
        if let dismissedInputNode = dismissedInputNode {
            transition.updateFrame(node: dismissedInputNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - CGFloat(FLT_EPSILON)), size: CGSize(width: layout.size.width, height: max(insets.bottom, dismissedInputNode.bounds.size.height))), completion: { [weak self, weak dismissedInputNode] completed in
                if completed {
                    if let strongSelf = self {
                        if strongSelf.inputNode !== dismissedInputNode {
                            dismissedInputNode?.removeFromSupernode()
                        }
                    } else {
                        dismissedInputNode?.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    private func chatPresentationInterfaceStateRequiresInputFocus(_ state: ChatPresentationInterfaceState) -> Bool {
        switch state.inputMode {
            case .text:
                if state.interfaceState.selectionState != nil {
                    return false
                } else {
                    return true
                }
            default:
                return false
        }
    }
    
    func updateChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, animated: Bool, interactive: Bool) {
        if let textInputPanelNode = self.textInputPanelNode {
            self.chatPresentationInterfaceState = self.chatPresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
        }
        
        if self.chatPresentationInterfaceState != chatPresentationInterfaceState {
            let updatedInputFocus = self.chatPresentationInterfaceStateRequiresInputFocus(self.chatPresentationInterfaceState) != self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState)
            let updateInputTextState = self.chatPresentationInterfaceState.interfaceState.effectiveInputState != chatPresentationInterfaceState.interfaceState.effectiveInputState
            self.chatPresentationInterfaceState = chatPresentationInterfaceState
            
            let keepSendButtonEnabled = chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil || chatPresentationInterfaceState.interfaceState.editMessage != nil
            var extendedSearchLayout = false
            if let inputQueryResult = chatPresentationInterfaceState.inputQueryResult {
                if case .contextRequestResult = inputQueryResult {
                    extendedSearchLayout = true
                }
            }
            
            if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
                textInputPanelNode.updateInputTextState(chatPresentationInterfaceState.interfaceState.effectiveInputState, keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, animated: animated)
            } else {
                textInputPanelNode?.updateKeepSendButtonEnabled(keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, animated: animated)
            }
            
            let layoutTransition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
            
            if updatedInputFocus {
                if !self.ignoreUpdateHeight {
                    self.scheduleLayoutTransitionRequest(layoutTransition)
                }
                
                if self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState) {
                    self.ensureInputViewFocused()
                } else {
                    if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                        inputTextPanelNode.ensureUnfocused()
                    }
                }
            } else {
                if !self.ignoreUpdateHeight {
                    if interactive {
                        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
                            switch scheduledLayoutTransitionRequest.1 {
                                case .immediate:
                                    self.scheduleLayoutTransitionRequest(layoutTransition)
                                default:
                                    break
                            }
                        } else {
                            self.scheduleLayoutTransitionRequest(layoutTransition)
                        }
                    } else {
                        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
                            switch scheduledLayoutTransitionRequest.1 {
                                case .immediate:
                                    self.requestLayout(layoutTransition)
                                case .animated:
                                    self.scheduleLayoutTransitionRequest(scheduledLayoutTransitionRequest.1)
                            }
                        } else {
                            self.requestLayout(layoutTransition)
                        }
                    }
                }
            }
        }
    }
    
    func ensureInputViewFocused() {
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            inputPanelNode.ensureFocused()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.dismissInput()
        }
    }
    
    func dismissInput() {
        switch self.chatPresentationInterfaceState.inputMode {
            case .none:
                break
            default:
                self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                    return (.none, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                })
        }
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(currentRequestTransition)
                }
            }
        })
        self.setNeedsLayout()
    }
    
    func loadInputPanels() {
        if self.inputMediaNode == nil {
            let inputNode = ChatMediaInputNode(account: self.account, controllerInteraction: self.controllerInteraction)
            inputNode.interfaceInteraction = interfaceInteraction
            self.inputMediaNode = inputNode
            let _ = inputNode.updateLayout(width: self.bounds.size.width, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
        }
    }
}
