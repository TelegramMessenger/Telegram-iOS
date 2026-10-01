import Foundation

/// Identification of TSupport volunteer accounts by phone number.
///
/// A support account is an ordinary Telegram account that authorised with a support phone
/// number. Support numbers are `+42` followed by a region code and the volunteer's own
/// number, e.g. `+42490918884564680` — region `490` (India), volunteer `918884564680`.
///
/// Every allocated support region code begins `424`, and `424` is unassigned in E.164. The
/// neighbouring assigned codes are `420` (Czech Republic), `421` (Slovakia) and `423`
/// (Liechtenstein), so matching on `42` alone would classify real users of those countries
/// as support accounts.
public enum SupportAccount {
    /// Dialing prefix shared by every support region code.
    ///
    /// Deliberately `424` and not `42`. Deliberately a prefix rather than an enumeration of
    /// the known region codes, so that region codes allocated later are recognised without
    /// an app update.
    public static let phoneNumberPrefix = "424"

    /// Whether `phone` belongs to a support account.
    ///
    /// Returns `false` for `nil` — an absent phone number means *unknown*, not *not a
    /// support account*. Callers that revoke support status must treat the two differently.
    ///
    /// Length is not constrained: the server may report either the full support number or a
    /// shortened form, and both must match.
    public static func isSupportPhoneNumber(_ phone: String?) -> Bool {
        guard let phone else {
            return false
        }
        return normalized(phone).hasPrefix(phoneNumberPrefix)
    }

    private static func normalized(_ phone: String) -> String {
        return String(phone.filter { $0.isNumber })
    }
}
