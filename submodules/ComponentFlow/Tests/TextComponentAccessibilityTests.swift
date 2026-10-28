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
    
    func testControlDeclaredAsTextIsTextInDisplayedContent() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 100.0))
        let name = UIControl(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 20.0))
        name.isAccessibilityElement = true
        name.accessibilityLabel = "Your story"
        name.accessibilityTraits = .staticText
        container.addSubview(name)
        let button = UIButton(frame: CGRect(x: 0.0, y: 40.0, width: 100.0, height: 20.0))
        button.accessibilityLabel = "Close"
        container.addSubview(button)
        
        let content = container.accessibilityDisplayedContent()
        XCTAssertEqual(content.texts, ["Your story"])
        XCTAssertTrue(content.hasInteractiveContent)
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
    
    func testTextBesideAnAreaSpeakingItIsSilent() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 200.0))
        let text = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Delete the chat?"))))
        text.frame = CGRect(x: 20.0, y: 80.0, width: 200.0, height: 20.0)
        container.addSubview(text)
        XCTAssertTrue(text.isAccessibilityElement)
        
        let area = UIView(frame: container.bounds)
        area.isAccessibilityElement = true
        area.accessibilityLabel = "Delete the chat?"
        container.addSubview(area)
        XCTAssertFalse(text.isAccessibilityElement)
        
        area.accessibilityLabel = "Something else"
        XCTAssertTrue(text.isAccessibilityElement)
    }
    
    func testTextInsideALabelledContainerIsSilent() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 60.0))
        container.accessibilityLabel = "John Telegram"
        let text = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "John Telegram"))))
        text.frame = CGRect(x: 10.0, y: 10.0, width: 200.0, height: 20.0)
        container.addSubview(text)
        XCTAssertFalse(text.isAccessibilityElement)
    }
    
    func testTextInsideAnElementIsSilent() {
        let button = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 60.0))
        button.isAccessibilityElement = true
        let wrapper = UIView(frame: button.bounds)
        button.addSubview(wrapper)
        let text = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Inner"))))
        wrapper.addSubview(text)
        XCTAssertFalse(text.isAccessibilityElement)
    }
    
    func testShortTextInsideALongerWordIsNotSilenced() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 60.0))
        container.accessibilityLabel = "last seen 10 minutes ago, Mention"
        let count = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "1"))))
        count.frame = CGRect(x: 10.0, y: 10.0, width: 20.0, height: 20.0)
        container.addSubview(count)
        XCTAssertTrue(count.isAccessibilityElement)
        let on = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "On"))))
        on.frame = CGRect(x: 40.0, y: 10.0, width: 20.0, height: 20.0)
        container.addSubview(on)
        XCTAssertTrue(on.isAccessibilityElement)
        let words = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "10 minutes"))))
        words.frame = CGRect(x: 70.0, y: 10.0, width: 80.0, height: 20.0)
        container.addSubview(words)
        XCTAssertFalse(words.isAccessibilityElement)
    }
    
    func testOverlappingCopiesDoNotSilenceEachOther() {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 60.0))
        let first = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Title"))))
        first.frame = CGRect(x: 10.0, y: 10.0, width: 100.0, height: 20.0)
        container.addSubview(first)
        let second = self.makeView(MultilineTextComponent(text: .plain(NSAttributedString(string: "Title"))))
        second.frame = first.frame
        container.addSubview(second)
        XCTAssertTrue(first.isAccessibilityElement || second.isAccessibilityElement)
    }
    
    func testAttachmentsAreNotRead() {
        let string = NSMutableAttributedString(string: "Remove ")
        string.append(NSAttributedString(attachment: NSTextAttachment()))
        string.append(NSAttributedString(string: " fee"))
        let view = self.makeView(MultilineTextComponent(text: .plain(string)))
        XCTAssertEqual(view.accessibilityLabel?.contains("\u{FFFC}"), false)
    }
}
