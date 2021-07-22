import Foundation
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import PhoneNumberFormat

public extension Peer {
    var compactDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName, !firstName.isEmpty {
                return firstName
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return lastName
            } else if let phone = user.phone {
                return formatPhoneNumber("+\(phone)")
            } else {
                return ""
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }
    
    func displayTitle(strings: PresentationStrings, displayOrder: PresentationPersonNameOrder) -> String {
        switch self {
        case let user as TelegramUser:
            if user.id.isReplies {
                return strings.DialogList_Replies
            }
            if let firstName = user.firstName, !firstName.isEmpty {
                if let lastName = user.lastName, !lastName.isEmpty {
                    switch displayOrder {
                    case .firstLast:
                        return "\(firstName) \(lastName)"
                    case .lastFirst:
                        return "\(lastName) \(firstName)"
                    }
                } else {
                    return firstName
                }
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return lastName
            } else if let phone = user.phone {
                return formatPhoneNumber("+\(phone)")
            } else {
                return strings.User_DeletedAccount
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }
}

public extension EnginePeer {
    var compactDisplayTitle: String {
        return self._asPeer().compactDisplayTitle
    }

    func displayTitle(strings: PresentationStrings, displayOrder: PresentationPersonNameOrder) -> String {
        return self._asPeer().displayTitle(strings: strings, displayOrder: displayOrder)
    }
}
