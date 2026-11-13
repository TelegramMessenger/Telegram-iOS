import Foundation
import Postbox

public func isSupportAccountPhone(_ phone: String?) -> Bool {
    guard let phone else {
        return false
    }
    return phone.hasPrefix("424")
}

func supportPremiumStatusHasExpiryDate(_ status: String) -> Bool {
    return status.range(of: "\\b\\d{1,2}[./-]\\d{1,2}[./-]\\d{2,4}\\b", options: .regularExpression) != nil
}

func supportUserWithPremiumFromStatus(transaction: Transaction, user: TelegramUser) -> TelegramUser {
    guard isSupportAccountPhone(user.phone), let status = transaction.getPreferencesEntry(key: PreferencesKeys.premiumPromo)?.get(PremiumPromoConfiguration.self)?.status, supportPremiumStatusHasExpiryDate(status) else {
        return user
    }
    var flags = user.flags
    flags.insert(.isPremium)
    flags.insert(.hidesPremiumStar)
    return user.withUpdatedFlags(flags)
}

func supportRefreshPremiumFromStatus(transaction: Transaction, accountPeerId: PeerId) {
    guard let user = transaction.getPeer(accountPeerId) as? TelegramUser, isSupportAccountPhone(user.phone) else {
        return
    }
    var flags = user.flags
    flags.remove(.isPremium)
    flags.remove(.hidesPremiumStar)
    updatePeersCustom(transaction: transaction, peers: [user.withUpdatedFlags(flags)], update: { _, updated in updated })
}

func resolvedIsSupportUser(storedPhone: String?, recordAttribute: Bool) -> Bool {
    if let storedPhone {
        return isSupportAccountPhone(storedPhone)
    }
    return recordAttribute
}

public func supportModeWasLost(phone: String?, isSupportUser: Bool) -> Bool {
    return !isSupportUser && isSupportAccountPhone(phone)
}

public func supportChatListHoleIsHeld(holeTimestamp: Int32, loadTill: Int32) -> Bool {
    return loadTill > 0 && holeTimestamp <= loadTill
}

func supportChatListInitialLoadTill(now: Int32, period: Int32) -> Int32 {
    if period == SupportSettings.allChatsLoadPeriod {
        return 0
    }
    return max(now - period, 0)
}

public enum SupportChatListLoadState: Equatable {
    case allLoaded
    case loading
    case held(holeTimestamp: Int32)
}

func supportChatListLoadState(holeTimestamps: [Int32], loadTill: Int32) -> SupportChatListLoadState {
    guard let latestHole = holeTimestamps.max() else {
        return .allLoaded
    }
    if holeTimestamps.contains(where: { !supportChatListHoleIsHeld(holeTimestamp: $0, loadTill: loadTill) }) {
        return .loading
    }
    return .held(holeTimestamp: latestHole)
}

func supportChatListLoadTillAfterLoadMore(current: Int32, holeTimestamp: Int32, period: Int32) -> Int32 {
    return max(min(current, holeTimestamp - period), 0)
}
