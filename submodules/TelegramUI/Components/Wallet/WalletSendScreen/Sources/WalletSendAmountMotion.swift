import Foundation
import UIKit
import CoreText

enum WalletSendAmountGlyphMetrics {
    private struct Key: Hashable {
        let text: String
        let font: UIFont
    }
    private static var widths: [Key: CGFloat] = [:]
    private static var inkBoundsCache: [Key: CGRect] = [:]

    static func inkBounds(_ text: String, font: UIFont) -> CGRect {
        let key = Key(text: text, font: font)
        if let bounds = self.inkBoundsCache[key] { return bounds }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        if self.inkBoundsCache.count >= 1024 { self.inkBoundsCache.removeAll(keepingCapacity: true) }
        self.inkBoundsCache[key] = bounds
        return bounds
    }

    static func width(_ text: String, font: UIFont) -> CGFloat {
        let key = Key(text: text, font: font)
        if let width = widths[key] { return width }
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        if widths.count >= 1024 { widths.removeAll(keepingCapacity: true) }
        widths[key] = width
        return width
    }
}

struct WalletSendAmountGlyph: Equatable {
    enum Group: Equatable {
        case integer, fraction, grouping, suffix, prefix
    }

    let text: String
    let font: UIFont
    var color: UIColor
    var position: CGPoint
    var group: Group

    let width: CGFloat

    init(text: String, font: UIFont, color: UIColor, position: CGPoint, group: Group) {
        self.text = text
        self.font = font
        self.color = color
        self.position = position
        self.group = group
        self.width = WalletSendAmountGlyphMetrics.width(text, font: font)
    }

    var leadingEdge: CGFloat {
        return self.position.x - self.width / 2.0
    }

    static func text(_ text: NSAttributedString, origin: CGPoint, group: Group) -> [WalletSendAmountGlyph] {
        guard text.length > 0 else { return [] }
        let line = CTLineCreateWithAttributedString(text)
        var positionsByIndex: [Int: CGPoint] = [:]
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)
            CTRunGetStringIndices(run, CFRangeMake(0, count), &indices)
            for i in 0 ..< count where positionsByIndex[indices[i]] == nil {
                positionsByIndex[indices[i]] = positions[i]
            }
        }
        var offset = 0
        return text.string.map { character in
            let string = String(character)
            let attributes = text.attributes(at: offset, effectiveRange: nil)
            let font = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 13.0)
            let width = WalletSendAmountGlyphMetrics.width(string, font: font)
            let position = positionsByIndex[offset] ?? CGPoint(x: CTLineGetOffsetForStringIndex(line, offset, nil), y: 0.0)
            offset += string.utf16.count
            return WalletSendAmountGlyph(
                text: string, font: font, color: attributes[.foregroundColor] as? UIColor ?? .black,
                position: CGPoint(x: origin.x + position.x + width / 2.0, y: origin.y - position.y), group: group
            )
        }
    }
}

struct WalletSendAmountMotionTiming: Equatable {
    static let switchingDuration = WalletSendRolling.Motion.duration
    let start: Double
    let duration: Double
    let spin: Bool
    let up: Bool
    let reduced: Bool

    init(spin: Bool, up: Bool, start: Double = CACurrentMediaTime()) {
        self.start = start
        self.reduced = UIAccessibility.isReduceMotionEnabled
        self.duration = self.reduced ? 0.15 : Self.switchingDuration
        self.spin = spin
        self.up = up
    }

    func progress(at time: Double) -> CGFloat {
        return CGFloat(min(1, max(0, (time - start) / duration)))
    }

    static func ease(_ t: CGFloat) -> CGFloat { WalletSendRolling.Motion.ease(Double(t)) }
    func layoutProgress(at time: Double) -> CGFloat { Self.ease(progress(at: time)) }
}

struct WalletSendAmountSprite {
    var glyph: WalletSendAmountGlyph
    var alpha: CGFloat = 1
    var scale: CGFloat = 1
    var spread: CGFloat = 0
    var travel: CGPoint = .zero
    var scaleTravel: CGFloat = 0
    var spreadTravel: CGFloat = 0
    var soft: CGFloat = 0
    var morph: WalletSendAmountMorph?
}

struct WalletSendAmountMorph {
    var from: WalletSendAmountGlyph
    let progress: CGFloat
}

func walletSendAmountMotionRect(_ a: CGRect, _ b: CGRect, _ p: CGFloat) -> CGRect {
    return CGRect(x: a.minX + (b.minX - a.minX) * p, y: a.minY + (b.minY - a.minY) * p,
                  width: a.width + (b.width - a.width) * p, height: a.height + (b.height - a.height) * p)
}

func walletSendAmountMotionColor(_ a: UIColor, _ b: UIColor, _ p: CGFloat) -> UIColor {
    if a.isEqual(b) { return b }
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return UIColor(red: ar + (br - ar) * p, green: ag + (bg - ag) * p,
                   blue: ab + (bb - ab) * p, alpha: aa + (ba - aa) * p)
}

final class WalletSendAmountMotion {
    private typealias Rolling = WalletSendRolling
    private struct Entry {
        var targetIndex: Int?
        var baselineFrom: CGFloat
        var baselineTo: CGFloat
        var inkFrom: CGFloat
        var inkTo: CGFloat
        var source: Sample?
    }
    private struct Sample {
        var width: CGFloat
        var center: CGFloat
        var baseline: CGFloat
        var sprites: [WalletSendAmountSprite]
    }

