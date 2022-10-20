import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import AppBundle

class InviteLinkInviteHeaderItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId = 0
    
    let theme: PresentationTheme
    let title: String
    let text: String
    
    init(theme: PresentationTheme, title: String, text: String) {
        self.theme = theme
        self.title = title
        self.text = text
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = InviteLinkInviteHeaderItemNode()
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
            guard let nodeValue = node() as? InviteLinkInviteHeaderItemNode else {
                assertionFailure()
                return
            }
            
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

private let titleFont = Font.medium(23.0)
private let textFont = Font.regular(13.0)

class InviteLinkInviteHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let textNode: TextNode
    private let iconBackgroundNode: ASImageNode
    private let iconNode: ASImageNode
    
    private var item: InviteLinkInviteHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.iconBackgroundNode = ASImageNode()
        self.iconBackgroundNode.displaysAsynchronously = false
        self.iconBackgroundNode.displayWithoutProcessing = true
        
        self.iconNode = ASImageNode()
        self.iconNode.contentMode = .center
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconBackgroundNode)
        self.addSubnode(self.iconNode)
    }
    
    func asyncLayout() -> (_ item: InviteLinkInviteHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 40.0 + params.leftInset
            let topInset: CGFloat = 98.0
            let spacing: CGFloat = 8.0
            let bottomInset: CGFloat = 24.0
            
            var updatedTheme: PresentationTheme?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let titleAttributedText = NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let attributedText = NSAttributedString(string: item.text, font: textFont, textColor: item.theme.list.freeTextColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + spacing + textLayout.size.height + bottomInset)
        
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                    
                    if let _ = updatedTheme {
                        strongSelf.iconBackgroundNode.image = generateFilledCircleImage(diameter: 92.0, color: item.theme.actionSheet.controlAccentColor)
                        strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Links/LargeLink"), color: item.theme.list.itemCheckColors.foregroundColor)
                    }
                                        
                    let iconSize = CGSize(width: 92.0, height: 92.0)
                    strongSelf.iconBackgroundNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.iconNode.frame = strongSelf.iconBackgroundNode.frame
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: topInset + 8.0), size: titleLayout.size)
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - textLayout.size.width) / 2.0), y: topInset + 8.0 + titleLayout.size.height + spacing), size: textLayout.size)
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
}
