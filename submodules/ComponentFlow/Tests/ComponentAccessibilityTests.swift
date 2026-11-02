import XCTest
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import Markdown
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
        
        let plainText = make(content: AnyComponent(Text(text: "Set", font: .systemFont(ofSize: 17.0), color: .white)))
        XCTAssertEqual(plainText.accessibilityLabel, "Set")
        
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
    
    func testMarkdownTitleDoesNotLeakMarkup() {
        let view = self.makeView(ButtonComponent(
            background: ButtonComponent.Background(style: .legacy, color: .blue, foreground: .white, pressedColor: .blue),
            content: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(text: .markdown(text: "**Buy**", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .systemFont(ofSize: 17.0), textColor: .white), bold: MarkdownAttributeSet(font: .boldSystemFont(ofSize: 17.0), textColor: .white), link: MarkdownAttributeSet(font: .systemFont(ofSize: 17.0), textColor: .white), linkAttribute: { _ in nil }))))),
            action: {}
        )).view!
        XCTAssertNil(view.accessibilityLabel)
    }
    
    func testCallSiteLabelSurvivesUpdateWithNilAccessibility() {
        let host = ComponentView<Empty>()
        func update(_ text: String) {
            let _ = host.update(transition: .immediate, component: AnyComponent(Button(content: AnyComponent(LabelComponent(text: text)), action: {})), environment: {}, containerSize: CGSize(width: 200.0, height: 60.0))
        }
        update("A")
        host.view!.accessibilityLabel = "Set by call site"
        update("B")
        XCTAssertEqual(host.view!.accessibilityLabel, "Set by call site")
        XCTAssertTrue(host.view!.accessibilityTraits.contains(.button))
        
        let plainHost = ComponentView<Empty>()
        func updatePlain(_ text: String) {
            let _ = plainHost.update(transition: .immediate, component: AnyComponent(PlainButtonComponent(content: AnyComponent(LabelComponent(text: text)), action: {})), environment: {}, containerSize: CGSize(width: 200.0, height: 60.0))
        }
        updatePlain("A")
        plainHost.view!.accessibilityLabel = "Set by call site"
        updatePlain("B")
        XCTAssertEqual(plainHost.view!.accessibilityLabel, "Set by call site")
    }
    
    func testGlassBarButtonAccessibilityActivate() {
        var calls = 0
        func make(isEnabled: Bool) -> GlassBarButtonComponent.View {
            return self.makeView(GlassBarButtonComponent(
                size: CGSize(width: 44.0, height: 44.0),
                backgroundColor: nil,
                isDark: false,
                isEnabled: isEnabled,
                component: AnyComponentWithIdentity(id: 0, component: AnyComponent(LabelComponent(text: "Inner"))),
                action: { _ in calls += 1 }
            )).view as! GlassBarButtonComponent.View
        }
        XCTAssertTrue(make(isEnabled: true).accessibilityActivate())
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(make(isEnabled: false).accessibilityActivate())
        XCTAssertEqual(calls, 1)
    }
    
    func testButtonWithoutLabelReadsItsText() {
        let view = self.makeView(Button(
            content: AnyComponent(HStack([
                AnyComponentWithIdentity(id: 0, component: AnyComponent(Rectangle(color: .red, width: 10.0, height: 10.0))),
                AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Gift Stars to Friends")))))
            ], spacing: 4.0)),
            action: {}
        )).view!
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "Gift Stars to Friends")
        
        let labelled = self.makeView(Button(
            content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Inner")))),
            action: {},
            accessibility: ComponentAccessibility(label: "Close")
        )).view!
        XCTAssertEqual(labelled.accessibilityLabel, "Close")
    }
    
    func testButtonComponentDerivesLabelThroughStacks() {
        let view = self.makeView(ButtonComponent(
            background: ButtonComponent.Background(style: .legacy, color: .blue, foreground: .white, pressedColor: .blue),
            content: AnyComponentWithIdentity(id: 0, component: AnyComponent(HStack([
                AnyComponentWithIdentity(id: "icon", component: AnyComponent(Rectangle(color: .white, width: 20.0, height: 20.0))),
                AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: "Top Up", font: .systemFont(ofSize: 17.0), color: .white)))
            ], spacing: 7.0))),
            action: {}
        )).view!
        XCTAssertEqual(view.accessibilityLabel, "Top Up")
        
        let stacked = self.makeView(ButtonComponent(
            background: ButtonComponent.Background(style: .legacy, color: .blue, foreground: .white, pressedColor: .blue),
            content: AnyComponentWithIdentity(id: 0, component: AnyComponent(VStack([
                AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Apply Style"))))),
                AnyComponentWithIdentity(id: 1, component: AnyComponent(Text(text: "02:00", font: .systemFont(ofSize: 11.0), color: .white)))
            ], spacing: 3.0))),
            action: {}
        )).view!
        XCTAssertEqual(stacked.accessibilityLabel, "Apply Style, 02:00")
    }
}
