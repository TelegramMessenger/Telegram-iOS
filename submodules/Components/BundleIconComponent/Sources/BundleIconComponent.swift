import Foundation
import UIKit
import ComponentFlow
import AppBundle
import Display

public final class BundleIconComponent: Component {
    public let name: String
    public let tintColor: UIColor?
    public let maxSize: CGSize?
    public let scaleFactor: CGFloat
    public let shadowColor: UIColor?
    public let shadowBlur: CGFloat
    
    public init(name: String, tintColor: UIColor?, maxSize: CGSize? = nil, scaleFactor: CGFloat = 1.0, shadowColor: UIColor? = nil, shadowBlur: CGFloat = 0.0) {
        self.name = name
        self.tintColor = tintColor
        self.maxSize = maxSize
        self.scaleFactor = scaleFactor
        self.shadowColor = shadowColor
        self.shadowBlur = shadowBlur
    }
    
    public static func ==(lhs: BundleIconComponent, rhs: BundleIconComponent) -> Bool {
        if lhs.name != rhs.name {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.maxSize != rhs.maxSize {
            return false
        }
        if lhs.scaleFactor != rhs.scaleFactor {
            return false
        }
        if lhs.shadowColor != rhs.shadowColor {
            return false
        }
        if lhs.shadowBlur != rhs.shadowBlur {
            return false
        }
        return true
    }
    
    public final class View: UIImageView {
        private var component: BundleIconComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BundleIconComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if self.component?.name != component.name || self.component?.tintColor != component.tintColor || self.component?.shadowColor != component.shadowColor || self.component?.shadowBlur != component.shadowBlur {
                var image: UIImage?
                if let tintColor = component.tintColor {
                    image = generateTintedImage(image: UIImage(bundleImageName: component.name), color: tintColor, backgroundColor: nil)
                } else {
                    image = UIImage(bundleImageName: component.name)
                }
                if let imageValue = image, let shadowColor = component.shadowColor, component.shadowBlur != 0.0 {
                    image = generateImage(CGSize(width: imageValue.size.width + component.shadowBlur * 2.0, height: imageValue.size.height + component.shadowBlur * 2.0), contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setShadow(offset: CGSize(), blur: component.shadowBlur, color: shadowColor.cgColor)
                        
                        if let cgImage = imageValue.cgImage {
                            context.draw(cgImage, in: CGRect(origin: CGPoint(x: component.shadowBlur, y: component.shadowBlur), size: imageValue.size))
                        }
                    })
                }
                self.image = image
            }
            self.component = component
            
            var imageSize = self.image?.size ?? CGSize()
            if let maxSize = component.maxSize {
                imageSize = imageSize.aspectFitted(maxSize)
            }
            if component.scaleFactor != 1.0 {
                imageSize.width = floor(imageSize.width * component.scaleFactor)
                imageSize.height = floor(imageSize.height * component.scaleFactor)
            }
            
            return CGSize(width: min(imageSize.width, availableSize.width), height: min(imageSize.height, availableSize.height))
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
