import XCTest
import UIKit
@testable import Display

/// iPhone Duo's status block and safe insets follow the system's report when it fits the window's posture, and fall
/// back to the table's settled values while it does not (the report is transitional after rotations and folds).
final class DuoSystemReservedAreaTests: XCTestCase {
    private let cover = CGSize(width: 466.0, height: 678.0)
    private let coverLandscape = CGSize(width: 678.0, height: 466.0)
    private let inner = CGSize(width: 669.0, height: 951.0)
    private let innerLandscape = CGSize(width: 951.0, height: 669.0)

    private func corners(topLeft: CGSize? = nil, topRight: CGSize? = nil, bottomLeft: CGSize? = nil, bottomRight: CGSize? = nil) -> ContainerViewLayoutCorners {
        return ContainerViewLayoutCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }

    // The report as measured on the simulator (bottom 34 is the home indicator, which the safe insets leave out).

    func test_coverPortrait_measuredReport_blockAndCamera() {
        let area = iPhoneDuoReservedArea(windowSize: self.cover, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 399.67, y: 29.33, width: 37.0, height: 37.0),
            CGRect(x: 382.0, y: 0.0, width: 84.0, height: 170.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 170.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_coverLandscapeRight_measuredReport_replacesTable() {
        // The table has 84x84; the system settles at 84x82.
        let area = iPhoneDuoReservedArea(windowSize: self.coverLandscape, orientation: .landscapeRight, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), systemOcclusions: [
            CGRect(x: 29.33, y: 29.33, width: 37.0, height: 37.0),
            CGRect(x: 0.0, y: 0.0, width: 84.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topLeft: CGSize(width: 84.0, height: 82.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))
    }

    func test_coverLandscapeLeft_measuredReport_bottomRight() {
        let area = iPhoneDuoReservedArea(windowSize: self.coverLandscape, orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 594.0, y: 384.0, width: 84.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(bottomRight: CGSize(width: 84.0, height: 82.0)))
    }

    // A block of another size than the table's: its size is the system's.

    func test_innerPortrait_islandOfAnotherHeight_followsSystem() {
        let area = iPhoneDuoReservedArea(windowSize: self.inner, orientation: .portraitUpsideDown, systemSafeInsets: UIEdgeInsets(top: 74.0, left: 0.0, bottom: 34.0, right: 0.0), systemOcclusions: [
            CGRect(x: 669.0 - 140.0, y: 0.0, width: 140.0, height: 74.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 140.0, height: 74.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 74.0, left: 0.0, bottom: 0.0, right: 0.0))
    }

    func test_coverPortrait_tallerBlock_followsSystem() {
        let area = iPhoneDuoReservedArea(windowSize: self.cover, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 382.0, y: 0.0, width: 84.0, height: 210.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 210.0)))
    }

    func test_innerLandscape_followsSystem() {
        let area = iPhoneDuoReservedArea(windowSize: self.innerLandscape, orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), systemOcclusions: [
            CGRect(x: 867.0, y: 0.0, width: 84.0, height: 126.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 126.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    // Transitional reports: the table stands in.

    func test_noReport_table() {
        let area = iPhoneDuoReservedArea(windowSize: self.inner, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 34.0, right: 0.0), systemOcclusions: [])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0))
    }

    func test_strayBlock_notInTheCorner_table() {
        let area = iPhoneDuoReservedArea(windowSize: self.cover, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 399.67, y: 29.33, width: 37.0, height: 37.0),
            CGRect(x: 300.0, y: 0.0, width: 84.0, height: 170.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 170.0)))
    }

