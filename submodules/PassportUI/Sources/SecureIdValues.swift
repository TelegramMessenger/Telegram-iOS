import Foundation
import TelegramCore

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

extension SecureIdDate {
    init?(timestamp: Int32) {
        let serializedString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        let data = serializedString.components(separatedBy: ".")
        guard data.count == 3 else {
            return nil
        }
        guard let day = Int32(data[0]), let month = Int32(data[1]), let year = Int32(data[2]) else {
            return nil
        }
        self.init(day: day, month: month, year: year)
    }
    
    var timestamp: Int32 {
        if let date = dateFormatter.date(from: "\(self.day).\(self.month).\(self.year)") {
            return Int32(date.timeIntervalSince1970)
        } else {
            return 0
        }
    }
}
