import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import TelegramCore

private let transactionIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

class WalletInfoTransactionItem: ListViewItem {
    let theme: PresentationTheme
    let walletTransaction: WalletTransaction
    let action: () -> Void
    
    init(theme: PresentationTheme, walletTransaction: WalletTransaction, action: @escaping () -> Void) {
        self.theme = theme
        self.walletTransaction = walletTransaction
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletInfoTransactionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem != nil, nextItem != nil)
            
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
            if let nodeValue = node() as? WalletInfoTransactionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, previousItem != nil, nextItem != nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
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

private let titleFont = Font.medium(17.0)
private let textFont = Font.monospace(15.0)
private let dateFont = Font.regular(14.0)
private let directionFont = Font.regular(15.0)

class WalletInfoTransactionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: TextNode
    private let directionNode: TextNode
    private let iconNode: ASImageNode
    private let textNode: TextNode
    private let dateNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: WalletInfoTransactionItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.directionNode = TextNode()
        self.directionNode.isUserInteractionEnabled = false
        self.directionNode.contentMode = .left
        self.directionNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.contentMode = .left
        self.dateNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.directionNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.dateNode)
        
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: WalletInfoTransactionItem, _ params: ListViewItemLayoutParams, _ hasPrevious: Bool, _ hasNext: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDirectionLayout = TextNode.asyncLayout(self.directionNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        
        let currentItem = self.item
        
        return { item, params, hasPrevious, hasNext in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            let iconImage: UIImage? = transactionIcon
            let iconSize = iconImage?.size ?? CGSize(width: 10.0, height: 10.0)
            
            let leftInset = 16.0 + params.leftInset
            
            let title: String
            let directionText: String
            let titleColor: UIColor
            let transferredValue = item.walletTransaction.transferredValue
            var text: String = ""
            if transferredValue <= 0 {
                title = "\(formatBalanceText(transferredValue))"
                titleColor = item.theme.list.itemPrimaryTextColor
                if item.walletTransaction.outMessages.isEmpty {
                    directionText = ""
                    text = "Empty Transaction"
                } else {
                    directionText = "to"
                    for message in item.walletTransaction.outMessages {
                        if !text.isEmpty {
                            text.append("\n")
                        }
                        text.append(message.destination)
                    }
                }
            } else {
                title = "+\(formatBalanceText(transferredValue))"
                titleColor = item.theme.chatList.secretTitleColor
                directionText = "from"
                if let inMessage = item.walletTransaction.inMessage {
                    text = inMessage.source
                } else {
                    text = "<unknown>"
                }
            }
            let dateText = " "
            
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (directionLayout, directionApply) = makeDirectionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: directionText, font: directionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0 - dateLayout.size.width - directionLayout.size.width - iconSize.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            itemBackgroundColor = item.theme.list.plainBackgroundColor
            itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
            
            let topInset: CGFloat = 11.0
            let bottomInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 2.0
            
            contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + titleSpacing + textLayout.size.height + bottomInset)
            insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    //strongSelf.activateArea.accessibilityLabel = item.title
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        strongSelf.iconNode.image = iconImage
                    }
                    
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = dateApply()
                    let _ = directionApply()
                    
                    if strongSelf.backgroundNode.supernode != nil {
                        strongSelf.backgroundNode.removeFromSupernode()
                    }
                    if strongSelf.topStripeNode.supernode != nil {
                        strongSelf.topStripeNode.removeFromSupernode()
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                    }
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    let iconFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 3.0, y: titleFrame.minY + floor((titleFrame.height - iconSize.height) / 2.0) - 1.0), size: iconSize)
                    strongSelf.iconNode.frame = iconFrame
                    
                    let directionFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + 3.0, y: titleFrame.maxY - directionLayout.size.height - 1.0), size: directionLayout.size)
                    strongSelf.directionNode.frame = directionFrame
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: textLayout.size)
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - dateLayout.size.width, y: topInset), size: dateLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel * 2.0))
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
