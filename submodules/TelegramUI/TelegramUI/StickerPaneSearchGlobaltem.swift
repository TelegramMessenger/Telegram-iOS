import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import StickerPackPreviewUI

final class StickerPaneSearchGlobalSection: GridSection {
    let height: CGFloat = 0.0
    
    var hashValue: Int {
        return 0
    }
    
    init() {
    }
    
    func isEqual(to: GridSection) -> Bool {
        if to is StickerPaneSearchGlobalSection {
            return true
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return ASDisplayNode()
    }
}


final class StickerPaneSearchGlobalItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let info: StickerPackCollectionInfo
    let topItems: [StickerPackItem]
    let grid: Bool
    let topSeparator: Bool
    let installed: Bool
    let installing: Bool
    let unread: Bool
    let open: () -> Void
    let install: () -> Void
    let getItemIsPreviewed: (StickerPackItem) -> Bool
    
    let section: GridSection? = StickerPaneSearchGlobalSection()
    var fillsRowWithHeight: CGFloat? {
        return self.grid ? nil : (128.0 + (self.topSeparator ? 12.0 : 0.0))
    }
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, info: StickerPackCollectionInfo, topItems: [StickerPackItem], grid: Bool, topSeparator: Bool, installed: Bool, installing: Bool = false, unread: Bool, open: @escaping () -> Void, install: @escaping () -> Void, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.info = info
        self.topItems = topItems
        self.grid = grid
        self.topSeparator = topSeparator
        self.installed = installed
        self.installing = installing
        self.unread = unread
        self.open = open
        self.install = install
        self.getItemIsPreviewed = getItemIsPreviewed
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
    private var itemNodes: [TrendingTopItemNode]
    private let topSeparatorNode: ASDisplayNode
    
    private var item: StickerPaneSearchGlobalItem?
    private var appliedItem: StickerPaneSearchGlobalItem?
    private let preloadDisposable = MetaDisposable()
    private let preloadedStickerPackThumbnailDisposable = MetaDisposable()
    
    private var preloadedThumbnail = false
    
    override var isVisibleInGrid: Bool {
        didSet {
            if oldValue != self.isVisibleInGrid {
                for node in self.itemNodes {
                    node.visibility = self.isVisibleInGrid
                }
                
                if let item = self.item, self.isVisibleInGrid, !self.preloadedThumbnail {
                    self.preloadedThumbnail = true
                    
                    self.preloadedStickerPackThumbnailDisposable.set(preloadedStickerPackThumbnail(account: item.account, info: item.info, items: item.topItems).start())
                }
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
    }
    
    deinit {
        self.preloadDisposable.dispose()
        self.preloadedStickerPackThumbnailDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(item: StickerPaneSearchGlobalItem) {
        if item.topItems.count < Int(item.info.count) && item.topItems.count < 5 && self.item?.info.id != item.info.id {
            self.preloadDisposable.set(preloadedFeaturedStickerSet(network: item.account.network, postbox: item.account.postbox, id: item.info.id).start())
        }
        
        self.item = item
        self.setNeedsLayout()
        
        self.updatePreviewing(animated: false)
    }
    
    override func layout() {
        super.layout()
        guard let item = self.item else {
            return
        }
        
        let params = ListViewItemLayoutParams(width: self.bounds.size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: self.bounds.height)
        
        var topOffset: CGFloat = 12.0
        if item.topSeparator {
            topOffset += 12.0
        }
        
        self.topSeparatorNode.isHidden = !item.topSeparator
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: CGSize(width: params.width - 16.0 * 2.0, height: UIScreenPixel))
        self.topSeparatorNode.backgroundColor = item.theme.chat.inputMediaPanel.stickersSectionTextColor.withAlphaComponent(0.3)
        
        let makeInstallLayout = TextNode.asyncLayout(self.installTextNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        
        let currentItem = self.appliedItem
        self.appliedItem = item
        
        var updateButtonBackgroundImage: UIImage?
        if currentItem?.theme !== item.theme {
            updateButtonBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddPackButtonImage(item.theme)
        }
        let unreadImage = PresentationResourcesItemList.stickerUnreadDotImage(item.theme)
        
        let leftInset: CGFloat = 14.0
        let rightInset: CGFloat = 16.0
        
        let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_Install, font: buttonFont, textColor: item.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.info.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0 - installLayout.size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.StickerPack_StickerCount(item.info.count), font: statusFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
        let strongSelf = self
    
        let _ = installApply()
        let _ = titleApply()
        let _ = descriptionApply()
    
        if let updateButtonBackgroundImage = updateButtonBackgroundImage {
            strongSelf.installBackgroundNode.image = updateButtonBackgroundImage
        }
    
        let installWidth: CGFloat = installLayout.size.width + 32.0
        let buttonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - installWidth, y: 4.0 + topOffset), size: CGSize(width: installWidth, height: 28.0))
        strongSelf.installBackgroundNode.frame = buttonFrame
        strongSelf.installTextNode.frame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - installLayout.size.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - installLayout.size.height) / 2.0) + 1.0), size: installLayout.size)
        strongSelf.installButtonNode.frame = buttonFrame
    
        if item.installed {
            strongSelf.installButtonNode.isHidden = true
            strongSelf.installBackgroundNode.isHidden = true
            strongSelf.installTextNode.isHidden = true
        } else {
            strongSelf.installButtonNode.isHidden = false
            strongSelf.installBackgroundNode.isHidden = false
            strongSelf.installTextNode.isHidden = false
        }
    
        let titleFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 2.0 + topOffset), size: titleLayout.size)
        strongSelf.titleNode.frame = titleFrame
        strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 23.0 + topOffset), size: descriptionLayout.size)
    
        if false && item.unread {
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
                node.visibility = strongSelf.isVisibleInGrid
                strongSelf.itemNodes.append(node)
                strongSelf.addSubnode(node)
            }
            if file.fileId != node.file?.fileId {
                node.setup(account: item.account, item: topItems[i], itemSize: itemSize, synchronousLoads: false)
            }
            if let dimensions = file.dimensions {
                let imageSize = dimensions.cgSize.aspectFitted(itemSize)
                node.frame = CGRect(origin: CGPoint(x: offset, y: 48.0 + topOffset), size: imageSize)
                offset += itemSize.width + itemSpacing
            }
        }
    
        if topItems.count < strongSelf.itemNodes.count {
            for i in (topItems.count ..< strongSelf.itemNodes.count).reversed() {
                strongSelf.itemNodes[i].removeFromSupernode()
                strongSelf.itemNodes.remove(at: i)
            }
        }
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
