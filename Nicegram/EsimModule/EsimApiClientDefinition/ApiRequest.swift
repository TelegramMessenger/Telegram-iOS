import Foundation

public struct ApiRequest<Response> {
    public let path: String
    public let method: String
    public let queryParams: [String: String]
    public let body: AnyEncodable?
}

public extension ApiRequest {
    static func get(path: String, queryParams: [String: String] = [:]) -> ApiRequest {
        return ApiRequest(path: path, method: "GET", queryParams: queryParams, body: nil)
    }
    
    static func post(path: String, queryParams: [String: String] = [:], body: Encodable?) -> ApiRequest {
        return ApiRequest(path: path, method: "POST", queryParams: queryParams, body: AnyEncodable(body))
    }
    
    static func put(path: String, queryParams: [String: String] = [:], body: Encodable?) -> ApiRequest {
        return ApiRequest(path: path, method: "PUT", queryParams: queryParams, body: AnyEncodable(body))
    }
    
    static func patch(path: String, queryParams: [String: String] = [:], body: Encodable?) -> ApiRequest {
        return ApiRequest(path: path, method: "PATCH", queryParams: queryParams, body: AnyEncodable(body))
    }
    
    static func delete(path: String, queryParams: [String: String] = [:], body: Encodable?) -> ApiRequest {
        return ApiRequest(path: path, method: "DELETE", queryParams: queryParams, body: AnyEncodable(body))
    }
}
