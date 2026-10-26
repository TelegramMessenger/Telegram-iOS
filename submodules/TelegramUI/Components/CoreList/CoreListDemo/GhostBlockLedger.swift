import Foundation
import CoreGraphics

struct GhostBlockID: Hashable, Comparable {
    let rawValue: UInt64

    static func < (lhs: GhostBlockID, rhs: GhostBlockID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum GhostBlockEdge: Equatable {
    case minY
    case maxY
}

/// Which coordinate space a ghost block's `settledRootY` is expressed in.
///
/// `.content` is the ordinary case: the block sits in `exitOverlay` inside the scrolling content
/// host, and a coordinate rebase must move it to hold its screen position.
///
/// `.viewport` is a carousel's departed strip. A carousel travels to a different region of the
/// collection, so the strip has NO position in the destination's content space — the adjacent
/// placement it is given is a fiction that survives only while the shared viewport track is the sole
/// thing moving. It is parked in `carouselExitOverlay`, outside the content host, so its root is
/// already a screen quantity and content-space shifts must not reach it.
enum GhostBlockAnchoring: Equatable {
    case content
    case viewport
}

enum GhostBoundaryWitness: Equatable {
    case liveMinY(AnyHashable)
    case liveMaxY(AnyHashable)
    case ghostMinY(GhostBlockID)
    case ghostMaxY(GhostBlockID)
    case unresolved
}

struct GhostLiveEdges: Equatable {
    let minY: CGFloat
    let maxY: CGFloat
}

struct GhostBlockSnapshot: Equatable {
    let id: GhostBlockID
    let witness: GhostBoundaryWitness
    let attachmentEdge: GhostBlockEdge
    let isBoundaryOpen: Bool
    let settledRootY: CGFloat
    let anchoring: GhostBlockAnchoring
    let localMinY: CGFloat
    let localMaxY: CGFloat
    let visibleMemberCount: Int
    let dependentCount: Int
}

final class GhostBlockLedger {
    private struct Node {
        let id: GhostBlockID
        var witness: GhostBoundaryWitness
        var attachmentEdge: GhostBlockEdge
        var isBoundaryOpen: Bool
        var settledRootY: CGFloat
        var anchoring: GhostBlockAnchoring
        let localMinY: CGFloat
        let localMaxY: CGFloat
        var visibleMemberCount: Int
        var dependents: Set<GhostBlockID>
    }

    private var nextID: UInt64 = 0
    private var nodes: [GhostBlockID: Node] = [:]

    var snapshots: [GhostBlockSnapshot] {
        nodes.values.map { snapshot($0) }.sorted { $0.id < $1.id }
    }

    func snapshot(for id: GhostBlockID) -> GhostBlockSnapshot? {
        nodes[id].map { snapshot($0) }
    }

    @discardableResult
    func insert(rootY: CGFloat,
                localMinY: CGFloat,
                localMaxY: CGFloat,
                attachmentEdge: GhostBlockEdge = .minY,
                witness: GhostBoundaryWitness,
                visibleMemberCount: Int) -> GhostBlockID {
        precondition(visibleMemberCount >= 0)
        precondition(localMinY <= localMaxY)
        nextID += 1
        let id = GhostBlockID(rawValue: nextID)
        nodes[id] = Node(id: id,
                         witness: .unresolved,
                         attachmentEdge: attachmentEdge,
                         isBoundaryOpen: true,
                         settledRootY: rootY,
                         anchoring: .content,
                         localMinY: localMinY,
                         localMaxY: localMaxY,
                         visibleMemberCount: visibleMemberCount,
                         dependents: [])
        precondition(setWitness(witness, for: id))
        return id
    }

    func canSetWitness(_ witness: GhostBoundaryWitness,
                       for id: GhostBlockID) -> Bool {
        guard let node = nodes[id] else { return false }
        // A viewport-anchored block has no content neighbourhood to attach to — having travelled to a
        // different region of the collection is what made it one. A witness there hands it a second
        // vertical owner alongside the viewport track, which walks it onto whatever it witnessed.
        //
        // `CoreVirtualListView` already declines to attach one at CREATION (`:1710`), but that guard
        // only covers blocks born in the carousel pass. An EXISTING strip is re-linked later by the
        // geometry/migration path: with two carousels in a row, the first strip acquired
        // `.ghostMinY` onto the second strip's block and both resolved to the same screen Y — the old
        // window landing exactly on top of the new one. Refusing here covers every path at once,
        // which is the only way to state "never" about a graph edge.
        if node.anchoring == .viewport {
            return witness == .unresolved
        }
        switch witness {
        case let .ghostMinY(target), let .ghostMaxY(target):
            return nodes[target] != nil && target != id && !reaches(id, from: target)
        case .liveMinY, .liveMaxY, .unresolved:
            return true
        }
    }

    @discardableResult
    func setWitness(_ witness: GhostBoundaryWitness,
                    for id: GhostBlockID) -> Bool {
        guard let attachmentEdge = nodes[id]?.attachmentEdge else { return false }
        return setBoundaryLink(attachmentEdge: attachmentEdge,
                               witness: witness,
                               for: id)
    }

    @discardableResult
    func setBoundaryLink(attachmentEdge: GhostBlockEdge,
                         witness: GhostBoundaryWitness,
                         for id: GhostBlockID) -> Bool {
        guard canSetWitness(witness, for: id), let old = nodes[id]?.witness else {
            return false
        }
        if let target = ghostTarget(of: old) {
            nodes[target]?.dependents.remove(id)
        }
        nodes[id]?.attachmentEdge = attachmentEdge
        nodes[id]?.witness = witness
        if let target = ghostTarget(of: witness) {
            nodes[target]?.dependents.insert(id)
        }
        return true
    }

    func resolvedTargets(liveEdges: [AnyHashable: GhostLiveEdges])
        -> [GhostBlockID: CGFloat] {
        var result: [GhostBlockID: CGFloat] = [:]
        for id in nodes.keys.sorted() {
            var visiting: Set<GhostBlockID> = []
            result[id] = resolve(id, liveEdges: liveEdges, visiting: &visiting)
        }
        return result
    }

    func setSettledRootY(_ value: CGFloat, for id: GhostBlockID) {
        nodes[id]?.settledRootY = value
    }

    func setAnchoring(_ anchoring: GhostBlockAnchoring, for id: GhostBlockID) {
        nodes[id]?.anchoring = anchoring
    }

    func sealBoundary(for id: GhostBlockID) {
        nodes[id]?.isBoundaryOpen = false
    }

    /// Rebases one coordinate space's roots. The default is the content-space rebase; viewport-
    /// anchored blocks are excluded from it because their roots are screen quantities, so a delta
    /// that keeps content children still would MOVE them. They have their own, unrelated rebase:
    /// a viewport track replacement steps the shared correction, and their rendering subtracts only
    /// that correction.
    func shiftRoots(by delta: CGFloat, anchoring: GhostBlockAnchoring = .content) {
        guard delta != 0 else { return }
        for id in Array(nodes.keys) where nodes[id]?.anchoring == anchoring {
            nodes[id]?.settledRootY += delta
        }
    }

    func removeVisibleMember(from id: GhostBlockID) {
        guard let count = nodes[id]?.visibleMemberCount, count > 0 else { return }
        nodes[id]?.visibleMemberCount = count - 1
    }

    func collectOrphanedEmptyBlocks() -> [GhostBlockID] {
        var removed: [GhostBlockID] = []
        while let id = nodes.values
            .filter({ $0.visibleMemberCount == 0 && $0.dependents.isEmpty })
            .map(\.id).min() {
            if let target = nodes[id].flatMap({ ghostTarget(of: $0.witness) }) {
                nodes[target]?.dependents.remove(id)
            }
            nodes.removeValue(forKey: id)
            removed.append(id)
        }
        return removed
    }

    func reset() {
        nodes.removeAll()
    }

    func assertInvariants() {
#if DEBUG
        for node in nodes.values {
            if let target = ghostTarget(of: node.witness) {
                assert(target != node.id)
                assert(nodes[target] != nil)
                assert(nodes[target]?.dependents.contains(node.id) == true)
            }
            for dependent in node.dependents {
                assert(nodes[dependent] != nil)
                assert(nodes[dependent].flatMap { ghostTarget(of: $0.witness) } == node.id)
            }
        }

        var visited: Set<GhostBlockID> = []
        var visiting: Set<GhostBlockID> = []
        func visit(_ id: GhostBlockID) {
            assert(visiting.insert(id).inserted)
            if let target = nodes[id].flatMap({ ghostTarget(of: $0.witness) }),
               !visited.contains(target) {
                visit(target)
            }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in nodes.keys where !visited.contains(id) {
            visit(id)
        }
#endif
    }

    private func snapshot(_ node: Node) -> GhostBlockSnapshot {
        GhostBlockSnapshot(id: node.id,
                           witness: node.witness,
                           attachmentEdge: node.attachmentEdge,
                           isBoundaryOpen: node.isBoundaryOpen,
                           settledRootY: node.settledRootY,
                           anchoring: node.anchoring,
                           localMinY: node.localMinY,
                           localMaxY: node.localMaxY,
                           visibleMemberCount: node.visibleMemberCount,
                           dependentCount: node.dependents.count)
    }

    private func ghostTarget(of witness: GhostBoundaryWitness) -> GhostBlockID? {
        switch witness {
        case let .ghostMinY(id), let .ghostMaxY(id): return id
        case .liveMinY, .liveMaxY, .unresolved: return nil
        }
    }

    private func reaches(_ target: GhostBlockID, from start: GhostBlockID) -> Bool {
        var cursor: GhostBlockID? = start
        var visited: Set<GhostBlockID> = []
        while let current = cursor, visited.insert(current).inserted {
            if current == target { return true }
            cursor = nodes[current].flatMap { ghostTarget(of: $0.witness) }
        }
        return false
    }

    private func resolve(_ id: GhostBlockID,
                         liveEdges: [AnyHashable: GhostLiveEdges],
                         visiting: inout Set<GhostBlockID>) -> CGFloat {
        guard let node = nodes[id] else { return 0 }
        guard visiting.insert(id).inserted else {
            assertionFailure("ghost witness cycle")
            return node.settledRootY
        }
        defer { visiting.remove(id) }
        let boundaryY: CGFloat
        switch node.witness {
        case let .liveMinY(identity):
            guard let value = liveEdges[identity]?.minY else {
                return node.settledRootY
            }
            boundaryY = value
        case let .liveMaxY(identity):
            guard let value = liveEdges[identity]?.maxY else {
                return node.settledRootY
            }
            boundaryY = value
        case let .ghostMinY(target):
            guard let targetNode = nodes[target] else { return node.settledRootY }
            boundaryY = resolve(target, liveEdges: liveEdges, visiting: &visiting)
                + targetNode.localMinY
        case let .ghostMaxY(target):
            guard let targetNode = nodes[target] else { return node.settledRootY }
            boundaryY = resolve(target, liveEdges: liveEdges, visiting: &visiting)
                + targetNode.localMaxY
        case .unresolved:
            return node.settledRootY
        }
        let attachmentY: CGFloat
        switch node.attachmentEdge {
        case .minY: attachmentY = node.localMinY
        case .maxY: attachmentY = node.localMaxY
        }
        return boundaryY - attachmentY
    }
}
