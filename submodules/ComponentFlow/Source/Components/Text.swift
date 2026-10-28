import Foundation
import UIKit
import Display

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
        
        // VoiceOver: a visible text is a static-text element reading exactly what it shows, unless a call site
        // decides otherwise (anything it sets wins). A parent that is itself an element (a button) hides it as usual.
        // Computed in the getters, so nothing runs while no accessibility client asks.
        private var explicitIsAccessibilityElement: Bool?
        private var explicitAccessibilityLabel: String??
        private var explicitAccessibilityTraits: UIAccessibilityTraits?
        
        override public var isAccessibilityElement: Bool {
            get {
                if let explicitIsAccessibilityElement = self.explicitIsAccessibilityElement {
                    return explicitIsAccessibilityElement
                }
                if self.isHidden || self.alpha < 0.01 {
                    return false
                }
                guard let label = self.accessibilityLabel, !label.isEmpty else {
                    return false
                }
                // Silent when an element drawn over it already speaks these words (a hand-labelled area beside it).
                return !accessibilityTextIsSpokenByCoveringElement(self, text: label)
            } set(value) {
                self.explicitIsAccessibilityElement = value
            }
        }
        
        override public var accessibilityLabel: String? {
            get {
                if let explicitAccessibilityLabel = self.explicitAccessibilityLabel {
                    return explicitAccessibilityLabel
                }
                if self.explicitIsAccessibilityElement == false {
                    // Turned off by the call site: nothing to announce from here either.
                    return nil
                }
                return self.measureState.flatMap { accessibilityDisplayedText($0.attributedText) }
            } set(value) {
                self.explicitAccessibilityLabel = .some(value)
            }
        }
        
        override public var accessibilityTraits: UIAccessibilityTraits {
            get {
                if let explicitAccessibilityTraits = self.explicitAccessibilityTraits {
                    return explicitAccessibilityTraits
                }
                return self.explicitIsAccessibilityElement == false ? [] : .staticText
            } set(value) {
                self.explicitAccessibilityTraits = value
            }
        }
        

        public func update(component: Text, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let attributedText = NSAttributedString(string: component.text, attributes: [
                NSAttributedString.Key.font: component.font,
                NSAttributedString.Key.foregroundColor: component.color
            ])
            
            if let tintColor = component.tintColor {
                transition.setTintColor(layer: self.layer, color: tintColor)
            }
            
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
    public let tintColor: UIColor?
    
    public init(text: String, font: UIFont, color: UIColor, tintColor: UIColor? = nil) {
        self.text = text
        self.font = font
        self.color = color
        self.tintColor = tintColor
    }
    
    public convenience init(attributedString: NSAttributedString, tintColor: UIColor? = nil) {
        let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
        let color = attributes[.foregroundColor] as? UIColor ?? .black
        self.init(
            text: attributedString.string,
            font: font,
            color: color,
            tintColor: tintColor
        )
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
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
