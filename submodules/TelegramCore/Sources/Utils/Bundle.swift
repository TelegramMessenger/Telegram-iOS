import Foundation

@objc // to avoid Undefined symbols (extension in TelegramCore):__C.NSBundle.*.getter : Swift.String
public extension Bundle {
    var appVersion: String {
        return (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    var appBuildNumber: String {
        return (infoDictionary?[kCFBundleVersionKey as String] as? String) ?? "unknown"
    }

    var originalVersion: String {
        return (infoDictionary?["TelegramOriginalVersion"] as? String) ?? "unknown"
    }
    
    #if targetEnvironment(simulator)
    static let isTestFlightOrDevelopment: Bool = true
    #else
    // also will be true for builds installed locally on device during development
    static let isTestFlightOrDevelopment: Bool = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #endif
}
