import Foundation
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// A server error about a new bot's username, from `bots.checkUsername` or `bots.createBot`.
///
/// A bot username ends in 'bot', or — with Telegram Premium — in one of the endings the
/// `bot_allowed_suffixes` app config lists, and an account may hold only a few of those Premium
/// endings across all its bots. `USERNAME_SUFFIX_MISSING` is the server's answer to an ending it does
/// not allow (seen live). The Premium and cap errors are matched by KEYWORD, because their exact strings
/// have not been confirmed against the server yet; every error is logged with its exact text (tag
/// `BotUsername`) so the matching can be pinned to the real strings.
public enum BotUsernameServerError: Equatable {
    case occupied
    case purchaseAvailable
    /// The username does not end in an ending the server allows for this account.
    case suffixNotAllowed
    case premiumRequired
    /// The account already has as many Premium-ending usernames as it may. `limit` is read from a
    /// trailing number in the error (`..._2`), when the server sends one.
    case suffixLimitExceeded(limit: Int32?)

    public init?(errorDescription: String) {
        switch errorDescription {
        case "USERNAME_OCCUPIED":
            self = .occupied
        case "USERNAME_PURCHASE_AVAILABLE":
            self = .purchaseAvailable
        case "USERNAME_SUFFIX_MISSING":
            self = .suffixNotAllowed
        default:
            let text = errorDescription.uppercased()
            let isLimit = text.contains("LIMIT") || text.contains("TOO_MANY") || text.contains("TOO_MUCH")
            let isAboutUsernames = text.contains("SUFFIX") || text.contains("USERNAME")
            // The cap is checked first: an account without Premium is stopped on the device before a
            // Premium ending reaches the server, so an error naming both is a Premium user at the cap.
            if isLimit && isAboutUsernames {
                var limit: Int32?
                if let last = text.split(separator: "_").last, last.allSatisfy(\.isNumber) {
                    limit = Int32(last)
                }
                self = .suffixLimitExceeded(limit: limit)
            } else if text.contains("PREMIUM") {
                self = .premiumRequired
            } else {
                return nil
            }
        }
    }
}

public enum BotUsernameAvailability: Equatable {
    case available
    case invalid
    case taken
    case purchaseAvailable
    case suffixNotAllowed
    case premiumRequired
    case suffixLimitExceeded(limit: Int32?)
}

func _internal_checkBotUsername(account: Account, username: String) -> Signal<BotUsernameAvailability, NoError> {
    return account.network.request(Api.functions.bots.checkUsername(flags: 0, username: username))
    |> map { result -> BotUsernameAvailability in
        switch result {
        case .boolTrue:
            return .available
        case .boolFalse:
            return .taken
        }
    }
    |> `catch` { error -> Signal<BotUsernameAvailability, NoError> in
        Logger.shared.log("BotUsername", "bots.checkUsername(\(username)) failed: \(error.errorDescription ?? "")")
        switch BotUsernameServerError(errorDescription: error.errorDescription ?? "") {
        case .occupied:
            return .single(.taken)
        case .purchaseAvailable:
            return .single(.purchaseAvailable)
        case .suffixNotAllowed:
            return .single(.suffixNotAllowed)
        case .premiumRequired:
            return .single(.premiumRequired)
        case let .suffixLimitExceeded(limit):
            return .single(.suffixLimitExceeded(limit: limit))
        case nil:
            return .single(.invalid)
        }
    }
}
