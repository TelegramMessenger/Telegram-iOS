import XCTest
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
@testable import NavigationBarComponent

/// A node that reports its own size, as the bar's real custom nodes do (a plain ASDisplayNode measures to the size
/// it is offered).
private final class NodeWithInteractiveChild: ASDisplayNode {
    let child = ASDisplayNode()

    override init() {
        super.init()
        self.child.frame = CGRect(x: 0.0, y: 0.0, width: 30.0, height: 30.0)
        self.addSubnode(self.child)
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 30.0, height: 30.0)
    }
}

private final class FixedSizeNode: ASDisplayNode {
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 20.0, height: 20.0)
    }
}

final class NavigationButtonComponentTests: XCTestCase {
    private func makeTheme(buttonColor: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: false, buttonColor: buttonColor, disabledButtonColor: .gray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .gray, accentForegroundColor: .white)
    }

    private func moreButtonAfterUpdate(_ button: ComponentView<NavigationButtonEnvironment>, theme: NavigationBarTheme) -> AnyObject? {
        let _ = button.update(
            transition: .immediate,
            component: AnyComponent(NavigationButtonComponent(content: .more, color: theme.buttonColor, isEnabled: true, pressed: { _ in }, contextAction: nil)),
            environment: {
                NavigationButtonEnvironment(theme: theme)
            },
            containerSize: CGSize(width: 100.0, height: 44.0)
        )
        return (button.view as? NavigationButtonComponent.View)?.moreButton
    }

    func test_moreButton_survivesARecreatedThemeWithTheSameColors() {
        let button = ComponentView<NavigationButtonEnvironment>()
        let first = self.moreButtonAfterUpdate(button, theme: self.makeTheme(buttonColor: .black))
        let second = self.moreButtonAfterUpdate(button, theme: self.makeTheme(buttonColor: .black))
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }

    func test_moreButton_isRebuiltWhenTheColorChanges() {
        let button = ComponentView<NavigationButtonEnvironment>()
        let first = self.moreButtonAfterUpdate(button, theme: self.makeTheme(buttonColor: .black))
        let second = self.moreButtonAfterUpdate(button, theme: self.makeTheme(buttonColor: .white))
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }

    func test_textButton_isAtLeastOneTapTargetWide() {
        let button = ComponentView<NavigationButtonEnvironment>()
        let size = button.update(
            transition: .immediate,
            component: AnyComponent(NavigationButtonComponent(content: .text(title: "Edit", isBold: false), color: .black, isEnabled: true, pressed: { _ in }, contextAction: nil)),
            environment: {
                NavigationButtonEnvironment(theme: self.makeTheme(buttonColor: .black))
            },
            containerSize: CGSize(width: 100.0, height: 44.0)
        )
        XCTAssertGreaterThanOrEqual(size.width, 44.0)
        XCTAssertEqual(size.height, 44.0)
    }

    private func render(_ content: NavigationBarComponent.Button.Content, isEnabled: Bool = true, color: UIColor = .black) -> (NavigationButtonComponent.View, CGSize) {
        let button = ComponentView<NavigationButtonEnvironment>()
        let size = button.update(
            transition: .immediate,
            component: AnyComponent(NavigationButtonComponent(content: content, color: color, isEnabled: isEnabled, pressed: { _ in }, contextAction: nil)),
            environment: {
                NavigationButtonEnvironment(theme: self.makeTheme(buttonColor: color))
            },
            containerSize: CGSize(width: 100.0, height: 44.0)
        )
        return (button.view as! NavigationButtonComponent.View, size)
    }

    func test_nodeButton_hostsTheNode() {
        let node = FixedSizeNode()
        let (view, size) = self.render(.node(node))
        XCTAssertTrue(node.view.superview === view)
        XCTAssertTrue(node.view.isUserInteractionEnabled)
        XCTAssertEqual(size.width, 44.0)
    }

    // The chat's avatar is a plain node holding a context-gesture source: its descendants must get the touch.
    func test_nodeButton_letsTheNodesDescendantsTakeTouches() {
        let node = NodeWithInteractiveChild()
        let (view, size) = self.render(.node(node))
        view.frame = CGRect(origin: CGPoint(), size: size)
        XCTAssertTrue(view.hitTest(CGPoint(x: size.width * 0.5, y: size.height * 0.5), with: nil) === node.child.view)
    }

    // Touches a hosted node's descendants pass up the responder chain press the button, once.
    func test_nodeButton_forwardedTouchesPressTheButtonOnce() {
        let node = NodeWithInteractiveChild()
        var pressed = 0
        let button = ComponentView<NavigationButtonEnvironment>()
        let size = button.update(
            transition: .immediate,
            component: AnyComponent(NavigationButtonComponent(content: .node(node), color: .black, isEnabled: true, pressed: { _ in
                pressed += 1
            }, contextAction: nil)),
            environment: {
                NavigationButtonEnvironment(theme: self.makeTheme(buttonColor: .black))
            },
            containerSize: CGSize(width: 100.0, height: 44.0)
        )
        let view = button.view as! NavigationButtonComponent.View
        view.frame = CGRect(origin: CGPoint(), size: size)
        let touch = UITouch()
        view.touchesBegan([touch], with: nil)
        view.touchesEnded([touch], with: nil)
        XCTAssertEqual(pressed, 1)
    }

    // A button node (the chat's "…", galleries' more buttons) takes its own touches.
    func test_nodeButton_keepsHighlightableButtonNodeTouches() {
        let node = HighlightableButtonNode()
        node.setTitle("More", with: Font.regular(17.0), with: .black, for: .normal)
        node.addTarget(self, action: #selector(self.buttonNodePressed), forControlEvents: .touchUpInside)
        let (view, size) = self.render(.node(node))
        view.frame = CGRect(origin: CGPoint(), size: size)
        XCTAssertTrue(view.hitTest(CGPoint(x: size.width * 0.5, y: size.height * 0.5), with: nil) === node.view)
    }

    @objc private func buttonNodePressed() {
    }

    func test_disabledButton_isNotEnabled() {
        let (view, _) = self.render(.text(title: "Save", isBold: true), isEnabled: false)
        XCTAssertFalse(view.isEnabled)
    }

    func test_templateImage_takesTheButtonColor() {
        let image = generateImage(CGSize(width: 10.0, height: 10.0), rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        })!.withRenderingMode(.alwaysTemplate)
        let (view, _) = self.render(.image(image), color: .red)
        XCTAssertEqual(view.iconView?.tintColor, .red)
    }

    func test_backButton_badgeWidensIt() {
        let theme = self.makeTheme(buttonColor: .black)
        let strings = NavigationBarStrings(back: "Back", close: "Close", more: "More")
        let plain = NavigationBarBackButtonView(onPressed: {})
        let badged = NavigationBarBackButtonView(onPressed: {})
        let plainSize = plain.update(kind: .back, badge: nil, contextAction: nil, theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: 44.0), transition: .immediate)
        let badgedSize = badged.update(kind: .back, badge: "12", contextAction: nil, theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: 44.0), transition: .immediate)
        XCTAssertEqual(plainSize.width, 44.0)
        XCTAssertGreaterThan(badgedSize.width, 44.0)
    }

    func test_closeBack_isLabelledClose() {
        let view = NavigationBarBackButtonView(onPressed: {})
        let _ = view.update(kind: .close, badge: nil, contextAction: nil, theme: self.makeTheme(buttonColor: .black), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), availableSize: CGSize(width: 100.0, height: 44.0), transition: .immediate)
        XCTAssertEqual(view.accessibilityLabel, "Close")
    }

    func test_backButton_contextActionEnablesTheGesture() {
        let view = NavigationBarBackButtonView(onPressed: {})
        let theme = self.makeTheme(buttonColor: .black)
        let strings = NavigationBarStrings(back: "Back", close: "Close", more: "More")
        let _ = view.update(kind: .back, badge: nil, contextAction: nil, theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: 44.0), transition: .immediate)
        XCTAssertFalse(view.isGestureEnabled)
        let _ = view.update(kind: .back, badge: nil, contextAction: { _, _ in }, theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: 44.0), transition: .immediate)
        XCTAssertTrue(view.isGestureEnabled)
    }
}
