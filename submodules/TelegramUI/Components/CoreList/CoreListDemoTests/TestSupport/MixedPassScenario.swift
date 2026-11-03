import UIKit
@testable import CoreListDemo

final class MixedPassItemView: UIView, CoreListItemView {
    var onContentDidChange: ((Bool) -> Void)?
    nonisolated(unsafe) private var contentHeight: CGFloat

    init(height: CGFloat) {
        contentHeight = height
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func apply(height: CGFloat) {
        contentHeight = height
    }

    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        contentHeight
    }
}

final class MixedPassAttachmentView: UIView, CoreListAttachedItemView {
    var onContentDidChange: ((Bool) -> Void)?
    private var contentHeight: CGFloat

    init(height: CGFloat) {
        contentHeight = height
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(height: CGFloat) { contentHeight = height }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat { contentHeight }
}

/// Even groups reserve space, odd groups overlay, so one seeded run exercises both placements — and
/// therefore the reservation gap the oracle now accounts for. Edge and floating vary on other moduli
/// so a run of groups covers the combinations without needing a separate action for each.
final class MixedPassAttachment: CoreListAttachedItem {
    let group: Int
    let height: CGFloat

    init(group: Int, height: CGFloat) {
        self.group = group
        self.height = height
    }

    var placement: CoreListAttachmentPlacement { group.isMultiple(of: 2) ? .reservesSpace : .overlay }
    var edge: CoreListAttachmentEdge { group.isMultiple(of: 3) ? .bottom : .top }
    var isFloating: Bool { !group.isMultiple(of: 5) }

    func view() -> UIView & CoreListAttachedItemView { MixedPassAttachmentView(height: height) }

    func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? MixedPassAttachment else { return false }
        return other.group == group && other.height == height
    }

    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? MixedPassAttachmentView)?.apply(height: height)
    }
}

final class MixedPassItem: CoreListItem, Equatable {
    let id: Int
    let height: CGFloat
    /// `nil` means this row publishes no attachment, which is what creates gaps between runs.
    let group: Int?

    var identity: AnyHashable { id }

    init(id: Int, height: CGFloat, group: Int? = nil) {
        self.id = id
        self.height = height
        self.group = group
    }

    // Reference type ⇒ no synthesized ==; keep value equality over id + height + group (what
    // `isEqual(to:)` relies on).
    static func == (lhs: MixedPassItem, rhs: MixedPassItem) -> Bool {
        lhs.id == rhs.id && lhs.height == rhs.height && lhs.group == rhs.group
    }

    var attachedItems: [AnyHashable: CoreListAttachedItem] {
        guard let group else { return [:] }
        return ["g\(group)": MixedPassAttachment(group: group, height: 28)]
    }

    func view() -> UIView & CoreListItemView {
        MixedPassItemView(height: height)
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? MixedPassItem else { return false }
        return other == self   // value equality over id + height + group
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? MixedPassItemView)?.apply(height: height)
    }
}

enum MixedPassAction: Equatable, CustomStringConvertible {
    case insert(index: Int, ids: [Int])
    case remove(range: Range<Int>, ids: [Int])
    case move(range: Range<Int>, destination: Int)
    case replace(index: Int, oldID: Int, newID: Int)
    case resize(index: Int, id: Int, from: CGFloat, to: CGFloat)
    case horizontalInsets(left: CGFloat, right: CGFloat)
    case verticalInsets(top: CGFloat, bottom: CGFloat)
    case viewport(CGSize)
    case scroll(index: Int, pointOffset: CGFloat)
    case regroup(size: Int)
    case dropAttachments(range: Range<Int>)
    case sameTarget

    var description: String {
        switch self {
        case let .insert(index, ids):
            return "insert@\(index):\(ids)"
        case let .remove(range, ids):
            return "remove\(range):\(ids)"
        case let .move(range, destination):
            return "move\(range)->\(destination)"
        case let .replace(index, oldID, newID):
            return "replace@\(index):\(oldID)->\(newID)"
        case let .resize(index, id, from, to):
            return "resize@\(index)#\(id):\(from)->\(to)"
        case let .horizontalInsets(left, right):
            return "insetsH:\(left),\(right)"
        case let .verticalInsets(top, bottom):
            return "insetsV:\(top),\(bottom)"
        case let .viewport(size):
            return "viewport:\(size.width)x\(size.height)"
        case let .scroll(index, pointOffset):
            return "scroll@\(index)+\(pointOffset)"
        case let .regroup(size):
            return "regroup(size: \(size))"
        case let .dropAttachments(range):
            return "dropAttachments(\(range))"
        case .sameTarget:
            return "sameTarget"
        }
    }
}

struct MixedPassStep: CustomStringConvertible {
    let items: [MixedPassItem]
    let size: CGSize
    let insets: UIEdgeInsets
    let scrollTo: CoreListScrollTarget?
    let transition: CoreListTransition
    let advanceAfter: TimeInterval
    let actions: [MixedPassAction]

