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
    var best: MediaGridPaneHole?
    var bestDistance = Int.max
    for hole in holes {
        let distance = abs(hole.anchorIndex - firstEmpty)
        if distance < bestDistance || (distance == bestDistance && hole.anchorIndex > (best?.anchorIndex ?? Int.min)) {
            best = hole
            bestDistance = distance
        }
    }
    return best
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
