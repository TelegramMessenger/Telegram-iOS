import Foundation
import Postbox
import TelegramCore

/// Whether a notification has to say which account it was delivered to: more than one is signed
/// in (bugs.telegram.org/c/18387). Every record not marked logged out counts. The app also leaves
/// out a record whose session turns out to be unauthorized when it opens it, which the extension
/// cannot know without opening every account; such a record counts here until it is marked.
func notificationsNameRecipientAccount(records: [AccountRecord<TelegramAccountManagerTypes.Attribute>]) -> Bool {
    let accountCount = records.filter { record in
        return !record.attributes.contains(where: { attribute in
            if case .loggedOut = attribute {
                return true
            } else {
                return false
            }
        })
    }.count
    return accountCount > 1
}

/// The name a notification uses for the account it was delivered to, as the extension named it
/// before its 2021 rewrite dropped the feature (`StoredAccountInfo.peerName`): the username
/// without "@", else the account's name.
func notificationRecipientAccountName(accountPeer: Peer?) -> String? {
    guard let accountPeer else {
        return nil
    }
    if let addressName = accountPeer.addressName, !addressName.isEmpty {
        return addressName
    }
    let title = accountPeer.debugDisplayTitle
    return title.isEmpty ? nil : title
}

/// The names one notification is drawn and donated with.
///
/// On iOS 15+ a notification with sender info is a communication notification, and the system
/// draws the sender's name in place of `title` (it also hides `subtitle`, so the account cannot
/// go there). The account therefore goes into both `title` and `displayedSenderName`. The
/// interaction donated for Siri, share sheet and Focus suggestions keeps the sender alone:
/// the system draws the notification from the intent it is updated from, not the donated one.
struct NotificationNames: Equatable {
    var title: String?
    /// The sender's name the notification is drawn with.
    var displayedSenderName: String?
    /// The sender's name handed to the system with the donated interaction.
    var donatedSenderName: String?

    init(title: String?, senderName: String?, silent: Bool, recipientAccountName: String?) {
        // No title means the chat's message previews are off, and then the account is left out,
        // as it was before 2021, even where the system still draws the sender's name.
        let recipientAccountName = (title?.isEmpty ?? true) ? nil : recipientAccountName

        func decorated(_ name: String, recipientAccountName: String?) -> String {
            var result = name
            if let recipientAccountName {
                // The arrow is not mirrored, and the system lays a title out in the direction of its
                // first letter: in a right-to-left title "→" would point from the account back to
                // the sender.
                let isRightToLeft = firstLetterIsRightToLeft(name) ?? firstLetterIsRightToLeft(recipientAccountName) ?? false
                result += isRightToLeft ? " ← \(recipientAccountName)" : " → \(recipientAccountName)"
            }
            // The muted marker describes the message, so it stays last.
            if silent {
                result += " 🔕"
            }
            return result
        }

        self.title = title.flatMap { decorated($0, recipientAccountName: recipientAccountName) }
        self.displayedSenderName = senderName.flatMap { decorated($0, recipientAccountName: recipientAccountName) }
        self.donatedSenderName = senderName.flatMap { decorated($0, recipientAccountName: nil) }
    }
}

/// Whether the first letter of `string` belongs to a right-to-left script, or nil when it has no
/// letter. This is the part of Unicode's paragraph-direction rule (UAX #9, P2) that names need:
/// digits, punctuation and emoji are skipped, and a leading directional mark decides outright.
private func firstLetterIsRightToLeft(_ string: String) -> Bool? {
    for scalar in string.unicodeScalars {
        switch scalar.value {
        case 0x200F, 0x061C:
            // RIGHT-TO-LEFT MARK, ARABIC LETTER MARK
            return true
        case 0x200E:
            // LEFT-TO-RIGHT MARK
            return false
        default:
            break
        }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            switch scalar.value {
            case 0x0590 ... 0x08FF, 0xFB1D ... 0xFDFF, 0xFE70 ... 0xFEFF, 0x10800 ... 0x10FFF, 0x1E800 ... 0x1EFFF:
                // Hebrew, Arabic, Syriac, Thaana, NKo and the other right-to-left blocks
                return true
            default:
                return false
            }
        default:
            continue
        }
    }
    return nil
}
