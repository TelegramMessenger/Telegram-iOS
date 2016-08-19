import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display

private let backgroundImage = UIImage(bundleImageName: "Chat/Wallpapers/Builtin0")

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
    let inputNode: ChatInputNode
    let navigateToLatestButton: ChatHistoryNavigationButtonNode
    
    private var ignoreUpdateHeight = false
    
    var displayAttachmentMenu: () -> Void = { }
    var setupSendActionOnViewUpdate: (() -> Void) -> Void = { _ in }
    var requestLayout: (Bool) -> Void = { _ in }
    
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
        //self.listView.debugInfo = true
        self.inputNode = ChatInputNode()
        
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
        
        self.addSubnode(self.inputNode)
        
        self.addSubnode(self.navigateToLatestButton)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        self.inputNode.updateHeight = { [weak self] in
            if let strongSelf = self, !strongSelf.ignoreUpdateHeight {
                strongSelf.requestLayout(true)
            }
        }
        
        self.inputNode.sendMessage = { [weak self] in
            if let strongSelf = self {
                if strongSelf.inputNode.textInputNode?.isFirstResponder() ?? false {
                    applyKeyboardAutocorrection()
                }
                let text = strongSelf.inputNode.text
                
                strongSelf.setupSendActionOnViewUpdate({ [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        strongSelf.ignoreUpdateHeight = true
                        strongSelf.inputNode.text = ""
                        strongSelf.ignoreUpdateHeight = false
                    }
                })
                
                let _ = enqueueMessage(account: strongSelf.account, peerId: strongSelf.peerId, text: text).start()
            }
        }
        
        self.inputNode.displayAttachmentMenu = { [weak self] in
            self?.displayAttachmentMenu()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, listViewTransaction: @noescape(ListViewUpdateSizeAndInsets) -> Void) {
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
        
        let messageTextInputSize = self.inputNode.calculateSizeThatFits(CGSize(width: layout.size.width, height: min(layout.size.height / 2.0, 240.0)))
        
        self.backgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listView.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let listViewCurve: ListViewAnimationCurve
        var speedFactor: CGFloat = 1.0
        if curve == 7 {
            speedFactor = CGFloat(duration) / 0.5
            listViewCurve = .Spring(speed: CGFloat(speedFactor))
        } else {
            listViewCurve = .Default
        }
        
        let inputViewFrame = CGRect(x: 0.0, y: layout.size.height - messageTextInputSize.height - insets.bottom, width: layout.size.width, height: messageTextInputSize.height)
        
        listViewTransaction(ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.bottom + inputViewFrame.size.height + 4.0, left: insets.right, bottom: insets.top, right: insets.left), duration: duration, curve: listViewCurve))
        
        let navigateToLatestButtonSize = self.navigateToLatestButton.bounds.size
        let navigateToLatestButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - navigateToLatestButtonSize.width - 6.0, y: inputViewFrame.minY - navigateToLatestButtonSize.height - 6.0), size: navigateToLatestButtonSize)
        
        if duration > DBL_EPSILON {
            UIView.animate(withDuration: duration / Double(speedFactor), delay: 0.0, options: UIViewAnimationOptions(rawValue: curve << 16), animations: {
                self.inputNode.frame = inputViewFrame
                self.navigateToLatestButton.frame = navigateToLatestButtonFrame
            }, completion: nil)
        } else {
            self.inputNode.frame = inputViewFrame
            self.navigateToLatestButton.frame = navigateToLatestButtonFrame
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.view.endEditing(true)
        }
    }
}
