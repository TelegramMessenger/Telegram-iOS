import Foundation
import Postbox
import SwiftSignalKit

public struct ContactSynchronizationSettings: Equatable, PreferencesEntry {
    public var synchronizeDeviceContacts: Bool
    public var nameDisplayOrder: PresentationPersonNameOrder
    
    public static var defaultSettings: ContactSynchronizationSettings {
        return ContactSynchronizationSettings(synchronizeDeviceContacts: true, nameDisplayOrder: .firstLast)
    }
    
    public init(synchronizeDeviceContacts: Bool, nameDisplayOrder: PresentationPersonNameOrder) {
        self.synchronizeDeviceContacts = synchronizeDeviceContacts
        self.nameDisplayOrder = nameDisplayOrder
    }
    
    public init(decoder: PostboxDecoder) {
        self.synchronizeDeviceContacts = decoder.decodeInt32ForKey("synchronizeDeviceContacts", orElse: 0) != 0
        self.nameDisplayOrder = PresentationPersonNameOrder(rawValue: decoder.decodeInt32ForKey("nameDisplayOrder", orElse: 0)) ?? .firstLast
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.synchronizeDeviceContacts ? 1 : 0, forKey: "synchronizeDeviceContacts")
        encoder.encodeInt32(self.nameDisplayOrder.rawValue, forKey: "synchronizeDeviceContacts")
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
