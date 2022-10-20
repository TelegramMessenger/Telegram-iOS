import Foundation
import NGModels

public protocol EsimCountriesRepository {
    func fetchCountries(completion: ((Result<[EsimCountry], Error>) -> ())?)
    func getCountryWith(id: Int) -> EsimCountry?
    func getCountriesWith(regionId: Int) -> [EsimCountry]
}
