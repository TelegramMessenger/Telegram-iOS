import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData

final class VerticalListContextResultsChatInputPanelButtonItem: ListViewItem {
    enum Style {
        case regular
        case round
    }
    
    fileprivate let theme: PresentationTheme
    fileprivate let style: Style
    fileprivate let title: String
    fileprivate let pressed: () -> Void
    
    public init(theme: PresentationTheme, style: Style = .regular, title: String, pressed: @escaping () -> Void) {
        self.theme = theme
        self.style = style
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

final class VerticalListContextResultsChatInputPanelButtonItemNode: ListViewItemNode {
    static func itemHeight(style: VerticalListContextResultsChatInputPanelButtonItem.Style) -> CGFloat {
        switch style {
        case .regular:
            return 32.0
        case .round:
            return 42.0
        }
    }
    
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: TextNode
    private let separatorNode: ASDisplayNode
    
    private var item: VerticalListContextResultsChatInputPanelButtonItem?
    
    init() {
        self.buttonNode = HighlightTrackingButtonNode()

        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
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
            let titleFont: UIFont
            switch item.style {
            case .regular:
                titleFont = Font.regular(15.0)
            case .round:
                titleFont = Font.regular(17.0)
            }
            
            let titleString = NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.chat.inputPanel.panelControlColor)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 16.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight(style: item.style)), insets: UIEdgeInsets())
            
            return (nodeLayout, { animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    
                    let titleOffsetY: CGFloat
                    switch item.style {
                    case .regular:
                        strongSelf.separatorNode.isHidden = !mergedBottom
                        titleOffsetY = 2.0
                    case .round:
                        strongSelf.separatorNode.isHidden = !mergedBottom
                        titleOffsetY = 1.0
                    }
                    
                    let _ = titleApply()
                    
                    let titleFrame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.size.width) / 2.0), y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0) + titleOffsetY), size: titleLayout.size)
                    animation.animator.updatePosition(layer: strongSelf.titleNode.layer, position: titleFrame.center, completion: nil)
                    strongSelf.titleNode.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                    
                    animation.animator.updateFrame(layer: strongSelf.separatorNode.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width, height: UIScreenPixel)), completion: nil)
                    
                    animation.animator.updateFrame(layer: strongSelf.buttonNode.layer, frame: CGRect(origin: CGPoint(), size: nodeLayout.contentSize), completion: nil)
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
