import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import PhotoResources
import Postbox

class BotCheckoutHeaderItem: ListViewItem, ItemListItem {
    let account: Account
    let theme: PresentationTheme
    let invoice: TelegramMediaInvoice
    let botName: String
    let sectionId: ItemListSectionId
    
    init(account: Account, theme: PresentationTheme, invoice: TelegramMediaInvoice, botName: String, sectionId: ItemListSectionId) {
        self.account = account
        self.theme = theme
        self.invoice = invoice
        self.botName = botName
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BotCheckoutHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? BotCheckoutHeaderItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    let selectable: Bool = false
}

private let titleFont = Font.semibold(16.0)
private let textFont = Font.regular(14.0)

class BotCheckoutHeaderItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let imageNode: TransformImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let botNameNode: TextNode
    
    private var item: BotCheckoutHeaderItem?
    
    private let fetchDisposable = MetaDisposable()
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.botNameNode = TextNode()
        self.botNameNode.isUserInteractionEnabled = false
        self.botNameNode.contentMode = .left
        self.botNameNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.botNameNode)
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    func asyncLayout() -> (_ item: BotCheckoutHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeBotNameLayout = TextNode.asyncLayout(self.botNameNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let previousPhoto = currentItem?.invoice.photo
            var imageUpdated = false
            if let previousPhoto = previousPhoto, let photo = item.invoice.photo {
                if !previousPhoto.isEqual(to: photo) {
                    imageUpdated = true
                }
            } else if (previousPhoto != nil) != (item.invoice.photo != nil) {
                imageUpdated = true
            }
            
            let textColor = item.theme.list.itemPrimaryTextColor
            
            let contentInsets = UIEdgeInsets(top: 15.0, left: 15.0 + params.leftInset, bottom: 15.0, right: 15.0 + params.rightInset)
            let separatorHeight = UIScreenPixel
            let titleTextSpacing: CGFloat = 1.0
            let textBotNameSpacing: CGFloat = 3.0
            let imageTextSpacing: CGFloat = 15.0
            
            let imageSize = CGSize(width: 134.0, height: 134.0)
            
            let maxTextHeight = imageSize.height
            var maxTextWidth = params.width - contentInsets.left - contentInsets.right
            
            var imageApply: (() -> Void)?
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedFetchSignal: Signal<FetchResourceSourceType, FetchResourceError>?
            if let photo = item.invoice.photo, let dimensions = photo.dimensions {
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: dimensions.cgSize.aspectFilled(imageSize), boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                imageApply = makeImageLayout(arguments)
                maxTextWidth = max(1.0, maxTextWidth - imageSize.width - imageTextSpacing)
                if imageUpdated {
                    updatedImageSignal = chatWebFileImage(account: item.account, file: photo)
                    updatedFetchSignal = fetchedMediaResource(mediaBox: item.account.postbox.mediaBox, reference: .standalone(resource: photo.resource))
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.invoice.title, font: titleFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (botNameLayout, botNameApply) = makeBotNameLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.botName, font: textFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.invoice.description, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: maxTextHeight - titleLayout.size.height - titleTextSpacing - botNameLayout.size.height - textBotNameSpacing), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentHeight: CGFloat
            if let _ = imageApply {
                contentHeight = contentInsets.top + contentInsets.bottom + imageSize.height
            } else {
                contentHeight = contentInsets.top + contentInsets.bottom + titleLayout.size.height + titleTextSpacing + textLayout.size.height + textBotNameSpacing + botNameLayout.size.height
            }
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = botNameApply()
                    
                    if let imageApply = imageApply {
                        let _ = imageApply()
                        if let updatedImageSignal = updatedImageSignal {
                            strongSelf.imageNode.setSignal(updatedImageSignal)
                        }
                        if let updatedFetchSignal = updatedFetchSignal {
                            strongSelf.fetchDisposable.set(updatedFetchSignal.start())
                        }
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.imageNode.isHidden = true
                    }
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: imageSize)
                    
                    /*if strongSelf.backgroundNode.supernode != nil {
                        strongSelf.backgroundNode.removeFromSupernode()
                    }*/
                    if strongSelf.topStripeNode.supernode != nil {
                        strongSelf.topStripeNode.removeFromSupernode()
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
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
                    switch neighbors.bottom {
                        case .sameSection(false):
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height - separatorHeight), size: CGSize(width: params.width, height: separatorHeight))
                    
                    var titleFrame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: titleLayout.size)
                    if let _ = imageApply {
                        titleFrame.origin.x += imageSize.width + imageTextSpacing
                    }
                    strongSelf.titleNode.frame = titleFrame
                    
                    let textFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleTextSpacing), size: textLayout.size)
                    strongSelf.textNode.frame = textFrame
                    
                    strongSelf.botNameNode.frame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.maxY + textBotNameSpacing), size: botNameLayout.size)

                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: contentSize.height))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
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
