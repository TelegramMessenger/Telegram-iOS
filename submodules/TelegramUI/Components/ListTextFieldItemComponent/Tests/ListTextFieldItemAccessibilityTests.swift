import XCTest
import UIKit
import ComponentFlow
import TelegramPresentationData
@testable import ListTextFieldItemComponent

/// The field is labelled with its placeholder (drawn by a separate view) and the icon-only clear button with the label
/// the host passes.
final class ListTextFieldItemAccessibilityTests: XCTestCase {
    private func render(clearLabel: String?) -> UIView {
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(
            transition: .immediate,
            component: AnyComponent(ListTextFieldItemComponent(
                style: .glass,
                theme: defaultDarkPresentationTheme,
                initialText: "Ann",
                placeholder: "First Name",
                clearButtonAccessibilityLabel: clearLabel,
                updated: { _ in }
            )),
            environment: {},
            containerSize: CGSize(width: 370.0, height: 100.0)
        )
        return componentView.view!
    }

    private func allViews(_ view: UIView) -> [UIView] {
        return [view] + view.subviews.flatMap { self.allViews($0) }
    }

    func testFieldIsLabelledWithItsPlaceholder() {
        let view = self.render(clearLabel: nil)
        let field = self.allViews(view).first(where: { $0 is UITextField })
        XCTAssertEqual(field?.accessibilityLabel, "First Name")
    }

    func testClearButtonIsLabelled() {
        let view = self.render(clearLabel: "Clear")
        let clear = self.allViews(view).first(where: { $0.accessibilityLabel == "Clear" })
        XCTAssertNotNil(clear)
        XCTAssertTrue(clear?.isAccessibilityElement ?? false)
        XCTAssertTrue(clear?.accessibilityTraits.contains(.button) ?? false)
    }

    func testNoLabelLeavesTheButtonAsBefore() {
        XCTAssertNil(listTextFieldClearButtonAccessibility(label: nil))
        XCTAssertNil(listTextFieldClearButtonAccessibility(label: ""))
        XCTAssertEqual(listTextFieldClearButtonAccessibility(label: "Clear")?.label, "Clear")
    }
}
