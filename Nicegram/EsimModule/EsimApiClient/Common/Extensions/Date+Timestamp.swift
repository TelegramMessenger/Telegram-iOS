import Foundation

extension Date {
    func timeStampMillis() -> Int64 {
        return Int64(timeIntervalSince1970 * 1000)
    }
}
