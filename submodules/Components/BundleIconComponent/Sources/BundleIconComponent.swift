import Foundation
import UIKit
import ComponentFlow
import AppBundle
import Display

public final class BundleIconComponent: Component {
    public let name: String
    public let tintColor: UIColor?
    public let maxSize: CGSize?
    
    public init(name: String, tintColor: UIColor?, maxSize: CGSize? = nil) {
        self.name = name
        self.tintColor = tintColor
        self.maxSize = maxSize
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
        
        func update(component: BundleIconComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.component?.name != component.name || self.component?.tintColor != component.tintColor {
                if let tintColor = component.tintColor {
                    self.image = generateTintedImage(image: UIImage(bundleImageName: component.name), color: tintColor, backgroundColor: nil)
                } else {
                    self.image = UIImage(bundleImageName: component.name)
                }
            }
            self.component = component
            
            var imageSize = self.image?.size ?? CGSize()
            if let maxSize = component.maxSize {
                imageSize = imageSize.aspectFitted(maxSize)
            }
            
            return CGSize(width: min(imageSize.width, availableSize.width), height: min(imageSize.height, availableSize.height))
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
