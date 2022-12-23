import EsimApiClientDefinition
import Foundation
import NGCore

public protocol CreateTicketService {
    func createTicket(numbers: [Int], completion: @escaping (Result<LotteryNetworkData, Error>) -> Void)
}

public class CreateTicketServiceImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: ApiClient
    
    //  MARK: - Lifecycle
    
    public init(apiClient: ApiClient) {
        self.apiClient = apiClient
    }
}


extension CreateTicketServiceImpl: CreateTicketService {
    public func createTicket(numbers: [Int], completion: @escaping (Result<LotteryNetworkData, Error>) -> Void) {
        let body = CreateTicketBody(
            number: TicketNumbersDTO(
                numbers: numbers
            )
        )
        apiClient.send(.powerballGenerateTicket(body: body)) { result in
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
    static func powerballGenerateTicket(body: CreateTicketBody) -> ApiRequest<LotteryDataDTO> {
        return .post(path: "powerball/generate-ticket", body: body)
    }
}

//  MARK: - DTO

private struct CreateTicketBody: Encodable {
    let number: TicketNumbersDTO
}
