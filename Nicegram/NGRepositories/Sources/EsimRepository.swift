import Foundation
import NGModels

public protocol EsimRepository: EsimOffersRepository, EsimRegionsRepository, EsimCountriesRepository, UserEsimsRepository {
    func fetch(completion: ((Result<(), Error>) -> ())?)
}

public class EsimRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let offersRepository: EsimOffersRepository
    private let regionsRepository: EsimRegionsRepository
    private let countriesRepository: EsimCountriesRepository
    private let userEsimsRepository: UserEsimsRepository
    
    //  MARK: - Lifecycle
    
    public init(offersRepository: EsimOffersRepository, regionsRepository: EsimRegionsRepository, countriesRepository: EsimCountriesRepository, userEsimsRepository: UserEsimsRepository) {
        self.offersRepository = offersRepository
        self.regionsRepository = regionsRepository
        self.countriesRepository = countriesRepository
        self.userEsimsRepository = userEsimsRepository
    }
}

//  MARK: - EsimOffersRepository

extension EsimRepositoryImpl: EsimOffersRepository {
    public func fetchOffers(completion: ((Result<[EsimOffer], Error>) -> ())?) {
        offersRepository.fetchOffers(completion: completion)
    }
    
    public func getOffersWith(regionId: Int) -> [EsimOffer] {
        return offersRepository.getOffersWith(regionId: regionId)
    }
}

//  MARK: - EsimRegionsRepository

extension EsimRepositoryImpl: EsimRegionsRepository {
    public func fetchRegions(completion: ((Result<[EsimRegion], Error>) -> ())?) {
        regionsRepository.fetchRegions(completion: completion)
    }
    
    public func getRegionWith(id: Int) -> EsimRegion? {
        return regionsRepository.getRegionWith(id: id)
    }
}

//  MARK: - EsimCountriesRepository

extension EsimRepositoryImpl: EsimCountriesRepository {
    public func fetchCountries(completion: ((Result<[EsimCountry], Error>) -> ())?) {
        countriesRepository.fetchCountries(completion: completion)
    }
    
    public func getCountryWith(id: Int) -> EsimCountry? {
        return countriesRepository.getCountryWith(id: id)
    }
    
    public func getCountriesWith(regionId: Int) -> [EsimCountry] {
        return countriesRepository.getCountriesWith(regionId: regionId)
    }
}

//  MARK: - UserEsimsRepository

extension EsimRepositoryImpl: UserEsimsRepository {
    public func getUserEsims() -> [UserEsim]? {
        return userEsimsRepository.getUserEsims()
    }
    
    public func fetchAllEsims(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?) {
        userEsimsRepository.fetchAllEsims(completion: completion)
    }
    
    public func refreshEsims(ids: [String], completion: ((Result<[UserEsim], Error>) -> ())?) {
        userEsimsRepository.refreshEsims(ids: ids, completion: completion)
    }
    
    public func getEsim(with id: String) -> UserEsim? {
        return userEsimsRepository.getEsim(with: id)
    }
    
    public func addEsim(_ esim: UserEsim) {
        userEsimsRepository.addEsim(esim)
    }
    
    public func updateEsim(_ esim: UserEsim) {
        userEsimsRepository.updateEsim(esim)
    }
    
    public func clear() {
        userEsimsRepository.clear()
    }
}

//  MARK: - EsimRepository

extension EsimRepositoryImpl: EsimRepository {
    public func fetch(completion: ((Result<(), Error>) -> ())?) {
        let group = DispatchGroup()
        
        var error: Error?

        group.enter()
        offersRepository.fetchOffers { result in
            error = result.getError()
            group.leave()
        }

        group.enter()
        regionsRepository.fetchRegions { result in
            error = result.getError()
            group.leave()
        }

        group.enter()
        countriesRepository.fetchCountries { result in
            error = result.getError()
            group.leave()
        }

        group.notify(queue: .main) {
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
}

//  MARK: - Helpers

private extension Result {
    func getError() -> Failure? {
        switch self {
        case .success(_): return nil
        case .failure(let failure): return failure
        }
    }
}
