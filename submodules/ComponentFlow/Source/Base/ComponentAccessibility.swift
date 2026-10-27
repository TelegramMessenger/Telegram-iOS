import Foundation
import UIKit
import Display

/// How a component presents itself to VoiceOver. Components take it as an optional, defaulted, last init parameter and
/// forward it to their view with `UIView.apply(accessibility:defaultTraits:)`.
public struct ComponentAccessibility: Equatable {
    public var label: String?
    public var value: String?
    public var hint: String?
    /// Added to the traits the component supplies itself (`.button`, `.notEnabled`, ...).
    public var traits: UIAccessibilityTraits
    /// `true`: the view is not an element and its subviews are hidden from VoiceOver too.
    public var isHidden: Bool
    
    public init(label: String? = nil, value: String? = nil, hint: String? = nil, traits: UIAccessibilityTraits = [], isHidden: Bool = false) {
        self.label = label
        self.value = value
        self.hint = hint
        self.traits = traits
        self.isHidden = isHidden
    }
}

public extension UIView {
    /// Makes the view a single VoiceOver element (its subviews are not separately reachable), or hides it and its
    /// subviews when `accessibility.isHidden`. `nil` leaves label, value and hint as they are.
    func apply(accessibility: ComponentAccessibility?, defaultTraits: UIAccessibilityTraits) {
        if let accessibility, accessibility.isHidden {
            self.isAccessibilityElement = false
            self.accessibilityElementsHidden = true
            self.accessibilityLabel = nil
            self.accessibilityValue = nil
            self.accessibilityHint = nil
            return
        }
        self.isAccessibilityElement = true
        self.accessibilityElementsHidden = false
        guard let accessibility else {
            // Without a description only the element-ness and traits are managed: a label a call site set directly on
            // the view must survive component updates.
            self.accessibilityTraits = defaultTraits
            return
        }
        self.accessibilityLabel = accessibility.label
        self.accessibilityValue = accessibility.value
        self.accessibilityHint = accessibility.hint
        self.accessibilityTraits = defaultTraits.union(accessibility.traits)
    }
}

public extension UIView {
    /// What a component's view tree shows as text, top to bottom and left to right, so a row can describe itself with
    /// exactly the words on screen. `hasInteractiveContent` is `true` when the tree holds something VoiceOver users
    /// need to reach on its own (a control, a view that is already an element, a tappable link): the caller must not
    /// fold such a tree into one element.
    func accessibilityDisplayedContent() -> (texts: [String], hasInteractiveContent: Bool) {
        var found: [(origin: CGPoint, text: String)] = []
        var hasInteractiveContent = false
        
        func visit(_ view: UIView, root: UIView) {
            if view.isHidden || view.alpha < 0.01 || view.accessibilityElementsHidden {
                return
            }
            let origin = view.convert(CGPoint(), to: root)
            if let textView = view as? ImmediateTextView {
                if textView.tapAttributeAction != nil || textView.highlightAttributeAction != nil {
                    hasInteractiveContent = true
                }
                if let string = textView.attributedText?.string, !string.isEmpty {
                    found.append((origin, string))
                }
                return
            }
            if let label = view as? UILabel {
                if let string = label.attributedText?.string ?? label.text, !string.isEmpty {
                    found.append((origin, string))
                }
                return
            }
            if view is UIControl || view.isAccessibilityElement {
                if view.isAccessibilityElement, let label = view.accessibilityLabel, !label.isEmpty, !(view is UIControl) {
                    found.append((origin, label))
                }
                hasInteractiveContent = true
                return
            }
            for subview in view.subviews {
                visit(subview, root: root)
            }
        }
        visit(self, root: self)
        found.sort { lhs, rhs in
            if abs(lhs.origin.y - rhs.origin.y) > 0.5 {
                return lhs.origin.y < rhs.origin.y
            }
            return lhs.origin.x < rhs.origin.x
        }
        return (found.map { $0.text }, hasInteractiveContent)
    }
}

public extension ComponentAccessibility {
    /// Value and trait of a switch row when the call site gives none. On iOS 17 and later `.toggleButton` makes
    /// VoiceOver say the on/off state in the system language from the `1`/`0` value; earlier systems read the value.
    static func toggleDefaults(isOn: Bool) -> (value: String, traits: UIAccessibilityTraits) {
        let value = isOn ? "1" : "0"
        if #available(iOS 17.0, *) {
            return (value, .toggleButton)
        }
        return (value, .button)
    }
}
