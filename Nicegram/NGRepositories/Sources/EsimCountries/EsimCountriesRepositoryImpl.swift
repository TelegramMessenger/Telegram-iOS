import Foundation
import NGModels
import NGRemoteDataSources

public class EsimCountriesRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let remoteDataSource: EsimCountriesRemoteDataSource
    
    //  MARK: - Logic
    
    private var countries: [EsimCountry]?
    
    //  MARK: - Lifecycle
    
    public init(remoteDataSource: EsimCountriesRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }
    
}

//  MARK: - Repository Impl

extension EsimCountriesRepositoryImpl: EsimCountriesRepository {
    public func fetchCountries(completion: ((Result<[EsimCountry], Error>) -> ())?) {
        if let countries = countries {
            completion?(.success(countries))
        } else {
            refreshCountries(completion: completion)
        }
    }
    
    public func getCountryWith(id: Int) -> EsimCountry? {
        return countries?.first(where: { $0.id == id })
    }
    
    public func getCountriesWith(regionId: Int) -> [EsimCountry] {
        return countries?.filter({ $0.regionIds.contains(regionId) }) ?? []
    }
}

//  MARK: - Private Functions

private extension EsimCountriesRepositoryImpl {
    func refreshCountries(completion: ((Result<[EsimCountry], Error>) -> ())?) {
        remoteDataSource.fetchCountries { result in
            switch result {
            case .success(let countries):
                self.countries = countries
            case .failure(_):
                break
            }
            completion?(result)
        }
    }
}
