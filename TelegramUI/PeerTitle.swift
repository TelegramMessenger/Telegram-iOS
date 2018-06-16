import Foundation
import TelegramCore
import Postbox

extension Peer {
    func displayTitle(strings: PresentationStrings) -> String {
        switch self {
            case let user as TelegramUser:
                if let firstName = user.firstName {
                    if let lastName = user.lastName {
                        if strings.lc == 0x6b6f {
                            return "\(lastName) \(firstName)"
                        } else {
                            return "\(firstName) \(lastName)"
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
