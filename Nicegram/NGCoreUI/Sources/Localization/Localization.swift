import Foundation
import NGLocalization

public func ngLocalized(_ key: String) -> String {
    return NGLocalization.ngLocalized(key)
}

public func ngLocalized(_ key: String, with args: CVarArg...) -> String {
    return NGLocalization.ngLocalized(key, with: args)
}
