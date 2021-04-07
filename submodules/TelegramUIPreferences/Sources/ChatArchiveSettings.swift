import Foundation
import Postbox
import SwiftSignalKit

public struct ChatArchiveSettings: Equatable, PreferencesEntry {
    public var isHiddenByDefault: Bool
    public var hiddenPsaPeerId: PeerId?
    
    public static var `default`: ChatArchiveSettings {
        return ChatArchiveSettings(isHiddenByDefault: false, hiddenPsaPeerId: nil)
    }
    
    public init(isHiddenByDefault: Bool, hiddenPsaPeerId: PeerId?) {
        self.isHiddenByDefault = isHiddenByDefault
        self.hiddenPsaPeerId = hiddenPsaPeerId
    }
    
    public init(decoder: PostboxDecoder) {
        self.isHiddenByDefault = decoder.decodeInt32ForKey("isHiddenByDefault", orElse: 1) != 0
        self.hiddenPsaPeerId = decoder.decodeOptionalInt64ForKey("hiddenPsaPeerId").flatMap(PeerId.init)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isHiddenByDefault ? 1 : 0, forKey: "isHiddenByDefault")
        if let hiddenPsaPeerId = self.hiddenPsaPeerId {
            encoder.encodeInt64(hiddenPsaPeerId.toInt64(), forKey: "hiddenPsaPeerId")
        } else {
            encoder.encodeNil(forKey: "hiddenPsaPeerId")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatArchiveSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateChatArchiveSettings(transaction: Transaction, _ f: @escaping (ChatArchiveSettings) -> ChatArchiveSettings) {
    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatArchiveSettings, { entry in
        let currentSettings: ChatArchiveSettings
        if let entry = entry as? ChatArchiveSettings {
            currentSettings = entry
        } else {
            currentSettings = .default
        }
        return f(currentSettings)
    })
}
