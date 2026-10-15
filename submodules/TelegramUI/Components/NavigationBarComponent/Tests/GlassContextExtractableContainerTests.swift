import XCTest
import UIKit
import Display
import GlassBackgroundComponent
@testable import NavigationBarComponent

final class GlassContextExtractableContainerTests: XCTestCase {
    // Renewing the glass (ending UIKit's press on it) while a context menu has the container extracted would swap the
    // effect view out from under the menu's morph: it does nothing then.
    func test_renewGlass_whileExtracted_keepsTheEffectView() {
        let container = GlassContextExtractableContainer()
        container.update(size: CGSize(width: 44.0, height: 44.0), cornerRadius: 22.0, isDark: false, tintColor: GlassBackgroundView.TintColor(kind: .panel), isInteractive: true, transition: .immediate)
        guard let before = navigationBarTestGlassEffectView(content: container.contentView, container: container) else {
            XCTFail("no native glass")
            return
        }
        container.updateState(state: .extracted(size: CGSize(width: 200.0, height: 100.0), cornerRadius: 20.0, state: .animatedIn), transition: .transition(.immediate), completion: nil)
        container.renewGlass()
        XCTAssertTrue(navigationBarTestGlassEffectView(content: container.contentView, container: container) === before)
        // Back in its normal state, it renews.
        container.updateState(state: .normal, transition: .transition(.immediate), completion: nil)
        container.renewGlass()
        XCTAssertFalse(navigationBarTestGlassEffectView(content: container.contentView, container: container) === before)
    }
}
