import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

public final class JoinLinkPreviewController: ViewController {
    private var controllerNode: JoinLinkPreviewControllerNode {
        return self.displayNode as! JoinLinkPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private let link: String
    private let navigateToPeer: (PeerId) -> Void
    private var presentationData: PresentationData
    
    private let disposable = MetaDisposable()
    
    public init(account: Account, link: String, navigateToPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.link = link
        self.navigateToPeer = navigateToPeer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = JoinLinkPreviewControllerNode(account: self.account, requestLayout: { [weak self] transition in
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
        self.disposable.set((joinLinkInformation(self.link, account: self.account) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                switch result {
                    case let .invite(title, photoRepresentation, participantsCount, participants):
                        let data = JoinLinkPreviewData(isGroup: participants != nil, isJoined: false)
                        strongSelf.controllerNode.setPeer(image: photoRepresentation, title: title, memberCount: participantsCount, members: participants ?? [], data: data)
                    case let .alreadyJoined(peerId):
                        strongSelf.navigateToPeer(peerId)
                        strongSelf.dismiss()
                    default:
                        break
                }
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
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
        self.disposable.set((joinChatInteractively(with: self.link, account: self.account) |> deliverOnMainQueue).start(next: { [weak self] peerId in
            if let strongSelf = self {
                if let peerId = peerId {
                    strongSelf.navigateToPeer(peerId)
                    strongSelf.dismiss()
                }
            }
        }))
    }
}

