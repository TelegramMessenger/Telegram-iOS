import Foundation
import UIKit

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
    /// subviews when `accessibility.isHidden`. `nil` leaves the element unlabelled.
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
        self.accessibilityLabel = accessibility?.label
        self.accessibilityValue = accessibility?.value
        self.accessibilityHint = accessibility?.hint
        self.accessibilityTraits = defaultTraits.union(accessibility?.traits ?? [])
    }
}