    private struct RenderedFrame {
        let time: Double
        let frameDuration: Double
        let cells: [Sample]
        let outgoing: [WalletSendAmountSprite]
        let sprites: [WalletSendAmountSprite]
    }
    private var cachedGeometry: (time: Double, row: Rolling.RowLayout)?
    private var cachedFrame: RenderedFrame?
    private var initialRow: Rolling.RowLayout?

    private let liquid: Bool
    private(set) var target: [WalletSendAmountGlyph] = []
    private(set) var timing: WalletSendAmountMotionTiming?
    private var segments: [Rolling.Segment] = []
    private var entries: [Entry] = []
    private var oldExtent: CGFloat = 0
    private var newExtent: CGFloat = 0
    private var reducedSource: [WalletSendAmountSprite] = []
    private var outgoing: [WalletSendAmountSprite] = []

    init(liquid: Bool = false) { self.liquid = liquid }

    func isAnimating(at time: Double) -> Bool {
        return timing.map { $0.progress(at: time) < 1 } ?? false
    }

    func finish() {
        cachedGeometry = nil
        cachedFrame = nil
        initialRow = nil
        timing = nil
        segments.removeAll()
        entries.removeAll()
        reducedSource.removeAll()
        outgoing.removeAll()
    }

    private func phase(at time: Double, frame: Double = 1.0 / 120.0) -> Rolling.Phase {
        return Rolling.Phase(t: Double(timing?.progress(at: time) ?? 1), frame: frame)
    }

    private func geometry(at time: Double) -> Rolling.RowLayout {
        if let cachedGeometry, cachedGeometry.time == time { return cachedGeometry.row }
        let row = Rolling.RowLayout(segments, phase: phase(at: time))
        cachedGeometry = (time, row)
        return row
    }

    func update(_ glyphs: [WalletSendAmountGlyph], width: CGFloat, timing: WalletSendAmountMotionTiming?, at now: Double = CACurrentMediaTime(), frameDuration: Double = 1.0 / 120.0, fromPlaceholder: Bool = false) {
        guard glyphs != target || width != newExtent else { return }
        let previous = target
        let interrupted = isAnimating(at: now)
        let samples = interrupted ? sampledCells(at: now, frame: frameDuration) : [:]
        let departing = interrupted ? departingCells(at: now, frame: frameDuration) : []
        let visible = interrupted ? frame(at: now, frameDuration: frameDuration) : previous.map { WalletSendAmountSprite(glyph: $0) }
        let previousExtent = interrupted && self.timing?.reduced == false
            ? geometry(at: now).width : newExtent
        let previousTargetExtent = newExtent
        finish()
        target = glyphs
        oldExtent = previousExtent
        newExtent = width
        guard let timing else { return }
        self.timing = timing
        if timing.reduced {
            reducedSource = visible
            return
        }
        outgoing = departing

        let span = timing.spin ? Rolling.Motion.duration : Rolling.Motion.typing
        var oldEnd: CGFloat = 0
        var newEnd: CGFloat = 0
        var initialPen: CGFloat = 0
        for group in [WalletSendAmountGlyph.Group.prefix, .integer, .fraction, .suffix] {
            func belongs(_ glyph: WalletSendAmountGlyph) -> Bool {
                return glyph.group == group || (group == .integer && glyph.group == .grouping)
            }
            let old = previous.indices.filter { belongs(previous[$0]) }.sorted { previous[$0].position.x < previous[$1].position.x }
            let new = glyphs.indices.filter { belongs(glyphs[$0]) }.sorted { glyphs[$0].position.x < glyphs[$1].position.x }
            guard let example = new.first.map({ glyphs[$0] }) ?? old.first.map({ previous[$0] }) else { continue }
            let before = old.first.map { previous[$0] } ?? example
            let after = new.first.map { glyphs[$0] } ?? example
            let oldStart = old.first.map { previous[$0].leadingEdge } ?? oldEnd
            let newStart = new.first.map { glyphs[$0].leadingEdge } ?? newEnd
            let gap = oldStart - oldEnd
            segments.append(.space(from: gap, to: newStart - newEnd, span: span, springs: !timing.spin))
            initialPen += gap
            let a = old.map { previous[$0].text }.joined()
            let b = new.map { glyphs[$0].text }.joined()
            let font = Rolling.GlyphFont(ui: before.font)
            let fontTo = before.font == after.font ? nil : Rolling.GlyphFont(ui: after.font)
            var cells: [Rolling.Cell]
            if group == .suffix || group == .prefix {
                cells = Rolling.Cells.letters(from: a, to: b, font: font, colorFrom: before.color,
                    colorTo: after.color, fontTo: fontTo)
            } else if timing.spin {
                cells = Rolling.Cells.spinning(from: a, to: b, font: font, color: before.color,
                    colorTo: after.color, fontTo: fontTo, fromRight: group == .integer, up: timing.up)
            } else {
                let separator = new.first(where: { glyphs[$0].group == .grouping }).flatMap { glyphs[$0].text.first }
                    ?? old.first(where: { previous[$0].group == .grouping }).flatMap { previous[$0].text.first } ?? "\u{0}"
                cells = Rolling.Cells.number(from: a, to: b, font: font, color: before.color,
                    colorTo: after.color, fontTo: fontTo, separator: separator, liquid: liquid)
                if fromPlaceholder, group == .integer {
                    for i in cells.indices where cells[i].from > 0 {
                        cells[i].span = Rolling.Motion.placeholderMelt
                    }
                }
            }
            var unusedOld = old
            var unusedNew = new
            func take(_ character: Character?, from indices: inout [Int], in source: [WalletSendAmountGlyph]) -> Int? {
                guard let character, let slot = indices.firstIndex(where: { source[$0].text == String(character) }) else { return nil }
                return indices.remove(at: slot)
            }
            func advance(_ index: Int, indices: [Int], in source: [WalletSendAmountGlyph]) -> CGFloat {
                if let position = indices.firstIndex(of: index), position + 1 < indices.count {
                    return source[indices[position + 1]].leadingEdge - source[index].leadingEdge
                }
                return source[index].width
            }
            for i in cells.indices {
                let was: Character?
                let will: Character?
                switch cells[i].kind {
                case let .still(character): was = character; will = character
                case let .pop(a, b): was = a; will = b
                case let .drum(column):
                    was = cells[i].from == 0 ? nil : column.first
                    will = cells[i].to == 0 ? nil : column.last
                }
                let oldIndex = take(was, from: &unusedOld, in: previous)
                let newIndex = take(will, from: &unusedNew, in: glyphs)
                let from = oldIndex.map { previous[$0] }
                let to = newIndex.map { glyphs[$0] }
                let sample = oldIndex.flatMap { samples[$0] }
                let fromWidth = oldIndex.map { advance($0, indices: old, in: previous) } ?? 0
                let toWidth = newIndex.map { advance($0, indices: new, in: glyphs) } ?? 0
                cells[i].from = sample?.width ?? fromWidth
                cells[i].to = toWidth
                if let from {
                    cells[i].slide = (sample.map { $0.center - $0.width / 2 } ?? from.leadingEdge) - initialPen
                }
                let needsSnapshot = sample.map { sample -> Bool in
                    guard sample.sprites.count == 1, let sprite = sample.sprites.first, let from else { return true }
                    return sprite.morph != nil || sprite.glyph.text != from.text || sprite.glyph.font != from.font
                        || !sprite.glyph.color.isEqual(from.color) || sprite.alpha < 0.999
                        || abs(sprite.scale - 1) > 0.001 || sprite.spread > 0.01
                } ?? false
                entries.append(Entry(targetIndex: newIndex,
                    baselineFrom: sample?.baseline ?? from?.position.y ?? after.position.y,
                    baselineTo: to?.position.y ?? before.position.y,
                    inkFrom: ((from?.width ?? fromWidth) - fromWidth) / 2,
                    inkTo: ((to?.width ?? toWidth) - toWidth) / 2,
                    source: needsSnapshot ? sample : nil))
                initialPen += cells[i].from
            }
            segments.append(.cells(cells))
            oldEnd = old.last.map { previous[$0].position.x + previous[$0].width / 2 } ?? oldEnd
            newEnd = new.last.map { glyphs[$0].position.x + glyphs[$0].width / 2 } ?? newEnd
        }
        let tail = previousTargetExtent - oldEnd
        segments.append(.space(from: tail, to: width - newEnd, span: span, springs: !timing.spin))
        initialPen += tail
        if interrupted {
            let remaining = oldExtent - initialPen
            if abs(remaining) > 0.001 {
                segments.append(.space(from: remaining, to: 0, span: span, springs: !timing.spin))
            }
        }
        initialRow = Rolling.RowLayout(segments, phase: Rolling.Phase(t: 0))
    }

