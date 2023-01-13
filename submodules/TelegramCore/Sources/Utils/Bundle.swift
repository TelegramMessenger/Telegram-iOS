import Foundation

@objc // to avoid Undefined symbols (extension in TelegramCore):__C.NSBundle.*.getter : Swift.String
public extension Bundle {
    var appVersion: String {
        return (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    var appBuildNumber: String {
        return (infoDictionary?[kCFBundleVersionKey as String] as? String) ?? "unknown"
    }

    var ptgVersion: String {
        return (infoDictionary?["PTelegramVersion"] as? String) ?? "unknown"
    }
}
