import XCTest
import UIKit
@testable import Display

/// Optional floating presentations (anchored popovers, centered sheets and modals) are for wide layouts,
/// except on iPhone Duo, which always uses the phone presentations — also on its unfolded screen, whose
/// landscape layout is regular width (and keeps the split view).
final class FloatingPanelsTests: XCTestCase {
    private func layout(size: CGSize, widthClass: ContainerViewLayoutSizeClass, deviceMetrics: DeviceMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: widthClass, heightClass: widthClass, orientation: .landscapeLeft, windowSize: size), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_duoUnfoldedLandscape_regular_noFloatingPanels() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), widthClass: .regular, deviceMetrics: .iPhoneDuo)
        XCTAssertFalse(l.presentsFloatingPanels)
    }

    func test_iPad_regular_floatingPanels() {
        let l = self.layout(size: CGSize(width: 1366.0, height: 1024.0), widthClass: .regular, deviceMetrics: .iPadPro)
        XCTAssertTrue(l.presentsFloatingPanels)
    }

    func test_compact_noFloatingPanels() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), widthClass: .compact, deviceMetrics: .iPhone16Pro)
        XCTAssertFalse(l.presentsFloatingPanels)
    }

    func test_forOptionalFloatingPresentation_duoRegular_becomesCompact() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), widthClass: .regular, deviceMetrics: .iPhoneDuo)
        let phone = l.forOptionalFloatingPresentation
        XCTAssertEqual(phone.metrics.widthClass, .compact)
        XCTAssertEqual(phone.metrics.heightClass, .compact)
        XCTAssertEqual(phone.metrics.orientation, l.metrics.orientation)
        XCTAssertEqual(phone.metrics.windowSize, l.metrics.windowSize)
        XCTAssertEqual(phone.size, l.size)
    }

    func test_forOptionalFloatingPresentation_iPad_unchanged() {
        let l = self.layout(size: CGSize(width: 1366.0, height: 1024.0), widthClass: .regular, deviceMetrics: .iPadPro)
        XCTAssertEqual(l.forOptionalFloatingPresentation, l)
    }

    func test_forOptionalFloatingPresentation_compact_unchanged() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), widthClass: .compact, deviceMetrics: .iPhone16Pro)
        XCTAssertEqual(l.forOptionalFloatingPresentation, l)
    }
}
