import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

/// Strip row for a TSupport canned-reply template match (D28): Question only, one line, tap
/// always inserts into the compose draft - there is no secondary "send immediately" mode the
/// way bot-command rows have an arrow button, so this is deliberately simpler than
/// `CommandChatInputPanelItem`.
final class SupportTemplateChatInputPanelItem: ListViewItem {
    // Neighbors only matter here as "is there one" (top/bottom merging), so nothing about
    // this item influences its neighbors - same as `CommandChatInputPanelItem`.
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    fileprivate let presentationData: ItemListPresentationData
    fileprivate let template: SupportTemplate
    fileprivate let templateSelected: (SupportTemplate) -> Void
    
    let selectable: Bool = true
    
    init(presentationData: ItemListPresentationData, template: SupportTemplate, templateSelected: @escaping (SupportTemplate) -> Void) {
        self.presentationData = presentationData
        self.template = template
        self.templateSelected = templateSelected
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = SupportTemplateChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (neighbors.previous != nil, neighbors.next != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? SupportTemplateChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (neighbors.previous != nil, neighbors.next != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    func selected(listView: ListView) {
        self.templateSelected(self.template)
    }
}

final class SupportTemplateChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 42.0
    
    private var item: SupportTemplateChatInputPanelItem?
    private let textNode: TextNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let activateAreaNode: AccessibilityAreaNode
    
    init() {
        self.textNode = TextNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = [.button]
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateAreaNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = item as? SupportTemplateChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: neighbors.previous != nil, bottom: neighbors.next != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: SupportTemplateChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let textFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 15.0 / 17.0))
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            
            let questionString = NSAttributedString(string: item.template.question, font: textFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: questionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: SupportTemplateChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    
                    let _ = textApply()
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    strongSelf.activateAreaNode.accessibilityLabel = item.template.question
                    strongSelf.activateAreaNode.frame = CGRect(origin: .zero, size: nodeLayout.size)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
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
}