    func test_previousPostureBlock_inAnotherCorner_table() {
        // Folded portrait's block still reported after rotating to landscape-left, whose block is at the bottom right.
        let area = iPhoneDuoReservedArea(windowSize: self.coverLandscape, orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 594.0, y: 0.0, width: 84.0, height: 170.0)
        ])
        XCTAssertEqual(area.corners, self.corners(bottomRight: CGSize(width: 84.0, height: 82.0)))
    }

    func test_previousPostureBlock_inTheSameCorner_table() {
        // Unfolded portrait's island still reported after rotating to landscape, whose block is also at the top right:
        // it is not as thick as the landscape's side inset.
        let area = iPhoneDuoReservedArea(windowSize: self.innerLandscape, orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), systemOcclusions: [
            CGRect(x: 951.0 - 134.0, y: 0.0, width: 134.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_previousPostureInsets_table() {
        // Portrait's top inset kept on the landscape inner screen (measured after an unfold), with portrait's island.
        let area = iPhoneDuoReservedArea(windowSize: self.innerLandscape, orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0), systemOcclusions: [
            CGRect(x: 951.0 - 134.0, y: 0.0, width: 134.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_newBlock_previousPostureInsets_table() {
        // The island already reported, the landscape's side inset not yet gone.
        let area = iPhoneDuoReservedArea(windowSize: self.inner, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 669.0 - 134.0, y: 0.0, width: 134.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertEqual(area.safeInsets, UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0))
    }

    // Postures the table does not know: no corners, the live insets apply.

    func test_unknownPosture_nilInsets_noCorners() {
        let area = iPhoneDuoReservedArea(windowSize: self.cover, orientation: .portraitUpsideDown, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), systemOcclusions: [
            CGRect(x: 0.0, y: 508.0, width: 84.0, height: 170.0)
        ])
        XCTAssertNil(area.safeInsets)
        XCTAssertEqual(area.corners, ContainerViewLayoutCorners.none)
    }

    func test_windowNotFillingAScreen_noCorners() {
        let area = iPhoneDuoReservedArea(windowSize: CGSize(width: 475.0, height: 669.0), orientation: .landscapeLeft, systemSafeInsets: UIEdgeInsets(), systemOcclusions: [
            CGRect(x: 391.0, y: 0.0, width: 84.0, height: 120.0)
        ])
        XCTAssertNil(area.safeInsets)
        XCTAssertEqual(area.corners, ContainerViewLayoutCorners.none)
    }

    // After a rotation or a fold the report is not taken until it has settled: folded landscape-left's 84x82 block
    // reported in folded portrait's corner, beside portrait's inset, fits portrait (measured for 47ms).

    func test_previousPostureBlock_fittingThePosture_isTakenWhenPassed() {
        let area = iPhoneDuoReservedArea(windowSize: self.cover, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), systemOcclusions: [
            CGRect(x: 382.0, y: 0.0, width: 84.0, height: 82.0)
        ])
        XCTAssertEqual(area.corners, self.corners(topRight: CGSize(width: 84.0, height: 82.0)))
    }

    func test_postureChange_unsettlesTheReportForTheSettleDelay() {
        iPhoneDuoPostureWillChange()
        XCTAssertFalse(iPhoneDuoSystemReportIsSettled)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: iPhoneDuoSystemReportSettleDelay + 0.05))
        XCTAssertTrue(iPhoneDuoSystemReportIsSettled)
    }

    // What the layout derives from a system-sized block.

    func test_systemBlock_keepsTheSideStrip() {
        let area = iPhoneDuoReservedArea(windowSize: self.coverLandscape, orientation: .landscapeRight, systemSafeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), systemOcclusions: [
            CGRect(x: 0.0, y: 0.0, width: 84.0, height: 82.0)
        ])
        let layout = ContainerViewLayout(size: self.coverLandscape, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: area.safeInsets!, reservedCorners: area.corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: 0.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
        XCTAssertEqual(layout.sideStrip(edge: .left), CGRect(x: 0.0, y: 82.0, width: 84.0, height: 466.0 - 82.0))
    }

    func test_systemIsland_movesTheTopBarClearOfIt() {
        let area = iPhoneDuoReservedArea(windowSize: self.inner, orientation: .portrait, systemSafeInsets: UIEdgeInsets(top: 74.0, left: 0.0, bottom: 34.0, right: 0.0), systemOcclusions: [
            CGRect(x: 669.0 - 140.0, y: 0.0, width: 140.0, height: 74.0)
        ])
        let layout = ContainerViewLayout(size: self.inner, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: area.safeInsets!, reservedCorners: area.corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: 74.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
        XCTAssertEqual(layout.topBarStatusIsland, CGSize(width: 140.0, height: 74.0))
        XCTAssertEqual(layout.navigationBarTrailingButtonsInset, 140.0)
    }
}