    func widthAdjustment(at time: Double) -> CGFloat {
        guard let timing, !timing.reduced else { return 0 }
        let expected = oldExtent + (newExtent - oldExtent) * timing.layoutProgress(at: time)
        return geometry(at: time).width - expected
    }

    func caretPosition(at time: Double, fromX: CGFloat, toX: CGFloat) -> CGFloat {
        guard let timing else { return toX }
        guard !timing.reduced else { return fromX + (toX - fromX) * timing.layoutProgress(at: time) }
        let phase = phase(at: time)
        let row = geometry(at: time)
        let candidates = target.indices.filter { target[$0].group == .integer || target[$0].group == .fraction }
        var anchor = candidates.min(by: { abs(target[$0].position.x - toX) < abs(target[$1].position.x - toX) })
        if !timing.spin,
           let lastDigit = candidates.max(by: { target[$0].position.x < target[$1].position.x }),
           toX >= target[lastDigit].position.x,
           let suffix = target.indices.filter({ target[$0].group == .suffix }).min(by: { target[$0].leadingEdge < target[$1].leadingEdge }) {
            anchor = suffix
        }
        guard let index = anchor,
              let slot = entries.firstIndex(where: { $0.targetIndex == index }) else { return toX }
        let (x, width, cell) = row.placed[slot]
        let own = cell.phase(phase)
        let ink = entries[slot].inkFrom + (entries[slot].inkTo - entries[slot].inkFrom) * own.p
        let slide = cell.slide * (1 - Rolling.Motion.inertia(own.t))
        guard let initial = initialRow?.placed[slot] else { return toX }
        let position: CGFloat
        let initialPosition: CGFloat
        if toX >= target[index].position.x {
            let offset = toX - target[index].position.x - target[index].width / 2
            position = x + width + ink * 2 + slide + offset
            initialPosition = initial.x + cell.from + entries[slot].inkFrom * 2 + cell.slide + offset
        } else {
            let offset = toX - target[index].leadingEdge
            position = x + slide + offset
            initialPosition = initial.x + cell.slide + offset
        }
        return position + (fromX - initialPosition) * (1 - own.p)
    }

