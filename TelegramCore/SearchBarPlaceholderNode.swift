import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private func generateBackground() -> UIImage? {
    let diameter: CGFloat = 8.0
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(0xededed).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: true)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private let searchBarBackground = generateBackground()

private class SearchBarPlaceholderNodeLayer: CALayer {
}

private class SearchBarPlaceholderNodeView: UIView {
    override static var layerClass: AnyClass {
        return SearchBarPlaceholderNodeLayer.self
    }
}

class SearchBarPlaceholderNode: ASDisplayNode, ASEditableTextNodeDelegate {
    var activate: (() -> Void)?
    
    let backgroundNode: ASImageNode
    let labelNode: TextNode
    
    var placeholderString: NSAttributedString?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = false
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = searchBarBackground
        
        self.labelNode = TextNode()
        self.labelNode.isOpaque = true
        self.labelNode.isLayerBacked = true
        self.labelNode.backgroundColor = UIColor(0xededed)
        
        super.init()
        /*super.init(viewBlock: {
            return SearchBarPlaceholderNodeView()
        }, didLoad: nil)*/
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        
        self.backgroundNode.isUserInteractionEnabled = true
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.backgroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTap(_:))))
    }
    
    func asyncLayout() -> (placeholderString: NSAttributedString?, constrainedSize: CGSize) -> (() -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { placeholderString, constrainedSize in
            let (labelLayoutResult, labelApply) = labelLayout(attributedString: placeholderString, backgroundColor: UIColor(0xededed), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, cutout: nil)
            
            return { [weak self] in
                if let strongSelf = self {
                    let _ = labelApply()
                    
                    strongSelf.placeholderString = placeholderString
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - labelLayoutResult.size.width) / 2.0), y: floor((28.0 - labelLayoutResult.size.height) / 2.0) + 2.0), size: labelLayoutResult.size)
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: 28.0))
                }
            }
        }
    }
    
    @objc private func backgroundTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let activate = self.activate {
                activate()
            }
        }
    }
}
