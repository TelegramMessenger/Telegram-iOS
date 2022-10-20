import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import StickerPackPreviewUI
import ListSectionHeaderNode

final class StickerPaneSearchGlobalSection: GridSection {
    let title: String?
    let theme: PresentationTheme
    
    var height: CGFloat {
        if let _ = self.title {
            return 28.0
        } else {
            return 0.0
        }
    }
    
    var hashValue: Int {
        if let _ = self.title {
            return 1
        } else {
            return 0
        }
    }
    
    init(title: String?, theme: PresentationTheme) {
        self.title = title
        self.theme = theme
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? StickerPaneSearchGlobalSection {
            return to.hashValue == self.hashValue
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return StickerPaneSearchGlobalSectionNode(theme: self.theme, title: self.title ?? "")
    }
}

private final class StickerPaneSearchGlobalSectionNode: ASDisplayNode {
    private let node: ListSectionHeaderNode
    
    init(theme: PresentationTheme, title: String) {
        self.node = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        if !title.isEmpty {
            self.node.title = title
            self.addSubnode(self.node)
        }
    }
    
    override func layout() {
        super.layout()
        
        self.node.frame = self.bounds
        self.node.updateLayout(size: self.bounds.size, leftInset: 0.0, rightInset: 0.0)
    }
}

final class StickerPaneSearchGlobalItemContext {
    var canPlayMedia: Bool = false
}

final class StickerPaneSearchGlobalItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let listAppearance: Bool
    let fillsRow: Bool
    let info: StickerPackCollectionInfo
    let topItems: [StickerPackItem]
    let topSeparator: Bool
    let regularInsets: Bool
    let installed: Bool
    let installing: Bool
    let unread: Bool
    let open: () -> Void
    let install: () -> Void
    let getItemIsPreviewed: (StickerPackItem) -> Bool
    let itemContext: StickerPaneSearchGlobalItemContext
    
    let section: GridSection?
    var fillsRowWithHeight: (CGFloat, Bool)? {
        var additionalHeight: CGFloat = 0.0
        if self.regularInsets {
            additionalHeight = 12.0 + 12.0
        } else {
            additionalHeight += 12.0
            if self.topSeparator {
                additionalHeight += 12.0
            }
        }
        
        return (128.0 + additionalHeight, self.fillsRow)
    }
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, listAppearance: Bool, fillsRow: Bool = true, info: StickerPackCollectionInfo, topItems: [StickerPackItem], topSeparator: Bool, regularInsets: Bool, installed: Bool, installing: Bool = false, unread: Bool, open: @escaping () -> Void, install: @escaping () -> Void, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool, itemContext: StickerPaneSearchGlobalItemContext, sectionTitle: String? = nil) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.listAppearance = listAppearance
        self.fillsRow = fillsRow
        self.info = info
        self.topItems = topItems
        self.topSeparator = topSeparator
        self.regularInsets = regularInsets
        self.installed = installed
        self.installing = installing
        self.unread = unread
        self.open = open
        self.install = install
        self.getItemIsPreviewed = getItemIsPreviewed
        self.itemContext = itemContext
        self.section = StickerPaneSearchGlobalSection(title: sectionTitle, theme: theme)
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPaneSearchGlobalItemNode()
        node.setup(item: self)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPaneSearchGlobalItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self)
    }
}

private let titleFont = Font.bold(16.0)
private let statusFont = Font.regular(15.0)
private let buttonFont = Font.semibold(13.0)

