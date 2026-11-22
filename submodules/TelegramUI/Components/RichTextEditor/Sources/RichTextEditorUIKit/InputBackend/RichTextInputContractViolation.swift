#if canImport(UIKit)
import Foundation

/// Spec failure class 1 (programmer violation): "Debug asserts with a precise message. Release
/// rejects safely and records a diagnostic." The overridable reporter exists because
/// `assertionFailure` traps the XCTest runner, and the contract suite must OBSERVE violations.
@available(iOS 13.0, *)
enum RichTextInputContractViolation {
    static var reporter: ((String) -> Void)?

    static func report(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        if let reporter {
            reporter(message)
            return
        }
        #if DEBUG
        assertionFailure("RichTextInput contract violation: \(message)", file: file, line: line)
        #else
        NSLog("RichTextInput contract violation: %@", message)
        #endif
    }
}
#endif
