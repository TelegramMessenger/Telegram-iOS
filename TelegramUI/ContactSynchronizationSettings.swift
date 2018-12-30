import Foundation
import Postbox
import SwiftSignalKit

public enum ContactsSortOrder: Int32 {
    case presence
    case natural
}

public struct ContactSynchronizationSettings: Equatable, PreferencesEntry {
    public var synchronizeDeviceContacts: Bool
    public var nameDisplayOrder: PresentationPersonNameOrder
    public var sortOrder: ContactsSortOrder
    
    public static var defaultSettings: ContactSynchronizationSettings {
        return ContactSynchronizationSettings(synchronizeDeviceContacts: true, nameDisplayOrder: .firstLast, sortOrder: .presence)
    }
    
    public init(synchronizeDeviceContacts: Bool, nameDisplayOrder: PresentationPersonNameOrder, sortOrder: ContactsSortOrder) {
        self.synchronizeDeviceContacts = synchronizeDeviceContacts
        self.nameDisplayOrder = nameDisplayOrder
        self.sortOrder = sortOrder
    }
    
    public init(decoder: PostboxDecoder) {
        self.synchronizeDeviceContacts = decoder.decodeInt32ForKey("synchronizeDeviceContacts", orElse: 0) != 0
        self.nameDisplayOrder = PresentationPersonNameOrder(rawValue: decoder.decodeInt32ForKey("nameDisplayOrder", orElse: 0)) ?? .firstLast
        self.sortOrder = ContactsSortOrder(rawValue: decoder.decodeInt32ForKey("sortOrder", orElse: 0)) ?? .presence
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.synchronizeDeviceContacts ? 1 : 0, forKey: "synchronizeDeviceContacts")
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

func updateContactSettingsInteractively(postbox: Postbox, _ f: @escaping (ContactSynchronizationSettings) -> ContactSynchronizationSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.contactSynchronizationSettings, { entry in
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
