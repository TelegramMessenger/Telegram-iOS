import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import AccountContext
import TextFormat

final class EmojisChatInputPanelItem: ListViewItem {
    fileprivate let context: AccountContext
    fileprivate let theme: PresentationTheme
    fileprivate let symbol: String
    fileprivate let text: String
    fileprivate let file: TelegramMediaFile?
    fileprivate let animationCache: AnimationCache
    fileprivate let animationRenderer: MultiAnimationRenderer
    private let emojiSelected: (String, TelegramMediaFile?) -> Void
    
    let selectable: Bool = true
    
    public init(context: AccountContext, theme: PresentationTheme, symbol: String, text: String, file: TelegramMediaFile?, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, emojiSelected: @escaping (String, TelegramMediaFile?) -> Void) {
        self.context = context
        self.theme = theme
        self.symbol = symbol
        self.text = text
        self.file = file
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
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
        self.emojiSelected(self.symbol, self.file)
    }
}

private let textFont = Font.regular(32.0)

final class EmojisChatInputPanelItemNode: ListViewItemNode {
    static let itemSize = CGSize(width: 45.0, height: 45.0)
    private let symbolNode: TextNode
    private var emojiView: EmojiTextAttachmentView?
    
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
                    
                    if let file = item.file {
                        strongSelf.symbolNode.isHidden = true
                        
                        let emojiView: EmojiTextAttachmentView
                        if let current = strongSelf.emojiView {
                            emojiView = current
                        } else {
                            emojiView = EmojiTextAttachmentView(
                                context: item.context,
                                emoji: ChatTextInputTextCustomEmojiAttribute(
                                    interactivelySelectedFromPackId: nil,
                                    fileId: file.fileId.id,
                                    file: file
                                ),
                                file: file,
                                cache: item.animationCache,
                                renderer: item.animationRenderer,
                                placeholderColor: item.theme.list.mediaPlaceholderColor,
                                pointSize: CGSize(width: 40.0, height: 40.0)
                            )
                            emojiView.layer.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.emojiView = emojiView
                            strongSelf.view.addSubview(emojiView)
                            
                            let emojiSize = CGSize(width: 40.0, height: 40.0)
                            let emojiFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((EmojisChatInputPanelItemNode.itemSize.width - emojiSize.width) / 2.0) + 1.0, y: floorToScreenPixels((EmojisChatInputPanelItemNode.itemSize.height - emojiSize.height) / 2.0)), size: emojiSize)
                            
                            emojiView.center = emojiFrame.center
                            emojiView.bounds = CGRect(origin: CGPoint(), size: emojiFrame.size)
                        }
                    } else {
                        strongSelf.symbolNode.isHidden = false
                        
                        if let emojiView = strongSelf.emojiView {
                            strongSelf.emojiView = nil
                            emojiView.removeFromSuperview()
                        }
                    }
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
