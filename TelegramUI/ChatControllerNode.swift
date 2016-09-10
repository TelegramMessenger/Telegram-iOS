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

enum ChatMessageViewPosition: Equatable {
    case AroundUnread(count: Int)
    case Around(index: MessageIndex, anchorIndex: MessageIndex)
    case Scroll(index: MessageIndex, anchorIndex: MessageIndex, sourceIndex: MessageIndex, scrollPosition: ListViewScrollPosition)
}

func ==(lhs: ChatMessageViewPosition, rhs: ChatMessageViewPosition) -> Bool {
    switch lhs {
        case let .Around(lhsId, lhsAnchorIndex):
            switch rhs {
                case let .Around(rhsId, rhsAnchorIndex) where lhsId == rhsId && lhsAnchorIndex == rhsAnchorIndex:
                    return true
                default:
                    return false
            }
        case let .Scroll(lhsIndex, lhsAnchorIndex, lhsSourceIndex, lhsScrollPosition):
            switch rhs {
                case let .Scroll(rhsIndex, rhsAnchorIndex, rhsSourceIndex, rhsScrollPosition) where lhsIndex == rhsIndex && lhsAnchorIndex == rhsAnchorIndex && lhsSourceIndex == rhsSourceIndex && lhsScrollPosition == rhsScrollPosition:
                    return true
                default:
                    return false
            }
        case let .AroundUnread(lhsCount):
            switch rhs {
                case let .AroundUnread(rhsCount) where lhsCount == rhsCount:
                    return true
                default:
                    return false
            }
    }
}

class ChatControllerNode: ASDisplayNode {
    let account: Account
    let peerId: PeerId
    
    let backgroundNode: ASDisplayNode
    let listView: ListView
    
    private let inputPanelBackgroundNode: ASDisplayNode
    private let inputPanelBackgroundSeparatorNode: ASDisplayNode
    
    private var inputPanelNode: ChatInputPanelNode?
    private var accessoryPanelNode: AccessoryPanelNode?
    private var inputContextPanelNode: ChatInputContextPanelNode?
    
    private var textInputPanelNode: ChatTextInputPanelNode?
    
    let navigateToLatestButton: ChatHistoryNavigationButtonNode
    
    private var ignoreUpdateHeight = false
    
    var chatPresentationInterfaceState = ChatPresentationInterfaceState()
    
    var requestUpdateChatInterfaceState: (Bool, (ChatInterfaceState) -> ChatInterfaceState) -> Void = { _ in }
    var displayAttachmentMenu: () -> Void = { }
    var setupSendActionOnViewUpdate: (@escaping () -> Void) -> Void = { _ in }
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    init(account: Account, peerId: PeerId) {
        self.account = account
        self.peerId = peerId
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.contentMode = .scaleAspectFill
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.clipsToBounds = true
        
        self.listView = ListView()
        self.listView.preloadPages = false
        
        self.inputPanelBackgroundNode = ASDisplayNode()
        self.inputPanelBackgroundNode.backgroundColor = UIColor(0xfafafa)
        self.inputPanelBackgroundNode.isLayerBacked = true
        
        self.inputPanelBackgroundSeparatorNode = ASDisplayNode()
        self.inputPanelBackgroundSeparatorNode.backgroundColor = UIColor(0xcdccd3)
        self.inputPanelBackgroundSeparatorNode.isLayerBacked = true
        
        self.navigateToLatestButton = ChatHistoryNavigationButtonNode()
        self.navigateToLatestButton.alpha = 0.0
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor(0xdee3e9)
        self.backgroundNode.contents = backgroundImage?.cgImage
        self.addSubnode(self.backgroundNode)
        
        self.listView.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
        self.addSubnode(self.listView)
        
        self.addSubnode(self.inputPanelBackgroundNode)
        self.addSubnode(self.inputPanelBackgroundSeparatorNode)
        
        self.addSubnode(self.navigateToLatestButton)
        
        self.listView.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
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
                let text = textInputPanelNode.text
                
                strongSelf.setupSendActionOnViewUpdate({ [weak strongSelf] in
                    if let strongSelf = strongSelf, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                        strongSelf.ignoreUpdateHeight = true
                        textInputPanelNode.text = ""
                        strongSelf.requestUpdateChatInterfaceState(false, { $0.withUpdatedReplyMessageId(nil) })
                        strongSelf.ignoreUpdateHeight = false
                    }
                })
                
