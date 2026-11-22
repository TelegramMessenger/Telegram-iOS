import XCTest
import UIKit
import Display
@testable import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import ListActionItemComponent
import ListSectionComponent
import ListSwitchItemComponent

final class ComponentAccessibilityListTests: XCTestCase {
    private let theme = defaultPresentationTheme
    
    private func text(_ string: String) -> AnyComponent<Empty> {
        return AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: string, font: UIFont.systemFont(ofSize: 17.0), textColor: .black))))
    }
    
    private func make<C: Component>(_ component: C) -> UIView where C.EnvironmentType == Empty {
        let host = ComponentView<Empty>()
        let _ = host.update(transition: .immediate, component: AnyComponent(component), environment: {}, containerSize: CGSize(width: 320.0, height: 400.0))
        return host.view!
    }
    
    func testActionRowIsSingleButtonElement() {
        var tapped = 0
        let view = self.make(ListActionItemComponent(
            theme: self.theme,
            title: AnyComponent(VStack([
                AnyComponentWithIdentity(id: 0, component: self.text("Auto-Delete Messages")),
                AnyComponentWithIdentity(id: 1, component: self.text("After 1 week"))
            ], alignment: .left, spacing: 2.0)),
            icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: self.text("Off"))),
            accessory: .arrow,
            action: { _ in tapped += 1 }
        ))
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "Auto-Delete Messages, After 1 week")
        XCTAssertEqual(view.accessibilityValue, "Off")
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertTrue(view.accessibilityActivate())
        XCTAssertEqual(tapped, 1)
        
        let plain = self.make(ListActionItemComponent(theme: self.theme, title: self.text("Info"), accessory: nil, action: nil))
        XCTAssertTrue(plain.isAccessibilityElement)
        XCTAssertEqual(plain.accessibilityLabel, "Info")
        XCTAssertFalse(plain.accessibilityTraits.contains(.button))
        
        let explicit = self.make(ListActionItemComponent(
            theme: self.theme,
            title: self.text("Info"),
            accessory: nil,
            action: nil,
            accessibility: ComponentAccessibility(label: "Custom", value: "V", hint: "H")
        ))
        XCTAssertEqual(explicit.accessibilityLabel, "Custom")
        XCTAssertEqual(explicit.accessibilityValue, "V")
        XCTAssertEqual(explicit.accessibilityHint, "H")
    }
    
    func testSwitchRowValueAndActivate() {
        var received: [Bool] = []
        func row(isOn: Bool, isEnabled: Bool = true) -> UIView {
            return self.make(ListActionItemComponent(
                theme: self.theme,
                title: self.text("Notifications"),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: isOn, isEnabled: isEnabled, action: { received.append($0) })),
                action: nil
            ))
        }
        let off = row(isOn: false)
        XCTAssertTrue(off.isAccessibilityElement)
        XCTAssertEqual(off.accessibilityLabel, "Notifications")
        XCTAssertEqual(off.accessibilityValue, "0")
        XCTAssertTrue(off.accessibilityActivate())
        let on = row(isOn: true)
        XCTAssertEqual(on.accessibilityValue, "1")
        XCTAssertTrue(on.accessibilityActivate())
        XCTAssertEqual(received, [true, false])
        
        let disabled = row(isOn: true, isEnabled: false)
        XCTAssertTrue(disabled.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(disabled.accessibilityActivate())
        XCTAssertEqual(received, [true, false])
        
        var switched: [Bool] = []
        let standalone = self.make(ListSwitchItemComponent(
            theme: self.theme,
            title: "Allow Reactions",
            value: true,
            valueUpdated: { switched.append($0) },
            accessibility: ComponentAccessibility(value: "On")
        ))
        XCTAssertTrue(standalone.isAccessibilityElement)
        XCTAssertEqual(standalone.accessibilityLabel, "Allow Reactions")
        XCTAssertEqual(standalone.accessibilityValue, "On")
        XCTAssertTrue(standalone.accessibilityActivate())
        XCTAssertEqual(switched, [false])
    }
    
    func testRowDescriptionFollowsUpdates() {
        // The row works its description out when asked and keeps it until the next update: an update must not leave
        // the previous state behind.
        let host = ComponentView<Empty>()
        func update(title: String, isOn: Bool, options: [String]) -> UIView {
            let _ = host.update(transition: .immediate, component: AnyComponent(ListActionItemComponent(
                theme: self.theme,
                title: self.text(title),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: isOn, action: { _ in })),
                contextOptions: options.map { ListActionItemComponent.ContextOption(id: $0, title: $0, color: .red, action: {}) },
                action: nil
            )), environment: {}, containerSize: CGSize(width: 320.0, height: 400.0))
            return host.view!
        }
        var view = update(title: "Sounds", isOn: false, options: [])
        XCTAssertEqual(view.accessibilityLabel, "Sounds")
        XCTAssertEqual(view.accessibilityValue, "0")
        XCTAssertNil(view.accessibilityCustomActions)
        view = update(title: "Vibrate", isOn: true, options: ["Delete"])
        XCTAssertEqual(view.accessibilityLabel, "Vibrate")
        XCTAssertEqual(view.accessibilityValue, "1")
        XCTAssertEqual(view.accessibilityCustomActions?.map { $0.name }, ["Delete"])
    }
    
    func testSectionHeaderTrait() {
        let view = self.make(ListSectionComponent(
            theme: self.theme,
            header: self.text("PRIVACY"),
            footer: self.text("Choose who can see this."),
            items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(theme: self.theme, title: self.text("Row"), action: { _ in })))]
        ))
        func element(labelled label: String) -> UIView? {
            var queue: [UIView] = [view]
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if current.isAccessibilityElement && current.accessibilityLabel == label {
                    return current
                }
                queue.append(contentsOf: current.subviews)
            }
            return nil
        }
        let header = element(labelled: "PRIVACY")
        XCTAssertNotNil(header)
        XCTAssertTrue(header?.accessibilityTraits.contains(.header) ?? false)
        let footer = element(labelled: "Choose who can see this.")
        XCTAssertNotNil(footer)
        XCTAssertTrue(footer?.accessibilityTraits.contains(.staticText) ?? false)
        XCTAssertNotNil(element(labelled: "Row"))
    }
    
    func testPreIOS17SwitchValueUsesLocalizedStrings() {
        let previous = (ComponentAccessibilityStrings.on, ComponentAccessibilityStrings.off)
        defer {
            ComponentAccessibilityStrings.on = previous.0
            ComponentAccessibilityStrings.off = previous.1
        }
        ComponentAccessibilityStrings.on = "Вкл."
        ComponentAccessibilityStrings.off = "Выкл."
        let on = ComponentAccessibility.toggleDefaults(isOn: true, isIOS17OrLater: false)
        XCTAssertEqual(on.value, "Вкл.")
        XCTAssertTrue(on.traits.contains(.button))
        XCTAssertEqual(ComponentAccessibility.toggleDefaults(isOn: false, isIOS17OrLater: false).value, "Выкл.")
        if #available(iOS 17.0, *) {
            let modern = ComponentAccessibility.toggleDefaults(isOn: true, isIOS17OrLater: true)
            XCTAssertEqual(modern.value, "1")
            XCTAssertTrue(modern.traits.contains(.toggleButton))
        }
    }
}
