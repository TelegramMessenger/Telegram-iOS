import Foundation

/// Decides how many queued frames to hand the bridge in one WebView message.
///
/// The bridge parses a multi-frame batch out of a single ArrayBuffer (its
/// `splitFrames`/`frameBound` do the boundary walk), so coalescing collapses N
/// cross-process `evaluateJavaScript` round trips into one. Two limits are the
/// bridge's, not ours: it throws past 4096 frames, and its queue accounting is
/// sized around the 2 MiB carrier batch.
enum WebProxySendBatcher {
    /// Number of leading frames from `pending` to send as one message.
    ///
    /// `isFirstMessage` forces a batch of one: the bridge routes the very first
    /// ArrayBuffer to `createSession`, whose body must be the lone `HELLO` frame
    /// and which the relay caps at 64 bytes.
    static func batchCount(pending: [Data], isFirstMessage: Bool, maximumFrames: Int, maximumBytes: Int) -> Int {
        guard !pending.isEmpty else {
            return 0
        }
        if isFirstMessage {
            return 1
        }
        var count = 0
        var bytes = 0
        for frame in pending {
            if count == maximumFrames {
                break
            }
            // The first frame always goes, even when it alone exceeds the byte
            // budget — otherwise an oversized frame wedges the queue forever.
            if count > 0 && bytes + frame.count > maximumBytes {
                break
            }
            bytes += frame.count
            count += 1
        }
        return max(1, count)
    }
}
