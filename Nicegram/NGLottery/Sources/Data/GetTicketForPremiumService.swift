import EsimApiClientDefinition
import Foundation
import NGCore

public protocol GetTicketForPremiumService {
    func getTicket(receiptData: Data, completion: @escaping (Result<LotteryNetworkData, Error>) -> Void)
}

public class GetTicketForPremiumServiceImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: ApiClient
    
    //  MARK: - Lifecycle
    
    public init(apiClient: ApiClient) {
        self.apiClient = apiClient
    }
}


extension GetTicketForPremiumServiceImpl: GetTicketForPremiumService {
    public func getTicket(receiptData: Data, completion: @escaping (Result<LotteryNetworkData, Error>) -> Void) {
        let body = TicketForSubscriptionBody(
            receipt: receiptData.base64EncodedString()
        )
        apiClient.send(.powerballTicketForSubscription(body: body)) { result in
            switch result {
            case .success(let success):
                completion(.success(success.mapToLotteryData()))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
}

//  MARK: - ApiRequests Factory

private extension ApiRequest {
    static func powerballTicketForSubscription(body: TicketForSubscriptionBody) -> ApiRequest<LotteryDataDTO> {
        return .post(path: "powerball/apple/receive-ticket", body: body)
    }
}

//  MARK: - DTO

private struct TicketForSubscriptionBody: Encodable {
    let receipt: String
}
