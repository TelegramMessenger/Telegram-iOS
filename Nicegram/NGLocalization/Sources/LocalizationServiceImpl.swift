import Foundation

public class LocalizationServiceImpl {
    
    //  MARK: - Logic
    
    private let tableName: String = "NicegramLocalizable"
    
    private var languageCode: String = Locale.currentAppLocale.langCode
    
    //  MARK: - Lifecycle
    
    public static let shared: LocalizationServiceImpl = {
        return LocalizationServiceImpl()
    }()
    
    private init() {}
    
    //  MARK: - Public Functions

    public func setLanguageCode(_ langCode: String) {
        self.languageCode = self.mapLanguageCode(langCode)
    }

    //  MARK: - Private Functions

    private func localizedString(key: String, langCode: String) -> String {
        guard let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: nil, table: tableName)
    }

    private func mapLanguageCode(_ langCode: String) -> String {
        var result = langCode
        
        let rawSuffix = "-raw"
        if langCode.hasSuffix(rawSuffix) {
            result = String(langCode.dropLast(rawSuffix.count))
        }
        
        switch result {
        case "pt-br":
            return "pt"
        default:
            return result
        }
    }
}

extension LocalizationServiceImpl: LocalizationService {
    public func localized(_ key: String) -> String {
        let localizedString = self.localizedString(key: key, langCode: self.languageCode)
        
        if localizedString != key {
            return localizedString
        } else {
            return self.localizedString(key: key, langCode: "en")
        }
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