    private func renderedFrame(at time: Double, frameDuration: Double) -> RenderedFrame {
        if let cachedFrame, cachedFrame.time == time, cachedFrame.frameDuration == frameDuration {
            return cachedFrame
        }
        let phase = phase(at: time, frame: frameDuration)
        let row = geometry(at: time)
        let cells = row.placed.enumerated().map { index, placed -> Sample in
            let entry = entries[index]
            let own = placed.cell.phase(phase)
            let baseline = entry.baselineFrom + (entry.baselineTo - entry.baselineFrom) * own.p
            return Sample(width: placed.width,
                center: placed.x + placed.width / 2 + placed.cell.slide * (1 - Rolling.Motion.inertia(own.t)),
                baseline: baseline, sprites: render(placed.cell, x: placed.x, width: placed.width, entry: entry, phase: phase))
        }
        let outgoing = fadingOutgoing(phase: phase)
        let frame = RenderedFrame(time: time, frameDuration: frameDuration, cells: cells,
                                  outgoing: outgoing, sprites: cells.flatMap { $0.sprites } + outgoing)
        cachedFrame = frame
        return frame
    }

    private func sampledCells(at time: Double, frame: Double) -> [Int: Sample] {
        guard let timing, !timing.reduced else { return [:] }
        let frame = renderedFrame(at: time, frameDuration: frame)
        var result: [Int: Sample] = [:]
        for (i, sample) in frame.cells.enumerated() {
            if let index = entries[i].targetIndex { result[index] = sample }
        }
        return result
    }

    private func departingCells(at time: Double, frame: Double) -> [WalletSendAmountSprite] {
        guard let timing, !timing.reduced else { return [] }
        let frame = renderedFrame(at: time, frameDuration: frame)
        return frame.cells.enumerated().flatMap { index, sample -> [WalletSendAmountSprite] in
            return entries[index].targetIndex == nil ? sample.sprites : []
        } + frame.outgoing
    }

    private func fadingOutgoing(phase: Rolling.Phase) -> [WalletSendAmountSprite] {
        let own = phase.local(delay: 0, span: Rolling.Motion.melt * 1.3)
        return outgoing.compactMap { sprite in
            var sprite = sprite
            sprite.alpha *= 1 - own.p
            sprite.travel = .zero
            sprite.scaleTravel = 0
            return sprite.alpha > 0.006 ? sprite : nil
        }
    }

    private func render(_ cell: Rolling.Cell, x: CGFloat, width: CGFloat, entry: Entry, phase: Rolling.Phase) -> [WalletSendAmountSprite] {
        let own = cell.phase(phase)
        let baseline = entry.baselineFrom + (entry.baselineTo - entry.baselineFrom) * own.p
        let ink = entry.inkFrom + (entry.inkTo - entry.inkFrom) * own.p
        var result = WalletSendRollingRenderer(phase: phase, up: timing?.up ?? true, baseline: baseline).sprites(cell, x: x + ink, width: width)
        if let source = entry.source, !own.settled {
            let blend = own.p
            let center = x + width / 2 + cell.slide * (1 - Rolling.Motion.inertia(own.t))
            result = result.map { var sprite = $0; sprite.alpha *= blend; return sprite }
            result += source.sprites.map { sprite in
                var sprite = sprite
                sprite.glyph.position.x += center - source.center
                sprite.glyph.position.y += baseline - source.baseline
                sprite.alpha *= 1 - blend
                sprite.travel = .zero
                sprite.scaleTravel = 0
                return sprite
            }
        }
        return result.filter { $0.alpha > 0.006 }
    }

    func frame(at time: Double, frameDuration: Double = 1.0 / 120.0) -> [WalletSendAmountSprite] {
        guard let timing, isAnimating(at: time) else { return target.map { WalletSendAmountSprite(glyph: $0) } }
        if timing.reduced {
            let p = timing.layoutProgress(at: time)
            return reducedSource.map { var sprite = $0; sprite.alpha *= 1 - p; return sprite }
                + target.map { WalletSendAmountSprite(glyph: $0, alpha: p) }
        }
        return renderedFrame(at: time, frameDuration: frameDuration).sprites
    }
}

enum WalletSendRolling {
    enum Motion {
        static let duration: Double = 0.46
        static let stagger: Double = 0.05
        static let typing: Double = 0.22
        static let melt: Double = 0.12
        static let placeholderMelt: Double = 0.12
        static let steps = 2

        private static let sharpness: Double = 2.2

        static func ease(_ raw: Double) -> CGFloat {
            let t = min(max(raw, 0), 1)
            return CGFloat(1 - pow(1 - t, sharpness))
        }

        static func speed(_ raw: Double) -> CGFloat {
            let t = min(max(raw, 0), 1)
            return CGFloat(sharpness * pow(1 - t, sharpness - 1))
        }

        private static func spring(_ raw: Double, _ decay: Double, _ swing: Double) -> CGFloat {
            let t = min(max(raw, 0), 1)
            let u = t * t * (3 - 2 * t)
            let fade = exp(-decay * u)
            return CGFloat(1 - fade * (cos(swing * u) + decay / swing * sin(swing * u)))
        }

