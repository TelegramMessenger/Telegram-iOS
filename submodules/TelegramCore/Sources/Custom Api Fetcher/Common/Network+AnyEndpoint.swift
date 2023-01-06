import Foundation
import SwiftSignalKit

public typealias APIResult<Value> = Swift.Result<Value, Error>

extension Network {
    public func request<T>(endpoint: AnyEndpoint<T>) -> Signal<APIResult<T>, Error> {
        return Signal { subsciber in
            let task = URLSession.shared.dataTask(with: endpoint.makeRequest()) { data, response, error in
                if let error {
                    subsciber.putError(error)
                    return
                }
                let result = APIResult<T> { () throws -> T in
                    return try endpoint.content(from: response, with: data.unsafelyUnwrapped)
                }
                subsciber.putNext(result)
                subsciber.putCompletion()
            }
            task.resume()
            return EmptyDisposable
        }
    }
}
