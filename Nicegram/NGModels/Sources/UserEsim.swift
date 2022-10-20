import Foundation

public struct UserEsim {
    public let icc: String
    public let lpa: String
    public let code: String
    public let regionId: Int
    public let regionIsoCode: String
    public let phoneNumber: String?
    public let balance: Balance
    public let expirationDate: ExpirationDate
    public let state: State
    
    public init(icc: String, lpa: String, code: String, regionId: Int, regionIsoCode: String, phoneNumber: String?, balance: UserEsim.Balance, expirationDate: UserEsim.ExpirationDate, state: State) {
        self.icc = icc
        self.lpa = lpa
        self.code = code
        self.regionId = regionId
        self.regionIsoCode = regionIsoCode
        self.phoneNumber = phoneNumber
        self.balance = balance
        self.expirationDate = expirationDate
        self.state = state
    }
    
    public enum Balance {
        case megabytes(Int)
        case money(Money)
    }
    
    public enum ExpirationDate {
        case notActivated
        case unlimited
        case date(Date)
    }
    
    public enum State {
        case blocked
        case expired
        case active
    }
}

public extension UserEsim {
    var id: String { return icc }
    
    var activationInfo: EsimActivationInfo {
        return EsimActivationInfo(icc: icc, lpa: lpa, code: code)
    }
}
