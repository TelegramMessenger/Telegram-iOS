import Foundation
import UIKit
import Display
import ComponentFlow

public final class TextBadgeComponent: Component {
    public let text: String
    public let font: UIFont
    public let background: UIColor
    public let foreground: UIColor
    public let insets: UIEdgeInsets
    
    public init(
        text: String,
        font: UIFont,
        background: UIColor,
        foreground: UIColor,
        insets: UIEdgeInsets
    ) {
        self.text = text
        self.font = font
        self.background = background
        self.foreground = foreground
        self.insets = insets
    }
    
    public static func ==(lhs: TextBadgeComponent, rhs: TextBadgeComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.foreground != rhs.foreground {
            return false
        }
        if lhs.insets != rhs.insets {
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
        private let backgroundView: UIImageView
        private let textContentsView: UIImageView
        
        private var textLayout: TextLayout?
        
        private var component: TextBadgeComponent?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIImageView()
            
            self.textContentsView = UIImageView()
            self.textContentsView.layer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.textContentsView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: TextBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            if component.text != previousComponent?.text || component.font != previousComponent?.font {
                let attributedText = NSAttributedString(string: component.text, attributes: [
                    NSAttributedString.Key.font: component.font,
                    NSAttributedString.Key.foregroundColor: UIColor.white
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
                    
                    self.textContentsView.image = context.generateImage()?.withRenderingMode(.alwaysTemplate)
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: opticalBounds)
                } else {
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: CGRect(origin: CGPoint(), size: boundingRect.size))
                }
            }
            
            let textSize = self.textLayout?.size ?? CGSize(width: 1.0, height: 1.0)
            
            var size = CGSize(width: textSize.width + component.insets.left + component.insets.right, height: textSize.height + component.insets.top + component.insets.bottom)
            size.width = max(size.width, size.height)
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) * 0.5), y: component.insets.top + UIScreenPixel), size: textSize)
            /*if let textLayout = self.textLayout {
                textFrame.origin.x = textLayout.opticalBounds.minX + floorToScreenPixels((backgroundFrame.width - textLayout.opticalBounds.width) * 0.5)
                textFrame.origin.y = textLayout.opticalBounds.minY + floorToScreenPixels((backgroundFrame.height - textLayout.opticalBounds.height) * 0.5)
            }*/
            
            transition.setPosition(view: self.textContentsView, position: textFrame.origin)
            self.textContentsView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            
            if size.height != self.backgroundView.image?.size.height {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: size.height, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            
            self.backgroundView.tintColor = component.background
            self.textContentsView.tintColor = component.foreground
            
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
