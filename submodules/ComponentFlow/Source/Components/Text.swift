import Foundation
import UIKit

public final class Text: Component {
    private final class MeasureState: Equatable {
        let attributedText: NSAttributedString
        let availableSize: CGSize
        let size: CGSize
        
        init(attributedText: NSAttributedString, availableSize: CGSize, size: CGSize) {
            self.attributedText = attributedText
            self.availableSize = availableSize
            self.size = size
        }

        static func ==(lhs: MeasureState, rhs: MeasureState) -> Bool {
            if !lhs.attributedText.isEqual(rhs.attributedText) {
                return false
            }
            if lhs.availableSize != rhs.availableSize {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    public final class View: UIView {
        private var measureState: MeasureState?

        public func update(component: Text, availableSize: CGSize) -> CGSize {
            let attributedText = NSAttributedString(string: component.text, attributes: [
                NSAttributedString.Key.font: component.font,
                NSAttributedString.Key.foregroundColor: component.color
            ])
            
            if let measureState = self.measureState {
                if measureState.attributedText.isEqual(to: attributedText) && measureState.availableSize == availableSize {
                    return measureState.size
                }
            }
            
            var boundingRect = attributedText.boundingRect(with: availableSize, options: .usesLineFragmentOrigin, context: nil)
            boundingRect.size.width = ceil(boundingRect.size.width)
            boundingRect.size.height = ceil(boundingRect.size.height)

            let measureState = MeasureState(attributedText: attributedText, availableSize: availableSize, size: boundingRect.size)
            if #available(iOS 10.0, *) {
                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: measureState.size))
                let image = renderer.image { context in
                    UIGraphicsPushContext(context.cgContext)
                    measureState.attributedText.draw(at: CGPoint())
                    UIGraphicsPopContext()
                }
                self.layer.contents = image.cgImage
            } else {
                UIGraphicsBeginImageContextWithOptions(measureState.size, false, 0.0)
                measureState.attributedText.draw(at: CGPoint())
                self.layer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
                UIGraphicsEndImageContext()
            }

            self.measureState = measureState
            
            return boundingRect.size
        }
    }
    
    public let text: String
    public let font: UIFont
    public let color: UIColor
    
    public init(text: String, font: UIFont, color: UIColor) {
        self.text = text
        self.font = font
        self.color = color
    }

    public static func ==(lhs: Text, rhs: Text) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if !lhs.font.isEqual(rhs.font) {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        return true
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
