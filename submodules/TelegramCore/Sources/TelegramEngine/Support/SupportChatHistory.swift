import Foundation
import Postbox

let supportChatHistoryLimit = 50

struct SupportChatHistory: Equatable {
    private(set) var peerIds: [PeerId] = []
    private(set) var position: Int = -1

    mutating func push(peerId: PeerId) {
        if self.position >= 0 && self.peerIds[self.position] == peerId {
            return
        }
        self.peerIds.removeLast(self.peerIds.count - self.position - 1)
        self.peerIds.removeAll(where: { $0 == peerId })
        self.peerIds.append(peerId)
        self.position = self.peerIds.count - 1
        if self.peerIds.count > supportChatHistoryLimit {
            self.peerIds.removeFirst()
            self.position -= 1
        }
    }

    func target(steps: Int) -> PeerId? {
        let position = self.position + steps
        guard !self.peerIds.isEmpty, position >= 0, position < self.peerIds.count else {
            return nil
        }
        return self.peerIds[position]
    }

    mutating func move(steps: Int) {
        if self.target(steps: steps) != nil {
            self.position += steps
        }
    }
}

public enum SupportHardwareKey: Hashable {
    case chatHistory
    case toggleMuted
    case reloadTemplates
    case composerReturn
    case escape
    case openAbuseBot

    var quietGap: Double {
        switch self {
        case .chatHistory, .escape:
            return 0.25
        case .toggleMuted, .reloadTemplates, .composerReturn, .openAbuseBot:
            return 0.8
        }
    }
}

// UIKit reports a held key as more presses and has no way to tell them apart before iOS 26, so a press
// counts only after a quiet gap, and every press restarts the gap. Holding Return must not walk the chats.
struct SupportHardwareKeyGate {
    private var lastPresses: [SupportHardwareKey: Double] = [:]

    mutating func allowsPress(of key: SupportHardwareKey, at timestamp: Double) -> Bool {
        let previous = self.lastPresses.updateValue(timestamp, forKey: key)
        guard let previous else {
            return true
        }
        return timestamp - previous >= key.quietGap
    }
}
