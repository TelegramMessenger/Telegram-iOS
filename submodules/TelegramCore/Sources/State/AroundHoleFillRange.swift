import Foundation
import Postbox

/// The hole an around fill closes, from the ids it stored and the server's position facts.
///
/// The around request (`offsetId: anchor, addOffset: -limit/2`) returns every newer message up to
/// half the limit, the anchor, and half the limit older ones; the server does not fill downward when
/// fewer newer ones exist. `offset_id_offset` is the 1-based position of the anchor counted from the
/// newest message (measured 2026-10-13 on two channels: 16 with 15 newer ids returned, 17/16, 9/8).
/// So the top of the history was reached exactly when the newer ids returned number one less than
/// that position, and the whole history is known when the result holds `count` messages. `inexact`
/// vetoes both inferences. A deleted anchor gets no top inference: what the server reports as its
/// position was not measured. The bottom is never inferred: the count of older messages is not safely derivable.
///
/// Returns nil for an empty result; the caller keeps its own rule for that case.
func aroundHoleFillRange(anchorId: MessageId.Id, ids: [MessageId.Id], totalCount: Int32?, offsetIdOffset: Int32?, inexact: Bool) -> ClosedRange<MessageId.Id>? {
    guard let minId = ids.min(), let maxId = ids.max() else {
        return nil
    }
    let fetchedSpan = min(anchorId, minId) ... max(anchorId, maxId)
    if inexact {
        return fetchedSpan
    }
    if let totalCount, totalCount == Int32(clamping: ids.count) {
        return 1 ... (Int32.max - 1)
    }
    if let offsetIdOffset, offsetIdOffset >= 1, ids.contains(anchorId) {
        let newerCount = ids.filter({ $0 > anchorId }).count
        if newerCount == Int(offsetIdOffset) - 1 {
            return fetchedSpan.lowerBound ... (Int32.max - 1)
        }
    }
    return fetchedSpan
}
