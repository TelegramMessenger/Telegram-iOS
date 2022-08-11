import Foundation
import EsimApiClientDefinition
import EsimFeatureSimOffers
import NGModels

private struct Response {
    let offers: [EsimOffer]
    let regions: [EsimRegion]
    let countries: [EsimCountry]
}

public class EsimPlansRequestAdaper {
    
    //  MARK: - Dependencies
    
    private let apiCient: EsimApiClientProtocol
    
    //  MARK: - Logic
    
    private var cachedResponse: Response?
    
    private let semaphore = DispatchSemaphore(value: 1)
    
    //  MARK: - Lifecycle
    
    public init(apiCient: EsimApiClientProtocol) {
        self.apiCient = apiCient
    }
    
}

//  MARK: - DataSources

extension EsimPlansRequestAdaper: EsimOffersRemoteDataSource {
    public func fetchOffers(completion: ((Result<[EsimOffer], Error>) -> ())?) {
        fetchPlansSafety { result in
            switch result {
            case .success(let response):
                completion?(.success(response.offers))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

extension EsimPlansRequestAdaper: EsimRegionsRemoteDataSource {
    public func fetchRegions(completion: ((Result<[EsimRegion], Error>) -> ())?) {
        fetchPlansSafety { result in
            switch result {
            case .success(let response):
                completion?(.success(response.regions))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

extension EsimPlansRequestAdaper: EsimCountriesRemoteDataSource {
    public func fetchCountries(completion: ((Result<[EsimCountry], Error>) -> ())?) {
        fetchPlansSafety { result in
            switch result {
            case .success(let response):
                completion?(.success(response.countries))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

//  MARK: - Private Functions

private extension EsimPlansRequestAdaper {
    func fetchPlansSafety(completion: ((Result<Response, Error>) -> ())?) {
        DispatchQueue.global().async {
            self.semaphore.wait()
            if let cachedResponse = self.cachedResponse {
                self.semaphore.signal()
                completion?(.success(cachedResponse))
            } else {
                self.fetchPlans { result in
                    self.semaphore.signal()
                    completion?(result)
                }
            }
        }
    }
    
    func fetchPlans(completion: ((Result<Response, Error>) -> ())?) {
        apiCient.send(.plans()) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let dto):
                let response = self.mapPlansResponse(dto: dto)
                self.cachedResponse = response
                completion?(.success(response))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

//  MARK: - Mapping

private extension EsimPlansRequestAdaper {
    func mapPlansResponse(dto: PlansResponseDTO) -> Response {
        let offers = dto.offers.map({ self.mapEsimOffer(dto: $0) })
        let regions = dto.regions.map({ self.mapEsimRegion(dto: $0) })
        let countries = dto.countries.map({ self.mapEsimCounty(dto: $0) })
        
        return Response(offers: offers, regions: regions, countries: countries)
    }
    
    func mapEsimOffer(dto: EsimOfferDTO) -> EsimOffer {
        let traffic: EsimOffer.Traffic
        switch dto.traffic {
        case .payAsYouGo: traffic = .payAsYouGo
        case .megabytes(let megabytes): traffic = .megabytes(megabytes)
        }
        
        let duration: EsimOffer.Duration
        switch dto.duration {
        case .unlimited: duration = .unlimited
        case .days(let days): duration = .days(days)
        }
        
        return EsimOffer(id: dto.id, title: dto.title, regionId: dto.regionId, regionIsoCode: dto.regionIsoCode, traffic: traffic, duration: duration, price: Money(amount: dto.price, currency: .euro), includePhoneNumber: dto.includePhoneNumber)
    }
    
    func mapEsimRegion(dto: EsimRegionDTO) -> EsimRegion {
        return EsimRegion(id: dto.id, name: dto.name)
    }
    
    func mapEsimCounty(dto: EsimCountryDTO) -> EsimCountry {
        let rate: Money?
        if let amount = dto.payAsYouGoRate {
            rate = Money(amount: amount, currency: .euro)
        } else {
            rate = nil
        }
        return EsimCountry(id: dto.id, isoCode: dto.isoCode, name: dto.name, regionIds: dto.regionIds, payAsYouGoRate: rate)
    }
}
