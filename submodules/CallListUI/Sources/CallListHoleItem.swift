import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

private let titleFont = Font.regular(17.0)

class CallListHoleItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let theme: PresentationTheme
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CallListHoleItemNode()
            node.relativePosition = (first: neighbors.previous == nil, last: neighbors.next == nil)
            node.insets = UIEdgeInsets()
            node.layoutForParams(params, item: self, neighbors: neighbors)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is CallListHoleItemNode)
            if let nodeValue = node() as? CallListHoleItemNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let first = neighbors.previous == nil
                    let last = neighbors.next == nil
                    
                    let (nodeLayout, apply) = layout(self, params, first, last)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                            if let nodeValue = node() as? CallListHoleItemNode {
                                nodeValue.updateBackgroundAndSeparatorsLayout()
                            }
                        })
                    }
                }
            }
        }
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class CallListHoleItemNode: ListViewItemNode {
    let separatorNode: ASDisplayNode
    let labelNode: TextNode
    
    var relativePosition: (first: Bool, last: Bool) = (false, false)
    
    required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(rgb: 0xc8c7cc)
        self.separatorNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.labelNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! CallListHoleItem, params, self.relativePosition.first, self.relativePosition.last)
        apply()
    }
    
    func asyncLayout() -> (_ item: CallListHoleItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let labelNodeLayout = TextNode.asyncLayout(self.labelNode)
        
        return { [weak self] item, params, first, last in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let (labelLayout, labelApply) = labelNodeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "", font: titleFont, textColor: item.theme.chatList.messageTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: baseWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = UIEdgeInsets()
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 68.0), insets: insets)
            
            let separatorInset: CGFloat
            if last {
                separatorInset = 0.0
            } else {
                separatorInset = 80.0 + params.leftInset
            }
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.relativePosition = (first, last)
                    
                    let _ = labelApply()
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.chatList.itemSeparatorColor
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: floor((params.width - labelLayout.size.width) / 2.0), y: floor((layout.contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: separatorInset, y: 68.0 - separatorHeight), size: CGSize(width: params.width - separatorInset, height: separatorHeight))
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                    strongSelf.updateBackgroundAndSeparatorsLayout()
                }
            })
        }
    }
    
    func updateBackgroundAndSeparatorsLayout() {
        //let size = self.bounds.size
        //let insets = self.insets
    }
}
