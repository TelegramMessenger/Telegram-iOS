import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

final class ChatSendMessageActionSheetController: ViewController {
    var controllerNode: ChatSendMessageActionSheetControllerNode {
        return self.displayNode as! ChatSendMessageActionSheetControllerNode
    }
    
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction?
    private let sendButtonFrame: CGRect
    private let textInputNode: EditableTextNode
    
    private var didPlayPresentationAnimation = false
    
    private let hapticFeedback = HapticFeedback()

    init(context: AccountContext, controllerInteraction: ChatControllerInteraction?, sendButtonFrame: CGRect, textInputNode: EditableTextNode) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.sendButtonFrame = sendButtonFrame
        self.textInputNode = textInputNode
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
        self.statusBar.ignoreInCall = true
        
        self.lockOrientation = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatSendMessageActionSheetControllerNode(context: self.context, sendButtonFrame: self.sendButtonFrame, textInputNode: self.textInputNode, send: { [weak self] in
            self?.controllerInteraction?.sendCurrentMessage(false)
            self?.dismiss(cancel: false)
        }, sendSilently: { [weak self] in
            self?.controllerInteraction?.sendCurrentMessage(true)
            self?.dismiss(cancel: false)
        }, cancel: { [weak self] in
            self?.dismiss(cancel: true)
        })
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            
            self.hapticFeedback.impact()
            self.controllerNode.animateIn()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(cancel: true)
    }
    
    private func dismiss(cancel: Bool) {
        self.controllerNode.animateOut(cancel: cancel, completion: { [weak self] in
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
