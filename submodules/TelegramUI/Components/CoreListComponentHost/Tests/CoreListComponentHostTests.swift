import XCTest
import UIKit
import ComponentFlow
import CoreList
@testable import CoreListComponentHost

private final class FixedHeightComponent: Component {
    let height: CGFloat

    init(height: CGFloat) {
        self.height = height
    }

    static func ==(lhs: FixedHeightComponent, rhs: FixedHeightComponent) -> Bool {
        return lhs.height == rhs.height
    }

    final class View: UIView {
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return CGSize(width: availableSize.width, height: self.height)
    }
}

/// Grows by 10 pt each time its own state asks for an update.
private final class GrowingComponent: Component {
    static func ==(lhs: GrowingComponent, rhs: GrowingComponent) -> Bool {
        return true
    }

    final class View: UIView {
        var height: CGFloat = 20.0
        weak var state: EmptyComponentState?

        func grow() {
            self.height += 10.0
            self.state?.updated(transition: .immediate)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.state = state
        return CGSize(width: availableSize.width, height: view.height)
    }
}

final class CoreListComponentHostTests: XCTestCase {
    func testRowHeightIsTheComponentHeight() {
        let view = CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 44.0))).view()
        XCTAssertEqual(view.update(width: 320.0, transition: .immediate), 44.0)
    }

    func testEqualityFollowsIdentityAndComponent() {
        let item = CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 44.0)))
        XCTAssertTrue(item.isEqual(to: CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 44.0)))))
        XCTAssertFalse(item.isEqual(to: CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 50.0)))))
        XCTAssertFalse(item.isEqual(to: CoreListComponentItem(identity: "b", component: AnyComponent(FixedHeightComponent(height: 44.0)))))
    }

    func testApplyReconfiguresAReusedView() {
        let view = CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 44.0))).view()
        let _ = view.update(width: 320.0, transition: .immediate)
        CoreListComponentItem(identity: "a", component: AnyComponent(FixedHeightComponent(height: 60.0))).apply(to: view, transition: .immediate)
        XCTAssertEqual(view.update(width: 320.0, transition: .immediate), 60.0)
    }

    func testComponentStateUpdateAsksForARemeasure() {
        let view = CoreListComponentItem(identity: "g", component: AnyComponent(GrowingComponent())).view()
        var calls = 0
        view.onContentDidChange = { _ in
            calls += 1
        }
        XCTAssertEqual(view.update(width: 320.0, transition: .immediate), 20.0)
        guard let growing = (view as? CoreListComponentItemView)?.componentView as? GrowingComponent.View else {
            XCTFail("no component view")
            return
        }
        growing.grow()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(view.update(width: 320.0, transition: .immediate), 30.0)
    }

    func testBridgeMapsImmediateAndCurves() {
        if case .none = ComponentTransition(CoreListTransition.immediate).animation {
        } else {
            XCTFail("immediate must map to .none")
        }
        if case let .curve(duration, curve) = ComponentTransition(CoreListTransition.easeInOut(duration: 0.3)).animation {
            XCTAssertEqual(duration, 0.3)
            if case .easeInOut = curve {
            } else {
                XCTFail("wrong curve")
            }
        } else {
            XCTFail("expected a curve")
        }
    }
}
