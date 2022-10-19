import Foundation
import EsimAuth

public extension EsimApiClient {
    static func requiringAuthClient(baseURL: URL, apiKey: String, mobileIdentifier: String, auth: EsimAuth) -> EsimApiClient {
        let interceptor = EsimAuthInterceptor(auth: auth)
        return EsimApiClient(baseUrl: baseURL, apiKey: apiKey, mobileIdentifier: mobileIdentifier, interceptor: interceptor)
    }
}
