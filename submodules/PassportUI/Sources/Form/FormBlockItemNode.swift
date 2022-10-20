import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

protocol FormBlockItemNodeProto {
    
}

enum FormBlockItemInset {
    case regular
    case custom(CGFloat)
}

class FormBlockItemNode<Item: FormControllerItem>: ASDisplayNode, FormControllerItemNode, FormBlockItemNodeProto {
    private let topSeparatorInset: FormBlockItemInset
    
    private let highlightedBackgroundNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let selectionButtonNode: HighlightTrackingButtonNode
    
    init(selectable: Bool, topSeparatorInset: FormBlockItemInset) {
        self.topSeparatorInset = topSeparatorInset
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.selectionButtonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        
        if selectable {
            self.selectionButtonNode.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.highlightedBackgroundNode.alpha = 1.0
                    } else {
                        strongSelf.highlightedBackgroundNode.alpha = 0.0
                        strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    }
                }
            }
            self.addSubnode(self.selectionButtonNode)
            self.selectionButtonNode.addTarget(self, action: #selector(self.selectionButtonPressed), forControlEvents: .touchUpInside)
        }
    }
    
    final func updateInternal(item: Item, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        let (preLayout, apply) = self.update(item: item, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
        return (preLayout, { params in
            self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
            self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
            
            let height = apply(params)
            
            let topSeparatorInset: CGFloat
            switch previousNeighbor {
                case let .item(item) where item is FormBlockItemNodeProto:
                    switch self.topSeparatorInset {
                        case .regular:
                            topSeparatorInset = 16.0
                        case let .custom(value):
                            topSeparatorInset = value
                    }
                default:
                    topSeparatorInset = 0.0
            }
            
            switch nextNeighbor {
                case let .item(item) where item is FormBlockItemNodeProto:
                    self.bottomSeparatorNode.isHidden = true
                default:
                    self.bottomSeparatorNode.isHidden = false
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.selectionButtonNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: topSeparatorInset, y: 0.0), size: CGSize(width: width - topSeparatorInset, height: UIScreenPixel)))
            transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
            
            return height
        })
    }
    
    func update(item: Item, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        preconditionFailure()
    }
    
    @objc private func selectionButtonPressed() {
        self.selected()
    }
    
    func selected() {
    }
    
    var preventsTouchesToOtherItems: Bool {
        return false
    }
    
    func touchesToOtherItemsPrevented() {
    }
}

