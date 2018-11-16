import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox

final class StickerPaneSearchGlobalItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let info: StickerPackCollectionInfo
    let topItems: [StickerPackItem]
    let installed: Bool
    let unread: Bool
    let open: () -> Void
    let install: () -> Void
    let getItemIsPreviewed: (StickerPackItem) -> Bool
    
    let section: GridSection? = nil
    let fillsRowWithHeight: CGFloat? = 128.0
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, info: StickerPackCollectionInfo, topItems: [StickerPackItem], installed: Bool, unread: Bool, open: @escaping () -> Void, install: @escaping () -> Void, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.info = info
        self.topItems = topItems
        self.installed = installed
        self.unread = unread
        self.open = open
        self.install = install
        self.getItemIsPreviewed = getItemIsPreviewed
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
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
private let buttonFont = Font.medium(13.0)

private final class TrendingTopItemNode: TransformImageNode {
    var file: TelegramMediaFile? = nil
    let loadDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    func updatePreviewing(animated: Bool, isPreviewing: Bool) {
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "transform.scale", duration: 0.4, removeOnCompletion: false)
                }
            } else {
                self.layer.removeAnimation(forKey: "transform.scale")
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
            }
        }
    }
}

class StickerPaneSearchGlobalItemNode: GridItemNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let unreadNode: ASImageNode
    private let installTextNode: TextNode
    private let installBackgroundNode: ASImageNode
    private let installButtonNode: HighlightTrackingButtonNode
    private var itemNodes: [TrendingTopItemNode]
    
    private var item: StickerPaneSearchGlobalItem?
    private var appliedItem: StickerPaneSearchGlobalItem?
    private let preloadDisposable = MetaDisposable()
    
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
        
        self.itemNodes = []
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.unreadNode)
        self.addSubnode(self.installBackgroundNode)
        self.addSubnode(self.installTextNode)
        self.addSubnode(self.installButtonNode)
        
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
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(item: StickerPaneSearchGlobalItem) {
        self.item = item
        self.setNeedsLayout()
        
        self.updatePreviewing(animated: false)
    }
    
    override func layout() {
        super.layout()
        guard let item = self.item else {
            return
        }
        
        let params = ListViewItemLayoutParams(width: self.bounds.size.width, leftInset: 0.0, rightInset: 0.0)
        
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
        let topOffset: CGFloat = 12.0
        
        let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_Install, font: buttonFont, textColor: item.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.info.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0 - installLayout.size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.StickerPack_StickerCount(item.info.count), font: statusFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        var topItems = item.topItems
        if topItems.count > 5 {
            topItems.removeSubrange(5 ..< topItems.count)
        }
        
        let strongSelf = self
        if item.topItems.count < Int(item.info.count) && item.topItems.count < 5 && strongSelf.item?.info.id != item.info.id {
            strongSelf.preloadDisposable.set(preloadedFeaturedStickerSet(network: item.account.network, postbox: item.account.postbox, id: item.info.id).start())
        }
        strongSelf.item = item
    
        let _ = installApply()
        let _ = titleApply()
        let _ = descriptionApply()
    
        if let updateButtonBackgroundImage = updateButtonBackgroundImage {
            strongSelf.installBackgroundNode.image = updateButtonBackgroundImage
        }
    
        let installWidth: CGFloat = installLayout.size.width + 20.0
        let buttonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - installWidth, y: 4.0 + topOffset), size: CGSize(width: installWidth, height: 26.0))
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
    
        var offset: CGFloat = params.leftInset + leftInset
        let itemSize = CGSize(width: 68.0, height: 68.0)
    
        for i in 0 ..< topItems.count {
            let file = topItems[i].file
            let node: TrendingTopItemNode
            if i < strongSelf.itemNodes.count {
                node = strongSelf.itemNodes[i]
            } else {
                node = TrendingTopItemNode()
                node.contentAnimations = [.subsequentUpdates]
                strongSelf.itemNodes.append(node)
                strongSelf.addSubnode(node)
            }
            if file.fileId != node.file?.fileId {
                node.file = file
                node.setSignal(chatMessageSticker(account: item.account, file: file, small: true))
                node.loadDisposable.set(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: true)).start())
            }
            if let dimensions = file.dimensions {
                let imageSize = dimensions.aspectFitted(itemSize)
                node.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                node.frame = CGRect(origin: CGPoint(x: offset, y: 48.0 + topOffset), size: imageSize)
                offset += imageSize.width + 4.0
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
