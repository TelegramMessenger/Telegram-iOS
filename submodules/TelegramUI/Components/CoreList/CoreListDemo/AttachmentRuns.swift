import CoreGraphics

/// Run computation and serial inheritance for attached items. Pure value logic: no UIKit, no views,
/// no list state.
enum AttachmentRuns {
    /// A run resolved from the collection, before a serial has been assigned to it.
    struct PendingRun {
        let key: AnyHashable
        /// Collection-index range of this run's LOADED members.
        let memberRange: Range<Int>
        /// The descriptor published by the member nearest the pinning edge.
        let representative: CoreListAttachedItem
        /// True when `memberRange.lowerBound` is a genuine collection-level run start, i.e. the
        /// previous item does not continue this run. False when the run is merely clipped by the
        /// loaded window. Reservation is gated on this.
        let startsCollectionRun: Bool
        /// The mirror at the run's tail.
        let endsCollectionRun: Bool

        var placement: CoreListAttachmentPlacement { representative.placement }
        var edge: CoreListAttachmentEdge { representative.edge }
        var isFloating: Bool { representative.isFloating }
    }

    /// Resolves every run intersecting `loadedRange`.
    ///
    /// Boundary classification consults `items[loadedRange.lowerBound - 1]` and
    /// `items[loadedRange.upperBound]` when they exist — that is the whole difference between a
    /// collection-level run boundary and a merely-loaded one.
    ///
    /// Result order is `(memberRange.lowerBound, key description)`: deterministic, because
    /// `[AnyHashable: CoreListAttachedItem]` has no iteration order and `AnyHashable` supplies no
    /// ordering to impose one. Not by serial — serials are assigned against this order, and an
    /// inherited one is an arbitrary number from an earlier pass. Ties between different keys on the
    /// same boundary are arbitrary but stable, and must not be relied upon.
    static func pendingRuns(in items: [CoreListItem],
                            loadedRange: Range<Int>) -> [PendingRun] {
        guard !loadedRange.isEmpty else { return [] }

        func attachment(_ index: Int, _ key: AnyHashable) -> CoreListAttachedItem? {
            guard items.indices.contains(index) else { return nil }
            return items[index].attachedItems[key]
        }

        /// Whether `index` continues the run that `index - 1` belongs to, under `key`.
        func continues(_ index: Int, _ key: AnyHashable) -> Bool {
            guard let here = attachment(index, key),
                  let previous = attachment(index - 1, key)
            else { return false }
            return previous.combines(with: here)
        }

        var runs: [PendingRun] = []

        for index in loadedRange {
            for (key, descriptor) in items[index].attachedItems {
                // Only the run's loaded head emits a run; every other member is absorbed below.
                if index > loadedRange.lowerBound, continues(index, key) { continue }

                var upperBound = index + 1
                while upperBound < loadedRange.upperBound, continues(upperBound, key) {
                    upperBound += 1
                }
                let memberRange = index..<upperBound

                let startsCollectionRun = !continues(index, key)
                let endsCollectionRun = !continues(upperBound, key)

                let representativeIndex = descriptor.edge == .top
                    ? memberRange.lowerBound
                    : memberRange.upperBound - 1
                let representative = attachment(representativeIndex, key) ?? descriptor

                assert(memberRange.allSatisfy { memberIndex in
                    guard let member = attachment(memberIndex, key) else { return false }
                    return member.placement == representative.placement
                        && member.edge == representative.edge
                        && member.isFloating == representative.isFloating
                }, "all members of one run must agree on placement, edge and isFloating")

                runs.append(PendingRun(key: key,
                                       memberRange: memberRange,
                                       representative: representative,
                                       startsCollectionRun: startsCollectionRun,
                                       endsCollectionRun: endsCollectionRun))
            }
        }

        // A run that defers to a group present in this set renders BELOW it — ListViewImpl's
        // `insertItemBelowOtherHeaders` (Display/Source/ListView.swift:4167-4180), which likewise
        // sinks a stacked header below EVERY other header rather than only its own group's.
        //
        // Expressed as a leading rank rather than a pairwise clause in the comparator, because "A
        // before B if A yields to B's group" is not a strict weak ordering and `sorted` may produce
        // anything at all when given one. With no yield declared every rank is equal and the existing
        // order stands untouched.
        let groups = Set(runs.compactMap { $0.representative.stackingGroup })
        func layer(_ run: PendingRun) -> Int {
            guard let yield = run.representative.stackingYield, groups.contains(yield.group) else {
                return 1
            }
            return 0
        }

        return runs.sorted { lhs, rhs in
            if layer(lhs) != layer(rhs) {
                return layer(lhs) < layer(rhs)
            }
            if lhs.memberRange.lowerBound != rhs.memberRange.lowerBound {
                return lhs.memberRange.lowerBound < rhs.memberRange.lowerBound
            }
            return String(describing: lhs.key) < String(describing: rhs.key)
        }
    }

