import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class VerticalListContextResultsChatInputPanelButtonItem: ListViewItem {
    fileprivate let theme: PresentationTheme
    fileprivate let title: String
    fileprivate let pressed: () -> Void
    
    public init(theme: PresentationTheme, title: String, pressed: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.pressed = pressed
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = VerticalListContextResultsChatInputPanelButtonItemNode()
            
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
            if let nodeValue = node() as? VerticalListContextResultsChatInputPanelButtonItemNode {
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
}

private let titleFont = Font.regular(15.0)

final class VerticalListContextResultsChatInputPanelButtonItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 32.0
    
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private var item: VerticalListContextResultsChatInputPanelButtonItem?
    
    init() {
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(buttonPressed), forControlEvents: .touchUpInside)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? VerticalListContextResultsChatInputPanelButtonItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: VerticalListContextResultsChatInputPanelButtonItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let titleString = NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemAccentColor)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 16.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.theme.list.plainBackgroundColor
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.size.width) / 2.0), y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0) + 2.0), size: titleLayout.size)
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width, height: UIScreenPixel))
                    
                    strongSelf.buttonNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                }
            })
        }
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.pressed()
        }
    }
}
