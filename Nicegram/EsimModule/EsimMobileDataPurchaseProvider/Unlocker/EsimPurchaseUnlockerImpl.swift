import EsimApiClientDefinition

public class EsimPurchaseUnlockerImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol) {
        self.apiClient = apiClient
    }
}

//  MARK: - EsimPurchaseUnlocker

extension EsimPurchaseUnlockerImpl: EsimPurchaseUnlocker {
    public func unlock(paymentId: String?, completion: ((Result<(), Error>) -> ())?) {
        apiClient.send(.unlock(paymentId: paymentId)) { result in
            switch result {
            case .success(_):
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}


//  MARK: - ApiRequest Factory

private extension ApiRequest {
    static func unlock(paymentId: String?) -> ApiRequest<Void> {
        let body = UnlockBody(paymentId: paymentId)
        return .post(path: "unlock", body: body)
    }
}

//  MARK: - DTO

private struct UnlockBody: Encodable {
    let paymentId: String?
}
