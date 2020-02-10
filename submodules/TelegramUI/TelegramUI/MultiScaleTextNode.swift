import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class MultiScaleTextStateNode: ASDisplayNode {
    let textNode: ImmediateTextNode
    
    var currentLayout: MultiScaleTextLayout?
    
    override init() {
        self.textNode = ImmediateTextNode()
        
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
    
    func updateLayout(states: [AnyHashable: MultiScaleTextState]) -> [AnyHashable: MultiScaleTextLayout] {
        assert(Set(states.keys) == Set(self.stateNodes.keys))
        
        var result: [AnyHashable: MultiScaleTextLayout] = [:]
        for (key, state) in states {
            if let node = self.stateNodes[key] {
                node.textNode.attributedText = state.attributedText
                let nodeSize = node.textNode.updateLayout(state.constrainedSize)
                let nodeLayout = MultiScaleTextLayout(size: nodeSize)
                node.currentLayout = nodeLayout
                node.textNode.frame = CGRect(origin: CGPoint(x: -nodeSize.width / 2.0, y: -nodeSize.height / 2.0), size: nodeSize)
                result[key] = nodeLayout
            }
        }
        return result
    }
    
    func update(stateFractions: [AnyHashable: CGFloat], transition: ContainedViewLayoutTransition) {
        var fractionSum: CGFloat = 0.0
        for (_, fraction) in stateFractions {
            fractionSum += fraction
        }
        for (key, fraction) in stateFractions {
            if let node = self.stateNodes[key], let nodeLayout = node.currentLayout {
                transition.updateAlpha(node: node, alpha: fraction / fractionSum)
            }
        }
    }
}
