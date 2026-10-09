import XCTest
import UIKit
@testable import Display

/// `.modalInLargeLayout` opens a sheet only in a regular-width layout whose shorter side is at least
/// 700pt; smaller regular layouts (iPhone Duo unfolded in landscape) push it as compact layouts do.
final class ModalInLargeLayoutTests: XCTestCase {
    private func layout(_ size: CGSize, _ widthClass: ContainerViewLayoutSizeClass) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: widthClass, heightClass: widthClass, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_unfoldedDuoLandscape_pushes() {
        XCTAssertFalse(presentsModalInLargeLayout(self.layout(CGSize(width: 951.0, height: 669.0), .regular)))
    }

    func test_iPadMini_bothOrientations_sheet() {
        XCTAssertTrue(presentsModalInLargeLayout(self.layout(CGSize(width: 744.0, height: 1133.0), .regular)))
        XCTAssertTrue(presentsModalInLargeLayout(self.layout(CGSize(width: 1133.0, height: 744.0), .regular)))
    }

    func test_largeIPad_sheet() {
        XCTAssertTrue(presentsModalInLargeLayout(self.layout(CGSize(width: 1024.0, height: 1366.0), .regular)))
    }

    func test_compactPhone_pushes() {
        XCTAssertFalse(presentsModalInLargeLayout(self.layout(CGSize(width: 402.0, height: 874.0), .compact)))
    }

    func test_threshold_700() {
        XCTAssertFalse(presentsModalInLargeLayout(self.layout(CGSize(width: 1000.0, height: 699.0), .regular)))
        XCTAssertTrue(presentsModalInLargeLayout(self.layout(CGSize(width: 1000.0, height: 700.0), .regular)))
    }
}
