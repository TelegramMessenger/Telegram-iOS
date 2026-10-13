import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramCore
import AccountContext
import ItemListUI
import StickerResources

private enum RevealOptionKey: Int32 {
    case delete
}

private func webBrowserDomainExceptionPlaceholderLetter(_ title: String) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if let firstCharacter = trimmedTitle.first {
        return String(firstCharacter).uppercased()
    } else {
        return "#"
    }
}

final class WebBrowserDomainExceptionItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let systemStyle: ItemListSystemStyle
    let context: AccountContext
    let title: String
    let label: String
    let favicon: Int64?
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let deleted: (() -> Void)?
    
    init(
        presentationData: ItemListPresentationData,
        systemStyle: ItemListSystemStyle,
        context: AccountContext,
        title: String,
        label: String,
        favicon: Int64?,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        deleted: (() -> Void)?
    ) {
        self.presentationData = presentationData
        self.systemStyle = systemStyle
        self.context = context
        self.title = title
        self.label = label
        self.favicon = favicon
        self.sectionId = sectionId
        self.style = style
        self.deleted = deleted
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WebBrowserDomainExceptionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? WebBrowserDomainExceptionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = false
    
    func selected(listView: ListView){
    }
}

final class WebBrowserDomainExceptionItemNode: ItemListRevealOptionsItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    let iconNode: TransformImageNode
    private let iconPlaceholderNode: ASDisplayNode
    private let iconPlaceholderTextNode: TextNode
    let titleNode: TextNode
    let labelNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    private let iconDisposable = MetaDisposable()
    
    private var item: WebBrowserDomainExceptionItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var currentIconFile: TelegramMediaFile?
    
    override public var canBeSelected: Bool {
        return false
    }
    
    var tag: ItemListItemTag? = nil
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = TransformImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.iconPlaceholderNode = ASDisplayNode()
        self.iconPlaceholderNode.clipsToBounds = true
        self.iconPlaceholderNode.cornerRadius = 7.0

        self.iconPlaceholderTextNode = TextNode()
        self.iconPlaceholderTextNode.isUserInteractionEnabled = false
        self.iconPlaceholderTextNode.contentMode = .center
        self.iconPlaceholderTextNode.contentsScale = UIScreen.main.scale

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.iconPlaceholderNode)
        self.iconPlaceholderNode.addSubnode(self.iconPlaceholderTextNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.activateArea)
    }
    
    deinit {
        self.iconDisposable.dispose()
    }

    func asyncLayout() -> (_ item: WebBrowserDomainExceptionItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeIconPlaceholderTextLayout = TextNode.asyncLayout(self.iconPlaceholderTextNode)
                      
        let currentItem = self.item
        
        return { [weak self] item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset + 46.0
            
            let titleColor: UIColor = item.presentationData.theme.list.itemPrimaryTextColor
            let labelColor: UIColor = item.presentationData.theme.list.itemAccentColor
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let labelFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            let maxTitleWidth: CGFloat = params.width - params.rightInset - 20.0 - leftInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTitleWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor: labelColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTitleWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let iconPlaceholderText = webBrowserDomainExceptionPlaceholderLetter(item.title)
            let iconPlaceholderFont = Font.with(size: 17.0, design: .round, weight: .semibold)
            let (iconPlaceholderTextLayout, iconPlaceholderTextApply) = makeIconPlaceholderTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: iconPlaceholderText, font: iconPlaceholderFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: iconSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))

            let verticalInset: CGFloat
            switch item.systemStyle {
            case .glass:
                verticalInset = 11.0
            case .legacy:
                verticalInset = 11.0
            }
            let titleSpacing: CGFloat = 1.0
            
            let height: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + labelLayout.size.height
    
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.accessibilityValue = item.label
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.iconPlaceholderNode.backgroundColor = item.presentationData.theme.list.mediaPlaceholderColor
                    }
                    
                    if currentItem?.favicon != item.favicon {
                        strongSelf.currentIconFile = nil
                        strongSelf.iconDisposable.set(nil)
                        strongSelf.iconNode.reset()

                        if let favicon = item.favicon {
                            strongSelf.iconDisposable.set((item.context.engine.stickers.resolveInlineStickers(fileIds: [favicon])
                            |> deliverOnMainQueue).start(next: { [weak strongSelf] files in
                                guard let strongSelf, strongSelf.item?.favicon == favicon, let file = files[favicon] else {
                                    return
                                }
                                strongSelf.currentIconFile = file
                                var resolvedImageSize = iconSize
                                if let dimensions = file.dimensions?.cgSize {
                                    resolvedImageSize = dimensions.aspectFilled(resolvedImageSize)
                                }
                                if file.isAnimatedSticker || file.isVideoSticker {
                                    strongSelf.iconNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, userLocation: .other, file: file, small: false, size: resolvedImageSize, fetched: true))
                                } else {
                                    strongSelf.iconNode.setSignal(chatMessageSticker(account: item.context.account, userLocation: .other, file: file, small: false, fetched: true))
                                }
                                strongSelf.iconNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: resolvedImageSize, boundingSize: iconSize, intrinsicInsets: .zero))()
                                strongSelf.iconPlaceholderNode.isHidden = true
                                strongSelf.iconNode.isHidden = false
                            }))
                        }
                    }
                    var imageSize = iconSize
                    if strongSelf.currentIconFile?.fileId.id == item.favicon, let dimensions = strongSelf.currentIconFile?.dimensions?.cgSize {
                        imageSize = dimensions.aspectFilled(imageSize)
                    }
                    let hasResolvedIcon = item.favicon != nil && strongSelf.currentIconFile?.fileId.id == item.favicon
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    let _ = iconPlaceholderTextApply()
                    
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    case .blocks:
                        if strongSelf.backgroundNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                        }
                        if strongSelf.topStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                        }
                        if strongSelf.maskNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                        }
                        
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                hasTopCorners = true
                                strongSelf.topStripeNode.isHidden = hasCorners
                        }
                        let bottomStripeInset: CGFloat
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset - params.rightInset - separatorRightInset, height: separatorHeight))
                    }
                    
                    var centralContentHeight: CGFloat = titleLayout.size.height
                    centralContentHeight += titleSpacing
                    centralContentHeight += labelLayout.size.height
                       
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset + strongSelf.revealOffset, y: floor((height - centralContentHeight) / 2.0)), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    let labelFrame = CGRect(origin: CGPoint(x: leftInset + strongSelf.revealOffset, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + 16.0 + strongSelf.revealOffset, y: floorToScreenPixels((contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                    strongSelf.iconPlaceholderNode.frame = iconFrame
                    strongSelf.iconPlaceholderTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((iconSize.width - iconPlaceholderTextLayout.size.width) / 2.0) + UIScreenPixel, y: floorToScreenPixels((iconSize.height - iconPlaceholderTextLayout.size.height) / 2.0) + 1.0), size: iconPlaceholderTextLayout.size)
                    strongSelf.iconPlaceholderNode.isHidden = hasResolvedIcon
                    strongSelf.iconNode.isHidden = !hasResolvedIcon
                    strongSelf.iconNode.frame = iconFrame
                    
                    strongSelf.iconNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 7.0), imageSize: imageSize, boundingSize: iconSize, intrinsicInsets: .zero))()
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    var revealOptions: [ItemListRevealOption] = []
                    revealOptions.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, iconColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor, textColor: item.presentationData.theme.list.itemSecondaryTextColor))
                    strongSelf.setRevealOptions((left: [], right: revealOptions))
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let params = self.layoutParams {
            let leftInset: CGFloat = 16.0 + params.leftInset + 46.0
            
            var iconFrame = self.iconNode.frame
            iconFrame.origin.x = params.leftInset + 16.0 + offset
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
            
            var iconPlaceholderFrame = self.iconPlaceholderNode.frame
            iconPlaceholderFrame.origin.x = params.leftInset + 16.0 + offset
            transition.updateFrame(node: self.iconPlaceholderNode, frame: iconPlaceholderFrame)

            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var subtitleFrame = self.labelNode.frame
            subtitleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.labelNode, frame: subtitleFrame)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.delete.rawValue:
                    item.deleted?()
                default:
                    break
            }
        }
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
