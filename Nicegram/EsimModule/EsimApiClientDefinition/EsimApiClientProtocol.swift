public protocol EsimApiClientProtocol {
    func send<Response: Decodable>(_: ApiRequest<Response>, completion: ((Result<Response, EsimApiError>) -> ())?)
    func send<Response: Decodable>(_: ApiRequest<Response>, interceptor: EsimApiClientInterceptor, completion: ((Result<Response, EsimApiError>) -> ())?)
    func send(_: ApiRequest<Void>, completion: ((Result<Void, EsimApiError>) -> ())?)
    func send(_: ApiRequest<Void>, interceptor: EsimApiClientInterceptor, completion: ((Result<Void, EsimApiError>) -> ())?)
}
