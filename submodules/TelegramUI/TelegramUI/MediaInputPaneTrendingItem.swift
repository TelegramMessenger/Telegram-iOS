import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode

class MediaInputPaneTrendingItem: ListViewItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let interaction: TrendingPaneInteraction
    let info: StickerPackCollectionInfo
    let topItems: [StickerPackItem]
    let installed: Bool
    let unread: Bool
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: TrendingPaneInteraction, info: StickerPackCollectionInfo, topItems: [StickerPackItem], installed: Bool, unread: Bool) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.interaction = interaction
        self.info = info
        self.topItems = topItems
        self.installed = installed
        self.unread = unread
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MediaInputPaneTrendingItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { info in apply(synchronousLoads && info.isOnScreen) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? MediaInputPaneTrendingItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false)
                        })
                    }
                }
            }
        }
    }
}

private let titleFont = Font.bold(16.0)
private let statusFont = Font.regular(15.0)
private let buttonFont = Font.medium(13.0)

final class TrendingTopItemNode: ASDisplayNode {
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    public private(set) var file: TelegramMediaFile? = nil
    private var itemSize: CGSize?
    private let loadDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    var visibility: Bool = false {
        didSet {
            if oldValue != self.visibility {
                self.animationNode?.visibility = self.visibility
            }
        }
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.loadDisposable.dispose()
    }
    
    func setup(account: Account, item: StickerPackItem, itemSize: CGSize, synchronousLoads: Bool) {
        self.file = item.file
        self.itemSize = itemSize
        
        if item.file.isAnimatedSticker {
            let animationNode: AnimatedStickerNode
            if let currentAnimationNode = self.animationNode {
                animationNode = currentAnimationNode
            } else {
                animationNode = AnimatedStickerNode()
                animationNode.transform = self.imageNode.transform
                animationNode.visibility = self.visibility
                self.addSubnode(animationNode)
                self.animationNode = animationNode
            }
            animationNode.started = { [weak self] in
                self?.imageNode.alpha = 0.0
            }
            let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
            animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .cached)
            self.loadDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: item.file.resource).start())
        } else {
            self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: true, synchronousLoad: synchronousLoads), attemptSynchronously: synchronousLoads)
            
            if let currentAnimationNode = self.animationNode {
                self.animationNode = nil
                currentAnimationNode.removeFromSupernode()
            }
            self.loadDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: chatMessageStickerResource(file: item.file, small: true)).start())
        }
    }
    
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
    
    override func layout() {
        super.layout()
        
        if let dimensions = self.file?.dimensions, let itemSize = self.itemSize {
            let imageSize = dimensions.cgSize.aspectFitted(itemSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
        }
        
        self.imageNode.frame = self.bounds
        self.animationNode?.updateLayout(size: self.bounds.size)
    }
}

class MediaInputPaneTrendingItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let unreadNode: ASImageNode
    private let installTextNode: TextNode
    private let installBackgroundNode: ASImageNode
    private let installButtonNode: HighlightTrackingButtonNode
    private var itemNodes: [TrendingTopItemNode]
    
    private var item: MediaInputPaneTrendingItem?
    private let preloadDisposable = MetaDisposable()
    private let readDisposable = MetaDisposable()
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if isVisible != wasVisible {
                for node in self.itemNodes {
                    node.visibility = isVisible
                }
                
                if isVisible {
                    if let item = self.item, item.unread {
                        self.readDisposable.set((
                            markFeaturedStickerPacksAsSeenInteractively(postbox: item.account.postbox, ids: [item.info.id])
                            |> delay(1.0, queue: .mainQueue())
                        ).start())
                    }
                } else {
                    self.readDisposable.set(nil)
                }
            }
        }
    }
    
    init() {
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
        
        super.init(layerBacked: false, dynamicBounce: false)
        
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
        self.readDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func asyncLayout() -> (_ item: MediaInputPaneTrendingItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeInstallLayout = TextNode.asyncLayout(self.installTextNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        
        let currentItem = self.item
        
        return { item, params in
            var updateButtonBackgroundImage: UIImage?
            if currentItem?.theme !== item.theme {
                updateButtonBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddPackButtonImage(item.theme)
            }
            let unreadImage = PresentationResourcesItemList.stickerUnreadDotImage(item.theme)
            
            let leftInset: CGFloat = 14.0
            let rightInset: CGFloat = 16.0
            
            let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_Install, font: buttonFont, textColor: item.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.info.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0 - installLayout.size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.StickerPack_StickerCount(item.info.count), font: statusFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize = CGSize(width: params.width, height: 120.0)
            let insets: UIEdgeInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            var topItems = item.topItems
            if topItems.count > 5 {
                topItems.removeSubrange(5 ..< topItems.count)
            }
            
            return (layout, { [weak self] synchronousLoads in
                if let strongSelf = self {
                    if (item.topItems.count < Int(item.info.count) || item.topItems.count < 5) && strongSelf.item?.info.id != item.info.id {
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
                    let buttonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - installWidth, y: 4.0), size: CGSize(width: installWidth, height: 26.0))
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
                    
                    let titleFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 2.0), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: 23.0), size: descriptionLayout.size)
                    
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
                    
                    let isVisible = strongSelf.visibility != .none
                    
                    for i in 0 ..< topItems.count {
                        let file = topItems[i].file
                        let node: TrendingTopItemNode
                        if i < strongSelf.itemNodes.count {
                            node = strongSelf.itemNodes[i]
                        } else {
                            node = TrendingTopItemNode()
                            node.visibility = isVisible
                            strongSelf.itemNodes.append(node)
                            strongSelf.addSubnode(node)
                        }
                        if file.fileId != node.file?.fileId {
                            node.setup(account: item.account, item: topItems[i], itemSize: itemSize, synchronousLoads: synchronousLoads)
                        }
                        if let dimensions = file.dimensions {
                            let imageSize = dimensions.cgSize.aspectFitted(itemSize)
                            node.frame = CGRect(origin: CGPoint(x: offset, y: 48.0), size: imageSize)
                            offset += itemSize.width + itemSpacing
                        }
                    }
                    
                    if topItems.count < strongSelf.itemNodes.count {
                        for i in (topItems.count ..< strongSelf.itemNodes.count).reversed() {
                            strongSelf.itemNodes[i].removeFromSupernode()
                            strongSelf.itemNodes.remove(at: i)
                        }
                    }
                    
                    strongSelf.updatePreviewing(animated: false)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc func installPressed() {
        if let item = self.item {
            item.interaction.installPack(item.info)
        }
    }

    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                item.interaction.openPack(item.info)
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
                let isPreviewing = item.interaction.getItemIsPreviewed(item.topItems[index])
                itemNode.updatePreviewing(animated: animated, isPreviewing: isPreviewing)
            }
            index += 1
        }
    }
}
