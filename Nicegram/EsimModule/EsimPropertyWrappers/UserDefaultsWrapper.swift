import Foundation

@propertyWrapper
public struct UserDefaultsWrapper<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let userDefaults: UserDefaults
    
    public init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    public var wrappedValue: T {
        get {
            if let data = userDefaults.data(forKey: key),
               let value = try? JSONDecoder().decode(T.self, from: data) {
                return value
            } else {
                return defaultValue
            }
        } set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.setValue(data, forKey: key)
        }
    }
}
