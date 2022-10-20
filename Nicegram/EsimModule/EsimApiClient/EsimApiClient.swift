import Foundation
import DeviceKit
import EsimApiClientDefinition

public class EsimApiClient {
    
    //  MARK: - Private Properties
    
    private var baseUrl: URL
    private var apiKey: String
    private var mobileIdentifier: String
    
    private var session: URLSession
    private var interceptor: EsimApiClientInterceptor
    
    //  MARK: - Lifecycle
    
    public init(baseUrl: URL, apiKey: String, mobileIdentifier: String, session: URLSession = .shared, interceptor: EsimApiClientInterceptor = EsimDefaultInterceptor()) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.mobileIdentifier = mobileIdentifier
        self.session = session
        self.interceptor = interceptor
    }
    
    //  MARK: - Private Functions
    
    private func send<Response: Decodable>(_ request: URLRequest, interceptor: EsimApiClientInterceptor?, retryCount: Int, completion: ((Result<Response, EsimApiError>) -> ())?) {
        let interceptor = interceptor ?? self.interceptor
        
        interceptor.adapt(request) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let request):
                self.send(request) { data, response, error in
                    do {
                        let response: Response = try self.parse(data, response, error)
                        completion?(.success(response))
                    } catch let esimApiError as EsimApiError {
                        interceptor.retry(request, dueTo: esimApiError, withCurrentRetryCount: retryCount) { retryResult in
                            switch retryResult {
                            case .retry:
                                self.send(request, interceptor: interceptor, retryCount: retryCount + 1, completion: completion)
                            case .doNotRetry:
                                completion?(.failure(esimApiError))
                            }
                        }
                    } catch {
                        completion?(.failure(.underlying(error)))
                    }
                }
            case .failure(let error):
                completion?(.failure(.underlying(error)))
            }
        }
    }
    
    private func internalSend<Response: Decodable>(_ apiRequest: ApiRequest<Response>, interceptor: EsimApiClientInterceptor?, completion: ((Result<Response, EsimApiError>) -> ())?) {
        send(toUrlRequest(apiRequest), interceptor: interceptor, retryCount: 0, completion: completion)
    }
    
    private func internalSend(_ apiRequest: ApiRequest<Void>, interceptor: EsimApiClientInterceptor?, completion: ((Result<Void, EsimApiError>) -> ())?) {
        send(toUrlRequest(apiRequest), interceptor: interceptor, retryCount: 0) { (result: Result<AnyResponse?, EsimApiError>) in
            switch result {
            case .success(_):
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    private func parse<Response: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?) throws -> Response {
        if let error = error {
            throw EsimApiError.connection(error)
        }
        
        guard let data = data else { throw EsimApiError.unexpected }
        
        let response = try JSONDecoder().decode(EsimApiResponse<Response>.self, from: data)
        let payload = try self.parse(response)
        return payload
    }
    
    private func parse<Response>(_ response: EsimApiResponse<Response>) throws -> Response {
        switch response {
        case .success(let payload):
            return payload
        case .failure(let status, let message, let payload):
            switch status {
            case 401: throw EsimApiError.notAuthorized(message)
            default: throw EsimApiError.someServerError(.init(code: status, message: message, payload: payload))
            }
        }
    }
    
    //  MARK: - Private Helpers
    
    private func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        session.dataTask(with: request, completionHandler: completion).resume()
    }
    
    private func toUrlRequest<Response>(_ apiRequest: ApiRequest<Response>) -> URLRequest {
        let url = baseUrl.appendingPathComponent(apiRequest.path)
        
        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.method
        request.queryItems = apiRequest.queryParams.map({ .init(name: $0.key, value: $0.value) })
        
        let httpBody: Data?
        if let body = apiRequest.body {
            httpBody = try? JSONEncoder().encode(body)
        } else {
            httpBody = nil
        }
        
        request.httpBody = httpBody
        request = request.applying(headers: generateHeaders(httpBody: httpBody))
        
        return request
    }
    
    private func generateHeaders(httpBody: Data?) -> [String: String] {
        let timestamp = String(Date().timeStampMillis())
        
        var token: String = ""
        #if canImport(CryptoKit)
        let bodyBase64 = httpBody?.base64EncodedString() ?? ""
        token = [bodyBase64, apiKey].joined().sha256
        #endif
        
        let headers: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-identifier": mobileIdentifier,
            "X-agent": "\(Device.current)",
            "X-timestamp": timestamp,
            "X-token": token,
            "X-iOS-version": App.appVersionNumber,
            "X-iOS-build": App.appBuildNumber,
            "X-language": App.appLanguageCode ?? "en"
        ]
        
        return headers
    }
}

extension EsimApiClient: EsimApiClientProtocol {
    public func send<Response>(_ apiRequest: ApiRequest<Response>, completion: ((Result<Response, EsimApiError>) -> ())?) where Response : Decodable {
        internalSend(apiRequest, interceptor: nil, completion: completion)
    }
    
    public func send<Response>(_ apiRequest: ApiRequest<Response>, interceptor: EsimApiClientInterceptor, completion: ((Result<Response, EsimApiError>) -> ())?) where Response : Decodable {
        internalSend(apiRequest, interceptor: interceptor, completion: completion)
    }
    
    public func send(_ apiRequest: ApiRequest<Void>, completion: ((Result<Void, EsimApiError>) -> ())?) {
        internalSend(apiRequest, interceptor: nil, completion: completion)
    }
    
    public func send(_ apiRequest: ApiRequest<Void>, interceptor: EsimApiClientInterceptor, completion: ((Result<Void, EsimApiError>) -> ())?) {
        internalSend(apiRequest, interceptor: interceptor, completion: completion)
    }
}

//  MARK: - DTO Functions

private enum EsimApiResponse<Payload: Decodable>: Decodable {
    case success(Payload)
    case failure(status: Int, message: String, payload: SingleValueDecodingContainer?)
    
    enum CodingKeys: String, CodingKey {
        case data
        case status
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let status = try container.decode(Int.self, forKey: .status)
        if status == 200 {
            let payload = try container.decode(Payload.self, forKey: .data)
            self = .success(payload)
        } else {
            let payload = try? container.superDecoder(forKey: .data).singleValueContainer()
            let message = try container.decode(String.self, forKey: .message)
            self = .failure(status: status, message: message, payload: payload)
        }
    }
}

private struct AnyResponse: Decodable {}
