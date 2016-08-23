import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore

final class ContactsControllerNode: ASDisplayNode {
    let listView: ListView
    
    private let account: Account
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((PeerId) -> Void)?
    
    init(account: Account) {
        self.account = account
        self.listView = ListView()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.addSubnode(self.listView)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
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
        
        let listViewCurve: ListViewAnimationCurve
        var speedFactor: CGFloat = 1.0
        if curve == 7 {
            speedFactor = CGFloat(duration) / 0.5
            listViewCurve = .Spring(speed: CGFloat(speedFactor))
        } else {
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listView.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, completion: { _ in })
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        self.listView.forEachItemNode { node in
            if let node = node as? ChatListSearchItemNode {
                maybePlaceholderNode = node.searchBarNode
            }
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if let placeholderNode = maybePlaceholderNode {
            self.searchDisplayController = SearchDisplayController(contentNode: ContactsSearchContainerNode(account: self.account, openPeer: { [weak self] peerId in
                if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                    requestOpenPeerFromSearch(peerId)
                }
            }), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { subnode in
                self.insertSubnode(subnode, belowSubnode: navigationBar)
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch() {
        if let searchDisplayController = self.searchDisplayController {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.listView.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
            self.searchDisplayController = nil
        }
    }
}