                let _ = enqueueMessage(account: strongSelf.account, peerId: strongSelf.peerId, text: text, replyMessageId: strongSelf.chatPresentationInterfaceState.interfaceState.replyMessageId).start()
            }
        }
        
        self.textInputPanelNode?.displayAttachmentMenu = { [weak self] in
            self?.displayAttachmentMenu()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, listViewTransaction: (ListViewUpdateSizeAndInsets) -> Void) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listView.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
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
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listView.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        //let inputViewFrame = CGRect(x: 0.0, y: layout.size.height - messageTextInputSize.height - insets.bottom, width: layout.size.width, height: messageTextInputSize.height)
        
        var dismissedInputPanelNode: ASDisplayNode?
        var dismissedAccessoryPanelNode: ASDisplayNode?
        var dismissedInputContextPanelNode: ChatInputContextPanelNode?
        
        var inputPanelSize: CGSize?
        var immediatelyLayoutInputPanelAndAnimateAppearance = false
        if let inputPanelNode = inputPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputPanelNode, textInputPanelNode: self.textInputPanelNode, interfaceInteraction: self.interfaceInteraction) {
            inputPanelSize = inputPanelNode.measure(CGSize(width: layout.size.width, height: layout.size.height))
            
            if inputPanelNode !== self.inputPanelNode {
                if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                    inputTextPanelNode.ensureUnfocused()
                }
                dismissedInputPanelNode = self.inputPanelNode
                immediatelyLayoutInputPanelAndAnimateAppearance = true
                self.inputPanelNode = inputPanelNode
                self.insertSubnode(inputPanelNode, belowSubnode: self.navigateToLatestButton)
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
                        strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedReplyMessageId(nil) })
                    }
                }
                
                immediatelyLayoutAccessoryPanelAndAnimateAppearance = true
                accessoryPanelNode.insets = UIEdgeInsets(top: 0.0, left: 45.0, bottom: 0.0, right: 54.0)
            }
        } else if let accessoryPanelNode = self.accessoryPanelNode {
            dismissedAccessoryPanelNode = self.accessoryPanelNode
            self.accessoryPanelNode = nil
        }
        
        var immediatelyLayoutInputContextPanelAndAnimateAppearance = false
        if let inputContextPanelNode = inputContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputContextPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if inputContextPanelNode !== self.inputContextPanelNode {
                dismissedInputContextPanelNode = self.inputContextPanelNode
                self.inputContextPanelNode = inputContextPanelNode
                
                self.insertSubnode(inputContextPanelNode, aboveSubnode: self.navigateToLatestButton)
                immediatelyLayoutInputContextPanelAndAnimateAppearance = true
                
            }
        } else if let inputContextPanelNode = self.inputContextPanelNode {
            dismissedInputContextPanelNode = inputContextPanelNode
            self.inputContextPanelNode = nil
        }
        
        var inputPanelsHeight: CGFloat = 0.0
        
        var inputPanelFrame: CGRect?
        if let inputPanelNode = self.inputPanelNode {
            assert(inputPanelSize != nil)
            inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - inputPanelSize!.height), size: CGSize(width: layout.size.width, height: inputPanelSize!.height))
            inputPanelsHeight += inputPanelSize!.height
        }
        
        var accessoryPanelFrame: CGRect?
        if let accessoryPanelNode = self.accessoryPanelNode {
            assert(accessoryPanelSize != nil)
            accessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - accessoryPanelSize!.height), size: CGSize(width: layout.size.width, height: accessoryPanelSize!.height))
            inputPanelsHeight += accessoryPanelSize!.height
        }
        
        let inputBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight), size: CGSize(width: layout.size.width, height: inputPanelsHeight))
        
        listViewTransaction(ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.bottom + inputPanelsHeight + 4.0, left: insets.right, bottom: insets.top, right: insets.left), duration: duration, curve: listViewCurve))
        
        let navigateToLatestButtonSize = self.navigateToLatestButton.bounds.size
        let navigateToLatestButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - navigateToLatestButtonSize.width - 6.0, y: layout.size.height - insets.bottom - inputPanelsHeight - navigateToLatestButtonSize.height - 6.0), size: navigateToLatestButtonSize)
        
        transition.updateFrame(node: self.inputPanelBackgroundNode, frame: inputBackgroundFrame)
        transition.updateFrame(node: self.inputPanelBackgroundSeparatorNode, frame: CGRect(origin: inputBackgroundFrame.origin, size: CGSize(width: inputBackgroundFrame.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.navigateToLatestButton, frame: navigateToLatestButtonFrame)
        
        if let inputPanelNode = self.inputPanelNode, let inputPanelFrame = inputPanelFrame, !inputPanelNode.frame.equalTo(inputPanelFrame) {
            if immediatelyLayoutInputPanelAndAnimateAppearance {
                inputPanelNode.frame = inputPanelFrame.offsetBy(dx: 0.0, dy: inputPanelFrame.size.height)
                inputPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: inputPanelNode, frame: inputPanelFrame)
            transition.updateAlpha(node: inputPanelNode, alpha: 1.0)
            inputPanelNode.updateFrames(transition: transition)
        }
        
        if let accessoryPanelNode = self.accessoryPanelNode, let accessoryPanelFrame = accessoryPanelFrame, !accessoryPanelNode.frame.equalTo(accessoryPanelFrame) {
            if immediatelyLayoutAccessoryPanelAndAnimateAppearance {
                accessoryPanelNode.frame = accessoryPanelFrame.offsetBy(dx: 0.0, dy: accessoryPanelFrame.size.height)
                accessoryPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: accessoryPanelNode, frame: accessoryPanelFrame)
            transition.updateAlpha(node: accessoryPanelNode, alpha: 1.0)
        }
        
        let inputContextPanelsFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - inputPanelsHeight - insets.top)))
        
        if let inputContextPanelNode = self.inputContextPanelNode {
            if immediatelyLayoutInputContextPanelAndAnimateAppearance {
                inputContextPanelNode.frame = inputContextPanelsFrame
                inputContextPanelNode.updateFrames(transition: .immediate)
                inputContextPanelNode.animateIn()
            } else if !inputContextPanelNode.frame.equalTo(inputContextPanelsFrame) {
                transition.updateFrame(node: inputContextPanelNode, frame: inputContextPanelsFrame)
                inputContextPanelNode.updateFrames(transition: transition)
            }
        }
        
        if let dismissedInputPanelNode = dismissedInputPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            var completed = { [weak self, weak dismissedInputPanelNode] in
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
            var completed = { [weak dismissedAccessoryPanelNode] in
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
            var completed = { [weak dismissedInputContextPanelNode] in
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
    }
    
    func updateChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, animated: Bool) {
        if let textInputPanelNode = self.textInputPanelNode {
            self.chatPresentationInterfaceState = self.chatPresentationInterfaceState.updatedInterfaceState { $0.withUpdatedInputState(textInputPanelNode.inputTextState) }
        }
        
        if self.chatPresentationInterfaceState != chatPresentationInterfaceState {
            var updateInputTextState = self.chatPresentationInterfaceState.interfaceState.inputState != chatPresentationInterfaceState.interfaceState.inputState
            self.chatPresentationInterfaceState = chatPresentationInterfaceState
            
            if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
                textInputPanelNode.inputTextState = chatPresentationInterfaceState.interfaceState.inputState
            }
            
            if !self.ignoreUpdateHeight {
                self.requestLayout(animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
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
            self.view.endEditing(true)
        }
    }
}
