#if canImport(UIKit)
import RichTextInputDecObjC
import XCTest

/// Swift cannot catch an NSException; an uncaught one is an immediate crash. Every call the
/// adapter makes into the vendored kernel therefore goes through this trampoline.
final class ExceptionGuardTests: XCTestCase {

    func test_aRaisedExceptionBecomesAnError_notACrash() {
        var error: NSError?
        let ok = TGRichTextInputDecPerform({
            NSException(name: .internalInconsistencyException,
                        reason: "synthetic", userInfo: nil).raise()
        }, &error)
        XCTAssertFalse(ok)
        XCTAssertEqual(error?.domain, TGRichTextInputDecExceptionGuardErrorDomain)
        XCTAssertEqual(error?.localizedDescription, "synthetic")
    }

    func test_aCleanBlockReportsSuccessAndLeavesTheErrorUntouched() {
        var error: NSError? = NSError(domain: "sentinel", code: 0)
        var ran = false
        XCTAssertTrue(TGRichTextInputDecPerform({ ran = true }, &error))
        XCTAssertTrue(ran)
        XCTAssertEqual(error?.domain, "sentinel", "a successful call must not clobber the out-param")
    }

    func test_theObjectFlavorReturnsNilOnRaise_andTheValueOtherwise() {
        var error: NSError?
        XCTAssertNil(TGRichTextInputDecPerformReturningObject({
            NSException(name: .genericException, reason: "boom", userInfo: nil).raise()
            return NSString("unreachable")
        }, &error))
        XCTAssertNotNil(error)
        error = nil
        let value = TGRichTextInputDecPerformReturningObject({ NSString("ok") }, &error) as? String
        XCTAssertEqual(value, "ok")
        XCTAssertNil(error)
    }

    /// The exception name and userInfo must survive into the error, or a production report of
    /// "the kernel refused" carries no diagnostic value.
    func test_theExceptionNameAndUserInfoSurviveIntoTheError() {
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            NSException(name: .internalInconsistencyException, reason: "why",
                        userInfo: ["stage": "preflight"]).raise()
        }, &error)
        XCTAssertEqual(error?.userInfo["TGRichTextInputDecExceptionName"] as? String,
                       NSExceptionName.internalInconsistencyException.rawValue)
        XCTAssertEqual((error?.userInfo["TGRichTextInputDecExceptionUserInfo"]
                        as? [String: Any])?["stage"] as? String, "preflight")
    }

    /// ANTI-VACUITY: the four tests above raise a SYNTHETIC `NSException` to pin down the guard's
    /// mechanics in isolation. That proves the trampoline works, but not that it is actually
    /// wired in front of the vendored kernel's own `@throw` sites. This test fires a REAL one:
    /// `IDUIKitBehaviorReport.m`'s `-[IDUIKitCapabilityReport reportByActivating]` (one of the
    /// seven surviving vendored `@throw` statements — see Vendor/VENDOR.md and
    /// `TGRichTextInputDecContract.h`) raises `NSInternalInconsistencyException` whenever the
    /// receiver's state is neither `.available` nor already `.active`. `IDUIKitCapabilityReport`'s
    /// designated initializer is public and takes no manifest/resolver/view, so a `.unavailable`
    /// report is the cheapest way to reach a genuine kernel throw without touching Vendor/.
    ///
    /// Without the guard, this @throw crosses back into Swift uncaught and the test process
    /// crashes rather than failing — which is exactly why this call is not spelled as a bare
    /// `report.reportByActivating()`.
    func test_aRealKernelThrow_fromReportByActivating_becomesAnError() {
        let report = IDUIKitCapabilityReport(identifier: "probe",
                                              state: .unavailable,
                                              requiredMembers: [],
                                              observedABIs: [:],
                                              dependencies: [],
                                              fallback: "none",
                                              rejectionReason: "probe")
        var error: NSError?
        let activated = TGRichTextInputDecPerformReturningObject({
            report.activating()
        }, &error) as? IDUIKitCapabilityReport
        XCTAssertNil(activated, "a report that never reached .available must not activate")
        XCTAssertEqual(error?.domain, TGRichTextInputDecExceptionGuardErrorDomain)
        XCTAssertEqual(error?.localizedDescription,
                       "Capability probe cannot transition from unavailable to active")
    }
}
#endif
