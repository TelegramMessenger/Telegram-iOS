import Foundation

//  MARK: Nicegram CopyProtectedContent

private let bypassCopyProtectionKey = "ng:bypassCopyProtection"

public func getBypassCopyProtection() -> Bool {
    return UserDefaults.standard.bool(forKey: bypassCopyProtectionKey)
}

public func setBypassCopyProtection(_ value: Bool) {
    UserDefaults.standard.set(value, forKey: bypassCopyProtectionKey)
}

func canCopyProtectedContent() -> Bool {
    return getBypassCopyProtection()
}

//  MARK: Nicegram Translate

private let savedTranslationTargetLanguageKey = "ng:savedTranslationTargetLanguage"

public func getSavedTranslationTargetLanguage() -> String? {
    return UserDefaults.standard.string(forKey: savedTranslationTargetLanguageKey)
}

public func setSavedTranslationTargetLanguage(code: String) {
    UserDefaults.standard.set(code, forKey: savedTranslationTargetLanguageKey)
}
