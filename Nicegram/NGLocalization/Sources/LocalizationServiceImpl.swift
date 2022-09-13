import CrowdinSDK
import Foundation

public class LocalizationServiceImpl {
    
    //  MARK: - Logic
    
    private let tableName: String = "NicegramLocalizable"
    
    //  MARK: - Lifecycle
    
    public static let shared: LocalizationServiceImpl = {
        return LocalizationServiceImpl()
    }()
    
    private init() {}
    
    public func setup(hash: String, sourceLanguage: String, completion: (() -> ())?) {
        let providerConfig = CrowdinProviderConfig(hashString: hash, sourceLanguage: sourceLanguage)
        let config = CrowdinSDKConfig.config()
            .with(crowdinProviderConfig: providerConfig)
        DispatchQueue.global().async {
            CrowdinSDK.startWithConfig(config, completion: completion ?? {})
        }
    }
}

extension LocalizationServiceImpl: LocalizationService {
    public func localized(_ key: String) -> String {
        return NSLocalizedString(key, tableName: tableName, comment: "")
    }
    
    public func localized(_ key: String, with args: CVarArg...) -> String {
        return localized(key, withArguments: args)
    }
    
    public func localized(_ key: String, withArguments args: [CVarArg]) -> String {
        return String(
            format: localized(key),
            arguments: args
        )
    }
}

//  MARK: - Helpers

public func ngLocalized(_ key: String) -> String {
    return LocalizationServiceImpl.shared.localized(key)
}

public func ngLocalized(_ key: String, with args: CVarArg...) -> String {
    return LocalizationServiceImpl.shared.localized(key, withArguments: args)
}

public func mapErrorDescription(_ description: String?) -> String {
    if let description = description,
       !description.isEmpty {
        return description
    } else {
        return ngLocalized("Nicegram.Alert.BaseError")
    }
}
