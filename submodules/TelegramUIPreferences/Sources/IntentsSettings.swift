import Foundation
import Postbox
import SwiftSignalKit

public struct IntentsSettings: PreferencesEntry, Equatable {
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
    
    public init(decoder: PostboxDecoder) {
        self.initiallyReset = decoder.decodeBoolForKey("initiallyReset_v1", orElse: false)
        self.account = decoder.decodeOptionalInt64ForKey("account").flatMap { PeerId($0) }
        self.contacts = decoder.decodeBoolForKey("contacts", orElse: true)
        self.privateChats = decoder.decodeBoolForKey("privateChats", orElse: false)
        self.savedMessages = decoder.decodeBoolForKey("savedMessages", orElse: true)
        self.groups = decoder.decodeBoolForKey("groups", orElse: false)
        self.onlyShared = decoder.decodeBoolForKey("onlyShared", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.initiallyReset, forKey: "initiallyReset_v1")
        if let account = self.account {
            encoder.encodeInt64(account.toInt64(), forKey: "account")
        } else {
            encoder.encodeNil(forKey: "account")
        }
        encoder.encodeBool(self.contacts, forKey: "contacts")
        encoder.encodeBool(self.privateChats, forKey: "privateChats")
        encoder.encodeBool(self.savedMessages, forKey: "savedMessages")
        encoder.encodeBool(self.groups, forKey: "groups")
        encoder.encodeBool(self.onlyShared, forKey: "onlyShared")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? IntentsSettings {
            return self == to
        } else {
            return false
        }
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


public func updateIntentsSettingsInteractively(accountManager: AccountManager, _ f: @escaping (IntentsSettings) -> IntentsSettings) -> Signal<(IntentsSettings?, IntentsSettings?), NoError> {
    return accountManager.transaction { transaction -> (IntentsSettings?, IntentsSettings?) in
        var previousSettings: IntentsSettings? = nil
        var updatedSettings: IntentsSettings? = nil
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.intentsSettings, { entry in
            let currentSettings: IntentsSettings
            if let entry = entry as? IntentsSettings {
                currentSettings = entry
            } else {
                currentSettings = IntentsSettings.defaultSettings
            }
            previousSettings = currentSettings
            updatedSettings = f(currentSettings)
            return updatedSettings
        })
        return (previousSettings, updatedSettings)
    }
}
