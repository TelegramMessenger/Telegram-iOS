import EsimApiClientDefinition

public struct EsimOfferDTO {
    public let id: Int
    public let title: String
    public let regionId: Int
    public let regionIsoCode: String
    public let traffic: Traffic
    public let duration: Duration
    public let price: Double
    public let includePhoneNumber: Bool
    
    public enum Traffic {
        case payAsYouGo
        case megabytes(Int)
    }
    
    public enum Duration {
        case unlimited
        case days(Int)
    }
}

public struct EsimRegionDTO {
    public let id: Int
    public let name: String
}

public struct EsimCountryDTO {
    public let id: Int
    public let isoCode: String
    public let name: String
    public let regionIds: [Int]
    public let payAsYouGoRate: Double?
}

public struct PlansResponseDTO: Decodable {
    public let offers: [EsimOfferDTO]
    public let regions: [EsimRegionDTO]
    public let countries: [EsimCountryDTO]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let countriesDto = try container.decode([Country].self, forKey: .countries)
        let bundlesDto = try container.decode([Bundle].self, forKey: .bundles)
        
        let countries = countriesDto.map { dto -> EsimCountryDTO in
            return EsimCountryDTO(id: dto.id, isoCode: dto.isoName2, name: dto.country, regionIds: dto.regionlist, payAsYouGoRate: dto.tc)
        }
        
        var allOffers: [EsimOfferDTO] = []
        var regions: [EsimRegionDTO] = []
        
        for bundleDto in bundlesDto {
            let region = EsimRegionDTO(id: bundleDto.id, name: bundleDto.name)
            
            let offers = bundleDto.bundles.compactMap { megabytes, offer -> EsimOfferDTO? in
                guard let megabytes = Int(megabytes) else { return nil }
                
                let traffic: EsimOfferDTO.Traffic
                let duration: EsimOfferDTO.Duration
                let includePhoneNumber: Bool
                if bundleDto.worldwide {
                    traffic = .payAsYouGo
                    duration = .unlimited
                    includePhoneNumber = true
                } else {
                    traffic = .megabytes(megabytes)
                    duration = .days(offer.days)
                    includePhoneNumber = false
                }
                
                return EsimOfferDTO(id: megabytes, title: bundleDto.name, regionId: region.id, regionIsoCode: bundleDto.isoName2, traffic: traffic, duration: duration, price: offer.price, includePhoneNumber: includePhoneNumber)
            }
            
            regions.append(region)
            allOffers.append(contentsOf: offers)
        }
        
        self.offers = allOffers
        self.regions = regions
        self.countries = countries
    }
    
    public enum CodingKeys: String, CodingKey {
        case bundles
        case countries
    }
    
    private struct Bundle: Decodable {
        let id: Int
        let name: String
        let isoName2: String
        @EsimApiBool var worldwide: Bool
        let bundles: [String: Offer]
        
        struct Offer: Decodable {
            let days: Int
            let price: Double
        }
    }
    
    private struct Country: Decodable {
        let id: Int
        let isoName2: String
        let country: String
        let regionlist: [Int]
        let tc: Double?
    }
    
}
