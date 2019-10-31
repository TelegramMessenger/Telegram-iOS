import Foundation
import SwiftSignalKit
import TelegramCore
import SyncCore
import SyncCore

private func suggestedUserPresenceStringRefreshTimeout(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> Double {
    switch presence.status {
    case let .present(statusTimestamp):
        if statusTimestamp >= timestamp {
            return Double(statusTimestamp - timestamp)
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
    case .recently:
        let activeUntil = presence.lastActivity + 30
        if activeUntil >= timestamp {
            return Double(activeUntil - timestamp + 1)
        } else {
            return Double.infinity
        }
    case .none, .lastWeek, .lastMonth:
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
    
    public func reset(presence: TelegramUserPresence) {
        self.timer?.invalidate()
        self.timer = nil
        
        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        let timeout = suggestedUserPresenceStringRefreshTimeout(presence, relativeTo: Int32(timestamp))
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
