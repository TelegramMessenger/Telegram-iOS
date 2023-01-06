import Foundation
import SwiftSignalKit

open class APIFetcher {
    private let baseURL: URL
    
    private var disposable: Disposable?
    private let network: Network
    
    public init(baseURL: String,
                network: Network) {
        guard let url = URL(string: baseURL) else {
            fatalError("no base url provided")
        }
        self.baseURL = url
        self.network = network
    }
    
    public func fetchDateTime(
        region: RequestedRegion = .europe,
        city: RequestedCity = .moscow,
        completion: @escaping (APIResult<WorldTimeResponseDto>) -> () ) {
            let endpoint = AnyEndpoint(
                WorldTimeEndpoint(
                    baseUrl: baseURL,
                    city: city,
                    region: region)
            )
            disposable = (network.request(endpoint: endpoint)
                          |> deliverOnMainQueue)
                .start(next: { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let timeDto):
                        completion(.success(timeDto))
                    }
                })
        }
    
    deinit {
        disposable?.dispose()
    }
}
