import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import ItemListUI

public class LimitedPermissionItem: ListViewItem {
    public let selectable: Bool = false
    
    let presentationData: ItemListPresentationData
    let text: String
    let action: (() -> Void)?
    
    public init(
        presentationData: ItemListPresentationData,
        text: String,
        action: (() -> Void)?
    ) {
        self.presentationData = presentationData
        self.text = text
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LimitedPermissionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, nil)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LimitedPermissionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

public class LimitedPermissionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let actionButton: HighlightableButtonNode
    private let actionButtonTitleNode: TextNode
    private let actionButtonBackgroundNode: ASImageNode
    
    private let textNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: LimitedPermissionItem?
    
    public override var canBeSelected: Bool {
        return false
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        self.actionButton = HighlightableButtonNode()
        
        self.actionButtonBackgroundNode = ASImageNode()
        self.actionButtonBackgroundNode.displaysAsynchronously = false
        
        self.actionButtonTitleNode = TextNode()
        self.actionButtonTitleNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateArea)
        self.addSubnode(self.actionButtonBackgroundNode)
        self.addSubnode(self.actionButtonTitleNode)
        self.addSubnode(self.actionButton)
        
        self.actionButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionButtonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionButtonBackgroundNode.alpha = 0.4
                    strongSelf.actionButtonTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionButtonTitleNode.alpha = 0.4
                } else {
                    strongSelf.actionButtonBackgroundNode.alpha = 1.0
                    strongSelf.actionButtonBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.actionButtonTitleNode.alpha = 1.0
                    strongSelf.actionButtonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.actionButton.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func asyncLayout() -> (_ item: LimitedPermissionItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors?) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.actionButtonTitleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            
            let textFont = Font.regular(15.0)
    
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let insets: UIEdgeInsets
            if let neighbors = neighbors {
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            } else {
                insets = UIEdgeInsets()
            }
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
            let itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
            
            let attributedText = NSAttributedString(string: item.text, font: textFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)

            let (buttonTextLayout, buttonTextApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Contacts_LimitedAccess_Manage, font: Font.semibold(15.0), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - buttonTextLayout.size.width - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        
            let contentSize = CGSize(width: params.width, height: textLayout.size.height + 20.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.accessibilityLabel = attributedText.string
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = strongSelf.accessibilityLabel
                
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        
                        strongSelf.actionButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 14.0 * 2.0, color: item.presentationData.theme.list.itemCheckColors.fillColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil)
                    }

                    let _ = textApply()
                    let _ = buttonTextApply()
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    
                    if let neighbors = neighbors {
                        switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                strongSelf.topStripeNode.isHidden = true
                        }
                    }
                    let bottomStripeInset: CGFloat
                    if let neighbors = neighbors {
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                strongSelf.bottomStripeNode.isHidden = true
                        }
                    } else {
                        bottomStripeInset = leftInset
                        strongSelf.topStripeNode.isHidden = true
                    }
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                                                            
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 10.0), size: textLayout.size)
                    
                    let actionButtonSize = CGSize(width: max(buttonTextLayout.size.width + 26.0, 40.0), height: 28.0)
                    let actionButtonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - actionButtonSize.width - 10.0, y: floor((layout.size.height - actionButtonSize.height) / 2.0)), size: actionButtonSize)
                    strongSelf.actionButton.frame = actionButtonFrame
                    strongSelf.actionButtonBackgroundNode.frame = actionButtonFrame
                    strongSelf.actionButtonTitleNode.frame = CGRect(origin: CGPoint(x: actionButtonFrame.minX + floorToScreenPixels((actionButtonFrame.width - buttonTextLayout.size.width) / 2.0), y: actionButtonFrame.minY + floorToScreenPixels((actionButtonFrame.height - buttonTextLayout.size.height) / 2.0) + 1.0 - UIScreenPixel), size: buttonTextLayout.size)
                }
            })
        }
    }

    public override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    public override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    public override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action?()
        }
    }
}
