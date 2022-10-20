import Foundation
import NGModels

public protocol EsimCountriesRemoteDataSource {
    func fetchCountries(completion: ((Result<[EsimCountry], Error>) -> ())?)
}
