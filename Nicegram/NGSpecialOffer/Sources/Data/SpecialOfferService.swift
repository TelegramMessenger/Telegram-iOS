import Foundation
import EsimPropertyWrappers
import NGRemoteConfig

public protocol SpecialOfferService {
    func fetchSpecialOffer(completion: ((SpecialOffer?) -> ())?)
    func getSpecialOffer(with: String) -> SpecialOffer?
    func wasSpecialOfferSeen(id: String) -> Bool
    func markAsSeen(offerId: String)
}

public class SpecialOfferServiceImpl {
    
    //  MARK: - Dependencies
    
    private let remoteConfig: RemoteConfigService
    
    //  MARK: - Logic
    
    private var specialOffers: [SpecialOffer] = []
    
    @UserDefaultsWrapper(key: "ng_seen_special_offers", defaultValue: [])
    private var seenSpecialOfferIds: Set<String>
    
    //  MARK: - Lifecycle
    
    public init(remoteConfig: RemoteConfigService) {
        self.remoteConfig = remoteConfig
    }
}

extension SpecialOfferServiceImpl: SpecialOfferService {
    public func fetchSpecialOffer(completion: ((SpecialOffer?) -> ())?) {
        remoteConfig.fetch(SpecialOfferDto.self, byKey: Constants.specialOfferKey) { [weak self] dto in
            guard let self = self else { return }
            
            let specialOffer = self.mapDto(dto)
            
            if let specialOffer = specialOffer,
               !self.specialOffers.contains(where: { $0.id == specialOffer.id }) {
                self.specialOffers.append(specialOffer)
            }
            
            completion?(specialOffer)
        }
    }
    
    public func getSpecialOffer(with id: String) -> SpecialOffer? {
        return specialOffers.first(where: { $0.id == id })
    }
    
    public func wasSpecialOfferSeen(id: String) -> Bool {
        return seenSpecialOfferIds.contains(id)
    }
    
    public func markAsSeen(offerId: String) {
        seenSpecialOfferIds.insert(offerId)
    }
}

//  MARK: - Mapping

private extension SpecialOfferServiceImpl {
    func mapDto(_ dto: SpecialOfferDto?) -> SpecialOffer? {
        guard let dto = dto,
              let id = dto.offerId,
              let url = dto.url else {
            return nil
        }
        
        return SpecialOffer(
            id: String(id),
            url: url,
            shouldAutoshowToPremiumUser: dto.showToPremium ?? true,
            autoshowTimeInterval: dto.timeInterval
        )
    }
}

//  MARK: - DTO

private struct SpecialOfferDto: Decodable {
    let offerId: Int?
    let url: URL?
    let showToPremium: Bool?
    let timeInterval: Double?
}

//  MARK: - Constants

private extension SpecialOfferServiceImpl {
    struct Constants {
        static let specialOfferKey = "specialOffer"
    }
}