        static func inertia(_ raw: Double) -> CGFloat { spring(raw, 4.2, 5.6) }

        static func settle(_ raw: Double) -> CGFloat { spring(raw, 5.6, 6.2) }

        static var peakSpeed: CGFloat { CGFloat(sharpness) }
    }

    struct Phase {
        var t: Double
        var frame: Double = 1.0 / 120
        var p: CGFloat { Motion.ease(t) }
        var speed: CGFloat { Motion.speed(t) }
        var settled: Bool { t >= 1 }

        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * p }

        var previous: Phase {
            Phase(t: max(t - frame / Motion.duration, 0), frame: frame)
        }

        func local(delay: Double, span: Double) -> Phase {
            guard delay > 0 || span < Motion.duration else { return self }
            let elapsed = t * Motion.duration - delay
            return Phase(t: min(max(elapsed / span, 0), 1), frame: frame)
        }
    }

    struct GlyphFont: Equatable {
        let ui: UIFont
        var capHeight: CGFloat { ui.capHeight }
        var pitch: CGFloat { ui.capHeight * 0.8 }
        func width(_ character: Character?) -> CGFloat {
            character.map { WalletSendAmountGlyphMetrics.width(String($0), font: ui) } ?? 0
        }
    }

    struct Cell {
        enum Kind {
            case still(Character)
            case drum([Character])
            case pop(Character?, Character?)
        }

        var kind: Kind
        var font: GlyphFont
        var colorFrom: UIColor
        var colorTo: UIColor
        var from: CGFloat
        var to: CGFloat
        var squeeze: Bool = true
        var delay: Double = 0
        var span: Double = Motion.duration
        var slide: CGFloat = 0
        var orbits: Bool = false
        var springs: Bool = false
        var melts: Bool = false
        var fontTo: GlyphFont? = nil

        init(kind: Kind, font: GlyphFont, color: UIColor, colorTo: UIColor? = nil,
             from: CGFloat? = nil, to: CGFloat? = nil,
             squeeze: Bool = true, delay: Double = 0, span: Double = Motion.duration) {
            self.kind = kind
            self.font = font
            colorFrom = color
            self.colorTo = colorTo ?? color
            self.squeeze = squeeze
            self.delay = delay
            self.span = span
            switch kind {
            case let .still(character):
                self.from = from ?? font.width(character)
                self.to = to ?? font.width(character)
            case let .drum(column):
                self.from = from ?? font.width(column.first)
                self.to = to ?? font.width(column.last)
            case let .pop(old, new):
                self.from = from ?? font.width(old)
                self.to = to ?? font.width(new)
            }
        }

        func phase(_ row: Phase) -> Phase { row.local(delay: delay, span: span) }

        func width(_ row: Phase) -> CGFloat {
            let own = phase(row)
            guard springs else { return own.lerp(from, to) }
            return max(0, from + (to - from) * Motion.settle(own.t))
        }
    }


    enum Cells {
        static func spinning(from old: String, to new: String, font: GlyphFont, color: UIColor,
                             colorTo: UIColor? = nil, fontTo: GlyphFont? = nil,
                             fromRight: Bool, up: Bool) -> [Cell] {
            let a = Array(old), b = Array(new)
            let count = max(a.count, b.count)
            var pairs: [(was: Character?, will: Character?)] = []
            for slot in 0..<count {
                let i = fromRight ? a.count - 1 - slot : slot
                let j = fromRight ? b.count - 1 - slot : slot
                pairs.append((a.indices.contains(i) ? a[i] : nil,
                              b.indices.contains(j) ? b[j] : nil))
            }

            let clicks = pairs.compactMap { pair -> Int? in
                guard let was = pair.was, let will = pair.will, was != will else { return nil }
                return column(was, will, up: up).count - 1
            }.max() ?? Motion.steps

            var cells: [Cell] = []
            for pair in pairs {
                cells.append(cell(pair.was, pair.will, font: font, color: color, colorTo: colorTo,
                                  fontTo: fontTo, up: up, clicks: clicks))
            }
            return fromRight ? cells.reversed() : cells
        }

        static func number(from old: String, to new: String, font: GlyphFont, color: UIColor,
                           colorTo: UIColor? = nil, fontTo: GlyphFont? = nil,
                           separator: Character,
                           liquid: Bool = false) -> [Cell] {
            let after = fontTo ?? font
            func split(_ text: String) -> (digits: [Character], seps: [Int]) {
                var digits: [Character] = []
                var seps: [Int] = []
                for character in text {
                    if character == separator { seps.append(digits.count) } else { digits.append(character) }
                }
                return (digits, seps)
            }
            let a = split(old), b = split(new)

            let (head, tail) = shared(a.digits, b.digits)
            var slots: [(old: Int?, new: Int?)] = []
            for i in 0..<head { slots.append((i, i)) }
            let oldMiddle = head..<(a.digits.count - tail)
            let newMiddle = head..<(b.digits.count - tail)
            let paired = min(oldMiddle.count, newMiddle.count)
            for k in 0..<paired { slots.append((oldMiddle.lowerBound + k, newMiddle.lowerBound + k)) }
            for i in (oldMiddle.lowerBound + paired)..<oldMiddle.upperBound { slots.append((i, nil)) }
            for j in (newMiddle.lowerBound + paired)..<newMiddle.upperBound { slots.append((nil, j)) }
            for k in 0..<tail {
                slots.append((a.digits.count - tail + k, b.digits.count - tail + k))
            }

            let common = min(a.seps.count, b.seps.count)
            var moved: [Int: Int] = [:]
            for k in 0..<common {
                moved[b.seps[b.seps.count - 1 - k]] = a.seps[a.seps.count - 1 - k]
            }
            let gone = Set(a.seps.prefix(a.seps.count - common))
            let born = Set(b.seps.prefix(b.seps.count - common))

            var digitX: [CGFloat] = []
            var sepX: [Int: CGFloat] = [:]
            var pen: CGFloat = 0
            for character in old {
                if character == separator { sepX[digitX.count] = pen } else { digitX.append(pen) }
                pen += font.width(character)
            }

            func cell(_ kind: Cell.Kind, _ from: CGFloat, _ to: CGFloat) -> Cell {
                var pace = Motion.typing
                if liquid, case let .pop(was, will) = kind {
                    if was != nil, will != nil { pace = Motion.melt }
                    else if will == nil { pace = Motion.melt * 1.3 }
                }
                var cell = Cell(kind: kind, font: font, color: color, colorTo: colorTo,
                                from: from, to: to, span: pace)
                cell.springs = true
                cell.melts = liquid
                cell.fontTo = fontTo
                return cell
            }
            let sepWidth = font.width(separator)
            let newSepWidth = after.width(separator)
            var items: [(cell: Cell, wasAt: CGFloat?)] = []

            func separators(_ slot: (old: Int?, new: Int?)) {
                if let i = slot.old, gone.contains(i) {
                    items.append((cell(.pop(separator, nil), sepWidth, 0), sepX[i]))
                }
                guard let j = slot.new else { return }
                if let i = moved[j] {
                    var moving = cell(.still(separator), sepWidth, newSepWidth)
                    moving.orbits = true
                    items.append((moving, sepX[i]))
                } else if born.contains(j) {
                    items.append((cell(.pop(nil, separator), 0, newSepWidth), nil))
                }
            }

            for slot in slots {
                separators(slot)
                let was = slot.old.map { a.digits[$0] }
                let will = slot.new.map { b.digits[$0] }
                let wasWidth = font.width(was)
                let willWidth = after.width(will)
                let kind: Cell.Kind = was == will ? .still(will ?? " ") : .pop(was, will)
                items.append((cell(kind, wasWidth, willWidth),
                              slot.old.map { digitX[$0] }))
            }
            separators((old: a.digits.count, new: b.digits.count))

            var cells: [Cell] = []
            var seq: CGFloat = 0
            for item in items {
                var cell = item.cell
                if let wasAt = item.wasAt { cell.slide = wasAt - seq }
                seq += cell.from
                cells.append(cell)
            }
            return cells
        }

        static func letters(from old: String, to new: String, font: GlyphFont,
                            colorFrom: UIColor, colorTo: UIColor,
                            fontTo: GlyphFont? = nil) -> [Cell] {
            let after = fontTo ?? font
            let a = Array(old), b = Array(new)
            let (head, tail) = shared(a, b)
            var cells: [Cell] = []
            func still(_ character: Character) -> Cell {
                var cell = Cell(kind: .still(character), font: font, color: colorFrom, colorTo: colorTo,
                                from: font.width(character),
                                to: after.width(character), squeeze: false)
                cell.fontTo = fontTo
                return cell
            }
            for i in 0..<head { cells.append(still(b[i])) }
            let oldMiddle = Array(a[head..<(a.count - tail)])
            let newMiddle = Array(b[head..<(b.count - tail)])
            let count = max(oldMiddle.count, newMiddle.count)
            let step = count > 1 ? min(Motion.stagger, Motion.duration * 0.25 / Double(count - 1)) : 0
            let span = Motion.duration - step * Double(max(count - 1, 0))
            for k in 0..<count {
                let was: Character? = oldMiddle.indices.contains(k) ? oldMiddle[k] : nil
                let will: Character? = newMiddle.indices.contains(k) ? newMiddle[k] : nil
                var cell = Cell(kind: .drum([was ?? " ", will ?? " "]),
                                font: font, color: colorFrom, colorTo: colorTo,
                                from: font.width(was), to: after.width(will), squeeze: false,
                                delay: step * Double(k), span: span)
                cell.fontTo = fontTo
                cells.append(cell)
            }
            for i in (b.count - tail)..<b.count { cells.append(still(b[i])) }
            return cells
        }

        private static func cell(_ was: Character?, _ will: Character?, font: GlyphFont,
                                 color: UIColor, colorTo: UIColor? = nil, fontTo: GlyphFont? = nil,
                                 up: Bool, clicks: Int) -> Cell {
            let after = fontTo ?? font
            if was == will, let character = was {
                let column = fontTo == nil ? nil : turn(character, up: up, clicks: clicks)
                var cell = Cell(kind: column.map { Cell.Kind.drum($0) } ?? .still(character),
                                font: font, color: color, colorTo: colorTo,
                                from: font.width(character), to: after.width(character))
                cell.fontTo = fontTo
                return cell
            }
            let column: [Character]
            if let was, let will {
                column = Self.column(was, will, up: up)
            } else if let will, let digit = will.wholeNumberValue {
                column = ring(from: (digit - clicks * (up ? 1 : -1) + 100) % 10, to: digit, up: up)
            } else if let was, let digit = was.wholeNumberValue {
                column = ring(from: digit, to: (digit + clicks * (up ? 1 : -1) + 100) % 10, up: up)
            } else {
                column = [was ?? " ", will ?? " "]
            }
            var cell = Cell(kind: .drum(column), font: font, color: color, colorTo: colorTo,
                            from: font.width(was), to: after.width(will))
            cell.fontTo = fontTo
            return cell
        }

        private static func turn(_ character: Character, up: Bool, clicks: Int) -> [Character]? {
            guard let digit = character.wholeNumberValue, clicks > 0 else { return nil }
            let step = 10 / (clicks + 1)
            var column = [character]
            for k in 1...clicks {
                let value = (digit + (up ? k * step : 10 - k * step)) % 10
                column.append(Character(String(value)))
            }
            column.append(character)
            return column
        }

        private static func ring(from: Int, to: Int, up: Bool) -> [Character] {
            var path = [Character(String(from))]
            var value = from
            while value != to {
                value = (value + (up ? 1 : 9)) % 10
                path.append(Character(String(value)))
            }
            return path
        }

        private static func column(_ a: Character, _ b: Character, up: Bool) -> [Character] {
            guard a != b else { return [a] }
            guard let x = a.wholeNumberValue, let y = b.wholeNumberValue else { return [a, b] }
            return walk(x, y, ring: 10, up: up, limit: 5).map { Character(String($0)) }
        }

        private static func walk(_ a: Int, _ b: Int, ring: Int, up: Bool, limit: Int) -> [Int] {
            var path = [a]
            var value = a
            while value != b {
                value = (value + (up ? 1 : ring - 1)) % ring
                path.append(value)
            }
            guard path.count > limit + 1 else { return path }
            var short = [path[0]]
            for k in 1..<limit {
                short.append(path[Int(round(Double(k) / Double(limit) * Double(path.count - 1)))])
            }
            short.append(path[path.count - 1])
            return short
        }

        private static func shared(_ a: [Character], _ b: [Character]) -> (Int, Int) {
            var head = 0
            while head < a.count, head < b.count, a[head] == b[head] { head += 1 }
            var tail = 0
            while tail < a.count - head, tail < b.count - head,
                  a[a.count - 1 - tail] == b[b.count - 1 - tail] { tail += 1 }
            return (head, tail)
        }
    }


    enum Segment {
        case cells([Cell])
        case space(from: CGFloat, to: CGFloat, span: Double, springs: Bool)
    }

    struct RowLayout {
        var width: CGFloat = 0
        var placed: [(x: CGFloat, width: CGFloat, cell: Cell)] = []

        init(_ segments: [Segment], phase: Phase) {
            var x: CGFloat = 0
            for segment in segments {
                switch segment {
                case let .cells(cells):
                    for cell in cells {
                        let width = cell.width(phase)
                        placed.append((x, width, cell))
                        x += width
                    }
                case let .space(from, to, span, springs):
                    let own = phase.local(delay: 0, span: span)
                    let w = springs ? from + (to - from) * Motion.settle(own.t)
                                    : own.lerp(from, to)
                    x += w
                }
            }
            width = x
        }
    }
}