    var actionDescription: String {
        actions.map(\.description).joined(separator: " + ")
    }

    var description: String {
        "\(actionDescription) | count=\(items.count) size=\(size.width)x\(size.height) "
            + "insets=\(insets) scroll=\(String(describing: scrollTo)) "
            + "duration=\(transition.duration) curve=\(String(describing: transition.curve)) "
            + "advance=\(advanceAfter)"
    }
}

struct MixedPassScenario {
    let seed: UInt64
    private(set) var items: [MixedPassItem]
    private(set) var size = CGSize(width: 390, height: 800)
    private(set) var insets = UIEdgeInsets.zero
    private(set) var actionLog: [String] = []

    private var rng: SeededRNG
    /// Attachment decisions draw from their OWN generator. `MixedPassScenario` is a shared seeded
    /// generator and some focused suites replay its exact sequence (`ProgrammaticScrollAnimationTests`
    /// depends on a specific pass producing a crossing carry), so drawing attachment actions from
    /// `rng` would silently hand every one of them a different scenario.
    private var attachmentRNG: SeededRNG
    private var nextIdentity: Int
    private var positivePassSerial = 0
    /// Opt-in: only the stress suite wants attachments. Off, the scenario is byte-for-byte what it
    /// was before attachments existed.
    private let includesAttachments: Bool

    static let heights: [CGFloat] = [44, 60, 75, 96, 128]
    static let durations: [TimeInterval] = [0, 0.15, 0.35, 0.5]
    static let phases: [Double] = [0, 0.1, 0.5, 0.9]

    init(seed: UInt64, itemCount: Int, includesAttachments: Bool = false) {
        precondition(itemCount > 0)
        self.seed = seed
        self.includesAttachments = includesAttachments
        rng = SeededRNG(seed: seed)
        attachmentRNG = SeededRNG(seed: seed &+ 0x9E37_79B9_7F4A_7C15)
        items = (0..<itemCount).map {
            MixedPassItem(
                id: $0,
                height: Self.heights[$0 % Self.heights.count],
                group: includesAttachments ? $0 / 4 : nil
            )
        }
        nextIdentity = itemCount
    }

    func makeInitialItems() -> [CoreListItem] {
        items.map { $0 as CoreListItem }
    }

    mutating func nextStep() -> MixedPassStep {
        var actions: [MixedPassAction] = []
        var pendingScrollOffset: CGFloat?
        let actionCount = rng.int(in: 1..<4)

        for _ in 0..<actionCount {
            switch rng.int(in: 0..<10) {
            case 0:
                actions.append(insertBlock())
            case 1:
                actions.append(removeBlock())
            case 2:
                actions.append(moveBlock())
            case 3:
                actions.append(replaceItem())
            case 4:
                actions.append(resizeItem())
            case 5:
                actions.append(changeHorizontalInsets())
            case 6:
                actions.append(changeVerticalInsets())
            case 7:
                actions.append(changeViewport())
            case 8:
                let offsets: [CGFloat] = [0, 20, 80, -40]
                pendingScrollOffset = offsets[rng.int(in: offsets.indices)]
            default:
                actions.append(.sameTarget)
            }
        }

        if includesAttachments {
            switch attachmentRNG.int(in: 0..<4) {
            case 0: actions.append(regroup())
            case 1: actions.append(dropAttachments())
            default: break
            }
        }

        var scrollTo: CoreListScrollTarget?
        if let pointOffset = pendingScrollOffset {
            let index = rng.int(in: items.indices)
            actions.append(.scroll(index: index, pointOffset: pointOffset))
            scrollTo = CoreListScrollTarget(index: index, pointOffset: pointOffset)
        }
        if actions.isEmpty {
            actions.append(.sameTarget)
        }

        let duration = Self.durations[rng.int(in: 0..<Self.durations.count)]
        let transition: CoreListTransition
        if duration == 0 {
            transition = .immediate
        } else {
            positivePassSerial += 1
            // Two curves, alternating: the oracle compares installed CA metadata against the model
            // track, so a single curve everywhere would stop exercising curve propagation.
            transition = positivePassSerial.isMultiple(of: 2)
                ? .easeInOut(duration: duration)
                : .linear(duration: duration)
        }
        let phase = Self.phases[rng.int(in: 0..<Self.phases.count)]
        let step = MixedPassStep(
            items: items,
            size: size,
            insets: insets,
            scrollTo: scrollTo,
            transition: transition,
            advanceAfter: duration * phase,
            actions: actions
        )
        actionLog.append(step.description)
        return step
    }

    /// Re-derives every row's group from its POSITION, which splits and merges runs — the operation
    /// the witness rule exists for. Sizes are chosen so successive regroups rarely align.
    mutating private func regroup() -> MixedPassAction {
        let sizes = [2, 3, 5, 8]
        let size = sizes[rng.int(in: sizes.indices)]
        items = items.enumerated().map { position, item in
            MixedPassItem(id: item.id, height: item.height, group: position / size)
        }
        return .regroup(size: size)
    }

