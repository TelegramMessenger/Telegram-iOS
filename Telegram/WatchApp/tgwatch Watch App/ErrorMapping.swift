import Foundation
import TDShim

func humanMessage(_ error: Swift.Error) -> String {
    if let tdErr = error as? TDError {
        return humanMessageForTdLibCode(tdErr.message)
    }
    return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}

/// Maps a TDLib error from `checkAuthenticationPassword` to one of three
/// user-facing messages for the 2-step verification screen. Unlike
/// `humanMessage`, unknown codes collapse to a generic message rather than
/// passing the raw code through.
func passwordSubmitErrorMessage(_ error: Swift.Error) -> String {
    guard let tdErr = error as? TDError else {
        return L("Watch.Error.Generic")
    }
    if tdErr.message == "PASSWORD_HASH_INVALID" {
        return L("Watch.Password.Incorrect")
    }
    if let flood = floodWaitMessage(tdErr.message) {
        return flood
    }
    return L("Watch.Error.Generic")
}

private func humanMessageForTdLibCode(_ code: String) -> String {
    switch code {
    case "PHONE_NUMBER_INVALID":
        return L("Watch.Error.InvalidPhone")
    case "PHONE_CODE_INVALID":
        return L("Watch.Error.InvalidCode")
    case "PHONE_CODE_EXPIRED":
        return L("Watch.Error.CodeExpired")
    case "FIRSTNAME_INVALID":
        return L("Watch.Error.InvalidFirstName")
    case "LASTNAME_INVALID":
        return L("Watch.Error.InvalidLastName")
    default:
        return floodWaitMessage(code) ?? code
    }
}

/// Formats a `FLOOD_WAIT_<seconds>` code into a wait message, or `nil` if the
/// code is not a flood-wait code.
private func floodWaitMessage(_ code: String) -> String? {
    guard code.hasPrefix("FLOOD_WAIT_") else { return nil }
    let suffix = code.dropFirst("FLOOD_WAIT_".count)
    if let seconds = Int(suffix), seconds > 0 {
        return L("Watch.Error.FloodWait", seconds)
    }
    return L("Login.CodeFloodError")
}
