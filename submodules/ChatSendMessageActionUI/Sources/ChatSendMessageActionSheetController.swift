import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import ChatPresentationInterfaceState
import TextFormat

public final class ChatSendMessageActionSheetController: ViewController {
    private var controllerNode: ChatSendMessageActionSheetControllerNode {
        return self.displayNode as! ChatSendMessageActionSheetControllerNode
    }
    
    private let context: AccountContext
    private let interfaceState: ChatPresentationInterfaceState
    private let gesture: ContextGesture
    private let sourceSendButton: ASDisplayNode
    private let textInputNode: EditableTextNode
    private let attachment: Bool
    private let completion: () -> Void
    private let sendMessage: (Bool) -> Void
    private let schedule: () -> Void
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var didPlayPresentationAnimation = false
    
    private var validLayout: ContainerViewLayout?
    
    private let hapticFeedback = HapticFeedback()
    
    public var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, interfaceState: ChatPresentationInterfaceState, gesture: ContextGesture, sourceSendButton: ASDisplayNode, textInputNode: EditableTextNode, attachment: Bool = false, completion: @escaping () -> Void, sendMessage: @escaping (Bool) -> Void, schedule: @escaping () -> Void) {
        self.context = context
        self.interfaceState = interfaceState
        self.gesture = gesture
        self.sourceSendButton = sourceSendButton
        self.textInputNode = textInputNode
        self.attachment = attachment
        self.completion = completion
        self.sendMessage = sendMessage
        self.schedule = schedule
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updatePresentationData(presentationData)
                }
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
    
    override public func loadDisplayNode() {
        var forwardedCount: Int?
        if let forwardMessageIds = self.interfaceState.interfaceState.forwardMessageIds, forwardMessageIds.count > 0 {
            forwardedCount = forwardMessageIds.count
        }
        
        var reminders = false
        var isSecret = false
        var canSchedule = false
        var hasEntityKeyboard = false
        if let peerId = self.interfaceState.chatLocation.peerId {
            reminders = peerId == context.account.peerId
            isSecret = peerId.namespace == Namespaces.Peer.SecretChat
            canSchedule = !isSecret
        }
        
        if case .media = self.interfaceState.inputMode {
            hasEntityKeyboard = true
        }
        
        self.displayNode = ChatSendMessageActionSheetControllerNode(context: self.context, presentationData: self.presentationData, reminders: reminders, gesture: gesture, sourceSendButton: self.sourceSendButton, textInputNode: self.textInputNode, attachment: self.attachment, forwardedCount: forwardedCount, hasEntityKeyboard: hasEntityKeyboard, emojiViewProvider: self.emojiViewProvider, send: { [weak self] in
            self?.sendMessage(false)
            self?.dismiss(cancel: false)
        }, sendSilently: { [weak self] in
            self?.sendMessage(true)
            self?.dismiss(cancel: false)
        }, schedule: !canSchedule ? nil : { [weak self] in
            self?.schedule()
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
