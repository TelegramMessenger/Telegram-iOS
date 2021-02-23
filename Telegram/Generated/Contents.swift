//
// Contents.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum Contents: Int {
    case `unknown` = 0
    case `recent` = 1
    case `custom` = 2
}

@available(iOS 13.0, macOS 10.16, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(ContentsResolutionResult)
public class ContentsResolutionResult: INEnumResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given Contents. The resolvedValue can be different than the original Contents. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedContents:)
    public class func success(with resolvedValue: Contents) -> Self {
        return __success(withResolvedValue: resolvedValue.rawValue)
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithContentsToConfirm:)
    public class func confirmationRequired(with valueToConfirm: Contents) -> Self {
        return __confirmationRequiredWithValue(toConfirm: valueToConfirm.rawValue)
    }
}

#endif
