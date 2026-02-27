import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

private let minDiameter: CGFloat = 3.0
private let maxDiameter: CGFloat = 4.5

private func radiusFunction(value: CGFloat, timeOffset: CGFloat) -> CGFloat {
    var clampedValue = value + timeOffset
    if clampedValue > 1.0 {
        clampedValue = clampedValue - floor(clampedValue)
    }
    if clampedValue < 0.4 {
        return interpolate(from: minDiameter, to: maxDiameter, value: clampedValue / 0.4)
    } else if clampedValue < 0.8 {
        return interpolate(from: maxDiameter, to: minDiameter, value: (clampedValue - 0.4) / 0.4)
    }
    return minDiameter
}

private final class ChatTypingActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatTypingActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 0.7
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatTypingActivityIndicatorNodeParameters(color: color, progress: self.progress)
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
        
        guard let parameters = parameters as? ChatTypingActivityIndicatorNodeParameters else {
            return
        }
        
        let leftPadding: CGFloat = 6.0
        let topPadding: CGFloat = 9.0
        let distance: CGFloat = 11.0 / 2.0

        let minAlpha: CGFloat = 0.75
        let deltaAlpha: CGFloat = 1.0 - minAlpha

        var radius = radiusFunction(value: parameters.progress, timeOffset:0.4)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5

        let initialAlpha = parameters.color.alpha
        var dotsColor = parameters.color.withAlphaComponent((radius * deltaAlpha + minAlpha) * initialAlpha)
        context.setFillColor(dotsColor.cgColor)
        
        context.fillEllipse(in: CGRect(x: leftPadding - minDiameter / 2.0 - radius / 2.0, y: topPadding - minDiameter / 2.0 - radius / 2.0, width: minDiameter + radius, height: minDiameter + radius))
        
        radius = radiusFunction(value: parameters.progress, timeOffset: 0.2)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5
        
        dotsColor = parameters.color.withAlphaComponent((radius * deltaAlpha + minAlpha) * initialAlpha)
        context.setFillColor(dotsColor.cgColor)
        
        context.fillEllipse(in: CGRect(x: leftPadding + distance - minDiameter / 2.0 - radius / 2.0, y: topPadding - minDiameter / 2.0 - radius / 2.0, width: minDiameter + radius, height: minDiameter + radius))
        
        radius = radiusFunction(value: parameters.progress, timeOffset: 0.0)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5
        
        dotsColor = parameters.color.withAlphaComponent((radius * deltaAlpha + minAlpha) * initialAlpha)
        context.setFillColor(dotsColor.cgColor)
        
        context.fillEllipse(in: CGRect(x: leftPadding + distance * 2.0 - minDiameter / 2.0 - radius / 2.0, y: topPadding - minDiameter / 2.0 - radius / 2.0, width: minDiameter + radius, height: minDiameter + radius))
    }
}

class ChatTypingActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatTypingActivityIndicatorNode
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatTypingActivityIndicatorNode(color: color)
        
        super.init(text: text)
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func updateLayout(_ constrainedSize: CGSize, offset: CGFloat, alignment: NSTextAlignment) -> CGSize {
        let indicatorSize = CGSize(width: 24.0, height: 16.0)
        let size = self.textNode.updateLayout(CGSize(width: constrainedSize.width - indicatorSize.width, height: constrainedSize.height))
        var originX: CGFloat
        if case .center = alignment {
            originX = floorToScreenPixels((indicatorSize.width - size.width) / 2.0)
            let overflowX = max(0.0, size.width + indicatorSize.width + 8.0 - constrainedSize.width)
            originX = originX + overflowX
        } else {
            originX = indicatorSize.width
        }
        self.textNode.frame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: size)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: self.textNode.frame.minX - indicatorSize.width, y: floorToScreenPixels((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
        return CGSize(width: size.width + indicatorSize.width, height: size.height)
    }
}
