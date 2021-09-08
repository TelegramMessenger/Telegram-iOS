import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class WebSearchBadgeNode: ASDisplayNode {
    private var fillColor: UIColor
    private var strokeColor: UIColor
    private var textColor: UIColor
    
    private let textNode: ASTextNode
    private let backgroundNode: ASImageNode
    
    private let font: UIFont = Font.with(size: 17.0, design: .round, weight: .bold)
    
    var text: String = "" {
        didSet {
            self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
            self.invalidateCalculatedLayout()
        }
    }
    
    convenience init(theme: PresentationTheme) {
        self.init(fillColor: theme.list.itemCheckColors.fillColor, strokeColor: theme.list.itemCheckColors.fillColor, textColor: theme.list.itemCheckColors.foregroundColor)
    }
    
    init(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 22.0, color: fillColor, strokeColor: strokeColor, strokeWidth: 1.0)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }
    
    func updateTheme(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 22.0, color: fillColor, strokeColor: strokeColor, strokeWidth: 1.0)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
    }
    
    func animateBump(incremented: Bool) {
        if incremented {
            let firstTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
            firstTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.2)
            firstTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.2, completion: { finished in
                if finished {
                    let secondTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
                    secondTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.0)
                    secondTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.0)
                }
            })
        } else {
            let firstTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
            firstTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 0.8)
            firstTransition.updateTransformScale(layer: self.textNode.layer, scale: 0.8, completion: { finished in
                if finished {
                    let secondTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
                    secondTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.0)
                    secondTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.0)
                }
            })
        }
    }
    
    func animateOut() {
        let timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        self.backgroundNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, delay: 0.0, timingFunction: timingFunction, removeOnCompletion: true, completion: nil)
        self.textNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, delay: 0.0, timingFunction: timingFunction, removeOnCompletion: true, completion: nil)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let badgeSize = self.textNode.measure(constrainedSize)
        let backgroundSize = CGSize(width: max(22.0, badgeSize.width + 12.0), height: 22.0)
        let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
        self.backgroundNode.frame = backgroundFrame
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: floorToScreenPixels((backgroundFrame.size.height - badgeSize.height) / 2.0) - UIScreenPixel), size: badgeSize)
        
        return backgroundSize
    }
}
