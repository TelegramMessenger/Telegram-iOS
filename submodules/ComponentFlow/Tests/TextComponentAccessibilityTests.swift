import XCTest
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent

final class TextComponentAccessibilityTests: XCTestCase {
    private func makeView<C: Component>(_ component: C, size: CGSize = CGSize(width: 200.0, height: 60.0)) -> UIView where C.EnvironmentType == Empty {
        let view = ComponentView<Empty>()
        let _ = view.update(transition: .immediate, component: AnyComponent(component), environment: {}, containerSize: size)
        return view.view!
    }
    
    func testMultilineTextIsStaticTextReadingItsText() {
        let view = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "iPhone Simulator"))))
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "iPhone Simulator")
        XCTAssertEqual(view.accessibilityTraits, .staticText)
    }
    
    func testPlainTextComponentIsStaticText() {
        let view = self.makeView(Text(text: "Storage Usage", font: .systemFont(ofSize: 17.0), color: .black))
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "Storage Usage")
        XCTAssertEqual(view.accessibilityTraits, .staticText)
    }
    
    func testEmptyOrHiddenTextIsNotAnElement() {
        let empty = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: ""))))
        XCTAssertFalse(empty.isAccessibilityElement)
        
        let hidden = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Hidden"))))
        hidden.alpha = 0.0
        XCTAssertFalse(hidden.isAccessibilityElement)
    }
    
    func testCallSiteSettingsWin() {
        let view = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Title"))))
        view.accessibilityTraits = .header
        view.accessibilityLabel = "Other"
        XCTAssertEqual(view.accessibilityTraits, .header)
        XCTAssertEqual(view.accessibilityLabel, "Other")
        view.isAccessibilityElement = false
        XCTAssertFalse(view.isAccessibilityElement)
    }
    
    func testBalancedTextIsStaticText() {
        let view = self.makeView(BalancedTextComponent(text: .plain(NSAttributedString(string: "Balanced")), balanced: true, horizontalAlignment: .center, maximumNumberOfLines: 0))
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "Balanced")
        XCTAssertEqual(view.accessibilityTraits, .staticText)
    }
    
    func testStaticTextElementsAreTextNotControlsInDisplayedContent() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 100.0))
        let balanced = self.makeView(BalancedTextComponent(text: .plain(NSAttributedString(string: "First")), balanced: false, horizontalAlignment: .natural, maximumNumberOfLines: 1))
        balanced.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 20.0)
        container.addSubview(balanced)
        let multiline = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Second"))))
        multiline.frame = CGRect(x: 0.0, y: 40.0, width: 100.0, height: 20.0)
        container.addSubview(multiline)
        
        let content = container.accessibilityDisplayedContent()
        XCTAssertEqual(content.texts, ["First", "Second"])
        XCTAssertFalse(content.hasInteractiveContent)
    }
    
    func testStandardGlyphBarButtonReadsItsName() {
        func make(_ name: String, accessibility: ComponentAccessibility? = nil) -> UIView {
            return self.makeView(GlassBarButtonComponent(
                size: CGSize(width: 44.0, height: 44.0),
                backgroundColor: nil,
                isDark: false,
                component: AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(name: name, tintColor: .black))),
                action: { _ in },
                accessibility: accessibility
            ))
        }
        XCTAssertEqual(make("Navigation/Close").accessibilityLabel, ComponentAccessibilityStrings.close)
        XCTAssertEqual(make("Navigation/Back").accessibilityLabel, ComponentAccessibilityStrings.back)
        XCTAssertNil(make("Navigation/Other").accessibilityLabel)
        XCTAssertEqual(make("Navigation/Close", accessibility: ComponentAccessibility(label: "Dismiss")).accessibilityLabel, "Dismiss")
    }
}
