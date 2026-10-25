import Foundation

/// Identification of TSupport volunteer accounts by phone number.
///
/// A support account is an ordinary Telegram account that authorised with a support phone
/// number. Support numbers are `+42` followed by a region code and the volunteer's own
/// number, e.g. `+42490918884564680` — region code `42490`, volunteer number
/// `918884564680`.
///
/// Every allocated support region code begins `424`, and `424` is unassigned in E.164. The
/// neighbouring assigned codes are `420` (Czech Republic), `421` (Slovakia) and `423`
/// (Liechtenstein), so matching on `42` alone would classify real users of those countries
/// as support accounts.
public enum SupportAccount {
    /// Dialing prefix shared by every support region code. Descriptive only - every entry
    /// in `regionCodes` begins with this, but matching is against that exact list, not this
    /// prefix alone (see `regionCodes`).
    public static let phoneNumberPrefix = "424"

    /// The exact set of allocated support region codes. A phone number is classified as a
    /// support number only if it starts with one of these - an otherwise `424…`-prefixed
    /// number that matches none of them is **not** a support account.
    ///
    /// This is a deliberate reversal of the original design (a bare `424` prefix match,
    /// chosen so newly allocated codes would "just work" without an app update). Owner's
    /// words: "I would like to match the exact available codes. If it doesn't match, then
    /// do not consider it as support account." A newly allocated region code must be added
    /// here and shipped in an app update before accounts using it are recognised.
    public static let regionCodes: [String] = [
        "42400", "42410", "42434", "42439", "42449", "42450", "42455", "42460", "42470",
        "42479", "42482", "42490", "424960", "424980", "42400000", "42454321", "424314159",
    ]

    /// Whether `phone` belongs to a support account.
    ///
    /// Returns `false` for `nil` — an absent phone number means *unknown*, not *not a
    /// support account*. Callers that revoke support status must treat the two differently.
    ///
    /// Length is not constrained beyond the region code itself: the server may report
    /// either the full support number or a shortened form, and both must match.
    public static func isSupportPhoneNumber(_ phone: String?) -> Bool {
        guard let phone else {
            return false
        }
        let normalizedPhone = normalized(phone)
        return regionCodes.contains(where: { normalizedPhone.hasPrefix($0) })
    }

    private static func normalized(_ phone: String) -> String {
        return String(phone.filter { $0.isNumber })
    }
}
