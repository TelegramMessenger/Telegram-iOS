import Foundation
import NGModels

public protocol EsimOffersRemoteDataSource {
    func fetchOffers(completion: ((Result<[EsimOffer], Error>) -> ())?)
}
