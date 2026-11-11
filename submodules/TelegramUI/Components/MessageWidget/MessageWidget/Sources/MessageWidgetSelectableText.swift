import CoreGraphics
import Foundation
import WidgetRuntimeIOS

/// The text a widget lets the reader select (sdk-v1 §2.4, §5.10), as the runtime exported it for one layout
/// (`WRSession.selectableText`): the selectable text in document order, and where each run of it is drawn, in the widget
/// view's coordinates (the document's CSS px). Main answers the selection's questions from it without the runtime.
public struct MessageWidgetSelectableText: Equatable {
    public struct Run: Equatable {
        /// Its first UTF-16 unit in `text`, and how many.
        public let start: Int
        public let length: Int
        /// Its layout box, before `transform`.
        public let box: CGRect
        /// `length + 1` offsets from `box.minX`, one per UTF-16 boundary (descending right to left).
        public let carets: [CGFloat]
        /// Box space → the view.
        public let transform: CGAffineTransform
        /// Its Text node, and the UTF-16 offset of `start` in that node's drawn text.
        public let node: UInt64
        public let nodeOffset: Int

        public init(start: Int, length: Int, box: CGRect, carets: [CGFloat], transform: CGAffineTransform, node: UInt64, nodeOffset: Int) {
            self.start = start
            self.length = length
            self.box = box
            self.carets = carets
            self.transform = transform
            self.node = node
            self.nodeOffset = nodeOffset
        }
    }

    /// Where a knob stands: a caret's x, the top of its line and the line's height.
    public struct Edge: Equatable {
        public let x: CGFloat
        public let y: CGFloat
        public let height: CGFloat
    }

    /// A boundary as the runtime names it: a Text node, and an offset in its drawn text. It survives a new layout.
    public struct Position: Equatable {
        public let node: UInt64
        public let offset: Int
    }

    /// How far off its glyphs, above or below, a point still hits a run (at most half the run's height).
    static let reach: CGFloat = 4.0

    public let text: NSString
    /// In `text` order; separators between runs belong to none.
    public let runs: [Run]

    public init(text: NSString, runs: [Run]) {
        self.text = text
        self.runs = runs
    }

    init(_ exported: WRSelectableText) {
        let count = exported.runs.count / MemoryLayout<WRSelectableRun>.stride
        var records = [WRSelectableRun](repeating: WRSelectableRun(), count: count)
        records.withUnsafeMutableBufferPointer { buffer in
            _ = exported.runs.copyBytes(to: buffer)
        }
        var carets = [Float](repeating: 0.0, count: exported.carets.count / MemoryLayout<Float>.stride)
        carets.withUnsafeMutableBufferPointer { buffer in
            _ = exported.carets.copyBytes(to: buffer)
        }
        self.text = exported.text as NSString
        self.runs = records.compactMap { record in
            let first = Int(record.caretIndex)
            let end = first + Int(record.length) + 1
            guard end <= carets.count else {
                return nil
            }
            return Run(start: Int(record.start), length: Int(record.length), box: record.box, carets: carets[first ..< end].map { CGFloat($0) }, transform: record.transform, node: record.node, nodeOffset: Int(record.nodeOffset))
        }
    }

    public var isEmpty: Bool {
        return self.runs.isEmpty
    }

    /// The character under `point`, as TextNode answers it (a point on either half of a surrogate pair is the pair's
    /// first unit). A finger lands a little off the glyphs, so a point within `reach` above or below a run hits it too,
    /// the nearer run winning; no farther, or a hold on an unselectable line right under a selectable one would select
    /// the word above (final review M1). nil off every run, unless
    /// `nearest`: then the closest run (by vertical distance, then horizontal) answers, its start or its end for a point
    /// beyond its ends.
    public func index(at point: CGPoint, nearest: Bool) -> Int? {
        var hit: (run: Run, x: CGFloat, dy: CGFloat)?
        for run in self.runs {
            let local = point.applying(run.transform.inverted())
            let reach = min(run.box.height / 2.0, MessageWidgetSelectableText.reach)
            guard local.x >= run.box.minX && local.x < run.box.maxX && local.y >= run.box.minY - reach && local.y < run.box.maxY + reach else {
                continue
            }
            let dy = max(0.0, run.box.minY - local.y, local.y - run.box.maxY)
            if let current = hit, current.dy <= dy {
                continue
            }
            hit = (run, local.x - run.box.minX, dy)
        }
        if let hit, let k = self.character(in: hit.run, x: hit.x) {
            return hit.run.start + k
        }
        guard nearest else {
            return nil
        }
        var best: (run: Run, dy: CGFloat, dx: CGFloat)?
        for run in self.runs {
            let frame = run.box.applying(run.transform)
            let dy = max(0.0, frame.minY - point.y, point.y - frame.maxY)
            let dx = max(0.0, frame.minX - point.x, point.x - frame.maxX)
            if let current = best, (current.dy, current.dx) <= (dy, dx) {
                continue
            }
            best = (run, dy, dx)
        }
        guard let run = best?.run else {
            return nil
        }
        let x = point.applying(run.transform.inverted()).x - run.box.minX
        let leftToRight = run.carets[0] <= run.carets[run.length]
        let left = min(run.carets[0], run.carets[run.length])
        let right = max(run.carets[0], run.carets[run.length])
        if x < left {
            return leftToRight ? run.start : run.start + run.length
        }
        if x >= right {
            return leftToRight ? run.start + run.length : run.start
        }
        return run.start + (self.character(in: run, x: x) ?? 0)
    }

