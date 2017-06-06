import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

final class ChatListSearchRecentPeersNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let sectionHeaderNode: ListSectionHeaderNode
    private let listView: ListView
    
    private let disposable = MetaDisposable()
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peerSelected: @escaping (Peer) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        self.sectionHeaderNode.title = strings.DialogList_RecentTitlePeople
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init()
        
        self.addSubnode(self.sectionHeaderNode)
        self.addSubnode(self.listView)
        
        self.disposable.set((recentPeers(account: account) |> filter { !$0.isEmpty } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peers in
            if let strongSelf = self {
                var items: [ListViewItem] = []
                for peer in peers {
                    items.append(HorizontalPeerItem(theme: strongSelf.theme, strings: strongSelf.strings, account: account, peer: peer, action: peerSelected))
                }
                strongSelf.listView.transaction(deleteIndices: [], insertIndicesAndItems: (0 ..< items.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: items[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [], updateOpaqueState: nil)
            }
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.sectionHeaderNode.title = strings.DialogList_RecentTitlePeople
            self.sectionHeaderNode.updateTheme(theme: theme)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 120.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 29.0))
        self.sectionHeaderNode.layout()
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 92.0, height: bounds.size.width)
        self.listView.position = CGPoint(x: bounds.size.width / 2.0, y: 92.0 / 2.0 + 29.0)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: 92.0, height: bounds.size.width), insets: UIEdgeInsets(), duration: 0.0, curve: .Default), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func viewAndPeerAtPoint(_ point: CGPoint) -> (UIView, PeerId)? {
        let adjustedPoint = self.view.convert(point, to: self.listView.view)
        var selectedItemNode: ASDisplayNode?
        self.listView.forEachItemNode { itemNode in
            if itemNode.frame.contains(adjustedPoint) {
                selectedItemNode = itemNode
            }
        }
        if let selectedItemNode = selectedItemNode as? HorizontalPeerItemNode, let peer = selectedItemNode.peer {
            return (selectedItemNode.view, peer.id)
        }
        return nil
    }
}
