import XCTest
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import ButtonComponent
import PlainButtonComponent
import GlassBarButtonComponent

private final class LabelComponent: Component {
    let text: String
    
    init(text: String) {
        self.text = text
    }
    
    static func ==(lhs: LabelComponent, rhs: LabelComponent) -> Bool {
        return lhs.text == rhs.text
    }
    
    final class View: UILabel {
        func update(component: LabelComponent, availableSize: CGSize) -> CGSize {
            self.text = component.text
            self.isAccessibilityElement = true
            return CGSize(width: 80.0, height: 20.0)
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

final class ComponentAccessibilityTests: XCTestCase {
    private func makeView<C: Component>(_ component: C, size: CGSize = CGSize(width: 200.0, height: 60.0)) -> ComponentView<Empty> where C.EnvironmentType == Empty {
        let view = ComponentView<Empty>()
        let _ = view.update(transition: .immediate, component: AnyComponent(component), environment: {}, containerSize: size)
        return view
    }
    
    private func button(isEnabled: Bool = true, accessibility: ComponentAccessibility?) -> UIView {
        let host = self.makeView(Button(
            content: AnyComponent(LabelComponent(text: "Inner")),
            isEnabled: isEnabled,
            action: {},
            accessibility: accessibility
        ))
        return host.view!
    }
    
    func testButtonAppliesLabelAndButtonTrait() {
        let view = self.button(accessibility: ComponentAccessibility(label: "Close", value: "1", hint: "Closes the screen", traits: .selected))
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "Close")
        XCTAssertEqual(view.accessibilityValue, "1")
        XCTAssertEqual(view.accessibilityHint, "Closes the screen")
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertTrue(view.accessibilityTraits.contains(.selected))
        XCTAssertFalse(view.accessibilityTraits.contains(.notEnabled))
        
        let plain = self.makeView(PlainButtonComponent(content: AnyComponent(LabelComponent(text: "Inner")), action: {}, accessibility: ComponentAccessibility(label: "More"))).view!
        XCTAssertTrue(plain.isAccessibilityElement)
        XCTAssertEqual(plain.accessibilityLabel, "More")
        XCTAssertTrue(plain.accessibilityTraits.contains(.button))
        
        let glass = self.makeView(GlassBarButtonComponent(
            size: CGSize(width: 44.0, height: 44.0),
            backgroundColor: nil,
            isDark: false,
            component: AnyComponentWithIdentity(id: 0, component: AnyComponent(LabelComponent(text: "Inner"))),
            action: nil,
            accessibility: ComponentAccessibility(label: "Back")
        )).view!
        XCTAssertTrue(glass.isAccessibilityElement)
        XCTAssertEqual(glass.accessibilityLabel, "Back")
        XCTAssertTrue(glass.accessibilityTraits.contains(.button))
    }
    
    func testDisabledButtonHasNotEnabledTrait() {
        let view = self.button(isEnabled: false, accessibility: ComponentAccessibility(label: "Send"))
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertTrue(view.accessibilityTraits.contains(.notEnabled))
        
        let plain = self.makeView(PlainButtonComponent(content: AnyComponent(LabelComponent(text: "Inner")), action: {}, isEnabled: false)).view!
        XCTAssertTrue(plain.accessibilityTraits.contains(.notEnabled))
        
        let glass = self.makeView(GlassBarButtonComponent(
            size: CGSize(width: 44.0, height: 44.0),
            backgroundColor: nil,
            isDark: false,
            isEnabled: false,
            component: AnyComponentWithIdentity(id: 0, component: AnyComponent(LabelComponent(text: "Inner"))),
            action: nil
        )).view!
        XCTAssertTrue(glass.accessibilityTraits.contains(.notEnabled))
    }
    
    func testHiddenAccessibilityRemovesElement() {
        let view = self.button(accessibility: ComponentAccessibility(label: "Decoration", isHidden: true))
        XCTAssertFalse(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityElementsHidden)
        XCTAssertNil(view.accessibilityLabel)
    }
    
    func testButtonComponentDerivesLabelFromTitle() {
        func make(content: AnyComponent<Empty>, accessibility: ComponentAccessibility? = nil) -> UIView {
            return self.makeView(ButtonComponent(
                background: ButtonComponent.Background(style: .legacy, color: .blue, foreground: .white, pressedColor: .blue),
                content: AnyComponentWithIdentity(id: 0, component: content),
                action: {},
                accessibility: accessibility
            )).view!
        }
        
        let attributed = NSAttributedString(string: "Continue")
        let titled = make(content: AnyComponent(MultilineTextComponent(text: .plain(attributed))))
        XCTAssertTrue(titled.isAccessibilityElement)
        XCTAssertEqual(titled.accessibilityLabel, "Continue")
        XCTAssertTrue(titled.accessibilityTraits.contains(.button))
        
        let badged = make(content: AnyComponent(ButtonTextContentComponent(text: "Gifts", badge: 3, textColor: .white, badgeBackground: .red, badgeForeground: .white)))
        XCTAssertEqual(badged.accessibilityLabel, "Gifts, 3")
        
        let explicit = make(content: AnyComponent(MultilineTextComponent(text: .plain(attributed))), accessibility: ComponentAccessibility(label: "Proceed"))
        XCTAssertEqual(explicit.accessibilityLabel, "Proceed")
        
        let untitled = make(content: AnyComponent(LabelComponent(text: "Inner")))
        XCTAssertNil(untitled.accessibilityLabel)
    }
    
    func testLabelledButtonHidesInnerTextElements() {
        let view = self.button(accessibility: ComponentAccessibility(label: "Close"))
        // The button is the one element; its inner label is an element of its own that sits below an element, which
        // VoiceOver never reaches. Nothing in the button is exposed as a container.
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertNil(view.accessibilityElements)
        XCTAssertFalse(view.accessibilityElementsHidden)
        
        let titled = self.makeView(ButtonComponent(
            background: ButtonComponent.Background(style: .legacy, color: .blue, foreground: .white, pressedColor: .blue),
            content: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Continue"))))),
            action: {}
        )).view!
        XCTAssertTrue(titled.isAccessibilityElement)
        XCTAssertNil(titled.accessibilityElements)
    }
}
