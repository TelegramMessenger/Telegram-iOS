import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

private final class ChatChoosingStickerActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatChoosingStickerActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 2.0
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatChoosingStickerActivityIndicatorNodeParameters(color: color, progress: self.progress)
        } else {
            return nil
        }
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? ChatChoosingStickerActivityIndicatorNodeParameters else {
            return
        }
        
        context.setFillColor(UIColor.red.cgColor)
//        context.fill(bounds)
        
        let color = parameters.color
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)

        var heightProgress: CGFloat = parameters.progress * 4.0
        if heightProgress > 3.0 {
            heightProgress = 4.0 - heightProgress
        } else if heightProgress > 2.0 {
            heightProgress = heightProgress - 2.0
            heightProgress *= heightProgress
        } else if heightProgress > 1.0 {
            heightProgress = 2.0 - heightProgress
        } else {
            heightProgress *= heightProgress
        }
        
        var pupilProgress: CGFloat = parameters.progress * 4.0
        if pupilProgress > 2.0 {
            pupilProgress = 3.0 - pupilProgress
        }
        pupilProgress = min(1.0, max(0.0, pupilProgress))
        pupilProgress *= pupilProgress
        
        var positionProgress: CGFloat = parameters.progress * 2.0
        if positionProgress > 1.0 {
            positionProgress = 2.0 - positionProgress
        }
        
        let eyeWidth: CGFloat = 6.0
        let eyeHeight: CGFloat = 11.0 - 2.0 * heightProgress

        let eyeOffset: CGFloat = -1.0 + positionProgress * 2.0
        let leftCenter = CGPoint(x: bounds.width / 2.0 - eyeWidth - 1.0 + eyeOffset, y: bounds.height / 2.0)
        let rightCenter = CGPoint(x: bounds.width / 2.0 + 1.0 + eyeOffset, y: bounds.height / 2.0)
        
        let pupilSize: CGFloat = 4.0
        let pupilCenter = CGPoint(x: -1.0 + pupilProgress * 2.0, y: 0.0)
        
        context.strokeEllipse(in: CGRect(x: leftCenter.x - eyeWidth / 2.0, y: leftCenter.y - eyeHeight / 2.0, width: eyeWidth, height: eyeHeight))
        context.fillEllipse(in: CGRect(x: leftCenter.x - pupilSize / 2.0 + pupilCenter.x * eyeWidth / 4.0, y: leftCenter.y - pupilSize / 2.0, width: pupilSize, height: pupilSize))
        
        context.strokeEllipse(in: CGRect(x: rightCenter.x - eyeWidth / 2.0, y: rightCenter.y - eyeHeight / 2.0, width: eyeWidth, height: eyeHeight))
        context.fillEllipse(in: CGRect(x: rightCenter.x - pupilSize / 2.0 + pupilCenter.x * eyeWidth / 4.0, y: rightCenter.y - pupilSize / 2.0, width: pupilSize, height: pupilSize))
        
//        context.strokeEllipse(in: CGRect(x: 0.0, y: 0.0, width: 10.0, height: 20.0))
//        context.fillEllipse(in: CGRect(x: , y: , width: 4.0, height: 4.0))
      
    }
}

class ChatChoosingStickerActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatChoosingStickerActivityIndicatorNode
    private let advanced: Bool
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatChoosingStickerActivityIndicatorNode(color: color)
        
        var text = text
        self.advanced = text.string == "choosing sticker"
        if self.advanced {
            let mutable = text.mutableCopy() as? NSMutableAttributedString
            mutable?.replaceCharacters(in: NSMakeRange(2, 2), with: "     ")
            if let updated = mutable{
                text = updated
            }
        }
        
        super.init(text: text)
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func updateLayout(_ constrainedSize: CGSize, offset: CGFloat, alignment: NSTextAlignment) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        let indicatorSize = CGSize(width: 24.0, height: 16.0)
        let originX: CGFloat
        let indicatorOriginX: CGFloat
        if case .center = alignment {
            if self.advanced {
                originX = floorToScreenPixels((-size.width) / 2.0)
            } else {
                originX = floorToScreenPixels((indicatorSize.width - size.width) / 2.0)
            }
        } else {
            originX = indicatorSize.width
        }
        self.textNode.frame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: size)
        if self.advanced {
            indicatorOriginX = self.textNode.frame.minX + 14.0 + UIScreenPixel
        } else {
            indicatorOriginX = self.textNode.frame.minX - indicatorSize.width
        }
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: indicatorOriginX, y: 0.0), size: indicatorSize)
        return CGSize(width: size.width + indicatorSize.width, height: size.height)
    }
}
