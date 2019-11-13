import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI

final class ChatSendMessageActionSheetController: ViewController {
    var controllerNode: ChatSendMessageActionSheetControllerNode {
        return self.displayNode as! ChatSendMessageActionSheetControllerNode
    }
    
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction?
    private let interfaceState: ChatPresentationInterfaceState
    private let gesture: ContextGesture
    private let sendButtonFrame: CGRect
    private let textInputNode: EditableTextNode
    private let completion: () -> Void
    
    private var presentationDataDisposable: Disposable?
    
    private var didPlayPresentationAnimation = false
    
    private var validLayout: ContainerViewLayout?
    
    private let hapticFeedback = HapticFeedback()

    init(context: AccountContext, controllerInteraction: ChatControllerInteraction?, interfaceState: ChatPresentationInterfaceState, gesture: ContextGesture, sendButtonFrame: CGRect, textInputNode: EditableTextNode, completion: @escaping () -> Void) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.interfaceState = interfaceState
        self.gesture = gesture
        self.sendButtonFrame = sendButtonFrame
        self.textInputNode = textInputNode
        self.completion = completion
                
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Hide
        self.statusBar.ignoreInCall = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override func loadDisplayNode() {
        var forwardedCount = 0
        if let forwardMessageIds = self.interfaceState.interfaceState.forwardMessageIds {
            forwardedCount = forwardMessageIds.count
        }
        
        var reminders = false
        if case let .peer(peerId) = self.interfaceState.chatLocation, peerId == context.account.peerId {
            reminders = true
        }
        
        self.displayNode = ChatSendMessageActionSheetControllerNode(context: self.context, reminders: reminders, gesture: gesture, sendButtonFrame: self.sendButtonFrame, textInputNode: self.textInputNode, forwardedCount: forwardedCount, send: { [weak self] in
            self?.controllerInteraction?.sendCurrentMessage(false)
            self?.dismiss(cancel: false)
        }, sendSilently: { [weak self] in
            self?.controllerInteraction?.sendCurrentMessage(true)
            self?.dismiss(cancel: false)
        }, schedule: { [weak self] in
            self?.controllerInteraction?.scheduleCurrentMessage()
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
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(cancel: true)
    }
    
    private func dismiss(cancel: Bool) {
        self.statusBar.statusBarStyle = .Ignore
        self.controllerNode.animateOut(cancel: cancel, completion: { [weak self] in
            self?.completion()
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
