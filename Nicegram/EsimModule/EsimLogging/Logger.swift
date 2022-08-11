import Foundation

public protocol Logger {
    func log(message: String)
    func log(_: [String: Encodable])
}