    /// The rects of `range`, one per line (the runs a line holds merged, so the gaps between words are covered), and the
    /// knobs' edges at its ends; nil when it covers no run's text.
    public func rangeRects(_ range: NSRange) -> (rects: [CGRect], start: Edge, end: Edge)? {
        var rects: [CGRect] = []
        var start: Edge?
        var end: Edge?
        for run in self.runs {
            let lower = max(range.location, run.start) - run.start
            let upper = min(range.location + range.length, run.start + run.length) - run.start
            if lower >= upper {
                continue
            }
            let from = run.carets[lower]
            let to = run.carets[upper]
            let rect = CGRect(x: run.box.minX + min(from, to), y: run.box.minY, width: abs(to - from), height: run.box.height).applying(run.transform)
            if let last = rects.last, min(last.maxY, rect.maxY) - max(last.minY, rect.minY) >= min(last.height, rect.height) / 2.0 {
                rects[rects.count - 1] = last.union(rect)
            } else {
                rects.append(rect)
            }
            if start == nil {
                start = MessageWidgetSelectableText.edge(in: run, caret: from)
            }
            end = MessageWidgetSelectableText.edge(in: run, caret: to)
        }
        guard let start, let end, !rects.isEmpty else {
            return nil
        }
        return (rects, start, end)
    }

    /// The boundary `index` as the runtime names it; one inside a separator is the next run's start.
    public func position(at index: Int) -> Position? {
        for run in self.runs {
            if index < run.start {
                return Position(node: run.node, offset: run.nodeOffset)
            }
            if index <= run.start + run.length {
                return Position(node: run.node, offset: run.nodeOffset + index - run.start)
            }
        }
        guard let last = self.runs.last else {
            return nil
        }
        return Position(node: last.node, offset: last.nodeOffset + last.length)
    }

    /// Where a boundary the runtime named is now; nil when no run shows it (its node was removed or replaced, or the
    /// text there stopped being selectable).
    public func index(of position: Position) -> Int? {
        for run in self.runs where run.node == position.node {
            if position.offset >= run.nodeOffset && position.offset <= run.nodeOffset + run.length {
                return run.start + position.offset - run.nodeOffset
            }
        }
        return nil
    }

    /// A range of `previous` found again in this export: its two ends, named by Text node, where they are now, widened to
    /// whole characters (a node whose data changes in place keeps its name, so an old offset can land inside a surrogate
    /// pair: final review I2); nil when either end is gone.
    public func remap(_ range: NSRange, from previous: MessageWidgetSelectableText) -> NSRange? {
        guard let start = previous.position(at: range.location), let end = previous.position(at: range.location + range.length), let lower = self.index(of: start), let upper = self.index(of: end), upper > lower else {
            return nil
        }
        let whole = self.text.rangeOfComposedCharacterSequences(for: NSRange(location: lower, length: upper - lower))
        return whole.length > 0 ? whole : nil
    }

    /// The character of `run` whose glyphs span `x` (from the box's left); a surrogate pair's second unit answers as its
    /// first.
    private func character(in run: Run, x: CGFloat) -> Int? {
        for k in 0 ..< run.length {
            let lower = min(run.carets[k], run.carets[k + 1])
            let upper = max(run.carets[k], run.carets[k + 1])
            if x >= lower && x < upper {
                if k > 0 && CFStringIsSurrogateLowCharacter(self.text.character(at: run.start + k)) {
                    return k - 1
                }
                return k
            }
        }
        return nil
    }

    private static func edge(in run: Run, caret: CGFloat) -> Edge {
        let top = CGPoint(x: run.box.minX + caret, y: run.box.minY).applying(run.transform)
        let bottom = CGPoint(x: run.box.minX + caret, y: run.box.maxY).applying(run.transform)
        return Edge(x: top.x, y: min(top.y, bottom.y), height: abs(bottom.y - top.y))
    }
}
