import Foundation
import FileStorage
import NGModels

public protocol UserEsimsLocalDataSource: AnyObject {
    func getCachedUserEsims() -> [UserEsim]?
    func save(_: [UserEsim]?)
}

public class UserEsimsLocalDataSourceImpl {
    
    //  MARK: - Dependencies
    
    private let fileStorage: FileStorage<[UserEsimDTO]>
    
    //  MARK: - Lifecycle
    
    public init() {
        self.fileStorage = FileStorage<[UserEsimDTO]>(path: "nicegram-assistant/esims.json")
    }
}

extension UserEsimsLocalDataSourceImpl: UserEsimsLocalDataSource {
    public func getCachedUserEsims() -> [UserEsim]? {
        return fileStorage.read()?.map({ self.mapToDomain(dto: $0) })
    }
    
    public func save(_ esims: [UserEsim]?) {
        fileStorage.save(esims?.map({ self.mapToDto(domain: $0) }))
    }
}

//  MARK: - Mapping

private extension UserEsimsLocalDataSourceImpl {
    func mapToDomain(dto: UserEsimDTO) -> UserEsim {
        let balance: UserEsim.Balance
        switch dto.balance {
        case .megabytes(let megabytes):
            balance = .megabytes(megabytes)
        case .money(let amount, let currencyIsoCode):
            balance = .money(Money(amount: amount, currency: Currency(isoCode: currencyIsoCode)))
        }
        
        let expirationDate: UserEsim.ExpirationDate
        switch dto.expirationDate {
        case .notActivated:
            expirationDate = .notActivated
        case .unlimited:
            expirationDate = .unlimited
        case .date(let date):
            expirationDate = .date(date)
        }
        
        let state: UserEsim.State
        switch dto.state {
        case .blocked:
            state = .blocked
        case .expired:
            state = .expired
        case .active:
            state = .active
        }
        
        return UserEsim(icc: dto.icc, lpa: dto.lpa, code: dto.code, regionId: dto.regionsId, regionIsoCode: dto.regionIsoCode, phoneNumber: dto.phoneNumber, balance: balance, expirationDate: expirationDate, state: state)
    }
    
    func mapToDto(domain: UserEsim)-> UserEsimDTO {
        let balance: Balance
        switch domain.balance {
        case .megabytes(let megabytes):
            balance = .megabytes(megabytes)
        case .money(let money):
            balance = .money(amount: money.amount, currencyIsoCode: money.currency.isoCode)
        }
        
        let expirationDate: ExpirationDate
        switch domain.expirationDate {
        case .notActivated:
            expirationDate = .notActivated
        case .unlimited:
            expirationDate = .unlimited
        case .date(let date):
            expirationDate = .date(date)
        }
        
        let state: State
        switch domain.state {
        case .blocked:
            state = .blocked
        case .expired:
            state = .expired
        case .active:
            state = .active
        }
        
        return UserEsimDTO(icc: domain.icc, lpa: domain.lpa, code: domain.code, regionsId: domain.regionId, regionIsoCode: domain.regionIsoCode, phoneNumber: domain.phoneNumber, balance: balance, expirationDate: expirationDate, state: state)
    }
}

//  MARK: - DTO

private struct UserEsimDTO: Codable {
    let icc: String
    let lpa: String
    let code: String
    let regionsId: Int
    let regionIsoCode: String
    let phoneNumber: String?
    let balance: Balance
    let expirationDate: ExpirationDate
    let state: State
}

private enum State: Codable {
    case blocked
    case expired
    case active
}

private enum Balance: Codable {
    case megabytes(Int)
    case money(amount: Double, currencyIsoCode: String)
}

private enum ExpirationDate: Codable {
    case notActivated
    case unlimited
    case date(Date)
}

