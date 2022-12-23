import EsimApiClientDefinition
import Foundation
import NGCore

public protocol LoadLotteryDataNetworkService {
    func loadLotteryData(completion: @escaping (Result<LotteryNetworkData, Error>) -> Void)
}

public class LoadLotteryDataNetworkServiceImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: ApiClient
    
    //  MARK: - Lifecycle
    
    public init(apiClient: ApiClient) {
        self.apiClient = apiClient
    }
}


extension LoadLotteryDataNetworkServiceImpl: LoadLotteryDataNetworkService {
    public func loadLotteryData(completion: @escaping (Result<LotteryNetworkData, Error>) -> Void) {
        apiClient.send(.powerballUserInfo()) { result in
            switch result {
            case .success(let dto):
                completion(.success(dto.mapToLotteryData()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

//  MARK: - ApiRequests Factory

private extension ApiRequest {
    static func powerballUserInfo() -> ApiRequest<LotteryDataDTO> {
        return .get(path: "powerball/user-info")
    }
}
