import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SearchUI

enum ChannelMembersSearchControllerMode {
    case promote
    case ban
}

public enum ChannelMembersSearchFilter {
    case exclude([PeerId])
    case disable([PeerId])
}

final class ChannelMembersSearchController: ViewController {
    private let queue = Queue()
    
    private let context: AccountContext
    private let peerId: PeerId
    private let mode: ChannelMembersSearchControllerMode
    private let filters: [ChannelMembersSearchFilter]
    private let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    private var controllerNode: ChannelMembersSearchControllerNode {
        return self.displayNode as! ChannelMembersSearchControllerNode
    }
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    init(context: AccountContext, peerId: PeerId, mode: ChannelMembersSearchControllerMode, filters: [ChannelMembersSearchFilter] = [], openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        self.openPeer = openPeer
        self.filters = filters
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Channel_Members_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.controllerNode.scrollToTop()
            }
        }
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChannelMembersSearchControllerNode(context: self.context, presentationData: self.presentationData, peerId: self.peerId, mode: self.mode, filters: self.filters)
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
        self.controllerNode.pushController = { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }
        
        self.displayNodeDidLoad()
        
        self.controllerNode.listNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.controllerNode.listNode.didEndScrolling = { [weak self] in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                let _ = fixNavigationSearchableListNodeScrolling(strongSelf.controllerNode.listNode, searchNode: searchContentNode)
            }
        }
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
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            }
        }
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
}
