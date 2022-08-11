import Foundation
import EsimAuth
import NGAppCache
import NGEnv

public extension EsimApiClient {
    static func nicegramClient(auth: EsimAuth?) -> EsimApiClient {
        let baseUrl = URL(string: NGENV.esim_api_url)!
        let apiKey = NGENV.esim_api_key
        let mobileIdentifier = AppCache.mobileIdentifier
        
        if let auth = auth {
            return EsimApiClient(baseUrl: baseUrl, apiKey: apiKey, mobileIdentifier: mobileIdentifier, interceptor: EsimAuthInterceptor(auth: auth))
        } else {
            return EsimApiClient(baseUrl: baseUrl, apiKey: apiKey, mobileIdentifier: mobileIdentifier)
        }
    }
}
