import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private let subtitleFont = Font.regular(12.0)

final class SharePeersContainerNode: ASDisplayNode, ShareContentContainerNode {
    private let account: Account
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let controllerInteraction: ShareControllerInteraction
    var peers: [Peer]?
    
    private let contentGridNode: GridNode
    private let contentTitleNode: ASTextNode
    private let contentSubtitleNode: ASTextNode
    private let contentSeparatorNode: ASDisplayNode
    private let searchButtonNode: HighlightableButtonNode
    private let shareButtonNode: HighlightableButtonNode
    
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    var openSearch: (() -> Void)?
    var openShare: (() -> Void)?
    
    private var ensurePeerVisibleOnLayout: PeerId?
    private var validLayout: (CGSize, CGFloat)?
    private var overrideGridOffsetTransition: ContainedViewLayoutTransition?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peers: [Peer], controllerInteraction: ShareControllerInteraction, externalShare: Bool) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.controllerInteraction = controllerInteraction
        self.peers = peers
        
        self.contentGridNode = GridNode()
        
        self.contentTitleNode = ASTextNode()
        self.contentTitleNode.attributedText = NSAttributedString(string: strings.ShareMenu_ShareTo, font: Font.medium(20.0), textColor: self.theme.actionSheet.primaryTextColor)
        
        self.contentSubtitleNode = ASTextNode()
        self.contentSubtitleNode.maximumNumberOfLines = 1
        self.contentSubtitleNode.isLayerBacked = true
        self.contentSubtitleNode.displaysAsynchronously = false
        self.contentSubtitleNode.truncationMode = .byTruncatingTail
        self.contentSubtitleNode.attributedText = NSAttributedString(string: strings.ShareMenu_SelectChats, font: subtitleFont, textColor: self.theme.actionSheet.secondaryTextColor)
        
        self.searchButtonNode = HighlightableButtonNode()
        self.searchButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Share/SearchIcon"), color: self.theme.actionSheet.controlAccentColor), for: [])
        
        self.shareButtonNode = HighlightableButtonNode()
        self.shareButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Share/ShareIcon"), color: self.theme.actionSheet.controlAccentColor), for: [])
        self.shareButtonNode.isHidden = !externalShare
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        self.contentSeparatorNode.displaysAsynchronously = false
        self.contentSeparatorNode.backgroundColor = self.theme.actionSheet.opaqueItemSeparatorColor
        
        super.init()
        
        self.addSubnode(self.contentGridNode)
        
        self.addSubnode(self.contentTitleNode)
        self.addSubnode(self.contentSubtitleNode)
        self.addSubnode(self.searchButtonNode)
        self.addSubnode(self.shareButtonNode)
        self.addSubnode(self.contentSeparatorNode)
        
        var insertItems: [GridNodeInsertItem] = []
        for i in 0 ..< peers.count {
            insertItems.append(GridNodeInsertItem(index: i, item: ShareControllerPeerGridItem(account: self.account, theme: self.theme, strings: self.strings, peer: peers[i], chatPeer: nil, controllerInteraction: self.controllerInteraction), previousIndex: nil))
        }
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: insertItems, updateItems: [], scrollToItem: nil, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
        
        self.searchButtonNode.addTarget(self, action: #selector(self.searchPressed), forControlEvents: .touchUpInside)
        self.shareButtonNode.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
        self.ensurePeerVisibleOnLayout = peerId
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    private func calculateMetrics(size: CGSize) -> (topInset: CGFloat, itemWidth: CGFloat) {
        let itemCount = self.peers?.count ?? 1
        
        let itemInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
        let minimalItemWidth: CGFloat = size.width > 301.0 ? 70.0 : 60.0
        let effectiveWidth = size.width - itemInsets.left - itemInsets.right
        
        let itemsPerRow = Int(effectiveWidth / minimalItemWidth)
        
        let itemWidth = floor(effectiveWidth / CGFloat(itemsPerRow))
        var rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        rowCount = max(rowCount, 4)
        
        let minimallyRevealedRowCount: CGFloat = 3.7
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let gridTopInset = max(0.0, size.height - floor(initiallyRevealedRowCount * itemWidth) - 14.0)
        return (gridTopInset, itemWidth)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = (size, bottomInset)
        
        let gridLayoutTransition: ContainedViewLayoutTransition
        if firstLayout {
            gridLayoutTransition = .immediate
            self.overrideGridOffsetTransition = transition
        } else {
            gridLayoutTransition = transition
            self.overrideGridOffsetTransition = nil
        }
        
        let (gridTopInset, itemWidth) = self.calculateMetrics(size: size)
        
        var scrollToItem: GridNodeScrollToItem?
        if let ensurePeerVisibleOnLayout = self.ensurePeerVisibleOnLayout {
            self.ensurePeerVisibleOnLayout = nil
            if let index = self.peers?.index(where: { $0.id == ensurePeerVisibleOnLayout }) {
                scrollToItem = GridNodeScrollToItem(index: index, position: .visible, transition: transition, directionHint: .up, adjustForSection: false)
            }
        }
        
        let gridSize = CGSize(width: size.width - 12.0, height: size.height)
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 0.0, bottom: bottomInset, right: 0.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), lineSpacing: 0.0)), transition: gridLayoutTransition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        gridLayoutTransition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((size.width - gridSize.width) / 2.0), y: 0.0), size: gridSize))
        
        if firstLayout {
            self.animateIn()
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        guard let (size, _) = self.validLayout else {
            return
        }
        
        let actualTransition = self.overrideGridOffsetTransition ?? transition
        self.overrideGridOffsetTransition = nil
        
        let titleAreaHeight: CGFloat = 64.0
        
        let rawTitleOffset = -titleAreaHeight - presentationLayout.contentOffset.y
        let titleOffset = max(-titleAreaHeight, rawTitleOffset)
        
        let titleSize = self.contentTitleNode.measure(size)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: titleOffset + 15.0), size: titleSize)
        transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        
        let subtitleSize = self.contentSubtitleNode.measure(CGSize(width: size.width - 44.0 * 2.0 - 8.0 * 2.0, height: titleAreaHeight))
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleOffset + 40.0), size: subtitleSize)
        var originalSubtitleFrame = self.contentSubtitleNode.frame
        originalSubtitleFrame.origin.x = subtitleFrame.origin.x
        originalSubtitleFrame.size = subtitleFrame.size
        self.contentSubtitleNode.frame = originalSubtitleFrame
        transition.updateFrame(node: self.contentSubtitleNode, frame: subtitleFrame)
        
        let titleButtonSize = CGSize(width: 44.0, height: 44.0)
        let searchButtonFrame = CGRect(origin: CGPoint(x: 12.0, y: titleOffset + 12.0), size: titleButtonSize)
        transition.updateFrame(node: self.searchButtonNode, frame: searchButtonFrame)
        
        let shareButtonFrame = CGRect(origin: CGPoint(x: size.width - titleButtonSize.width - 12.0, y: titleOffset + 12.0), size: titleButtonSize)
        transition.updateFrame(node: self.shareButtonNode, frame: shareButtonFrame)
        
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleOffset + titleAreaHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        if rawTitleOffset.isLess(than: -titleAreaHeight) {
            self.contentSeparatorNode.alpha = 1.0
        } else {
            self.contentSeparatorNode.alpha = 0.0
        }
        
        self.contentOffsetUpdated?(presentationLayout.contentOffset.y, actualTransition)
    }
    
    func updateVisibleItemsSelection(animated: Bool) {
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
    
    func animateIn() {
        var durationOffset = 0.0
        self.contentGridNode.forEachRow { itemNodes in
            for itemNode in itemNodes {
                itemNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 4.0), to: CGPoint(), duration: 0.4 + durationOffset, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                if let itemNode = itemNode as? StickerPackPreviewGridItemNode {
                    itemNode.animateIn()
                }
            }
            durationOffset += 0.04
        }
        
        if let (size, _) = self.validLayout {
            let (topInset, _) = self.calculateMetrics(size: size)
            self.contentGridNode.layer.animateBoundsOriginYAdditive(from: -(topInset - 64.0), to: 0.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func updateSelectedPeers() {
        var subtitleText = self.strings.ShareMenu_SelectChats
        if !self.controllerInteraction.selectedPeers.isEmpty {
            subtitleText = self.controllerInteraction.selectedPeers.reduce("", { string, peer in
                if !string.isEmpty {
                    return string + ", " + peer.displayTitle
                } else {
                    return string + peer.displayTitle
                }
            })
        }
        self.contentSubtitleNode.attributedText = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: self.theme.actionSheet.secondaryTextColor)
        
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: true)
            }
        }
    }
    
    @objc func searchPressed() {
        self.openSearch?()
    }
    
    @objc func sharePressed() {
        self.openShare?()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let nodes: [ASDisplayNode] = [self.searchButtonNode, self.shareButtonNode]
        for node in nodes {
            let nodeFrame = node.frame
            if let result = node.hitTest(point.offsetBy(dx: -nodeFrame.minX, dy: -nodeFrame.minY), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
