import Foundation
import EsimApiClientDefinition
import EsimApiClient
import EsimAuth
import NGAppCache
import NGEnv

public func createNicegramApiClient(auth: EsimAuth?, trackMobileIdentifier: Bool = true) -> EsimApiClient {
    let baseUrl = URL(string: NGENV.esim_api_url)!
    let apiKey = NGENV.esim_api_key
    let mobileIdentifier = trackMobileIdentifier ? AppCache.mobileIdentifier : ""
    
    if let auth = auth {
        return EsimApiClient(baseUrl: baseUrl, apiKey: apiKey, mobileIdentifier: mobileIdentifier, interceptor: EsimAuthInterceptor(auth: auth))
    } else {
        return EsimApiClient(baseUrl: baseUrl, apiKey: apiKey, mobileIdentifier: mobileIdentifier)
    }
}
