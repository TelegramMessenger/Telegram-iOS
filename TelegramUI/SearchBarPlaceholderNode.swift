import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private func generateBackground(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    let diameter: CGFloat = 8.0
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: true)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

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
    var foregroundColor: UIColor
    let labelNode: TextNode
    
    var placeholderString: NSAttributedString?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = false
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.foregroundColor = UIColor(0xededed)
        
        self.backgroundNode.image = generateBackground(backgroundColor: UIColor.white, foregroundColor: self.foregroundColor)
        
        self.labelNode = TextNode()
        self.labelNode.isOpaque = true
        self.labelNode.isLayerBacked = true
        self.labelNode.backgroundColor = self.foregroundColor
        
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
    
    func asyncLayout() -> (_ placeholderString: NSAttributedString?, _ constrainedSize: CGSize, _ foregoundColor: UIColor) -> (() -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let currentForegroundColor = self.foregroundColor
        
        return { placeholderString, constrainedSize, foregroundColor in
            let (labelLayoutResult, labelApply) = labelLayout(placeholderString, foregroundColor, 1, .end, constrainedSize, .natural, nil, UIEdgeInsets())
            
            var updatedBackgroundImage: UIImage?
            if !currentForegroundColor.isEqual(foregroundColor) {
                updatedBackgroundImage = generateBackground(backgroundColor: UIColor.white, foregroundColor: foregroundColor)
            }
            
            return { [weak self] in
                if let strongSelf = self {
                    let _ = labelApply()
                    
                    strongSelf.foregroundColor = foregroundColor
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                        strongSelf.labelNode.backgroundColor = foregroundColor
                    }
                    
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
