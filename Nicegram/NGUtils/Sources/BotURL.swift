import Foundation
import NGCore

public func makeBotUrl(domain: String, startParam: String?) -> URL? {
    return  URL(string: "ncg://resolve")?
        .appendingQuery(key: "domain", value: domain)
        .appendingQuery(key: "start", value: startParam)
}


