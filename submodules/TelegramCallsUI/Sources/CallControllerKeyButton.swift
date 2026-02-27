import Foundation
import UIKit
import Display
import AsyncDisplayKit
import CallsEmoji

private let labelFont = Font.regular(22.0)
private let animationNodesCount = 3

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
    private let animationNodes: [ImmediateTextNode]
    
    override init() {
        self.maskNode = ASDisplayNode()
        self.containerNode = ASDisplayNode()
        self.node = ImmediateTextNode()
        self.animationNodes = (0 ..< animationNodesCount).map { _ in ImmediateTextNode() }
                    
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
        self.animationNodes.forEach({ self.containerNode.addSubnode($0) })
    }
    
    func animateIn(duration: Double) {
        for node in self.animationNodes {
            node.attributedText = NSAttributedString(string: randomCallsEmoji(), font: labelFont, textColor: .black)
            let _ = node.updateLayout(CGSize(width: 100.0, height: 100.0))
        }
        self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -self.containerNode.frame.height + self.bounds.height), to: CGPoint(), duration: duration, delay: 0.1, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
    
    override func layout() {
        super.layout()
        
        let maskInset: CGFloat = 4.0
        let maskFrame = self.bounds.insetBy(dx: 0.0, dy: -maskInset)
        self.maskNode.frame = maskFrame
        self.maskNode.layer.mask?.frame = CGRect(origin: CGPoint(), size: maskFrame.size)
        
        let spacing: CGFloat = 2.0
        let containerSize = CGSize(width: self.bounds.width, height: self.bounds.height * CGFloat(animationNodesCount + 1) + spacing * CGFloat(animationNodesCount))
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: maskInset), size: containerSize)
        
        self.node.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        var offset: CGFloat = self.bounds.height + spacing
        for node in self.animationNodes {
            node.frame = CGRect(origin: CGPoint(x: 0.0, y: offset), size: self.bounds.size)
            offset += self.bounds.height + spacing
        }
    }
}

final class CallControllerKeyButton: HighlightableButtonNode {
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
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        var duration: Double = 0.75
        for node in self.nodes {
            node.animateIn(duration: duration)
            duration += 0.3
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
        self.nodes.forEach({ self.containerNode.addSubnode($0) })
    }
}
