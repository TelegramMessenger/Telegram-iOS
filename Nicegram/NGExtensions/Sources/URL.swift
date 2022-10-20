import Foundation

public extension URL {
    var queryItems: [String: String] {
        let items = URLComponents(string: absoluteString)?.queryItems ?? []
        var dict = [String: String]()
        items.forEach({ dict[$0.name] = $0.value })
        return dict
    }
    
    func appending(_ queryItem: String, value: String?) -> URL {
        guard var urlComponents = URLComponents(string: absoluteString) else { return self }
        
        let queryItem = URLQueryItem(name: queryItem, value: value)

        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems

        return (urlComponents.url ?? self)
    }
}
