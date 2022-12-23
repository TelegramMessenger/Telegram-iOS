import EsimApiClient
import EsimApiClientDefinition

public protocol ApiClient: EsimApiClientProtocol {}

extension EsimApiClient: ApiClient {}
