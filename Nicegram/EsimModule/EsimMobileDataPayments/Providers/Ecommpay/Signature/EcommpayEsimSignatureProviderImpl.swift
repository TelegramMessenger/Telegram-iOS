import EsimApiClientDefinition
import EsimPayments

public class EcommpayEsimSignatureProviderImpl  {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol) {
        self.apiClient = apiClient
    }
}

extension EcommpayEsimSignatureProviderImpl: EcommpayEsimSignatureProvider {
    public func getSignature(signatureParams: String, regionId: Int, bundleId: Int, icc: String?, completion: @escaping (Result<String, EcommpaySignatureError>) -> ()) {
        apiClient.send(.getSignature(signatureParams: signatureParams, regionId: regionId, bundleId: bundleId, icc: icc)) { result in
            switch result {
            case .success(let dto):
                completion(.success(dto.data))
            case .failure(let esimApiError):
                completion(.failure(.underlying(esimApiError)))
            }
        }
    }
}

//  MARK: - ApiRequest Factory

private extension ApiRequest {
    static func getSignature(signatureParams: String, regionId: Int, bundleId: Int, icc: String?) -> ApiRequest<SignatureResponse> {
        let updateCurrentBundle = (icc != nil) ? 1 : 0
        let body = SignatureBody(regionId: regionId, bundleId: bundleId, updateCurrentBundle: updateCurrentBundle, icc: icc, data: signatureParams)
        return .post(path: "signature-and-lock", body: body)
    }
}

//  MARK: - DTO

private struct SignatureBody: Encodable {
    let regionId: Int
    let bundleId: Int
    let updateCurrentBundle: Int
    let icc: String?
    let data: String
}

private struct SignatureResponse: Decodable {
    let data: String
}
