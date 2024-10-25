import Foundation
import UIKit
import Display
import RasterizedCompositionComponent
import ComponentFlow

public final class BadgeComponent: Component {
    public let text: String
    public let font: UIFont
    public let cornerRadius: CGFloat
    public let insets: UIEdgeInsets
    public let outerInsets: UIEdgeInsets
    
    public init(
        text: String,
        font: UIFont,
        cornerRadius: CGFloat,
        insets: UIEdgeInsets,
        outerInsets: UIEdgeInsets
    ) {
        self.text = text
        self.font = font
        self.cornerRadius = cornerRadius
        self.insets = insets
        self.outerInsets = outerInsets
    }
    
    public static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.outerInsets != rhs.outerInsets {
            return false
        }
        return true
    }
    
    private struct TextLayout {
        var size: CGSize
        var opticalBounds: CGRect
        
        init(size: CGSize, opticalBounds: CGRect) {
            self.size = size
            self.opticalBounds = opticalBounds
        }
    }
    
    public final class View: UIView {
        override public static var layerClass: AnyClass {
            return RasterizedCompositionLayer.self
        }
        
        private let contentsClippingLayer: RasterizedCompositionLayer
        private let backgroundInsetLayer: RasterizedCompositionImageLayer
        private let backgroundLayer: RasterizedCompositionImageLayer
        private let textContentsLayer: RasterizedCompositionImageLayer
        
        private var textLayout: TextLayout?
        
        private var component: BadgeComponent?
        
        override public init(frame: CGRect) {
            self.contentsClippingLayer = RasterizedCompositionLayer()
            self.backgroundInsetLayer = RasterizedCompositionImageLayer()
            self.backgroundLayer = RasterizedCompositionImageLayer()
            
            self.textContentsLayer = RasterizedCompositionImageLayer()
            self.textContentsLayer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundInsetLayer)
            self.layer.addSublayer(self.backgroundLayer)
            self.layer.addSublayer(self.contentsClippingLayer)
            self.contentsClippingLayer.addSublayer(self.textContentsLayer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: BadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            if component.text != previousComponent?.text || component.font != previousComponent?.font {
                let attributedText = NSAttributedString(string: component.text, attributes: [
                    NSAttributedString.Key.font: component.font,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                
                var boundingRect = attributedText.boundingRect(with: availableSize, options: .usesLineFragmentOrigin, context: nil)
                boundingRect.size.width = ceil(boundingRect.size.width)
                boundingRect.size.height = ceil(boundingRect.size.height)
                
                if let context = DrawingContext(size: boundingRect.size, scale: 0.0, opaque: false, clear: true) {
                    context.withContext { c in
                        UIGraphicsPushContext(c)
                        defer {
                            UIGraphicsPopContext()
                        }
                        
                        attributedText.draw(at: CGPoint())
                    }
                    var minFilledLineY = Int(context.scaledSize.height) - 1
                    var maxFilledLineY = 0
                    var minFilledLineX = Int(context.scaledSize.width) - 1
                    var maxFilledLineX = 0
                    for y in 0 ..< Int(context.scaledSize.height) {
                        let linePtr = context.bytes.advanced(by: max(0, y) * context.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                        
                        for x in 0 ..< Int(context.scaledSize.width) {
                            let pixelPtr = linePtr.advanced(by: x)
                            if pixelPtr.pointee != 0 {
                                minFilledLineY = min(y, minFilledLineY)
                                maxFilledLineY = max(y, maxFilledLineY)
                                minFilledLineX = min(x, minFilledLineX)
                                maxFilledLineX = max(x, maxFilledLineX)
                            }
                        }
                    }
                    
                    var opticalBounds = CGRect()
                    if minFilledLineX <= maxFilledLineX && minFilledLineY <= maxFilledLineY {
                        opticalBounds.origin.x = CGFloat(minFilledLineX) / context.scale
                        opticalBounds.origin.y = CGFloat(minFilledLineY) / context.scale
                        opticalBounds.size.width = CGFloat(maxFilledLineX - minFilledLineX) / context.scale
                        opticalBounds.size.height = CGFloat(maxFilledLineY - minFilledLineY) / context.scale
                    }
                    
                    self.textContentsLayer.image = context.generateImage()
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: opticalBounds)
                } else {
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: CGRect(origin: CGPoint(), size: boundingRect.size))
                }
            }
            
            if component.cornerRadius != previousComponent?.cornerRadius {
                self.backgroundLayer.image = generateStretchableFilledCircleImage(diameter: component.cornerRadius * 2.0, color: .white)
                
                self.backgroundInsetLayer.image = generateStretchableFilledCircleImage(diameter: component.cornerRadius * 2.0, color: .black)
            }
            
            let textSize = self.textLayout?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let size = CGSize(width: textSize.width + component.insets.left + component.insets.right, height: textSize.height + component.insets.top + component.insets.bottom)
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            transition.setFrame(layer: self.contentsClippingLayer, frame: backgroundFrame)
            
            let outerInsetsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX - component.outerInsets.left, y: backgroundFrame.minY - component.outerInsets.top), size: CGSize(width: backgroundFrame.width + component.outerInsets.left + component.outerInsets.right, height: backgroundFrame.height + component.outerInsets.top + component.outerInsets.bottom))
            transition.setFrame(layer: self.backgroundInsetLayer, frame: outerInsetsFrame)
            
            var textFrame = CGRect(origin: CGPoint(x: component.insets.left, y: component.insets.top), size: textSize)
            if let textLayout = self.textLayout {
                textFrame.origin.x = -textLayout.opticalBounds.minX + floorToScreenPixels((backgroundFrame.width - textLayout.opticalBounds.width) * 0.5)
                textFrame.origin.y = -textLayout.opticalBounds.minY + floorToScreenPixels((backgroundFrame.height - textLayout.opticalBounds.height) * 0.5)
            }
            
            transition.setPosition(layer: self.textContentsLayer, position: textFrame.origin)
            self.textContentsLayer.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
