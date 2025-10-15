import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

public func generateDisclosureActionBoostLevelBadgeImage(text: String) -> UIImage {
    let attributedText = NSAttributedString(string: text, attributes: [
        .font: Font.medium(12.0),
        .foregroundColor: UIColor.white
    ])
    let bounds = attributedText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
    let leftInset: CGFloat = 16.0
    let rightInset: CGFloat = 4.0
    let size = CGSize(width: leftInset + rightInset + ceil(bounds.width), height: 20.0)
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 6.0).cgPath)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0x9076FF).cgColor, UIColor(rgb: 0xB86DEA).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        UIGraphicsPushContext(context)
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: .white) {
            let imageFit: CGFloat = 14.0
            let imageSize = image.size.aspectFitted(CGSize(width: imageFit, height: imageFit))
            let imageRect = CGRect(origin: CGPoint(x: 2.0, y: UIScreenPixel + floorToScreenPixels((size.height - imageSize.height) * 0.5)), size: imageSize)
            image.draw(in: imageRect)
        }
        
        attributedText.draw(at: CGPoint(x: leftInset, y: floorToScreenPixels((size.height - bounds.height) * 0.5)))
        
        UIGraphicsPopContext()
    })!
}

public final class BoostLevelIconComponent: Component {
    let strings: PresentationStrings
    let level: Int
    
    public init(
        strings: PresentationStrings,
        level: Int
    ) {
        self.strings = strings
        self.level = level
    }
    
    public static func ==(lhs: BoostLevelIconComponent, rhs: BoostLevelIconComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.level != rhs.level {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let imageView: UIImageView
        
        private var component: BoostLevelIconComponent?
        
        override init(frame: CGRect) {
            self.imageView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.imageView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BoostLevelIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component != component {
                self.imageView.image = generateDisclosureActionBoostLevelBadgeImage(text: component.strings.Channel_Appearance_BoostLevel("\(component.level)").string)
            }
            self.component = component
            
            if let image = self.imageView.image {
                self.imageView.frame = CGRect(origin: CGPoint(), size: image.size)
                return image.size
            } else {
                return CGSize(width: 1.0, height: 20.0)
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
