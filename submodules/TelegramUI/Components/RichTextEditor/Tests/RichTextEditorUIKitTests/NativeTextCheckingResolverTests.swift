#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class NativeTextCheckingResolverTests: XCTestCase {
    func test_privateClassResolvesOnThisOS() {
        // The class exists on the sim's iOS; if this ever fails, the engine silently disables (by design).
        XCTAssertTrue(NativeTextChecker.nativeCheckingControllerClassIsAvailable,
                      "native text-checking controller class did not resolve — engine would be OFF")
    }
    func test_initWithStubClientSucceeds() {
        let stub = StubClient()
        let checker = NativeTextChecker(client: stub)
        XCTAssertNotNil(checker, "could not instantiate the controller with a stub client")
        checker?.invalidate()
    }
    // Minimal UITextInput-ish stub (the controller only reads through it here).
    final class StubClient: NSObject {
        let s = NSMutableAttributedString(string: "hello")
        final class P: UITextPosition { let o: Int; init(_ o: Int){ self.o = o } }
        final class R: UITextRange { let a: P; let b: P; init(_ a: P,_ b: P){ self.a=a; self.b=b }
            override var start: UITextPosition { a }; override var end: UITextPosition { b } }
        @objc var beginningOfDocument: UITextPosition { P(0) }
        @objc var endOfDocument: UITextPosition { P(s.length) }
        @objc var selectedTextRange: UITextRange? { R(P(s.length), P(s.length)) }
        @objc(comparePosition:toPosition:) func cmp(_ x: UITextPosition,_ y: UITextPosition) -> ComparisonResult {
            let a=(x as! P).o, b=(y as! P).o; return a<b ? .orderedAscending : (a>b ? .orderedDescending : .orderedSame) }
        @objc(positionFromPosition:offset:) func pos(_ p: UITextPosition, offset n: Int) -> UITextPosition? {
            let v=(p as! P).o+n; return (v>=0 && v<=s.length) ? P(v) : nil }
        @objc(offsetFromPosition:toPosition:) func off(_ x: UITextPosition, to y: UITextPosition) -> Int { (y as! P).o-(x as! P).o }
        @objc(textRangeFromPosition:toPosition:) func rng(_ x: UITextPosition, to y: UITextPosition) -> UITextRange? { R(x as! P, y as! P) }
        @objc(textInRange:) func txt(_ r: UITextRange) -> String? {
            let rr=r as! R; return s.attributedSubstring(from: NSRange(location: rr.a.o, length: rr.b.o-rr.a.o)).string }
        @objc(annotatedSubstringForRange:) func ann(_ r: UITextRange) -> NSAttributedString? {
            let rr=r as! R; return s.attributedSubstring(from: NSRange(location: rr.a.o, length: rr.b.o-rr.a.o)) }
        @objc(replaceRange:withAnnotatedString:relativeReplacementRange:) func rep(_ r: UITextRange, withAnnotatedString a: NSAttributedString, relativeReplacementRange rr: NSRange) {}
        @objc(removeAnnotation:forRange:) func rem(_ a: Any, forRange r: UITextRange) {}
        @objc var validAnnotations: [Any] { [] }
        @objc var smartDashesType: UITextSmartDashesType { .no }
        @objc var smartQuotesType: UITextSmartQuotesType { .no }
        @objc var smartInsertDeleteType: UITextSmartInsertDeleteType { .no }
    }
}
#endif
