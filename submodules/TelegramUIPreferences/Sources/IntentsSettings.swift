import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct IntentsSettings: Codable, Equatable {
    public let initiallyReset: Bool
    
    public let account: PeerId?
    public let contacts: Bool
    public let privateChats: Bool
    public let savedMessages: Bool
    public let groups: Bool
    public let onlyShared: Bool
    
    public static var defaultSettings: IntentsSettings {
        return IntentsSettings(initiallyReset: false, account: nil, contacts: true, privateChats: false, savedMessages: true, groups: false, onlyShared: false)
    }
    
    public init(initiallyReset: Bool, account: PeerId?, contacts: Bool, privateChats: Bool, savedMessages: Bool, groups: Bool, onlyShared: Bool) {
        self.initiallyReset = initiallyReset
        self.account = account
        self.contacts = contacts
        self.privateChats = privateChats
        self.savedMessages = savedMessages
        self.groups = groups
        self.onlyShared = onlyShared
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.initiallyReset = try container.decodeIfPresent(Bool.self, forKey: "initiallyReset_v2") ?? false
        self.account = (try container.decodeIfPresent(Int64.self, forKey: "account")).flatMap { PeerId($0) }
        self.contacts = try container.decodeIfPresent(Bool.self, forKey: "contacts") ?? true
        self.privateChats = try container.decodeIfPresent(Bool.self, forKey: "privateChats") ?? false
        self.savedMessages = try container.decodeIfPresent(Bool.self, forKey: "savedMessages") ?? true
        self.groups = try container.decodeIfPresent(Bool.self, forKey: "groups") ?? false
        self.onlyShared = try container.decodeIfPresent(Bool.self, forKey: "onlyShared") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.initiallyReset, forKey: "initiallyReset_v2")
        try container.encodeIfPresent(self.account?.toInt64(), forKey: "account")
        try container.encode(self.contacts, forKey: "contacts")
        try container.encode(self.privateChats, forKey: "privateChats")
        try container.encode(self.savedMessages, forKey: "savedMessages")
        try container.encode(self.groups, forKey: "groups")
        try container.encode(self.onlyShared, forKey: "onlyShared")
    }
    
    public static func ==(lhs: IntentsSettings, rhs: IntentsSettings) -> Bool {
        return lhs.initiallyReset == rhs.initiallyReset && lhs.account == rhs.account && lhs.contacts == rhs.contacts && lhs.privateChats == rhs.privateChats && lhs.savedMessages == rhs.savedMessages && lhs.groups == rhs.groups && lhs.onlyShared == rhs.onlyShared
    }
    
    public func withUpdatedAccount(_ account: PeerId?) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: account, contacts: self.contacts, privateChats: self.privateChats, savedMessages: self.savedMessages, groups: self.groups, onlyShared: self.onlyShared)
    }
    
    public func withUpdatedContacts(_ contacts: Bool) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: self.account, contacts: contacts, privateChats: self.privateChats, savedMessages: self.savedMessages, groups: self.groups, onlyShared: self.onlyShared)
    }
    
    public func withUpdatedPrivateChats(_ privateChats: Bool) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: self.account, contacts: self.contacts, privateChats: privateChats, savedMessages: self.savedMessages, groups: self.groups, onlyShared: self.onlyShared)
    }
    
    public func withUpdatedSavedMessages(_ savedMessages: Bool) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: self.account, contacts: self.contacts, privateChats: self.privateChats, savedMessages: savedMessages, groups: self.groups, onlyShared: self.onlyShared)
    }
    
    public func withUpdatedGroups(_ groups: Bool) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: self.account, contacts: self.contacts, privateChats: self.privateChats, savedMessages: self.savedMessages, groups: groups, onlyShared: self.onlyShared)
    }
    
    public func withUpdatedOnlyShared(_ onlyShared: Bool) -> IntentsSettings {
        return IntentsSettings(initiallyReset: self.initiallyReset, account: self.account, contacts: self.contacts, privateChats: self.privateChats, savedMessages: self.savedMessages, groups: self.groups, onlyShared: onlyShared)
    }
}


public func updateIntentsSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (IntentsSettings) -> IntentsSettings) -> Signal<(IntentsSettings?, IntentsSettings?), NoError> {
    return accountManager.transaction { transaction -> (IntentsSettings?, IntentsSettings?) in
        var previousSettings: IntentsSettings? = nil
        var updatedSettings: IntentsSettings? = nil
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.intentsSettings, { entry in
            let currentSettings: IntentsSettings
            if let entry = entry?.get(IntentsSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = IntentsSettings.defaultSettings
            }
            previousSettings = currentSettings
            updatedSettings = f(currentSettings)
            return PreferencesEntry(updatedSettings)
        })
        return (previousSettings, updatedSettings)
    }
}
