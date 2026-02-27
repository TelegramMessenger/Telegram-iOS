import Foundation
import Postbox
import TelegramApi


extension TelegramUserPresence {
    convenience init(apiStatus: Api.UserStatus) {
        switch apiStatus {
        case .userStatusEmpty:
            self.init(status: .none, lastActivity: 0)
        case let .userStatusOnline(userStatusOnlineData):
            let (expires) = (userStatusOnlineData.expires)
            self.init(status: .present(until: expires), lastActivity: 0)
        case let .userStatusOffline(userStatusOfflineData):
            let (wasOnline) = (userStatusOfflineData.wasOnline)
            self.init(status: .present(until: wasOnline), lastActivity: 0)
        case let .userStatusRecently(userStatusRecentlyData):
            let (flags) = (userStatusRecentlyData.flags)
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .recently(isHidden: isHidden), lastActivity: 0)
        case let .userStatusLastWeek(userStatusLastWeekData):
            let (flags) = (userStatusLastWeekData.flags)
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .lastWeek(isHidden: isHidden), lastActivity: 0)
        case let .userStatusLastMonth(userStatusLastMonthData):
            let (flags) = (userStatusLastMonthData.flags)
            let isHidden = (flags & (1 << 0)) != 0
            self.init(status: .lastMonth(isHidden: isHidden), lastActivity: 0)
        }
    }
    
    convenience init?(apiUser: Api.User) {
        switch apiUser {
            case let .user(userData):
                let status = userData.status
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
