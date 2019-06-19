import Foundation
import Postbox
import SwiftSignalKit

public enum ContactsSortOrder: Int32 {
    case presence
    case natural
}

public enum PresentationPersonNameOrder: Int32 {
    case firstLast = 0
    case lastFirst = 1
}

public struct ContactSynchronizationSettings: Equatable, PreferencesEntry {
    public var _legacySynchronizeDeviceContacts: Bool
    public var nameDisplayOrder: PresentationPersonNameOrder
    public var sortOrder: ContactsSortOrder
    
    public static var defaultSettings: ContactSynchronizationSettings {
        return ContactSynchronizationSettings(_legacySynchronizeDeviceContacts: true, nameDisplayOrder: .firstLast, sortOrder: .presence)
    }
    
    public init(_legacySynchronizeDeviceContacts: Bool, nameDisplayOrder: PresentationPersonNameOrder, sortOrder: ContactsSortOrder) {
        self._legacySynchronizeDeviceContacts = _legacySynchronizeDeviceContacts
        self.nameDisplayOrder = nameDisplayOrder
        self.sortOrder = sortOrder
    }
    
    public init(decoder: PostboxDecoder) {
        self._legacySynchronizeDeviceContacts = decoder.decodeInt32ForKey("synchronizeDeviceContacts", orElse: 0) != 0
        self.nameDisplayOrder = PresentationPersonNameOrder(rawValue: decoder.decodeInt32ForKey("nameDisplayOrder", orElse: 0)) ?? .firstLast
        self.sortOrder = ContactsSortOrder(rawValue: decoder.decodeInt32ForKey("sortOrder", orElse: 0)) ?? .presence
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self._legacySynchronizeDeviceContacts ? 1 : 0, forKey: "synchronizeDeviceContacts")
        encoder.encodeInt32(self.nameDisplayOrder.rawValue, forKey: "nameDisplayOrder")
        encoder.encodeInt32(self.sortOrder.rawValue, forKey: "sortOrder")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ContactSynchronizationSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateContactSettingsInteractively(accountManager: AccountManager, _ f: @escaping (ContactSynchronizationSettings) -> ContactSynchronizationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.contactSynchronizationSettings, { entry in
            let currentSettings: ContactSynchronizationSettings
            if let entry = entry as? ContactSynchronizationSettings {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return f(currentSettings)
        })
    }
}
