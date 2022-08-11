import EsimApiClientDefinition
import EsimDTO

public class EsimPurchaseCompletenerImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol) {
        self.apiClient = apiClient
    }
}

//  MARK: - EsimPurchaseCompletener

extension EsimPurchaseCompletenerImpl: EsimPurchaseCompletener {
    public func completePurchase(icc: String?, regionId: Int, bundleId: Int, paymentId: String, paymentType: PaymentType, completion: @escaping (Result<EsimPurchaseResponse, Error>) -> ()) {
        apiClient.send(.completeEsimPurchase(icc: icc, regionId: regionId, bundleId: bundleId, paymentId: paymentId, paymentType: paymentType)) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let dto):
                completion(.success(self.mapReponseDto(dto)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

//  MARK: - Mapping

private extension EsimPurchaseCompletenerImpl {
    func mapReponseDto(_ dto: UserEsimResponseDTO) -> EsimPurchaseResponse {
        return EsimPurchaseResponse(esim: dto.esim)
    }
}

//  MARK: - ApiRequest Factory

private extension ApiRequest {
    static func completeEsimPurchase(icc: String?, regionId: Int, bundleId: Int, paymentId: String, paymentType: PaymentType) -> ApiRequest<UserEsimResponseDTO> {
        let paymentTypeString: String
        switch paymentType {
        case .ecommpay: paymentTypeString = "ecommpay"
        }
        
        let body = CompleteEsimPurchaseBody(regionId: regionId, bundleId: bundleId, paymentId: paymentId, paymentType: paymentTypeString)

        if let icc = icc {
            return .patch(path: "profile/\(icc)", body: body)
        } else {
            return .post(path: "profile", body: body)
        }
    }
}

//  MARK: - DTO

private struct CompleteEsimPurchaseBody: Encodable {
    let regionId: Int
    let bundleId: Int
    let paymentId: String
    let paymentType: String
}
