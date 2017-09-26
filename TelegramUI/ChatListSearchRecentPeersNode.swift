import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private func calculateItemCustomWidth(width: CGFloat) -> CGFloat {
    let itemInsets = UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 6.0)
    let minimalItemWidth: CGFloat = width > 301.0 ? 70.0 : 60.0
    let effectiveWidth1 = width - 12.0 - 12.0
    let effectiveWidth = width - itemInsets.left - itemInsets.right
    
    let itemsPerRow = Int(effectiveWidth1 / minimalItemWidth)
    let itemWidth = floor(effectiveWidth1 / CGFloat(itemsPerRow))
    
    let itemsInRow = Int(effectiveWidth / itemWidth)
    let itemsInRowWidth = CGFloat(itemsInRow) * itemWidth
    let remainingWidth = max(0.0, effectiveWidth - itemsInRowWidth)
    
    let itemSpacing = floorToScreenPixels(remainingWidth / CGFloat(itemsInRow + 1))
    
    return itemWidth + itemSpacing
}

final class ChatListSearchRecentPeersNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let sectionHeaderNode: ListSectionHeaderNode
    private let listView: ListView
    private let share: Bool
    
    private let peerSelected: (Peer) -> Void
    private let isPeerSelected: (PeerId) -> Bool
    
    private let disposable = MetaDisposable()
    
    private var items: [ListViewItem] = []
    private var itemCustomWidth: CGFloat?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peerSelected: @escaping (Peer) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, share: Bool = false) {
        self.theme = theme
        self.strings = strings
        self.share = share
        self.peerSelected = peerSelected
        self.isPeerSelected = isPeerSelected
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        self.sectionHeaderNode.title = strings.DialogList_RecentTitlePeople.uppercased()
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init()
        
        self.addSubnode(self.sectionHeaderNode)
        self.addSubnode(self.listView)
        
        self.disposable.set((recentPeers(account: account) |> filter { !$0.isEmpty } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peers in
            if let strongSelf = self {
                var items: [ListViewItem] = []
                for peer in peers {
                    items.append(HorizontalPeerItem(theme: strongSelf.theme, strings: strongSelf.strings, account: account, peer: peer, action: peerSelected, isPeerSelected: isPeerSelected, customWidth: strongSelf.itemCustomWidth))
                }
                strongSelf.items = items
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
        
        var insets = UIEdgeInsets()
        
        var itemCustomWidth: CGFloat?
        if self.share {
            insets.top = 7.0
            insets.bottom = 7.0
            
            itemCustomWidth = calculateItemCustomWidth(width: bounds.size.width)
        }
        
        var updateItems: [ListViewUpdateItem] = []
        if itemCustomWidth != self.itemCustomWidth {
            self.itemCustomWidth = itemCustomWidth
            
            for i in 0 ..< self.items.count {
                if let item = self.items[i] as? HorizontalPeerItem {
                    self.items[i] = HorizontalPeerItem(theme: self.theme, strings: self.strings, account: item.account, peer: item.peer, action: self.peerSelected, isPeerSelected: self.isPeerSelected, customWidth: itemCustomWidth)
                    updateItems.append(ListViewUpdateItem(index: i, previousIndex: i, item: self.items[i], directionHint: nil))
                }
            }
        }
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 92.0, height: bounds.size.width)
        self.listView.position = CGPoint(x: bounds.size.width / 2.0, y: 92.0 / 2.0 + 29.0)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: updateItems, options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: 92.0, height: bounds.size.width), insets: insets, duration: 0.0, curve: .Default), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func viewAndPeerAtPoint(_ point: CGPoint) -> (UIView, PeerId)? {
        let adjustedPoint = self.view.convert(point, to: self.listView.view)
        var selectedItemNode: ASDisplayNode?
        self.listView.forEachItemNode { itemNode in
            if itemNode.frame.contains(adjustedPoint) {
                selectedItemNode = itemNode
            }
        }
        if let selectedItemNode = selectedItemNode as? HorizontalPeerItemNode, let peer = selectedItemNode.item?.peer {
            return (selectedItemNode.view, peer.id)
        }
        return nil
    }
    
    func removePeer(_ peerId: PeerId) {
        for i in 0 ..< self.items.count {
            if let item = self.items[i] as? HorizontalPeerItem, item.peer.id == peerId {
                self.items.remove(at: i)
                self.listView.transaction(deleteIndices: [ListViewDeleteItem(index: i, directionHint: nil)], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.AnimateInsertion], updateOpaqueState: nil)
                break
            }
        }
    }
    
    func updateSelectedPeers(animated: Bool) {
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? HorizontalPeerItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
}
