import Foundation

public protocol TelegramAuthSessionStorage {
    func saveSession(_: TelegramAuthSession?)
    func getSession() -> TelegramAuthSession?
}

public class TelegramAuthSessionUserDefaultsStorage {
    
    //  MARK: - Dependencies
    
    private let userDefaults: UserDefaults
    
    //  MARK: - Constants
    
    private let key: String
   
    //  MARK: - Lifecycle
    
    public init(userDefaults: UserDefaults = .standard, key: String = "TelegramAuthSessionUserDefaultsStorage") {
        self.userDefaults = userDefaults
        self.key = key
    }
}

extension TelegramAuthSessionUserDefaultsStorage: TelegramAuthSessionStorage {
    public func saveSession(_ session: TelegramAuthSession?) {
        userDefaults.set(session?.id, forKey: key)
    }

    public func getSession() -> TelegramAuthSession? {
        guard let id = userDefaults.string(forKey: key) else {
            return nil
        }
        return TelegramAuthSession(id: id)
    }
}


