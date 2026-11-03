import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// Shared by the p19 selection-geometry regression tests: a range's selection rects must be finite, carry
/// exactly one logical start and one end, and its first rect must be finite (what UIKit draws the
/// highlight and the handles from, and places the edit menu and the autocorrection prompt against).
enum HarnessSelectionGeometry {
    static func problems(_ input: UIView & UITextInput, _ lower: Int, _ upper: Int) -> [String] {
        let begin = input.beginningOfDocument
        guard let start = input.position(from: begin, offset: lower), let end = input.position(from: begin, offset: upper),
              let range = input.textRange(from: start, to: end) else {
            return ["no range \(lower)..<\(upper)"]
        }
        var result: [String] = []
        let rects = input.selectionRects(for: range)
        if rects.isEmpty {
            result.append("no selection rects")
        }
        for rect in rects where !(rect.rect.minX.isFinite && rect.rect.minY.isFinite && rect.rect.height > 0) {
            result.append("selection rect \(rect.rect)")
        }
        let starts = rects.filter(\.containsStart).count
        let ends = rects.filter(\.containsEnd).count
        if starts != 1 || ends != 1 {
            result.append("rects carry \(starts) starts and \(ends) ends")
        }
        let first = input.firstRect(for: range)
        if !(first.minX.isFinite && first.minY.isFinite) {
            result.append("firstRect \(first)")
        }
        return result
    }

    /// The same question asked of a stock `UITextView` holding `text` (the oracle).
    static func stockProblems(_ root: HarnessRootViewController, _ text: String, _ lower: Int, _ upper: Int) -> [String] {
        let stock = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0))
        root.view.addSubview(stock)
        defer { stock.removeFromSuperview() }
        stock.text = text
        stock.layoutIfNeeded()
        return Self.problems(stock, lower, upper)
    }
}
