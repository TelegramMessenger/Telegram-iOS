import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class EmojisChatInputPanelItem: ListViewItem {
    fileprivate let theme: PresentationTheme
    fileprivate let symbol: String
    fileprivate let text: String
    private let emojiSelected: (String) -> Void
    
    let selectable: Bool = true
    
    public init(theme: PresentationTheme, symbol: String, text: String, emojiSelected: @escaping (String) -> Void) {
        self.theme = theme
        self.symbol = symbol
        self.text = text
        self.emojiSelected = emojiSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = EmojisChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? EmojisChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
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
        self.emojiSelected(self.symbol)
    }
}

private let textFont = Font.regular(32.0)

final class EmojisChatInputPanelItemNode: ListViewItemNode {
    static let itemSize = CGSize(width: 45.0, height: 45.0)
    private let symbolNode: TextNode
    
    init() {
        self.symbolNode = TextNode()
        self.symbolNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.symbolNode)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? EmojisChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: EmojisChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeSymbolLayout = TextNode.asyncLayout(self.symbolNode)
        return { [weak self] item, params, mergedTop, mergedBottom in
            let (symbolLayout, symbolApply) = makeSymbolLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(item.symbol)", font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: 50.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: EmojisChatInputPanelItemNode.itemSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    let _ = symbolApply()
                    strongSelf.symbolNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((EmojisChatInputPanelItemNode.itemSize.width - symbolLayout.size.width) / 2.0), y: 0.0), size: symbolLayout.size)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.symbolNode.alpha = 0.4
        } else {
            if animated {
                self.symbolNode.layer.animateAlpha(from: self.symbolNode.alpha, to: 1.0, duration: 0.4)
            }
            self.symbolNode.alpha = 1.0
        }
    }
}
