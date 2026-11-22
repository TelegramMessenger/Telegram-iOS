import Foundation

/// UI-facing authorization state. Decoupled from TDLibKit types so views never import TDLibKit.
enum AuthState: Equatable {
    case starting
    case waitTdlibParameters
    case waitPhoneNumber
    case waitCode(info: CodeInfo)
    case waitOtherDeviceConfirmation(link: String)
    case waitPassword(info: PasswordInfo)
    case ready
    case loggingOut
    case closed
    case failed(String)
}

struct PasswordInfo: Equatable {
    /// Hint set when the password was created. Empty string means no hint.
    let hint: String
    let hasRecoveryEmail: Bool
}

struct CodeInfo: Equatable {
    let phoneNumber: String
    let codeLength: Int?
    let typeDescription: String
}
