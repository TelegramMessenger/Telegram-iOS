import Foundation
import NGModels
import NGRemoteDataSources

public class EsimOffersRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let remoteDataSource: EsimOffersRemoteDataSource
    
    //  MARK: - Logic
    
    private var offers: [EsimOffer]?
    
    //  MARK: - Lifecycle
    
    public init(remoteDataSource: EsimOffersRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }
    
}

//  MARK: - Repository Impl

extension EsimOffersRepositoryImpl: EsimOffersRepository {
    public func fetchOffers(completion: ((Result<[EsimOffer], Error>) -> ())?) {
        if let offers = offers {
            completion?(.success(offers))
        } else {
            refreshOffers(completion: completion)
        }
    }
    
    public func getOffersWith(regionId: Int) -> [EsimOffer] {
        return offers?.filter({ $0.regionId == regionId }) ?? []
    }
}

//  MARK: - Private Functions

private extension EsimOffersRepositoryImpl {
    func refreshOffers(completion: ((Result<[EsimOffer], Error>) -> ())?) {
        remoteDataSource.fetchOffers { result in
            switch result {
            case .success(let offers):
                self.offers = offers
            case .failure(_):
                break
            }
            completion?(result)
        }
    }
}
