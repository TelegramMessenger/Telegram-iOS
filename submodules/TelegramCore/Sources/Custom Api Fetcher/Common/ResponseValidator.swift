import Foundation

public struct HTTPError: Error {
    public let statusCode: Int
    public let url: URL?

    public var localizedDescription: String {
        return HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }
}

internal enum ResponseValidator {

    internal static func validate(_ response: URLResponse?, with body: Data) throws {
        try validateHTTPstatus(response)
    }

    private static func validateHTTPstatus(_ response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              !(200..<300).contains(httpResponse.statusCode) else { return }

        throw HTTPError(statusCode: httpResponse.statusCode, url: httpResponse.url)
    }
}
