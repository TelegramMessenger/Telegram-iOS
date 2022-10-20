import Foundation

public func extractNameFromPath(_ path: String) -> String {
    let fileName = URL(fileURLWithPath: path).lastPathComponent
    return String(fileName.prefix(upTo: fileName.lastIndex { $0 == "." } ?? fileName.endIndex))
}
