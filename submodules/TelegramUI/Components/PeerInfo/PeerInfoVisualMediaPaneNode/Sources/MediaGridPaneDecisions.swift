import Foundation
import CoreGraphics

struct MediaGridPaneHole: Equatable {
    var anchorIndex: Int
}

let mediaGridPanePreviewWidths: [Int] = [64, 150, 200, 280]

func mediaGridPaneLevelColumns(storedColumns: Int32?) -> Int {
    guard let storedColumns else {
        return 3
    }
    if storedColumns <= 3 {
        return 3
    } else if storedColumns <= 7 {
        return 5
    } else {
        return 15
    }
}

func mediaGridPanePreviewWidth(cellPointWidth: CGFloat) -> Int {
    if cellPointWidth <= 50.0 {
        return 64
    } else if cellPointWidth <= 100.0 {
        return 150
    } else if cellPointWidth <= 140.0 {
        return 200
    } else {
        return 280
    }
}

func mediaGridPaneHoleToLoad(visible: Range<Int>, isLoaded: (Int) -> Bool, holes: [MediaGridPaneHole]) -> MediaGridPaneHole? {
    guard !holes.isEmpty, let firstEmpty = visible.first(where: { !isLoaded($0) }) else {
        return nil
    }
    return mediaGridPaneHoleNearest(to: firstEmpty, sortedHoles: holes.sorted(by: { $0.anchorIndex < $1.anchorIndex }))
}

func mediaGridPaneHoleNearest(to index: Int, sortedHoles holes: [MediaGridPaneHole]) -> MediaGridPaneHole? {
    guard !holes.isEmpty else {
        return nil
    }
    var low = 0
    var high = holes.count
    while low < high {
        let mid = (low + high) / 2
        if holes[mid].anchorIndex < index {
            low = mid + 1
        } else {
            high = mid
        }
    }
    if low == holes.count {
        return holes[holes.count - 1]
    }
    if low == 0 {
        return holes[0]
    }
    let lower = holes[low - 1]
    let upper = holes[low]
    return index - lower.anchorIndex < upper.anchorIndex - index ? lower : upper
}

func mediaGridPaneDateIndex(at index: Int, anchors: [(index: Int, timestamp: Int32)]) -> Int32? {
    var below: (index: Int, timestamp: Int32)?
    var above: (index: Int, timestamp: Int32)?
    for anchor in anchors {
        if anchor.index <= index {
            if below == nil || anchor.index > below!.index {
                below = anchor
            }
        } else if above == nil || anchor.index < above!.index {
            above = anchor
        }
    }
    return (below ?? above)?.timestamp
}

func mediaGridPaneChangedIndices<Key: Equatable>(old: [Int: Key], new: [Int: Key], overlap: Int) -> IndexSet {
    var result = IndexSet()
    var indices = Set<Int>()
    for index in old.keys where index < overlap {
        indices.insert(index)
    }
    for index in new.keys where index < overlap {
        indices.insert(index)
    }
    for index in indices where old[index] != new[index] {
        result.insert(index)
    }
    return result
}

struct MediaGridPaneStateGate<State> {
    private var held: State?

    var isHolding: Bool {
        return self.held != nil
    }

    mutating func offer(_ state: State, isBusy: Bool) -> State? {
        if isBusy {
            self.held = state
            return nil
        }
        self.held = nil
        return state
    }

    mutating func release() -> State? {
        let state = self.held
        self.held = nil
        return state
    }
}

func mediaGridPaneRowIsReady(index: Int, columns: Int, count: Int, isEndKnown: Bool, isReady: (Int) -> Bool) -> Bool {
    let columns = max(1, columns)
    let start = (index / columns) * columns
    for i in start ..< start + columns {
        if i >= count {
            return isEndKnown
        }
        if !isReady(i) {
            return false
        }
    }
    return true
}

func mediaGridPaneRevealDelays(rows: [Int]) -> [Int: Double] {
    let sorted = Set(rows).sorted()
    guard !sorted.isEmpty else {
        return [:]
    }
    let step = sorted.count > 1 ? min(0.04, 0.3 / Double(sorted.count - 1)) : 0.0
    var result: [Int: Double] = [:]
    for (rank, row) in sorted.enumerated() {
        result[row] = Double(rank) * step
    }
    return result
}
