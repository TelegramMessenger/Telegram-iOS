import Foundation
import SwiftSignalKit
import MtProtoKit

/// A history fill re-sends its request after a transient error 0.2 s later than the time before, at most
/// 5 s apart: the values of `retryRequest` and of the fill's own confirmation (`confirmStoredMessages`).
private let historyFillRequestRetryDelayIncrement: Double = 0.2
private let historyFillRequestRetryMaxDelay: Double = 5.0

/// A fill request that keeps failing with transient errors is logged on its first failure and once more
/// past this many, so one that never succeeds can be told from a slow one. It is still retried.
private let historyFillRequestFailureLogThreshold = 10

/// Whether `error`, the answer to a history fill's own request, is a definite answer (owner decision D4,
/// 2026-10-15; audit Q15). A definite answer closes nothing and is not retried:
/// - `CHANNEL_PRIVATE`, under any code: the account can no longer read the chat. Before D4 only a thread fill
///   held it back from its retry, and that retry never ran anyway (`maxRetries: 0`), so no fill retries it now
///   and none did before.
/// - an answer this build cannot read, under any code: `TL_VERIFICATION_ERROR` (`Network.request`, an answer
///   of another type than the function's), `TL_PARSING_ERROR` (an `rpc_result` the engine cannot parse) and
///   any other `TL_` text, read by its prefix as `networkFailureClass` reads it. The same build reads the same
///   answer the same way, so retrying cannot fix it, and a build that does not know a new constructor would
///   otherwise ask again forever.
/// - every other 4xx except a flood wait: `PEER_ID_INVALID`, `CHANNEL_INVALID`, `MSG_ID_INVALID`, the 420
///   `FROZEN_METHOD_INVALID`, and the logout-type 401/406 answers, which the session handles itself.
///
/// Everything else is transient and is retried until the request succeeds: a 5xx (`-500` and
/// `ENGINE_SWITCHED` included), a flood wait (`FLOOD_WAIT_*`, `FLOOD_PREMIUM_WAIT_*`, under any code; with
/// `automaticFloodWait` the engine normally waits those out itself and never hands them back), and any code
/// outside 400...499.
///
/// A fill that meets a definite answer ends with nil, which `ManagedMessageHistoryHoles` answers as any nil: it
/// starts the fill again after its 20-s pause while a view still shows the hole.
func historyFillRequestErrorIsDefinite(_ error: MTRpcError) -> Bool {
    let text = error.errorDescription ?? ""
    if text.hasPrefix("TL_") {
        return true
    }
    if text.hasPrefix("FLOOD_") {
        return false
    }
    if text == "CHANNEL_PRIVATE" {
        return true
    }
    return error.errorCode >= 400 && error.errorCode < 500
}

/// `request`, a history fill's own request, as the fill sends it (owner decision D4, 2026-10-15): a
/// transient error is retried until the request succeeds, 0.2 s later each time and at most 5 s apart, and
/// is never given up; its first failure and the one past `historyFillRequestFailureLogThreshold` are
/// logged. A definite answer (`historyFillRequestErrorIsDefinite`) is logged and becomes nil, which closes
/// nothing. `describe` names the fill in the log and runs only when a line is logged.
func historyFillRequestRetryingTransientErrors<T>(_ request: Signal<T, MTRpcError>, describe: @escaping () -> String) -> Signal<T?, NoError> {
    let failureCount = Atomic<Int>(value: 0)
    return request
    |> `catch` { error -> Signal<T, MTRpcError> in
        let count = failureCount.modify { $0 + 1 }
        if !historyFillRequestErrorIsDefinite(error) && (count == 1 || count == historyFillRequestFailureLogThreshold + 1) {
            Logger.shared.log("fetchMessageHistoryHole", "\(describe()): \(error.errorCode) \(error.errorDescription ?? ""), failure \(count); retrying")
        }
        return .fail(error)
    }
    |> retry(retryOnError: { error in
        return !historyFillRequestErrorIsDefinite(error)
    }, delayIncrement: historyFillRequestRetryDelayIncrement, maxDelay: historyFillRequestRetryMaxDelay, maxRetries: nil, onQueue: .concurrentDefaultQueue())
    |> map { value -> T? in
        return value
    }
    |> `catch` { error -> Signal<T?, NoError> in
        Logger.shared.log("fetchMessageHistoryHole", "\(describe()): \(error.errorCode) \(error.errorDescription ?? ""), a definite answer; closing nothing")
        return .single(nil)
    }
}
