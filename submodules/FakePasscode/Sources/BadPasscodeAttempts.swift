import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

public struct BadPasscodeAttempt: Codable, Equatable {
    public static let AppUnlockType: Int32 = 0
    public static let PasscodeSettingsType: Int32 = 1
    
    public let type: Int32
    public let isFakePasscode: Bool
    public let date: CFAbsoluteTime
    
    public init(type: Int32, isFakePasscode: Bool, date: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) {
        self.type = type
        self.isFakePasscode = isFakePasscode
        self.date = date
    }
}

public struct BadPasscodeAttempts: Codable, Equatable {
    public let badPasscodeAttempts: [BadPasscodeAttempt]
    
    public static var defaultSettings: BadPasscodeAttempts {
        return BadPasscodeAttempts(badPasscodeAttempts: [])
    }
    
    public init(badPasscodeAttempts: [BadPasscodeAttempt]) {
        self.badPasscodeAttempts = badPasscodeAttempts
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.badPasscodeAttempts = try container.decode([BadPasscodeAttempt].self, forKey: "bpa")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.badPasscodeAttempts, forKey: "bpa")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(BadPasscodeAttempts.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.badPasscodeAttempts)
        self.init(entry)
    }
    
    public static func ==(lhs: BadPasscodeAttempts, rhs: BadPasscodeAttempts) -> Bool {
        return lhs.badPasscodeAttempts == rhs.badPasscodeAttempts
    }
    
    public func withUpdatedBadPasscodeAttempts(_ badPasscodeAttempts: [BadPasscodeAttempt]) -> BadPasscodeAttempts {
        return BadPasscodeAttempts(badPasscodeAttempts: badPasscodeAttempts)
    }
}

public func updateBadPasscodeAttemptsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (BadPasscodeAttempts) -> BadPasscodeAttempts) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateBadPasscodeAttemptsInternal(transaction: transaction, f)
    }
}

public func updateBadPasscodeAttemptsInternal(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (BadPasscodeAttempts) -> BadPasscodeAttempts) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.badPasscodeAttempts, { entry in
        let currentSettings = BadPasscodeAttempts(entry)
        return PreferencesEntry(f(currentSettings))
    })
}

public func addBadPasscodeAttempt(accountManager: AccountManager<TelegramAccountManagerTypes>, bpa: BadPasscodeAttempt) {
    let _ = updateBadPasscodeAttemptsInteractively(accountManager: accountManager, { bpas in
        var badPasscodeAttempts = bpas.badPasscodeAttempts
        let removeBeforeDate = CFAbsoluteTimeGetCurrent() - 30 * 24 * 60 * 60 // remove records older than 30 days
        badPasscodeAttempts.removeAll(where: { $0.date < removeBeforeDate })
        badPasscodeAttempts.append(bpa)
        return bpas.withUpdatedBadPasscodeAttempts(badPasscodeAttempts)
    }).start()
}
