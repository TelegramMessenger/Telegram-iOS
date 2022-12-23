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
            case .userStatusRecently:
                self.init(status: .recently, lastActivity: 0)
            case .userStatusLastWeek:
                self.init(status: .lastWeek, lastActivity: 0)
            case .userStatusLastMonth:
                self.init(status: .lastMonth, lastActivity: 0)
        }
    }
    
    convenience init?(apiUser: Api.User) {
        switch apiUser {
            case let .user(_, _, _, _, _, _, _, _, _, status, _, _, _, _, _, _):
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
