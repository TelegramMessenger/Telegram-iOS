import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import PeerInfoUI

public final class JoinLinkPreviewController: ViewController {
    private var controllerNode: JoinLinkPreviewControllerNode {
        return self.displayNode as! JoinLinkPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let link: String
    private let navigateToPeer: (PeerId) -> Void
    private let parentNavigationController: NavigationController?
    private var resolvedState: ExternalJoiningChatState?
    private var presentationData: PresentationData
    
    private let disposable = MetaDisposable()
    
    public init(context: AccountContext, link: String, navigateToPeer: @escaping (PeerId) -> Void, parentNavigationController: NavigationController?, resolvedState: ExternalJoiningChatState? = nil) {
        self.context = context
        self.link = link
        self.navigateToPeer = navigateToPeer
        self.parentNavigationController = parentNavigationController
        self.resolvedState = resolvedState
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = JoinLinkPreviewControllerNode(context: self.context, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        })
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.join = { [weak self] in
            self?.join()
        }
        self.displayNodeDidLoad()
        
        let signal: Signal<ExternalJoiningChatState, NoError>
        if let resolvedState = self.resolvedState {
            signal = .single(resolvedState)
        } else {
            signal = joinLinkInformation(self.link, account: self.context.account)
        }
        
        self.disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.resolvedState = result
                switch result {
                    case let .invite(title, photoRepresentation, participantsCount, participants):
                        let data = JoinLinkPreviewData(isGroup: participants != nil, isJoined: false)
                        strongSelf.controllerNode.setPeer(image: photoRepresentation, title: title, memberCount: participantsCount, members: participants ?? [], data: data)
                    case let .alreadyJoined(peerId):
                        strongSelf.navigateToPeer(peerId)
                        strongSelf.dismiss()
                    case .invalidHash:
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.GroupInfo_InvitationLinkDoesNotExist, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        strongSelf.dismiss()
                }
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
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
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func join() {
        self.disposable.set((joinChatInteractively(with: self.link, account: self.context.account) |> deliverOnMainQueue).start(next: { [weak self] peerId in
            if let strongSelf = self {
                if let peerId = peerId {
                    strongSelf.navigateToPeer(peerId)
                    strongSelf.dismiss()
                }
            }
        }, error: { [weak self] error in
            if let strongSelf = self {
                if case .tooMuchJoined = error {
                    if let parentNavigationController = strongSelf.parentNavigationController {
                        let context = strongSelf.context
                        let link = strongSelf.link
                        let navigateToPeer = strongSelf.navigateToPeer
                        let resolvedState = strongSelf.resolvedState
                        parentNavigationController.pushViewController(oldChannelsController(context: strongSelf.context, intent: .join, completed: { [weak parentNavigationController] value in
                            if value {
                                (parentNavigationController?.viewControllers.last as? ViewController)?.present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: navigateToPeer, parentNavigationController: parentNavigationController, resolvedState: resolvedState), in: .window(.root))
                            }
                        }))
                    } else {
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Join_ChannelsTooMuch, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                    strongSelf.dismiss()
                }
            }
        }))
    }
}

