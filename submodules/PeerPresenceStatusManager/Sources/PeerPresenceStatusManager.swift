import Foundation
import SwiftSignalKit
import TelegramCore

private func suggestedUserPresenceStringRefreshTimeout(_ presence: EnginePeer.Presence, relativeTo timestamp: Int32, isOnline: Bool?) -> Double {
    switch presence.status {
    case let .present(statusTimestamp):
        if statusTimestamp >= timestamp {
            return Double(statusTimestamp - timestamp)
        } else {
            if let isOnline = isOnline, isOnline {
                return 1.0
            } else {
                let difference = timestamp - statusTimestamp
                if difference < 30 {
                    return Double((30 - difference) + 1)
                } else if difference < 60 * 60 {
                    return Double((difference % 60) + 1)
                } else {
                    return Double.infinity
                }
            }
        }
    case .recently:
        let activeUntil = presence.lastActivity + 30
        if activeUntil >= timestamp {
            return Double(activeUntil - timestamp + 1)
        } else {
            return Double.infinity
        }
    case .longTimeAgo, .lastWeek, .lastMonth:
        return Double.infinity
    }
}

public final class PeerPresenceStatusManager {
    private let update: () -> Void
    private var timer: SwiftSignalKit.Timer?
    
    public init(update: @escaping () -> Void) {
        self.update = update
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    public func reset(presence: EnginePeer.Presence, isOnline: Bool? = nil) {
        self.timer?.invalidate()
        self.timer = nil
        
        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        let timeout = suggestedUserPresenceStringRefreshTimeout(presence, relativeTo: Int32(timestamp), isOnline: isOnline)
        if timeout.isFinite {
            self.timer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.update()
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
}
