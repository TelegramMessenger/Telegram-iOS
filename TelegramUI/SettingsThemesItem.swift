import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore



class SettingsThemesItem: ListViewItem, ItemListItem {
    let account: Account
    let theme: PresentationTheme
    let title: String
    let sectionId: ItemListSectionId
    let action: () -> Void
    let openWallpaper: (TelegramWallpaper) -> Void
    let wallpapers: [TelegramWallpaper]
    
    init(account: Account, theme: PresentationTheme, title: String, sectionId: ItemListSectionId, action: @escaping () -> Void, openWallpaper: @escaping (TelegramWallpaper) -> Void, wallpapers: [TelegramWallpaper]) {
        self.account = account
        self.theme = theme
        self.title = title
        self.sectionId = sectionId
        self.action = action
        self.openWallpaper = openWallpaper
        self.wallpapers = wallpapers
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = SettingsThemesItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? SettingsThemesItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)

class SettingsThemesItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: TextNode
    let arrowNode: ASImageNode
    
    private var item: SettingsThemesItem?
    
    private var thumbnailNodes: [SettingsThemeWallpaperNode] = []
    
    var tag: Any? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.arrowNode)
        
        for i in 0 ..< 5 {
            let imageNode = SettingsThemeWallpaperNode()
            self.thumbnailNodes.append(imageNode)
            self.addSubnode(imageNode)
            let index = i
            imageNode.pressed = { [weak self] in
                if let strongSelf = self, let item = strongSelf.item {
                    if index < item.wallpapers.count {
                        item.openWallpaper(item.wallpapers[index])
                    }
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: SettingsThemesItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, width, neighbors in
            let textColor: UIColor = item.theme.list.itemPrimaryTextColor
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.title, font: titleFont, textColor: textColor), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let referenceImageSize = CGSize(width: 108.0, height: 163.0)
            
            let leftInset: CGFloat = 16.0
            let padding: CGFloat = 16.0
            let minSpacing: CGFloat = 7.0
            
            let imageCount = Int((width - padding * 2.0 + minSpacing) / (referenceImageSize.width + minSpacing))
            
            let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((width - padding * 2.0 - max(0.0, CGFloat(imageCount - 1) * minSpacing)) / CGFloat(imageCount)), height: referenceImageSize.height))
            
            let spacing = floor((width - padding * 2.0 - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount - 1))
            
            contentSize = CGSize(width: width, height: imageSize.height + 58.0)
            insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.arrowNode.image = updateArrowImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                        
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                    case .sameSection(false):
                        strongSelf.topStripeNode.isHidden = true
                    default:
                        strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = 16.0
                        bottomStripeOffset = -separatorHeight
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - titleLayout.size.height - 10.0), size: titleLayout.size)
                    if let arrowImage = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: width - 15.0 - arrowImage.size.width, y: contentSize.height - 26.0), size: arrowImage.size)
                    }
                    
                    let bounds = CGRect(origin: CGPoint(), size: contentSize)
                    
                    for i in 0 ..< strongSelf.thumbnailNodes.count {
                        
                        /*if (i >= (int)_imageViews.count)
                        {
                            imageView = [[TGRemoteImageView alloc] init];
                            imageView.fadeTransition = true;
                            imageView.fadeTransitionDuration = 0.2;
                            imageView.clipsToBounds = true;
                            imageView.contentMode = UIViewContentModeScaleAspectFill;
                            
                            imageViewContainer = [[UIButton alloc] init];
                            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                            [imageViewContainer addSubview:imageView];
                            
                            UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ModernWallpaperSelectedIndicator.png"]];
                            checkView.frame = CGRectOffset(checkView.frame, imageView.frame.size.width - 5.0f - checkView.frame.size.width, imageView.frame.size.height - 4.0f - checkView.frame.size.height);
                            checkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
                            checkView.tag = 100;
                            [imageView addSubview:checkView];
                            
                            [self addSubview:imageViewContainer];
                            [_imageViews addObject:imageViewContainer];
                            
                            [imageViewContainer addTarget:self action:@selector(imageViewTapped:) forControlEvents:UIControlEventTouchUpInside];
                        }
                        else
                        {
                            imageViewContainer = _imageViews[i];
                            imageView = [imageViewContainer.subviews firstObject];
                        }
                        
                        imageView.contentHints = _syncLoad ? TGRemoteImageContentHintLoadFromDiskSynchronously : 0;
                        
                        imageViewContainer.hidden = false;*/
                        
                        let itemFrame = CGRect(x: (i == imageCount - 1 && item.wallpapers.count >= 3) ? (bounds.size.width - padding - imageSize.width) : (padding + CGFloat(i) * (imageSize.width + spacing)), y: 15.0, width: imageSize.width, height: imageSize.height)
                        strongSelf.thumbnailNodes[i].frame = itemFrame
                        
                        let imageNode = strongSelf.thumbnailNodes[i]
                        if i >= item.wallpapers.count || i >= imageCount {
                            imageNode.isHidden = true
                        } else {
                            imageNode.isHidden = false
                            imageNode.setWallpaper(account: item.account, wallpaper: item.wallpapers[i], size: itemFrame.size)
                        }
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
