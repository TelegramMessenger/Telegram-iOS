import Foundation
import NGModels

public protocol EsimOffersRepository {
    func fetchOffers(completion: ((Result<[EsimOffer], Error>) -> ())?)
    func getOffersWith(regionId: Int) -> [EsimOffer]
}
