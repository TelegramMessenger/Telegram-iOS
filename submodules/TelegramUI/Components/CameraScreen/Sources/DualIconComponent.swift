import Foundation
import UIKit
import Display
import ComponentFlow

final class DualIconComponent: Component {
    typealias EnvironmentType = Empty
    
    let isSelected: Bool
    let tintColor: UIColor
    
    init(
        isSelected: Bool,
        tintColor: UIColor
    ) {
        self.isSelected = isSelected
        self.tintColor = tintColor
    }
    
    static func ==(lhs: DualIconComponent, rhs: DualIconComponent) -> Bool {
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView = UIImageView()
                
        private var component: DualIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
         
            let image = generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                
                if let image = UIImage(bundleImageName: "Camera/DualIcon"), let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels((size.height - image.size.height) / 2.0) - 1.0), size: image.size))
                }
            })?.withRenderingMode(.alwaysTemplate)
            
            let selectedImage = generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                if let image = UIImage(bundleImageName: "Camera/DualIcon"), let cgImage = image.cgImage {
                    context.setBlendMode(.clear)
                    context.clip(to: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels((size.height - image.size.height) / 2.0) - 1.0), size: image.size), mask: cgImage)
                    context.fill(CGRect(origin: .zero, size: size))
                }
            })?.withRenderingMode(.alwaysTemplate)
            
            self.iconView.image = image
            self.iconView.highlightedImage = selectedImage
                  
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: DualIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                        
            let size = CGSize(width: 36.0, height: 36.0)
            self.iconView.frame = CGRect(origin: .zero, size: size)
            self.iconView.isHighlighted = component.isSelected
            
            self.iconView.tintColor = component.tintColor
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
