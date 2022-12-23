import Foundation

public extension URL {
    var queryItems: [String: String] {
        get {
            guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                return [:]
            }
            
            var dict: [String: String] = [:]
            for item in queryItems {
                dict[item.name] = item.value
            }
            
            return dict
        } set {
            guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
                return
            }
            components.queryItems = newValue.map {  URLQueryItem(name: $0.key, value: $0.value) }
            
            self = components.url ?? self
        }
    }
    
    func appendingQuery(key: String, value: String?) -> URL {
        var url = self
        if let value {
            url.queryItems[key] = value
        }
        return url
    }
}
