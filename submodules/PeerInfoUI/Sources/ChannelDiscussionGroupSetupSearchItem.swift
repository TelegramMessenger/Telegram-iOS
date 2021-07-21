import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SearchBarNode

final class ChannelDiscussionGroupSetupSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let peers: [Peer]
    let cancel: () -> Void
    let dismissInput: () -> Void
    let openPeer: (Peer) -> Void
    
    init(context: AccountContext, peers: [Peer], cancel: @escaping () -> Void, dismissInput: @escaping () -> Void, openPeer: @escaping (Peer) -> Void) {
        self.context = context
        self.peers = peers
        self.cancel = cancel
        self.dismissInput = dismissInput
        self.openPeer = openPeer
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? ChannelDiscussionGroupSetupSearchItem {
            if self.context !== to.context {
                return false
            }
            if self.peers.count != to.peers.count {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? ChannelDiscussionSearchNavigationContentNode {
            current.updateTheme(presentationData.theme)
            return current
        } else {
            return ChannelDiscussionSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, cancel: self.cancel, updateActivity: { _ in
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return ChannelDiscussionGroupSetupSearchItemNode(context: self.context, peers: self.peers, openPeer: self.openPeer, cancel: self.cancel, updateActivity: { _ in
        }, dismissInput: self.dismissInput)
    }
}

private final class ChannelDiscussionGroupSetupSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: ChannelDiscussionGroupSearchContainerNode
    
    init(context: AccountContext, peers: [Peer], openPeer: @escaping (Peer) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping (Bool) -> Void, dismissInput: @escaping () -> Void) {
        self.containerNode = ChannelDiscussionGroupSearchContainerNode(context: context, peers: peers, openPeer: { peer in
            openPeer(peer)
        })
        self.containerNode.dismissInput = {
            dismissInput()
        }
        self.containerNode.cancel = {
            cancel()
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func scrollToTop() {
        self.containerNode.scrollToTop()
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout.withUpdatedSize(CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)), navigationBarHeight: 0.0, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}

private let searchBarFont = Font.regular(17.0)

private final class ChannelDiscussionSearchNavigationContentNode: NavigationBarContentNode, ItemListControllerSearchNavigationContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    var activity: Bool = false {
        didSet {
            searchBar.activity = activity
        }
    }
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void, updateActivity: @escaping(@escaping(Bool)->Void) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        
        updateActivity({ [weak self] value in
            self?.activity = value
        })
        
        self.updatePlaceholder()
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: self.theme), strings: self.strings)
        self.updatePlaceholder()
    }
    
    func updatePlaceholder() {
        let placeholderText: String
        placeholderText = self.strings.Channel_DiscussionGroup_SearchPlaceholder
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: self.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
    }
    
    override var nominalHeight: CGFloat {
        return 54.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}


