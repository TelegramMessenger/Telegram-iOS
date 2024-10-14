import Foundation
import BuildConfig

private enum Constants {
    static var isAuthorizedKey: String { "is_authorized" }
}

public final class AppReviewLogin {
    
    // Public static properties
    
    public static let shared = AppReviewLogin()
    
    // Public properties
    
    public var phoneWithCode: String? {
        guard let phone else {
            return nil
        }
        return "+999" + phone
    }
    
    public var phone: String? {
        if buildConfig.tpAppReviewerPhone == "" {
            return nil
        }
        return buildConfig.tpAppReviewerPhone
    }
    
    public var entryCode: String? {
        guard let phone, phone.count > 3 else {
            return nil
        }
        let codeChar = String(phone[2])
        
        return String(repeating: codeChar, count: 5)
    }
    
    public var isAuthorized: Bool {
        get {
            userDefaults.bool(forKey: Constants.isAuthorizedKey)
        }
        set {
            userDefaults.set(newValue, forKey: Constants.isAuthorizedKey)
        }
    }
    
    public var isActive = false
    
    // Private properties
    
    private let buildConfig: BuildConfig
    private lazy var userDefaults = UserDefaults(suiteName: "user_defaults.tp_auth") ?? .standard
    
    // MARK: - Initialization
    
    private init() {
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        self.buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
    }
}

extension StringProtocol {
    fileprivate subscript(offset: Int) -> Character { self[index(startIndex, offsetBy: offset)] }
}
