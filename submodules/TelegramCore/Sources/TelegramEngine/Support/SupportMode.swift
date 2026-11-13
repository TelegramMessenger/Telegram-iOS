import Foundation

public func isSupportAccountPhone(_ phone: String?) -> Bool {
    guard let phone else {
        return false
    }
    return phone.hasPrefix("424")
}

func resolvedIsSupportUser(storedPhone: String?, recordAttribute: Bool) -> Bool {
    if let storedPhone {
        return isSupportAccountPhone(storedPhone)
    }
    return recordAttribute
}

public func supportModeWasLost(phone: String?, isSupportUser: Bool) -> Bool {
    return !isSupportUser && isSupportAccountPhone(phone)
}
