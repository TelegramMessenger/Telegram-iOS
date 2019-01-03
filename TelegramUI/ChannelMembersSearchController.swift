import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

enum ChannelMembersSearchControllerMode {
    case promote
    case ban
}

enum ChannelMembersSearchFilter {
    case exclude([PeerId])
    case disable([PeerId])
}

final class ChannelMembersSearchController: ViewController {
    private let queue = Queue()
    
    private let account: Account
    private let peerId: PeerId
    private let mode: ChannelMembersSearchControllerMode
    private let filters: [ChannelMembersSearchFilter]
    private let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    private var controllerNode: ChannelMembersSearchControllerNode {
        return self.displayNode as! ChannelMembersSearchControllerNode
    }
    
    init(account: Account, peerId: PeerId, mode: ChannelMembersSearchControllerMode, filters: [ChannelMembersSearchFilter] = [], openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void) {
        self.account = account
        self.peerId = peerId
        self.mode = mode
        self.openPeer = openPeer
        self.filters = filters
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Channel_Members_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChannelMembersSearchControllerNode(account: self.account, theme: self.presentationData.theme, strings: self.presentationData.strings, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, peerId: self.peerId, mode: self.mode, filters: self.filters)
        self.controllerNode.navigationBar = self.navigationBar
        self.controllerNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        self.controllerNode.requestOpenPeerFromSearch = { [weak self] peer, participant in
            self?.openPeer(peer, participant)
        }
        self.controllerNode.present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
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
        self.view.endEditing(true)
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
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.controllerNode.deactivateSearch(animated: animated)
        }
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
}
