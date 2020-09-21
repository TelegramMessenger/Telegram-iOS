import Foundation
import UIKit
import TelegramCore
import SyncCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import ShareController

final class OverlayAudioPlayerControllerImpl: ViewController, OverlayAudioPlayerController {
    private let context: AccountContext
    let peerId: PeerId
    let type: MediaManagerPlayerType
    let initialMessageId: MessageId
    let initialOrder: MusicPlaybackSettingsOrder
    
    private weak var parentNavigationController: NavigationController?
    
    private var animatedIn = false
    
    private var controllerNode: OverlayAudioPlayerControllerNode {
        return self.displayNode as! OverlayAudioPlayerControllerNode
    }
    
    private var accountInUseDisposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, parentNavigationController: NavigationController?) {
        self.context = context
        self.peerId = peerId
        self.type = type
        self.initialMessageId = initialMessageId
        self.initialOrder = initialOrder
        self.parentNavigationController = parentNavigationController
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.ready.set(.never())
        
        self.accountInUseDisposable = context.sharedContext.setAccountUserInterfaceInUse(context.account.id)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.accountInUseDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayAudioPlayerControllerNode(context: self.context, peerId: self.peerId, type: self.type, initialMessageId: self.initialMessageId, initialOrder: self.initialOrder, requestDismiss: { [weak self] in
            self?.dismiss()
        }, requestShare: { [weak self] messageId in
            if let strongSelf = self {
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                    return transaction.getMessage(messageId)
                } |> deliverOnMainQueue).start(next: { message in
                    if let strongSelf = self, let message = message {
                        let shareController = ShareController(context: strongSelf.context, subject: .messages([message]), showInChat: { message in
                            if let strongSelf = self {
                                strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: message.id.peerId, messageId: message.id)
                                strongSelf.dismiss()
                            }
                        }, externalShare: true)
                        strongSelf.controllerNode.view.endEditing(true)
                        strongSelf.present(shareController, in: .window(.root))
                    }
                })
            }
        })
        
        self.ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
