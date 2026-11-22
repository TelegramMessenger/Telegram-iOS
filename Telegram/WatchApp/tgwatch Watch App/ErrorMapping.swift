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
        return "An error occurred"
    }
    if tdErr.message == "PASSWORD_HASH_INVALID" {
        return "Incorrect password"
    }
    if let flood = floodWaitMessage(tdErr.message) {
        return flood
    }
    return "An error occurred"
}

private func humanMessageForTdLibCode(_ code: String) -> String {
    switch code {
    case "PHONE_NUMBER_INVALID":
        return "That phone number doesn't look right."
    case "PHONE_CODE_INVALID":
        return "That code is wrong."
    case "PHONE_CODE_EXPIRED":
        return "Code expired — request a new one."
    case "FIRSTNAME_INVALID":
        return "That first name doesn't look right."
    case "LASTNAME_INVALID":
        return "That last name doesn't look right."
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
        return "Too many attempts. Wait \(seconds)s."
    }
    return "Too many attempts. Try again later."
}
