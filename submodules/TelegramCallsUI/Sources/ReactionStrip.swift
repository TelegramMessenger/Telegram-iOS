import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class ReactionStrip: ASDisplayNode {
    private var labelValues: [String] = []
    private var labelNodes: [ImmediateTextNode] = []
    
    var selected: ((String) -> Void)?
    
    override init() {
        self.labelValues = ["🧡", "🎆", "🎈", "🎉", "👍", "👎", "💩", "💸", "😂"]
        
        super.init()
        
        for labelValue in self.labelValues {
            let labelNode = ImmediateTextNode()
            labelNode.attributedText = NSAttributedString(string: labelValue, font: Font.regular(20.0), textColor: .black)
            self.labelNodes.append(labelNode)
            self.addSubnode(labelNode)
            labelNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.labelTapGesture(_:))))
        }
    }
    
    @objc private func labelTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            for i in 0 ..< self.labelNodes.count {
                if self.labelNodes[i].view === recognizer.view {
                    self.selected?(self.labelValues[i])
                    break
                }
            }
        }
    }
    
    func update(size: CGSize) {
        var labelOrigin = CGPoint(x: 0.0, y: 0.0)
        for labelNode in self.labelNodes {
            let labelSize = labelNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            labelNode.frame = CGRect(origin: labelOrigin, size: labelSize)
            labelOrigin.x += labelSize.width + 10.0
        }
    }
}
