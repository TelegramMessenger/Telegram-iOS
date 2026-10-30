import XCTest
import CoreGraphics
@testable import ChatTitleView

final class ChatTitleLeadingIconsLayoutTests: XCTestCase {
    private let titleFrame = CGRect(x: 100.0, y: 2.0, width: 80.0, height: 22.0)
    private let lockSize = CGSize(width: 10.0, height: 14.0)
    private let verificationSize = CGSize(width: 20.0, height: 20.0)

    // A secret chat with a third-party-verified user: [verification] [lock] [name], no overlap.
    func testVerificationIconSitsLeftOfLock() {
        let layout = chatTitleLeadingIconsLayout(titleFrame: self.titleFrame, lockIconSize: self.lockSize, lockIconSpacing: 3.0, verificationIconSize: self.verificationSize, verificationIconSpacing: 4.0)
        guard let lockFrame = layout.lockIconFrame, let verificationFrame = layout.verificationIconFrame else {
            return XCTFail("both icons expected")
        }
        XCTAssertEqual(lockFrame.maxX, self.titleFrame.minX - 3.0)
        XCTAssertEqual(verificationFrame.maxX, lockFrame.minX - 4.0)
        XCTAssertFalse(verificationFrame.intersects(lockFrame))
    }

    // A secret chat without verification: the lock keeps its place.
    func testLockAloneIsUnchanged() {
        let layout = chatTitleLeadingIconsLayout(titleFrame: self.titleFrame, lockIconSize: self.lockSize, lockIconSpacing: 3.0, verificationIconSize: nil, verificationIconSpacing: 4.0)
        XCTAssertEqual(layout.lockIconFrame, CGRect(x: 100.0 - 3.0 - 10.0, y: 2.0 + 3.0, width: 10.0, height: 14.0))
        XCTAssertNil(layout.verificationIconFrame)
    }

    // A non-secret chat with verification: the icon sits right before the name.
    func testVerificationAloneIsUnchanged() {
        let layout = chatTitleLeadingIconsLayout(titleFrame: self.titleFrame, lockIconSize: nil, lockIconSpacing: 3.0, verificationIconSize: self.verificationSize, verificationIconSpacing: 4.0)
        XCTAssertNil(layout.lockIconFrame)
        XCTAssertEqual(layout.verificationIconFrame, CGRect(x: 100.0 - 4.0 - 20.0, y: 2.0, width: 20.0, height: 20.0))
    }

    func testOutermostIconComesBeforeVerification() {
        let titleFrame = CGRect(x: 100.0, y: 10.0, width: 50.0, height: 20.0)
        let layout = chatTitleLeadingIconsLayout(titleFrame: titleFrame, lockIconSize: CGSize(width: 22.0, height: 22.0), lockIconSpacing: 6.0, verificationIconSize: CGSize(width: 20.0, height: 20.0), verificationIconSpacing: 4.0, lockIconIsOutermost: true)
        XCTAssertEqual(layout.verificationIconFrame?.minX, 76.0)
        XCTAssertEqual(layout.lockIconFrame?.minX, 48.0)
    }
}
