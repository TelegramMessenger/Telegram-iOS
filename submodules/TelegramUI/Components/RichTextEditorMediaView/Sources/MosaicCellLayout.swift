import Foundation
import UIKit
import TelegramCore

/// A pure multiset diff of media identities against an existing keyed pool, so an add/remove reuses the
/// cells whose media is unchanged (never rebuilding them → the image fetch is not re-issued). Duplicate
/// media (the same `EngineMedia.Id` twice) is matched greedily in order.
///
/// Returns, for each incoming item (in order), the pooled key to REUSE (or nil = create a fresh cell), plus
/// the set of pooled keys left OVER (to remove). `Key` is the cell-pool key: `EngineMedia.Id`.
enum MosaicCellDiff {
    struct Plan {
        /// Per incoming item: reuse this pooled occurrence (media id + occurrence index) or nil = create.
        let reuse: [PooledKey?]
        /// Pooled occurrences no longer present → remove.
        let removed: [PooledKey]
    }
    struct PooledKey: Hashable {
        let id: EngineMedia.Id
        let occurrence: Int
    }

    /// `poolKeys` = the keys currently in the pool (order irrelevant). `incoming` = the media ids in the new
    /// container order.
    static func plan(poolKeys: [PooledKey], incoming: [EngineMedia.Id]) -> Plan {
        var available: [EngineMedia.Id: [PooledKey]] = [:]
        for k in poolKeys { available[k.id, default: []].append(k) }
        for id in available.keys { available[id]?.sort { $0.occurrence < $1.occurrence } }

        var reuse: [PooledKey?] = []
        var used = Set<PooledKey>()
        for id in incoming {
            if var bucket = available[id], !bucket.isEmpty {
                let key = bucket.removeFirst()
                available[id] = bucket
                used.insert(key)
                reuse.append(key)
            } else {
                reuse.append(nil)
            }
        }
        let removed = poolKeys.filter { !used.contains($0) }
        return Plan(reuse: reuse, removed: removed)
    }
}