    /// Strips the attachment from a contiguous block, creating a gap between runs.
    mutating private func dropAttachments() -> MixedPassAction {
        guard !items.isEmpty else { return .sameTarget }
        let start = rng.int(in: items.indices)
        let length = min(rng.int(in: 1..<4), items.count - start)
        let range = start..<(start + length)
        for position in range {
            items[position] = MixedPassItem(id: items[position].id,
                                            height: items[position].height,
                                            group: nil)
        }
        return .dropAttachments(range: range)
    }

    mutating private func insertBlock() -> MixedPassAction {
        let index = rng.int(in: 0..<(items.count + 1))
        let count = rng.int(in: 1..<6)
        var inserted: [MixedPassItem] = []
        for _ in 0..<count {
            let id = nextIdentity
            nextIdentity += 1
            inserted.append(
                MixedPassItem(
                    id: id,
                    height: Self.heights[id % Self.heights.count]
                )
            )
        }
        items.insert(contentsOf: inserted, at: index)
        return .insert(index: index, ids: inserted.map(\.id))
    }

    mutating private func removeBlock() -> MixedPassAction {
        guard items.count > 1 else { return .sameTarget }
        let count = min(rng.int(in: 1..<6), items.count - 1)
        let start = rng.int(in: 0..<(items.count - count + 1))
        let range = start..<(start + count)
        let removed = Array(items[range])
        items.removeSubrange(range)
        return .remove(range: range, ids: removed.map(\.id))
    }

    mutating private func moveBlock() -> MixedPassAction {
        guard items.count > 2 else { return .sameTarget }
        let count = min(rng.int(in: 1..<6), items.count - 1)
        let start = rng.int(in: 0..<(items.count - count + 1))
        let range = start..<(start + count)
        let block = Array(items[range])
        items.removeSubrange(range)
        let destination = rng.int(in: 0..<(items.count + 1))
        items.insert(contentsOf: block, at: destination)
        return .move(range: range, destination: destination)
    }

    mutating private func replaceItem() -> MixedPassAction {
        let index = rng.int(in: items.indices)
        let old = items[index]
        let replacement = MixedPassItem(
            id: nextIdentity,
            height: Self.heights[nextIdentity % Self.heights.count]
        )
        nextIdentity += 1
        items[index] = replacement
        return .replace(index: index, oldID: old.id, newID: replacement.id)
    }

    mutating private func resizeItem() -> MixedPassAction {
        let index = rng.int(in: items.indices)
        let old = items[index]
        let candidates = Self.heights.filter { $0 != old.height }
        let height = candidates[rng.int(in: candidates.indices)]
        items[index] = MixedPassItem(id: old.id, height: height)
        return .resize(index: index, id: old.id, from: old.height, to: height)
    }

    mutating private func changeHorizontalInsets() -> MixedPassAction {
        let pairs: [(CGFloat, CGFloat)] = [
            (0, 0), (20, 30), (40, 50), (70, 10),
        ]
        let pair = pairs[rng.int(in: pairs.indices)]
        insets.left = pair.0
        insets.right = pair.1
        return .horizontalInsets(left: pair.0, right: pair.1)
    }

    mutating private func changeVerticalInsets() -> MixedPassAction {
        let pairs: [(CGFloat, CGFloat)] = [
            (0, 0), (120, 40), (300, 0), (40, 120),
        ]
        let pair = pairs[rng.int(in: pairs.indices)]
        insets.top = pair.0
        insets.bottom = pair.1
        return .verticalInsets(top: pair.0, bottom: pair.1)
    }

    mutating private func changeViewport() -> MixedPassAction {
        let sizes = [
            CGSize(width: 320, height: 640),
            CGSize(width: 390, height: 800),
            CGSize(width: 430, height: 874),
            CGSize(width: 500, height: 700),
        ]
        size = sizes[rng.int(in: sizes.indices)]
        return .viewport(size)
    }

    func failureContext(
        pass: Int,
        size: CGSize,
        insets: UIEdgeInsets,
        offset: CGFloat,
        loadedIndices: [Int],
        crossingIdentities: [AnyHashable],
        ghostDescriptions: [String]
    ) -> String {
        let loaded: String
        if let first = loadedIndices.first, let last = loadedIndices.last {
            loaded = "\(first)...\(last)"
        } else {
            loaded = "empty"
        }
        let actions = actionLog.enumerated().map {
            "\($0.offset): \($0.element)"
        }.joined(separator: "\n")
        let crossings = crossingIdentities
            .map { String(describing: $0) }
            .joined(separator: ", ")
        return """
        seed=\(seed) pass=\(pass)
        actions=\(actions)
        size=(\(size.width), \(size.height)) insets=\(insets)
        offset=\(offset) loaded=\(loaded)
        crossing=[\(crossings)]
        ghosts=\(ghostDescriptions)
        """
    }
}
