import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

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
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = BotCheckoutHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? BotCheckoutHeaderItemNode {
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
    
    let selectable: Bool = false
}

private let titleFont = Font.semibold(16.0)
private let textFont = Font.regular(14.0)

class BotCheckoutHeaderItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let imageNode: TransformImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let botNameNode: TextNode
    
    private var item: BotCheckoutHeaderItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.imageNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.botNameNode = TextNode()
        self.botNameNode.isLayerBacked = true
        self.botNameNode.contentMode = .left
        self.botNameNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.botNameNode)
    }
    
    func asyncLayout() -> (_ item: BotCheckoutHeaderItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeBotNameLayout = TextNode.asyncLayout(self.botNameNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item
        
        return { item, width, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let previousPhoto = currentItem?.invoice.photo
            var imageUpdated = false
            if let previousPhoto = previousPhoto, let photo = item.invoice.photo {
                if !previousPhoto.isEqual(photo) {
                    imageUpdated = true
                }
            } else if (previousPhoto != nil) != (item.invoice.photo != nil) {
                imageUpdated = true
            }
            
            let textColor = item.theme.list.itemPrimaryTextColor
            
            let contentInsets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
            let separatorHeight = UIScreenPixel
            let titleTextSpacing: CGFloat = 1.0
            let textBotNameSpacing: CGFloat = 3.0
            let imageTextSpacing: CGFloat = 15.0
            
            let imageSize = CGSize(width: 134.0, height: 134.0)
            
            let maxTextHeight = imageSize.height
            var maxTextWidth = width - contentInsets.left - contentInsets.right
            
            var imageApply: (() -> Void)?
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let photo = item.invoice.photo, let dimensions = photo.dimensions {
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(imageSize), boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                imageApply = makeImageLayout(arguments)
                maxTextWidth = max(1.0, maxTextWidth - imageSize.width - imageTextSpacing)
                if imageUpdated {
                    updatedImageSignal = chatWebFileImage(account: item.account, file: photo)
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.invoice.title, font: titleFont, textColor: textColor), nil, 1, .end, CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let (botNameLayout, botNameApply) = makeBotNameLayout(NSAttributedString(string: item.botName, font: textFont, textColor: item.theme.list.itemSecondaryTextColor), nil, 1, .end, CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let (textLayout, textApply) = makeTextLayout(NSAttributedString(string: item.invoice.description, font: textFont, textColor: textColor), nil, 0, .end, CGSize(width: maxTextWidth, height: maxTextHeight - titleLayout.size.height - titleTextSpacing - botNameLayout.size.height - textBotNameSpacing), .natural, nil, UIEdgeInsets())
            
            let contentHeight: CGFloat
            if let _ = imageApply {
                contentHeight = contentInsets.top + contentInsets.bottom + imageSize.height
            } else {
                contentHeight = contentInsets.top + contentInsets.bottom + titleLayout.size.height + titleTextSpacing + textLayout.size.height + textBotNameSpacing + botNameLayout.size.height
            }
            
            let contentSize = CGSize(width: width, height: contentHeight)
            let insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = botNameApply()
                    
                    if let imageApply = imageApply {
                        let _ = imageApply()
                        if let updatedImageSignal = updatedImageSignal {
                            strongSelf.imageNode.setSignal(account: item.account, signal: updatedImageSignal)
                        }
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.imageNode.isHidden = true
                    }
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: imageSize)
                    
                    if strongSelf.backgroundNode.supernode != nil {
                        strongSelf.backgroundNode.removeFromSupernode()
                    }
                    if strongSelf.topStripeNode.supernode != nil {
                        strongSelf.topStripeNode.removeFromSupernode()
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                    }
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height - separatorHeight), size: CGSize(width: width, height: separatorHeight))
                    
                    var titleFrame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: titleLayout.size)
                    if let _ = imageApply {
                        titleFrame.origin.x += imageSize.width + imageTextSpacing
                    }
                    strongSelf.titleNode.frame = titleFrame
                    
                    let textFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleTextSpacing), size: textLayout.size)
                    strongSelf.textNode.frame = textFrame
                    
                    strongSelf.botNameNode.frame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.maxY + textBotNameSpacing), size: botNameLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 44.0 + UIScreenPixel + UIScreenPixel))
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
