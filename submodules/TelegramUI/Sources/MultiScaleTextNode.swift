import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class MultiScaleTextStateNode: ASDisplayNode {
    let textNode: ImmediateTextNode
    
    var currentLayout: MultiScaleTextLayout?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
}

final class MultiScaleTextState {
    let attributedText: NSAttributedString
    let constrainedSize: CGSize
    
    init(attributedText: NSAttributedString, constrainedSize: CGSize) {
        self.attributedText = attributedText
        self.constrainedSize = constrainedSize
    }
}

struct MultiScaleTextLayout {
    var size: CGSize
}

final class MultiScaleTextNode: ASDisplayNode {
    private let stateNodes: [AnyHashable: MultiScaleTextStateNode]
    
    init(stateKeys: [AnyHashable]) {
        self.stateNodes = Dictionary(stateKeys.map { ($0, MultiScaleTextStateNode()) }, uniquingKeysWith: { lhs, _ in lhs })
        
        super.init()
        
        for (_, node) in self.stateNodes {
            self.addSubnode(node)
        }
    }
    
    func stateNode(forKey key: AnyHashable) -> ASDisplayNode? {
        return self.stateNodes[key]?.textNode
    }
    
    func updateLayout(states: [AnyHashable: MultiScaleTextState], mainState: AnyHashable) -> [AnyHashable: MultiScaleTextLayout] {
        assert(Set(states.keys) == Set(self.stateNodes.keys))
        assert(states[mainState] != nil)
        
        var result: [AnyHashable: MultiScaleTextLayout] = [:]
        var mainLayout: MultiScaleTextLayout?
        for (key, state) in states {
            if let node = self.stateNodes[key] {
                node.textNode.attributedText = state.attributedText
                let nodeSize = node.textNode.updateLayout(state.constrainedSize)
                let nodeLayout = MultiScaleTextLayout(size: nodeSize)
                if key == mainState {
                    mainLayout = nodeLayout
                }
                node.currentLayout = nodeLayout
                result[key] = nodeLayout
            }
        }
        if let mainLayout = mainLayout {
            let mainBounds = CGRect(origin: CGPoint(x: -mainLayout.size.width / 2.0, y: -mainLayout.size.height / 2.0), size: mainLayout.size)
            for (key, _) in states {
                if let node = self.stateNodes[key], let nodeLayout = result[key] {
                    node.textNode.frame = CGRect(origin: CGPoint(x: mainBounds.minX, y: mainBounds.minY + floor((mainBounds.height - nodeLayout.size.height) / 2.0)), size: nodeLayout.size)
                }
            }
        }
        return result
    }
    
    func update(stateFractions: [AnyHashable: CGFloat], alpha: CGFloat = 1.0, transition: ContainedViewLayoutTransition) {
        var fractionSum: CGFloat = 0.0
        for (_, fraction) in stateFractions {
            fractionSum += fraction
        }
        for (key, fraction) in stateFractions {
            if let node = self.stateNodes[key], let _ = node.currentLayout {
                if !transition.isAnimated {
                    node.layer.removeAllAnimations()
                }
                transition.updateAlpha(node: node, alpha: fraction / fractionSum * alpha)
            }
        }
    }
}