struct WalletSendRollingRenderer {
    typealias Cell = WalletSendRolling.Cell
    typealias Phase = WalletSendRolling.Phase
    typealias Motion = WalletSendRolling.Motion
    typealias GlyphFont = WalletSendRolling.GlyphFont

    struct Pose {
        var dy: CGFloat
        var dx: CGFloat = 0
        var spread: CGFloat = 0
        var scale: CGFloat = 1
    }

    var phase: Phase
    var up: Bool
    var baseline: CGFloat

    func sprites(_ cell: Cell, x: CGFloat, width: CGFloat) -> [WalletSendAmountSprite] {
        var result: [WalletSendAmountSprite] = []
        self.draw(cell, at: x, width: width, in: &result)
        return result
    }
    private func draw(_ cell: Cell, at x: CGFloat, width: CGFloat, in context: inout [WalletSendAmountSprite]) {
        let now = cell.phase(phase)
        let was = now.previous
        let face = cell.fontTo.map { now.p < 0.5 ? cell.font : $0 } ?? cell.font
        let center = x + width / 2
        let color = now.settled ? cell.colorTo : blend(cell.colorFrom, cell.colorTo, now.p)
        let slide = cell.slide == 0 ? 0 : cell.slide * (1 - Motion.inertia(now.t))
        let slideWas = cell.slide == 0 ? 0 : cell.slide * (1 - Motion.inertia(was.t))
        let hop = cell.orbits && abs(cell.slide) > 0.5 ? face.capHeight * 0.22 : 0
        func swoop(_ p: CGFloat) -> CGFloat {
            let x: CGFloat = max(0, min(1, p))
            return hop * pow(sin(.pi * x), 0.7)
        }
        let arc = hop == 0 ? 0 : swoop(Motion.inertia(now.t))
        let arcWas = hop == 0 ? 0 : swoop(Motion.inertia(was.t))
        let swell: CGFloat = min(1, Motion.inertia(now.t))
        let swellWas: CGFloat = min(1, Motion.inertia(was.t))
        let lift = hop == 0 ? 1 : 1 + 0.1 * sin(.pi * swell)
        let liftWas = hop == 0 ? 1 : 1 + 0.1 * sin(.pi * swellWas)

        switch cell.kind {
        case let .still(character):
            if let fontTo = cell.fontTo, fontTo != cell.font, !now.settled {
                melt(character, character, cell, face: cell.font, faceTo: fontTo,
                     at: center + slide, dy: arc,
                     p: CGFloat(now.t), in: &context)
                return
            }
            let dash = hypot(slide - slideWas, arc - arcWas)
            put(character, face, color, center,
                Pose(dy: arcWas, dx: slideWas, scale: liftWas),
                Pose(dy: arc, dx: slide, scale: lift),
                1, dash * 3, &context)

        case let .drum(column):
            let steps = CGFloat(column.count - 1)
            guard steps > 0 else {
                put(column[0], face, color, center,
                    Pose(dy: 0), Pose(dy: 0), 1, 0, &context)
                return
            }
            let direction: CGFloat = up ? 1 : -1
            func opening(_ phase: Phase) -> CGFloat {
                cell.from == 0 ? phase.p : (cell.to == 0 ? 1 - phase.p : 1)
            }
            let open = opening(now), openWas = opening(was)
            let haze = face.capHeight * 0.65
            let spread = cell.squeeze ? (1 - open) * haze : 0
            let spreadWas = cell.squeeze ? (1 - openWas) * haze : 0
            let pace = now.speed / Motion.peakSpeed
            let soft = face.capHeight * 0.45 * pace * pace
            for (index, character) in column.enumerated() {
                let dy = (CGFloat(index) - now.p * steps) * face.pitch * direction
                let dyWas = (CGFloat(index) - was.p * steps) * face.pitch * direction
                let visible = window(dy, face.pitch)
                guard visible > 0 else { continue }
                put(character, face, color, center,
                    Pose(dy: dyWas + arcWas, dx: slideWas, spread: spreadWas),
                    Pose(dy: dy + arc, dx: slide, spread: spread),
                    visible * pow(Double(open), 2.2), soft, &context)
            }

        case let .pop(old, new):
            let pace = now.speed / Motion.peakSpeed
            let soft = face.capHeight * 0.2 * pace * pace
            let bounce = cell.springs ? Motion.settle(now.t) : now.p
            let bounceWas = cell.springs ? Motion.settle(was.t) : was.p
            if cell.melts, old != nil, new != nil {
                melt(old, new, cell, face: cell.font, faceTo: cell.fontTo,
                     at: center + slide, dy: arc,
                     p: CGFloat(now.t), in: &context)
                return
            }
            if let old {
                put(old, face, cell.colorFrom, center,
                    Pose(dy: arcWas, dx: slideWas, scale: liftWas - 0.14 * bounceWas),
                    Pose(dy: arc, dx: slide, scale: lift - 0.14 * bounce),
                    pow(Double(1 - now.p), 1.2), soft, &context)
            }
            if let new {
                put(new, face, cell.colorTo, center,
                    Pose(dy: arcWas, dx: slideWas,
                         scale: liftWas - 0.14 + 0.14 * bounceWas),
                    Pose(dy: arc, dx: slide, scale: lift - 0.14 + 0.14 * bounce),
                    pow(Double(now.p), 1.2), soft, &context)
            }
        }
    }

