import Foundation
import EsimApiClientDefinition

public class ServerLogger {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    private let queue: DispatchQueue
    
    //  MARK: - Logic
    
    private let path = "client-logs"
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol, queue: DispatchQueue = .global(qos: .utility)) {
        self.apiClient = apiClient
        self.queue = queue
    }
    
    //  MARK: - Private Functions

    private func log(payload: Encodable) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let request = ApiRequest<Void>.post(
                path: self.path,
                body: payload
            )
            self.apiClient.send(request, completion: nil)
        }
        
    }
}

extension ServerLogger: Logger {
    public func log(_ info: [String : Encodable]) {
        log(payload: info.mapValues({ AnyEncodable($0) }))
    }
    
    public func log(message: String) {
        log(payload: message)
    }
}
