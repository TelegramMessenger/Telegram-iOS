import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit
import MonotonicTime

// How it works:
// Allowed [threshold] attempts per [duration] seconds.
// [counter] - number of failed/missed attempts.
// [firstMissUptime] - system uptime of first failure/miss (when counter becomes 1).
// System uptime is the only reliable time measure available all the time. But we have to deal with situations when device is rebooted. Therefore timestamp in Telegram server responses is also used as secondary trusted time source. It is stored in [firstMissTrustedTimestamp].
// When firstMissTime + duration goes to past, counter is reset to 0, and firstMissTime is reset to nil.
// In case of creation of new passcode or changing existing to new one, counter is also increased because in this case passcodes are also checked whether they already exist. That's why it is better called a miss rather than a failure.
// To further protect from brute-force attacks, multiple counters are used, each with its own threshould and duration. Passcode check is allowed only if all of them have not reached threshold. This allows enough attempts in short time, and not so much in longer periods if failures/misses continue.

private struct PtgPasscodeAttemptItem: Codable, Equatable {
    let threshold: Int32
    let duration: Int32
    var counter: Int32
    var firstMissUptime: Int32?
    var firstMissTrustedTimestamp: TimeInterval?
    
    public init(threshold: Int32, duration: Int32) {
        self.threshold = threshold
        self.duration = duration
        self.counter = 0
        self.firstMissUptime = nil
        self.firstMissTrustedTimestamp = nil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.threshold = try container.decode(Int32.self, forKey: "t")
        self.duration = try container.decode(Int32.self, forKey: "d")
        self.counter = try container.decode(Int32.self, forKey: "c")
        self.firstMissUptime = try container.decodeIfPresent(Int32.self, forKey: "fmu")
        self.firstMissTrustedTimestamp = try container.decodeIfPresent(TimeInterval.self, forKey: "fmtt")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.threshold, forKey: "t")
        try container.encode(self.duration, forKey: "d")
        try container.encode(self.counter, forKey: "c")
        try container.encodeIfPresent(self.firstMissUptime, forKey: "fmu")
        try container.encodeIfPresent(self.firstMissTrustedTimestamp, forKey: "fmtt")
    }
}

private struct PtgPasscodeAttempts: Codable, Equatable {
    let items: [PtgPasscodeAttemptItem]
    
    public init(items: [PtgPasscodeAttemptItem]) {
        self.items = items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.items = try container.decode([PtgPasscodeAttemptItem].self, forKey: "i")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.items, forKey: "i")
    }
}

private class PasscodeAttemptAccounterItem {
    private(set) var data: PtgPasscodeAttemptItem
    
    init(threshold: Int32, duration: Int32) {
        assert(threshold > 0 && duration > 0)
        self.data = PtgPasscodeAttemptItem(threshold: threshold, duration: duration)
    }
    
    func restore(_ item: PtgPasscodeAttemptItem) {
        assert(self.data.threshold == item.threshold)
        assert(self.data.duration == item.duration)
        self.data.counter = item.firstMissUptime == nil ? 0 : item.counter
        self.data.firstMissUptime = item.counter == 0 ? nil : item.firstMissUptime
        self.data.firstMissTrustedTimestamp = (item.counter == 0 || item.firstMissUptime == nil) ? nil : item.firstMissTrustedTimestamp
    }
    
    // must be called before every passcode check
    // returns nil if check is allowed, or number of seconds to wait before it should be allowed
    func preAttempt(trustedTimestamp: () -> TimeInterval?) -> (waitTime: Int32?, modified: Bool) {
        if self.data.counter > 0 {
            assert(self.data.firstMissUptime != nil)
            
            var modified = false
            let uptime = getDeviceUptimeSeconds(nil)
            
            if uptime < self.data.firstMissUptime! {
                // device was rebooted, can only confidently measure since system start
                self.data.firstMissUptime = 0
                modified = true
            }
            
            var waitTime = self.data.firstMissUptime! + self.data.duration - uptime
            
            if waitTime > 0, let trustedTimestamp = trustedTimestamp() {
                if self.data.firstMissTrustedTimestamp != nil {
                    waitTime = min(waitTime, Int32(self.data.firstMissTrustedTimestamp! + Double(self.data.duration) - trustedTimestamp))
                } else {
                    self.data.firstMissTrustedTimestamp = trustedTimestamp
                    modified = true
                }
            }
            
            if waitTime > 0 {
                return (self.data.counter < self.data.threshold ? nil : waitTime, modified)
            } else {
                self.data.counter = 0
                self.data.firstMissUptime = nil
                self.data.firstMissTrustedTimestamp = nil
                return (nil, true)
            }
        } else {
            assert(self.data.firstMissUptime == nil)
            assert(self.data.firstMissTrustedTimestamp == nil)
            return (nil, false)
        }
    }
    
    // must be called after passcode check, if passcode is not found among existing ones
    func attemptMissed(trustedTimestamp: () -> TimeInterval?) {
        self.data.counter += 1
        if self.data.counter == 1 {
            assert(self.data.firstMissUptime == nil)
            assert(self.data.firstMissTrustedTimestamp == nil)
            self.data.firstMissUptime = getDeviceUptimeSeconds(nil)
            self.data.firstMissTrustedTimestamp = trustedTimestamp()
        } else {
            assert(self.data.firstMissUptime != nil)
        }
    }
}

public class PasscodeAttemptAccounter {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let trustedTimestamp: () -> TimeInterval?
    
    private let items: [PasscodeAttemptAccounterItem] = [
        .init(threshold: 5, duration: 60 * 10),         // 5 attempts per 10 min
        .init(threshold: 10, duration: 60 * 60),        // 10 attempts per 1 hour
        .init(threshold: 15, duration: 60 * 60 * 6),    // 15 attempts per 6 hours
        .init(threshold: 20, duration: 60 * 60 * 24),   // 20 attempts per 24 hours
    ]
    
    public init(accountManager: AccountManager<TelegramAccountManagerTypes>, trustedTimestamp: @escaping () -> TimeInterval?) {
        self.accountManager = accountManager
        self.trustedTimestamp = trustedTimestamp
        
        let _ = (accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.ptgPasscodeAttempts])
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self, let ptgPasscodeAttempts = sharedData.entries[ApplicationSpecificSharedDataKeys.ptgPasscodeAttempts]?.get(PtgPasscodeAttempts.self) {
                for item in strongSelf.items {
                    if let loadedItem = ptgPasscodeAttempts.items.first(where: { $0.threshold == item.data.threshold && $0.duration == item.data.duration }) {
                        item.restore(loadedItem)
                    }
                }
            }
        })
    }
    
    private func save() {
        let ptgPasscodeAttempts = PtgPasscodeAttempts(items: self.items.map { $0.data })
        let _ = self.accountManager.transaction({ transaction in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.ptgPasscodeAttempts, { _ in
                return PreferencesEntry(ptgPasscodeAttempts)
            })
        }).start()
    }
    
    public func preAttempt() -> Int32? {
        assert(Queue.mainQueue().isCurrent())
        let results = self.items.map { $0.preAttempt(trustedTimestamp: self.trustedTimestamp) }
        if results.contains(where: { $0.modified }) {
            self.save()
        }
        return results.max(by: { $0.waitTime ?? 0 < $1.waitTime ?? 0 })?.waitTime
    }
    
    public func attemptMissed() {
        assert(Queue.mainQueue().isCurrent())
        self.items.forEach { $0.attemptMissed(trustedTimestamp: self.trustedTimestamp) }
        self.save()
    }
}
