import Foundation

extension URLRequest {
    var queryItems: [URLQueryItem]? {
        get {
            return urlComponents?.queryItems
        } set {
            guard var urlComponents = urlComponents else { return }
            urlComponents.queryItems = newValue
            url = urlComponents.url
        }
    }
    
    var urlComponents: URLComponents? {
        guard let absoluteString = url?.absoluteString else { return nil }
        return .init(string: absoluteString)
    }
}

extension URLRequest {
    func applying(headers: [String: String]) -> URLRequest {
        var request = self
        headers.forEach({ request.setValue($0.value, forHTTPHeaderField: $0.key) })
        return request
    }
}
