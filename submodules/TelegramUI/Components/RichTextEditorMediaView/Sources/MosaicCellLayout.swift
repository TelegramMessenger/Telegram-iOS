import Foundation
import UIKit
import TelegramCore
import MosaicLayout

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

/// The photo/video cell frames of a mosaic container `size` wide: the album engine packed within
/// `width × min(1000, width)` (the cap `MediaBlockBox.mosaicSize` reserves), then scaled to fit and centred
/// when the width-driven pack still exceeds the cap. Needs >= 2 items (the engine has no 1-item case).
enum MosaicCellFrames {
    static func frames(itemSizes: [CGSize], size: CGSize) -> [CGRect] {
        let cap = min(1000.0, size.width)
        let (rawFrames, naturalSize) = chatMessageBubbleMosaicLayout(
            maxSize: CGSize(width: size.width, height: cap),
            itemSizes: itemSizes)
        let scale: CGFloat = naturalSize.height > cap ? cap / naturalSize.height : 1.0
        let xOffset = floor((size.width - naturalSize.width * scale) / 2.0)
        return rawFrames.map { frame, _ in
            CGRect(x: xOffset + frame.minX * scale, y: frame.minY * scale,
                   width: frame.width * scale, height: frame.height * scale)
        }
    }
}
