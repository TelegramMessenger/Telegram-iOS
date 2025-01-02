import Foundation
import Postbox
import TelegramApi


extension TelegramUserPresence {
    convenience init(apiStatus: Api.UserStatus) {
        switch apiStatus {
        case .userStatusEmpty:
            self.init(status: .none, lastActivity: 0)
        case let .userStatusOnline(expires):
            self.init(status: .present(until: expires), lastActivity: 0)
        case let .userStatusOffline(wasOnline):
            self.init(status: .present(until: wasOnline), lastActivity: 0)
        case let .userStatusRecently(flags):
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .recently(isHidden: isHidden), lastActivity: 0)
        case let .userStatusLastWeek(flags):
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .lastWeek(isHidden: isHidden), lastActivity: 0)
        case let .userStatusLastMonth(flags):
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .lastMonth(isHidden: isHidden), lastActivity: 0)
        }
    }
    
    convenience init?(apiUser: Api.User) {
        switch apiUser {
            case let .user(_, _, _, _, _, _, _, _, _, status, _, _, _, _, _, _, _, _, _, _, _):
                if let status = status {
                    self.init(apiStatus: status)
                } else {
                    self.init(status: .none, lastActivity: 0)
                }
            case .userEmpty:
                return nil
        }
    }
}