    /// A run as it existed in the previous settled window.
    struct PriorRun {
        let key: AnyHashable
        let serial: UInt64
        /// The run's loaded members, in collection order, as of the previous window.
        let memberIdentities: [AnyHashable]
        let edge: CoreListAttachmentEdge
    }

    /// A run with its serial resolved.
    struct ResolvedRun {
        let pending: PendingRun
        let serial: UInt64
        /// True when no prior serial was inherited. The fade-in rule gates on this TOGETHER with
        /// insert/reconcile membership; freshness ALONE does not distinguish new content from newly
        /// loaded content.
        let isFresh: Bool

        var key: AnyHashable { pending.key }
        var memberRange: Range<Int> { pending.memberRange }
        var representative: CoreListAttachedItem { pending.representative }
    }

    /// Assigns a serial to every pending run.
    ///
    /// Each prior serial's WITNESS is its member nearest its pinning edge that survives into some new
    /// run of the same key. Each new run adopts the serial whose witness is nearest that new run's own
    /// pinning edge. Unclaimed prior serials depart.
    ///
    /// No global arbitration is needed: a witness is one identity, and each identity belongs to
    /// exactly one run, so a serial can be claimed by at most one run by construction.
    static func assignSerials(pending: [PendingRun],
                              newIdentities: [AnyHashable],
                              prior: [PriorRun],
                              nextSerial: inout UInt64)
        -> (assigned: [ResolvedRun], departed: [PriorRun]) {
        var newIndexByIdentity: [AnyHashable: Int] = [:]
        newIndexByIdentity.reserveCapacity(newIdentities.count)
        for (index, identity) in newIdentities.enumerated() {
            newIndexByIdentity[identity] = index
        }

        // Which pending run, if any, contains a given new collection index under a given key.
        func runIndex(containing index: Int, key: AnyHashable) -> Int? {
            pending.firstIndex { $0.key == key && $0.memberRange.contains(index) }
        }

        // Witness of each prior run: its edge-most member that survives INTO a run of the same key.
        // (witnessIndex is in NEW collection indices.)
        var witnessByPrior: [Int: (runIndex: Int, witnessIndex: Int)] = [:]
        for (priorIndex, priorRun) in prior.enumerated() {
            let ordered = priorRun.edge == .top
                ? priorRun.memberIdentities
                : priorRun.memberIdentities.reversed().map { $0 }
            for identity in ordered {
                guard let newIndex = newIndexByIdentity[identity],
                      let run = runIndex(containing: newIndex, key: priorRun.key)
                else { continue }
                witnessByPrior[priorIndex] = (run, newIndex)
                break
            }
        }

        // Each run adopts the witness nearest its own pinning edge.
        var claimByRun: [Int: Int] = [:]        // pending index -> prior index
        for (priorIndex, witness) in witnessByPrior {
            guard let incumbent = claimByRun[witness.runIndex] else {
                claimByRun[witness.runIndex] = priorIndex
                continue
            }
            let incumbentIndex = witnessByPrior[incumbent]!.witnessIndex
            let isNearer = pending[witness.runIndex].edge == .top
                ? witness.witnessIndex < incumbentIndex
                : witness.witnessIndex > incumbentIndex
            if isNearer { claimByRun[witness.runIndex] = priorIndex }
        }

        var assigned: [ResolvedRun] = []
        var claimedPrior = Set<Int>()
        assigned.reserveCapacity(pending.count)
        for (index, run) in pending.enumerated() {
            if let priorIndex = claimByRun[index] {
                claimedPrior.insert(priorIndex)
                assigned.append(ResolvedRun(pending: run,
                                            serial: prior[priorIndex].serial,
                                            isFresh: false))
            } else {
                assigned.append(ResolvedRun(pending: run, serial: nextSerial, isFresh: true))
                nextSerial += 1
            }
        }

        let departed = prior.enumerated()
            .filter { !claimedPrior.contains($0.offset) }
            .map(\.element)

        return (assigned, departed)
    }
}
