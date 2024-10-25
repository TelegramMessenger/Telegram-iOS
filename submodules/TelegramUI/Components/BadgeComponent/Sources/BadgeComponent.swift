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
    
    public final class View: UIView {
        override public static var layerClass: AnyClass {
            return RasterizedCompositionLayer.self
        }
        
        private let contentsClippingLayer: RasterizedCompositionLayer
        private let backgroundInsetLayer: RasterizedCompositionImageLayer
        private let backgroundLayer: RasterizedCompositionImageLayer
        private let textContentsLayer: RasterizedCompositionImageLayer
        
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

                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: boundingRect.size))
                let textImage = renderer.image { context in
                    UIGraphicsPushContext(context.cgContext)
                    attributedText.draw(at: CGPoint())
                    UIGraphicsPopContext()
                }
                self.textContentsLayer.image = textImage
            }
            
            if component.cornerRadius != previousComponent?.cornerRadius {
                self.backgroundLayer.image = generateStretchableFilledCircleImage(diameter: component.cornerRadius * 2.0, color: .white)
                
                self.backgroundInsetLayer.image = generateStretchableFilledCircleImage(diameter: component.cornerRadius * 2.0, color: .black)
            }
            
            let textSize = self.textContentsLayer.image?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let size = CGSize(width: textSize.width + component.insets.left + component.insets.right, height: textSize.height + component.insets.top + component.insets.bottom)
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            transition.setFrame(layer: self.contentsClippingLayer, frame: backgroundFrame)
            
            let outerInsetsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX - component.outerInsets.left, y: backgroundFrame.minY - component.outerInsets.top), size: CGSize(width: backgroundFrame.width + component.outerInsets.left + component.outerInsets.right, height: backgroundFrame.height + component.outerInsets.top + component.outerInsets.bottom))
            transition.setFrame(layer: self.backgroundInsetLayer, frame: outerInsetsFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: component.insets.left, y: component.insets.top), size: textSize)
            transition.setPosition(layer: self.textContentsLayer, position: textFrame.origin)
            self.textContentsLayer.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            //self.textContentsLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.4).cgColor
            
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
