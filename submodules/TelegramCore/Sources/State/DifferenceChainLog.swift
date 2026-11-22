import Foundation
internal import TelegramApi

/// What the `State` log reports about one getDifference chain of the main app's poll cycle, to tune
/// `pts_total_limit` later (spec section 5 of the differenceTooLong design). It only logs: nothing reads it
/// to decide anything. Kept on the state manager's queue.
struct DifferenceChainLog {
    let startPts: Int32
    let startTime: Double
    private(set) var lastRequestPts: Int32
    private(set) var requestCount: Int = 0
    private(set) var tooLongCount: Int = 0
    private(set) var tooLongGapPts: Int64 = 0

    init(startPts: Int32, startTime: Double) {
        self.startPts = startPts
        self.startTime = startTime
        self.lastRequestPts = startPts
    }

    mutating func noteRequest(pts: Int32) {
        self.lastRequestPts = pts
        self.requestCount += 1
    }

    /// A differenceTooLong answer to the last request, carrying `replyPts`. A reset that got
    /// messages.dialogsNotModified moves nothing, so the next request may ask from the same pts again.
    mutating func noteTooLong(replyPts: Int32) {
        self.tooLongCount += 1
        self.tooLongGapPts += Int64(replyPts) - Int64(self.lastRequestPts)
    }

    /// Once per chain: the pts it covered and the total time. `endPts` is nil when the chain ended without a
    /// difference: AUTH_KEY_DUPLICATED, or a poll that applied nothing and was replaced (the state changed
    /// under it; the replacing poll starts a new chain).
    func logEnd(endPts: Int32?) {
        if let endPts = endPts {
            let covered = Int64(endPts) - Int64(self.startPts)
            Logger.shared.log("State", "getDifference chain: pts \(self.startPts) -> \(endPts) (\(covered) pts), \(self.requestCount) request(s), \(self.tooLongCount) differenceTooLong (gaps \(self.tooLongGapPts) pts), \(differenceLogElapsed(since: self.startTime))")
        } else {
            Logger.shared.log("State", "getDifference chain from pts \(self.startPts) ended without a difference: \(self.requestCount) request(s), \(self.tooLongCount) differenceTooLong (gaps \(self.tooLongGapPts) pts), \(differenceLogElapsed(since: self.startTime))")
        }
    }
}

/// The time since `startTime`, formatted for a State log line. Call it inside the logged string: `Logger.log`
/// takes the string as an autoclosure and builds it only while logging is on.
private func differenceLogElapsed(since startTime: Double) -> String {
    return String(format: "%.3f s", CFAbsoluteTimeGetCurrent() - startTime)
}

/// One `State` log line per getDifference answer of the main app's poll: request pts -> new pts, what it
/// carried, slice or final, and the request's wall time; for differenceTooLong the reply's pts and the gap.
func logDifferenceAnswer(_ difference: Api.updates.Difference, requestPts: Int32, requestStartTime: Double) {
    switch difference {
    case let .difference(differenceData):
        let newPts: Int32
        switch differenceData.state {
        case let .state(stateData):
            newPts = stateData.pts
        }
        Logger.shared.log("State", "getDifference answer: pts \(requestPts) -> \(newPts), \(differenceData.newMessages.count) new messages, \(differenceData.newEncryptedMessages.count) encrypted, \(differenceData.otherUpdates.count) other updates, final, \(differenceLogElapsed(since: requestStartTime))")
    case let .differenceSlice(differenceSliceData):
        let newPts: Int32
        switch differenceSliceData.intermediateState {
        case let .state(stateData):
            newPts = stateData.pts
        }
        Logger.shared.log("State", "getDifference answer: pts \(requestPts) -> \(newPts), \(differenceSliceData.newMessages.count) new messages, \(differenceSliceData.newEncryptedMessages.count) encrypted, \(differenceSliceData.otherUpdates.count) other updates, slice, \(differenceLogElapsed(since: requestStartTime))")
    case let .differenceEmpty(differenceEmptyData):
        Logger.shared.log("State", "getDifference answer: pts \(requestPts) -> \(requestPts), empty (date \(differenceEmptyData.date), seq \(differenceEmptyData.seq)), final, \(differenceLogElapsed(since: requestStartTime))")
    case let .differenceTooLong(differenceTooLongData):
        let gap = Int64(differenceTooLongData.pts) - Int64(requestPts)
        Logger.shared.log("State", "getDifference answer: pts \(requestPts): differenceTooLong, reply pts \(differenceTooLongData.pts), gap \(gap), \(differenceLogElapsed(since: requestStartTime))")
    }
}
