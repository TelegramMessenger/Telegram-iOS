import Foundation

public enum CameraBatchAppendResult: Equatable {
    case appended(opensReview: Bool)
    case refused
}

public enum CameraBatchCancelAction: Equatable {
    case dismiss
    case confirmDiscard
}

public func cameraBatchCapacity(maxCount: Int, isSingleShot: Bool) -> Int {
    return isSingleShot ? 1 : max(1, maxCount)
}

public func cameraBatchAcceptsCapture(count: Int, maxCount: Int, isSingleShot: Bool) -> Bool {
    return count < cameraBatchCapacity(maxCount: maxCount, isSingleShot: isSingleShot)
}

public func cameraBatchOpensReview(count: Int, isSingleShot: Bool) -> Bool {
    guard count > 0 else {
        return false
    }
    if isSingleShot {
        return true
    }
    return count == 1 || count % 10 == 0
}

public enum CameraBatchReviewRequest: Equatable {
    case open
    case deferUntilRecordingStops
}

public func cameraBatchReviewRequest(isRecording: Bool) -> CameraBatchReviewRequest {
    return isRecording ? .deferUntilRecordingStops : .open
}

public func cameraBatchOpensDeferredReview(hasDeferredReview: Bool, isRecording: Bool, pendingCount: Int) -> Bool {
    return hasDeferredReview && !isRecording && pendingCount == 0
}

public func cameraBatchCancelAction(count: Int, pendingCount: Int) -> CameraBatchCancelAction {
    return count + pendingCount > 0 ? .confirmDiscard : .dismiss
}

public func cameraBatchAllowsInteractiveDismiss(count: Int, pendingCount: Int) -> Bool {
    return count + pendingCount == 0
}

public enum CameraBatchReviewPresentation: Equatable {
    case opened
    case deferred
    case unavailable
}

public func cameraBatchChromeCount(count: Int, heldCount: Int?) -> Int {
    guard let heldCount else {
        return count
    }
    return min(heldCount, count)
}

public func cameraBatchKeepsChromeHold(opensReview: Bool, presentation: CameraBatchReviewPresentation) -> Bool {
    guard opensReview else {
        return false
    }
    switch presentation {
    case .opened, .deferred:
        return true
    case .unavailable:
        return false
    }
}

public enum CameraBatchPanDismissOutcome: Equatable {
    case dismiss
    case confirmDiscard
    case snapBack
}

public func cameraBatchPanDismissOutcome(count: Int, pendingCount: Int, completes: Bool) -> CameraBatchPanDismissOutcome {
    guard completes else {
        return .snapBack
    }
    return cameraBatchAllowsInteractiveDismiss(count: count, pendingCount: pendingCount) ? .dismiss : .confirmDiscard
}

public struct CameraBatchList<Payload> {
    public struct Entry {
        public let id: String
        public let payload: Payload
    }

    public let maxCount: Int
    public let isSingleShot: Bool
    public private(set) var entries: [Entry] = []
    public private(set) var pendingCount = 0
    public private(set) var isClosed = false

    public init(maxCount: Int, isSingleShot: Bool) {
        self.maxCount = maxCount
        self.isSingleShot = isSingleShot
    }

    public var count: Int {
        return self.entries.count
    }

    public var hasContent: Bool {
        return self.entries.count + self.pendingCount > 0
    }

    public var acceptsCapture: Bool {
        return !self.isClosed && cameraBatchAcceptsCapture(count: self.entries.count + self.pendingCount, maxCount: self.maxCount, isSingleShot: self.isSingleShot)
    }

    public mutating func beginPending() {
        self.pendingCount += 1
    }

    public mutating func endPending() {
        self.pendingCount = max(0, self.pendingCount - 1)
    }

    public mutating func close() -> [Payload] {
        self.isClosed = true
        return self.removeAll()
    }

    public mutating func append(id: String, payload: Payload) -> CameraBatchAppendResult {
        guard !self.isClosed, cameraBatchAcceptsCapture(count: self.entries.count, maxCount: self.maxCount, isSingleShot: self.isSingleShot), !self.entries.contains(where: { $0.id == id }) else {
            return .refused
        }
        self.entries.append(Entry(id: id, payload: payload))
        return .appended(opensReview: cameraBatchOpensReview(count: self.entries.count, isSingleShot: self.isSingleShot))
    }

    public mutating func remove(id: String) -> Payload? {
        guard let index = self.entries.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return self.entries.remove(at: index).payload
    }

    public mutating func removeAll() -> [Payload] {
        let payloads = self.entries.map { $0.payload }
        self.entries.removeAll()
        return payloads
    }
}
