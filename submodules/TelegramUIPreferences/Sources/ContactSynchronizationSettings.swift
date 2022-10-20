import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum ContactsSortOrder: Int32 {
    case presence
    case natural
}

public enum PresentationPersonNameOrder: Int32 {
    case firstLast = 0
    case lastFirst = 1
}

public struct ContactSynchronizationSettings: Equatable, Codable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self._legacySynchronizeDeviceContacts = (try container.decode(Int32.self, forKey: "synchronizeDeviceContacts")) != 0
        self.nameDisplayOrder = PresentationPersonNameOrder(rawValue: try container.decode(Int32.self, forKey: "nameDisplayOrder")) ?? .firstLast
        self.sortOrder = ContactsSortOrder(rawValue: try container.decode(Int32.self, forKey: "sortOrder")) ?? .presence
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self._legacySynchronizeDeviceContacts ? 1 : 0) as Int32, forKey: "synchronizeDeviceContacts")
        try container.encode(self.nameDisplayOrder.rawValue, forKey: "nameDisplayOrder")
        try container.encode(self.sortOrder.rawValue, forKey: "sortOrder")
    }
}

public func updateContactSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ContactSynchronizationSettings) -> ContactSynchronizationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.contactSynchronizationSettings, { entry in
            let currentSettings: ContactSynchronizationSettings
            if let entry = entry?.get(ContactSynchronizationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
