import Foundation
import SwiftSignalKit
import TelegramCore

final class PeerPresenceStatusManager {
    private let update: () -> Void
    private var timer: SwiftSignalKit.Timer?
    
    init(update: @escaping () -> Void) {
        self.update = update
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func reset(presence: TelegramUserPresence) {
        self.timer?.invalidate()
        self.timer = nil
        
        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        let timeout = userPresenceStringRefreshTimeout(presence, relativeTo: Int32(timestamp))
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
