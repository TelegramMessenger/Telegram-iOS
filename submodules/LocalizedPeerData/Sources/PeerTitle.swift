import Foundation
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences

public extension Peer {
    func displayTitle(strings: PresentationStrings, displayOrder: PresentationPersonNameOrder) -> String {
        switch self {
            case let user as TelegramUser:
                if let firstName = user.firstName {
                    if let lastName = user.lastName {
                        switch displayOrder {
                            case .firstLast:
                                return "\(firstName) \(lastName)"
                            case .lastFirst:
                                return "\(lastName) \(firstName)"
                        }
                    } else {
                        return firstName
                    }
                } else if let lastName = user.lastName {
                    return lastName
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
