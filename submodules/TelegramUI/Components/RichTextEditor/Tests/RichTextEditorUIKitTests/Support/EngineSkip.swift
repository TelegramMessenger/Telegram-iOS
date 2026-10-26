#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

/// True when the bundle is running the forced-TextKit-1 pass (`TK1=1 Scripts/iostest.sh`).
var isForcedTextKit1: Bool { BlockLayoutBackend.forceTextKit1 }

/// Throws XCTSkip under the forced-TextKit-1 pass. The ONLY legitimate reasons are the three
/// documented TK1 trade-offs in PKG/CLAUDE.md: no spoiler text-hiding, no loupe, no inline
/// predictions. Anything else is a real TK1 bug and must not be skipped.
func skipOnTextKit1(_ reason: String, file: StaticString = #filePath, line: UInt = #line) throws {
    try XCTSkipIf(isForcedTextKit1, "TK1: \(reason)", file: file, line: line)
}
#endif
