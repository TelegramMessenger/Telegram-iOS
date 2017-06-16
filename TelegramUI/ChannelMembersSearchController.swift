import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChannelMembersSearchController: TelegramController {
    private let queue = Queue()
    
    private let account: Account
    private let peerId: PeerId
    private let openPeer: (Peer) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    private var controllerNode: ChannelMembersSearchControllerNode {
        return self.displayNode as! ChannelMembersSearchControllerNode
    }
    
    init(account: Account, peerId: PeerId, openPeer: @escaping (Peer) -> Void) {
        self.account = account
        self.peerId = peerId
        self.openPeer = openPeer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(account: account)
        
        self.title = self.presentationData.strings.Channel_Members_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChannelMembersSearchControllerNode(account: self.account, theme: self.presentationData.theme, strings: self.presentationData.strings, peerId: peerId)
        self.controllerNode.navigationBar = self.navigationBar
        self.controllerNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        self.controllerNode.requestOpenPeerFromSearch = { [weak self] peer in
            self?.dismiss()
            self?.openPeer(peer)
        }
        
        self.displayNodeDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.controllerNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.controllerNode.deactivateSearch(animated: animated)
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
        }
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
}
