import XCTest
import UIKit
@testable import Display

final class SplitMasterWidthTests: XCTestCase {
    private let innerLandscape = CGSize(width: 951.0, height: 669.0)

    func test_flat_usesDefaultMasterWidth() {
        XCTAssertEqual(splitMasterWidth(containerSize: self.innerLandscape, division: nil), 320.0)
    }

    func test_activeVerticalFold_splitsOnTheHingeMidline() {
        let fold = CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0)
        XCTAssertEqual(splitMasterWidth(containerSize: self.innerLandscape, division: fold), floorToScreenPixels(475.5))
    }

    func test_horizontalFold_usesDefaultMasterWidth() {
        let fold = CGRect(x: 0.0, y: 314.5, width: 951.0, height: 40.0)
        XCTAssertEqual(splitMasterWidth(containerSize: self.innerLandscape, division: fold), 320.0)
    }

    func test_foldNotSpanningContainer_usesDefaultMasterWidth() {
        let fold = CGRect(x: 455.5, y: 100.0, width: 40.0, height: 300.0)
        XCTAssertEqual(splitMasterWidth(containerSize: self.innerLandscape, division: fold), 320.0)
    }

    func test_defaultFormula_isThirdClampedTo320AndHalf() {
        XCTAssertEqual(splitMasterWidth(containerSize: CGSize(width: 1366.0, height: 1024.0), division: nil), floor(1366.0 / 3.0))
        XCTAssertEqual(splitMasterWidth(containerSize: CGSize(width: 600.0, height: 800.0), division: nil), 300.0)
    }
}
