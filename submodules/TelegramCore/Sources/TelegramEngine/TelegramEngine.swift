import SwiftSignalKit
import Postbox

public final class TelegramEngine {
    public let account: Account

    public init(account: Account) {
        self.account = account
    }

    public lazy var secureId: SecureId = {
        return SecureId(account: self.account)
    }()

    public lazy var peersNearby: PeersNearby = {
        return PeersNearby(account: self.account)
    }()

    public lazy var payments: Payments = {
        return Payments(account: self.account)
    }()

    public lazy var peers: Peers = {
        return Peers(account: self.account)
    }()

    public lazy var auth: Auth = {
        return Auth(account: self.account)
    }()

    public lazy var accountData: AccountData = {
        return AccountData(account: self.account)
    }()

    public lazy var stickers: Stickers = {
        return Stickers(account: self.account)
    }()

    public lazy var localization: Localization = {
        return Localization(account: self.account)
    }()
    
    public lazy var themes: Themes = {
        return Themes(account: self.account)
    }()

    public lazy var messages: Messages = {
        return Messages(account: self.account)
    }()

    public lazy var privacy: Privacy = {
        return Privacy(account: self.account)
    }()

    public lazy var calls: Calls = {
        return Calls(account: self.account)
    }()

    public lazy var historyImport: HistoryImport = {
        return HistoryImport(account: self.account)
    }()

    public lazy var contacts: Contacts = {
        return Contacts(account: self.account)
    }()

    public lazy var resources: Resources = {
        return Resources(account: self.account)
    }()

    public lazy var resolve: Resolve = {
        return Resolve(account: self.account)
    }()

    public lazy var data: EngineData = {
        return EngineData(account: self.account)
    }()

    public lazy var orderedLists: OrderedLists = {
        return OrderedLists(account: self.account)
    }()
}

public final class TelegramEngineUnauthorized {
    public let account: UnauthorizedAccount

    public init(account: UnauthorizedAccount) {
        self.account = account
    }

    public lazy var auth: Auth = {
        return Auth(account: self.account)
    }()

    public lazy var localization: Localization = {
        return Localization(account: self.account)
    }()
}

public enum SomeTelegramEngine {
    case unauthorized(TelegramEngineUnauthorized)
    case authorized(TelegramEngine)
}