    private func melt(_ old: Character?, _ new: Character?, _ cell: Cell, face: GlyphFont,
                      faceTo: GlyphFont? = nil, at center: CGFloat, dy: CGFloat, p: CGFloat,
                      in context: inout [WalletSendAmountSprite]) {
        guard let old, let new else { return }
        let position = CGPoint(x: center, y: baseline + dy)
        let from = WalletSendAmountGlyph(text: String(old), font: face.ui, color: cell.colorFrom, position: position, group: .integer)
        let to = WalletSendAmountGlyph(text: String(new), font: (faceTo ?? face).ui, color: cell.colorTo, position: position, group: .integer)
        if p <= 0 {
            context.append(WalletSendAmountSprite(glyph: from))
        } else if p >= 1 {
            context.append(WalletSendAmountSprite(glyph: to))
        } else {
            var glyph = to
            glyph.color = blend(cell.colorFrom, cell.colorTo, p)
            context.append(WalletSendAmountSprite(glyph: glyph, morph: WalletSendAmountMorph(from: from, progress: p)))
        }
    }

    private func window(_ dy: CGFloat, _ pitch: CGFloat) -> CGFloat {
        let k = abs(dy) / (pitch * 0.58)
        return k >= 1 ? 0 : 1 - pow(k, 2.2)
    }

    private func put(_ character: Character, _ font: GlyphFont, _ color: UIColor,
                     _ centerX: CGFloat, _ was: Pose, _ now: Pose,
                     _ alpha: CGFloat, _ soft: CGFloat,
                     _ context: inout [WalletSendAmountSprite]) {
        guard alpha > 0.006, character != " " else { return }
        context.append(WalletSendAmountSprite(
            glyph: WalletSendAmountGlyph(text: String(character), font: font.ui, color: color,
                position: CGPoint(x: centerX + now.dx, y: baseline + now.dy), group: .integer),
            alpha: alpha, scale: now.scale, spread: now.spread,
            travel: CGPoint(x: now.dx - was.dx, y: now.dy - was.dy),
            scaleTravel: now.scale - was.scale, spreadTravel: now.spread - was.spread, soft: soft
        ))
    }

    private func blend(_ a: UIColor, _ b: UIColor, _ p: CGFloat) -> UIColor {
        return walletSendAmountMotionColor(a, b, p)
    }
}
