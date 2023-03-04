import Foundation
import UIKit
import Display
import AsyncDisplayKit
import CallsEmoji

private let labelFont = Font.regular(22.0)
private let animationNodesCount = 4

private class EmojiSlotNode: ASDisplayNode {
    var emoji: String = "" {
        didSet {
            self.node.attributedText = NSAttributedString(string: emoji, font: labelFont, textColor: .black)
            let _ = self.node.updateLayout(CGSize(width: 100.0, height: 100.0))
        }
    }
    
    private let maskNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let node: ImmediateTextNode
    private let animationNode: ImmediateTextNode
    
    override init() {
        self.maskNode = ASDisplayNode()
        self.containerNode = ASDisplayNode()
        self.node = ImmediateTextNode()
        self.animationNode = ImmediateTextNode()
                    
        super.init()
        
        let maskLayer = CAGradientLayer()
        maskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        maskLayer.locations = [0.0, 0.2, 0.8, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.maskNode.layer.mask = maskLayer
        
        self.addSubnode(self.maskNode)
        self.maskNode.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.node)
        self.containerNode.addSubnode(animationNode)
    }
    
    func animateIn() {
            node.attributedText = NSAttributedString(string: emoji, font: labelFont, textColor: .black)
            let _ = node.updateLayout(CGSize(width: 100.0, height: 100.0))
    }
    
    override func layout() {
        super.layout()
        
        let maskInset: CGFloat = 4.0
        let maskFrame = self.bounds.insetBy(dx: 0.0, dy: -maskInset)
        self.maskNode.frame = maskFrame
        self.maskNode.layer.mask?.frame = CGRect(origin: CGPoint(), size: maskFrame.size)
        
        let spacing: CGFloat = 2.0
        let containerSize = CGSize(width: self.bounds.width, height: self.bounds.height + spacing)
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerSize)
        
        self.node.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        node.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.bounds.size)
    }
}

final class NewCallControllerKeyButton: HighlightableButtonNode {
    private let containerNode: ASDisplayNode
    private let nodes: [EmojiSlotNode]
    
    var key: String = "" {
        didSet {
            var index = 0
            for emoji in self.key {
                guard index < 4 else {
                    return
                }
                self.nodes[index].emoji = String(emoji)
                index += 1
            }
        }
    }
    
    init() {
        self.containerNode = ASDisplayNode()
        self.nodes = (0 ..< 4).map { _ in EmojiSlotNode() }
       
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.containerNode)
        self.nodes.forEach({ self.containerNode.addSubnode($0) })
    }
        
    func animateIn() {
        self.layoutIfNeeded()
        self.containerNode.alpha = 1.0
        let duration: Double = 0.75
        var distance: Double = 30
        for node in self.nodes {
            node.animateIn()
            node.layer.animate(from: (node.layer.position.x - distance) as NSNumber, to: (node.layer.position.x) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: duration)
            node.layer.position.x = node.layer.position.x
            distance -= 0.25 * distance
            node.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
    }
    
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 114.0, height: 26.0)
    }
    
    override func layout() {
        super.layout()
        
        self.containerNode.frame = self.bounds
        var index = 0
        let nodeSize = CGSize(width: 29.0, height: self.bounds.size.height)
        for node in self.nodes {
            node.frame = CGRect(origin: CGPoint(x: CGFloat(index) * nodeSize.width, y: 0.0), size: nodeSize)
            index += 1
        }
    }
}