class StickerPaneSearchGlobalItemNode: GridItemNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let unreadNode: ASImageNode
    private let installTextNode: TextNode
    private let installBackgroundNode: ASImageNode
    private let installButtonNode: HighlightTrackingButtonNode
    private let uninstallTextNode: TextNode
    private let uninstallBackgroundNode: ASImageNode
    private let uninstallButtonNode: HighlightTrackingButtonNode
    private var itemNodes: [TrendingTopItemNode]
    private let topSeparatorNode: ASDisplayNode
    private var highlightNode: ASDisplayNode?
    
    var item: StickerPaneSearchGlobalItem?
    private var appliedItem: StickerPaneSearchGlobalItem?
    private let preloadDisposable = MetaDisposable()
    private let preloadedStickerPackThumbnailDisposable = MetaDisposable()
    
    private var preloadedThumbnail = false
    private var canPlay = false
    
    private var canPlayMedia: Bool = false {
        didSet {
            if self.canPlayMedia != oldValue {
                self.updatePlayback()
            }
        }
    }
    
    override var isVisibleInGrid: Bool {
        didSet {
            if oldValue != self.isVisibleInGrid {
                self.updatePlayback()
            }
        }
    }
    
    private func updatePlayback() {
        let canPlay = self.canPlayMedia && self.isVisibleInGrid
        if canPlay != self.canPlay {
            self.canPlay = canPlay
            
            for node in self.itemNodes {
                node.visibility = self.canPlay
            }
            
            if let item = self.item, self.isVisibleInGrid, !self.preloadedThumbnail {
                self.preloadedThumbnail = true
                
                self.preloadedStickerPackThumbnailDisposable.set(preloadedStickerPackThumbnail(account: item.account, info: item.info, items: item.topItems).start())
            }
        }
    }
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.contentMode = .left
        self.descriptionNode.contentsScale = UIScreen.main.scale
        
        self.unreadNode = ASImageNode()
        self.unreadNode.isLayerBacked = true
        self.unreadNode.displayWithoutProcessing = true
        self.unreadNode.displaysAsynchronously = false
        
        self.installTextNode = TextNode()
        self.installTextNode.isUserInteractionEnabled = false
        self.installTextNode.contentMode = .left
        self.installTextNode.contentsScale = UIScreen.main.scale
        
        self.installBackgroundNode = ASImageNode()
        self.installBackgroundNode.isLayerBacked = true
        self.installBackgroundNode.displayWithoutProcessing = true
        self.installBackgroundNode.displaysAsynchronously = false
        
        self.installButtonNode = HighlightTrackingButtonNode()
        
        self.uninstallTextNode = TextNode()
        self.uninstallTextNode.isUserInteractionEnabled = false
        self.uninstallTextNode.contentMode = .left
        self.uninstallTextNode.contentsScale = UIScreen.main.scale
        
        self.uninstallBackgroundNode = ASImageNode()
        self.uninstallBackgroundNode.isLayerBacked = true
        self.uninstallBackgroundNode.displayWithoutProcessing = true
        self.uninstallBackgroundNode.displaysAsynchronously = false
        
        self.uninstallButtonNode = HighlightTrackingButtonNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.itemNodes = []
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.unreadNode)
        self.addSubnode(self.installBackgroundNode)
        self.addSubnode(self.installTextNode)
        self.addSubnode(self.installButtonNode)
        self.addSubnode(self.uninstallBackgroundNode)
        self.addSubnode(self.uninstallTextNode)
        self.addSubnode(self.uninstallButtonNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.installButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.installBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.installBackgroundNode.alpha = 0.4
                    strongSelf.installTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.installTextNode.alpha = 0.4
                } else {
                    strongSelf.installBackgroundNode.alpha = 1.0
                    strongSelf.installBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.installTextNode.alpha = 1.0
                    strongSelf.installTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.installButtonNode.addTarget(self, action: #selector(self.installPressed), forControlEvents: .touchUpInside)
        
        self.uninstallButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.uninstallBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.uninstallBackgroundNode.alpha = 0.4
                    strongSelf.uninstallTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.uninstallTextNode.alpha = 0.4
                } else {
                    strongSelf.uninstallBackgroundNode.alpha = 1.0
                    strongSelf.uninstallBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.uninstallTextNode.alpha = 1.0
                    strongSelf.uninstallTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.uninstallButtonNode.addTarget(self, action: #selector(self.installPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.preloadDisposable.dispose()
        self.preloadedStickerPackThumbnailDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private var absoluteLocation: (CGRect, CGSize)?
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        
        for node in self.itemNodes {
            let nodeRect = CGRect(origin: CGPoint(x: rect.minX + node.frame.minX, y: rect.minY + node.frame.minY), size: node.frame.size)
            node.updateAbsoluteRect(nodeRect, within: containerSize)
        }
    }
    
    func setup(item: StickerPaneSearchGlobalItem) {
        if item.topItems.count < Int(item.info.count) && item.topItems.count < 5 && self.item?.info.id != item.info.id {
            self.preloadDisposable.set(preloadedFeaturedStickerSet(network: item.account.network, postbox: item.account.postbox, id: item.info.id).start())
        }
        
        self.item = item
        self.setNeedsLayout()
        
        self.updatePreviewing(animated: false)
    }
    
    func updateCanPlayMedia() {
        guard let item = self.item else {
            return
        }
        
        self.canPlayMedia = item.itemContext.canPlayMedia
    }
    
    func highlight() {
        guard self.highlightNode == nil else {
            return
        }
        
        let highlightNode = ASDisplayNode()
        highlightNode.frame = self.bounds
        if let theme = self.item?.theme {
            highlightNode.backgroundColor = theme.list.itemCheckColors.fillColor.withAlphaComponent(0.08)
        }
        self.highlightNode = highlightNode
        self.insertSubnode(highlightNode, at: 0)
        
        Queue.mainQueue().after(1.5) {
            self.highlightNode = nil
            highlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak highlightNode] _ in
                highlightNode?.removeFromSupernode()
            })
        }
    }
    
    override func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
        guard let item = self.item else {
            return
        }
        
        let params = ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: size.height)
        
        let topSeparatorOffset: CGFloat
        var topOffset: CGFloat = 0.0
        if item.regularInsets {
            topOffset = 12.0
            topSeparatorOffset = -UIScreenPixel
        } else {
            topSeparatorOffset = 16.0
            topOffset += 12.0
            if item.topSeparator {
                topOffset += 12.0
            }
        }
        
        self.topSeparatorNode.isHidden = !item.topSeparator
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 16.0, y: topSeparatorOffset), size: CGSize(width: params.width - 16.0 * 2.0, height: UIScreenPixel))
        if item.listAppearance {
            self.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
        } else {
            self.topSeparatorNode.backgroundColor = item.theme.chat.inputMediaPanel.stickersSectionTextColor.withAlphaComponent(0.3)
        }
        
        let makeInstallLayout = TextNode.asyncLayout(self.installTextNode)
        let makeUninstallLayout = TextNode.asyncLayout(self.uninstallTextNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        
        let currentItem = self.appliedItem
        self.appliedItem = item
        
        var updateButtonBackgroundImage: UIImage?
        var updateUninstallButtonBackgroundImage: UIImage?
        if currentItem?.theme !== item.theme {
            updateUninstallButtonBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddedPackButtonImage(item.theme)
            updateButtonBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddPackButtonImage(item.theme)
        }
        let unreadImage = PresentationResourcesItemList.stickerUnreadDotImage(item.theme)
        
        let leftInset: CGFloat = 14.0
        let rightInset: CGFloat = 16.0
        
        let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_Install, font: buttonFont, textColor: item.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (uninstallLayout, uninstallApply) = makeUninstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_Installed, font: buttonFont, textColor: item.theme.list.itemCheckColors.fillColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.info.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0 - max(installLayout.size.width, uninstallLayout.size.width), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.StickerPack_StickerCount(item.info.count), font: statusFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
        let strongSelf = self
    
        let _ = installApply()
        let _ = uninstallApply()
        let _ = titleApply()
        let _ = descriptionApply()
    
        if let updateButtonBackgroundImage = updateButtonBackgroundImage {
            strongSelf.installBackgroundNode.image = updateButtonBackgroundImage
        }
        if let updateUninstallButtonBackgroundImage = updateUninstallButtonBackgroundImage {
            strongSelf.uninstallBackgroundNode.image = updateUninstallButtonBackgroundImage
        }
    
        let installWidth: CGFloat = installLayout.size.width + 32.0
        let buttonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - installWidth, y: 4.0 + topOffset), size: CGSize(width: installWidth, height: 28.0))
        strongSelf.installBackgroundNode.frame = buttonFrame
        strongSelf.installTextNode.frame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - installLayout.size.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - installLayout.size.height) / 2.0) + 1.0), size: installLayout.size)
        strongSelf.installButtonNode.frame = buttonFrame
        
        let uninstallWidth: CGFloat = uninstallLayout.size.width + 32.0
        let uninstallButtonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - uninstallWidth, y: 4.0 + topOffset), size: CGSize(width: uninstallWidth, height: 28.0))
        strongSelf.uninstallBackgroundNode.frame = uninstallButtonFrame
        strongSelf.uninstallTextNode.frame = CGRect(origin: CGPoint(x: uninstallButtonFrame.minX + floor((uninstallButtonFrame.width - uninstallLayout.size.width) / 2.0), y: uninstallButtonFrame.minY + floor((uninstallButtonFrame.height - uninstallLayout.size.height) / 2.0) + 1.0), size: uninstallLayout.size)
        strongSelf.uninstallButtonNode.frame = uninstallButtonFrame
    
        strongSelf.installButtonNode.isHidden = item.installed
        strongSelf.installBackgroundNode.isHidden = item.installed
        strongSelf.installTextNode.isHidden = item.installed
        
        strongSelf.uninstallButtonNode.isHidden = !item.installed
        strongSelf.uninstallBackgroundNode.isHidden = !item.installed
        strongSelf.uninstallTextNode.isHidden = !item.installed
    
        let titleFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 2.0 + topOffset), size: titleLayout.size)
        strongSelf.titleNode.frame = titleFrame
        strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 23.0 + topOffset), size: descriptionLayout.size)
    
        if item.unread {
            strongSelf.unreadNode.isHidden = false
        } else {
            strongSelf.unreadNode.isHidden = true
        }
        if let image = unreadImage {
            strongSelf.unreadNode.image = image
            strongSelf.unreadNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + 2.0, y: titleFrame.minY + 7.0), size: image.size)
        }
    
        let sideInset: CGFloat = 2.0
        let availableWidth = params.width - params.leftInset - params.rightInset - sideInset * 2.0
        var itemSide: CGFloat = floor(availableWidth / 5.0)
        itemSide = min(itemSide, 75.0)
        let itemSize = CGSize(width: itemSide, height: itemSide)
        var offset = sideInset
        let itemSpacing = (max(0, availableWidth - 5.0 * itemSide - sideInset * 2.0)) / 4.0
        
        var topItems = item.topItems
        if topItems.count > 5 {
            topItems.removeSubrange(5 ..< topItems.count)
        }
        
        for i in 0 ..< topItems.count {
            let file = topItems[i].file
            let node: TrendingTopItemNode
            if i < strongSelf.itemNodes.count {
                node = strongSelf.itemNodes[i]
            } else {
                node = TrendingTopItemNode()
                node.visibility = strongSelf.canPlay
                strongSelf.itemNodes.append(node)
                strongSelf.addSubnode(node)
            }
            if file.fileId != node.file?.fileId {
                node.setup(account: item.account, item: topItems[i], itemSize: itemSize, synchronousLoads: synchronousLoads)
            }
            if item.theme !== node.theme {
                node.update(theme: item.theme, listAppearance: item.listAppearance)
            }
            if let dimensions = file.dimensions {
                let imageSize = dimensions.cgSize.aspectFitted(itemSize)
                node.frame = CGRect(origin: CGPoint(x: offset, y: 48.0 + topOffset), size: imageSize)
                offset += itemSize.width + itemSpacing
            }
            if let (rect, size) = strongSelf.absoluteLocation {
                strongSelf.updateAbsoluteRect(rect, within: size)
            }
        }
    
        if topItems.count < strongSelf.itemNodes.count {
            for i in (topItems.count ..< strongSelf.itemNodes.count).reversed() {
                strongSelf.itemNodes[i].removeFromSupernode()
                strongSelf.itemNodes.remove(at: i)
            }
        }
        
        self.canPlayMedia = item.itemContext.canPlayMedia
    }
    
    @objc func installPressed() {
        if let item = self.item {
            item.install()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                item.open()
            }
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPackItem)? {
        guard let item = self.item else {
            return nil
        }
        var index = 0
        for itemNode in self.itemNodes {
            if itemNode.frame.contains(point), index < item.topItems.count {
                return (itemNode, item.topItems[index])
            }
            index += 1
        }
        return nil
    }
    
    func updatePreviewing(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        var index = 0
        for itemNode in self.itemNodes {
            if index < item.topItems.count {
                let isPreviewing = item.getItemIsPreviewed(item.topItems[index])
                itemNode.updatePreviewing(animated: animated, isPreviewing: isPreviewing)
            }
            index += 1
        }
    }
}
