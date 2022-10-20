import Foundation
import EsimDTO
import NGModels

public class UserEsimMapper {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func map(_ dto: UserEsimDTO) -> UserEsim? {
        let balance: UserEsim.Balance
        let expirationDate: UserEsim.ExpirationDate
        
        switch dto.providerType {
        case "MTX":
            let megabytes = toMegabytes(bytes: dto.totalVolumeBytes - dto.usedVolumeBytes)
            balance = .megabytes(megabytes)
            if let endDate = dto.endDate {
                expirationDate = .date(endDate)
            } else {
                expirationDate = .notActivated
            }
        case "TOP_CONNECT":
            balance = .money(Money(amount: dto.balance ?? 0, currency: .euro))
            expirationDate = .unlimited
        default:
            return nil
        }
        
        return UserEsim(icc: dto.icc, lpa: dto.lpaDisplay, code: dto.code, regionId: dto.regionId, regionIsoCode: dto.isoName2, phoneNumber: dto.phoneNumber, balance: balance, expirationDate: expirationDate, state: mapState(dto))
    }
    
    //  MARK: - Private Functions
    
    private func mapState(_ dto: UserEsimDTO) -> UserEsim.State {
        if dto.expired {
            return .expired
        }
        if !dto.active {
            return .blocked
        }
        return .active
    }

    private func toMegabytes(bytes: Int) -> Int {
        return Int(round(Double(bytes) / (1024 * 1024)))
    }
}


