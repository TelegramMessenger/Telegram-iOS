import Foundation

struct App {
    
    @BundleVariable(key: "CFBundleShortVersionString", defaultValue: "")
    static var appVersionNumber: String
    
    @BundleVariable(key: "CFBundleVersion", defaultValue: "")
    static var appBuildNumber: String
    
    static var appLanguageCode: String? { return Locale.current.languageCode }
}

@propertyWrapper
struct BundleVariable<T> {
    private let key: String
    private let defaultValue: T
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        return Bundle.main.object(forInfoDictionaryKey: key) as? T ?? defaultValue
    }
}
