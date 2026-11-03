// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/18/18.
//

import Foundation

struct DateBox: Equatable, Sendable {
    enum Format: Equatable {
        case secondsSince1970
        case millisecondsSince1970
        case iso8601
        case formatter(DateFormatter)
    }

    typealias Unboxed = Date

    let unboxed: Unboxed
    let format: Format

    init(_ unboxed: Unboxed, format: Format) {
        self.unboxed = unboxed
        self.format = format
    }

    init?(secondsSince1970 string: String) {
        guard let seconds = TimeInterval(string) else {
            return nil
        }
        let unboxed = Date(timeIntervalSince1970: seconds)
        self.init(unboxed, format: .secondsSince1970)
    }

    init?(millisecondsSince1970 string: String) {
        guard let milliseconds = TimeInterval(string) else {
            return nil
        }
        let unboxed = Date(timeIntervalSince1970: milliseconds / 1000.0)
        self.init(unboxed, format: .millisecondsSince1970)
    }

    init?(iso8601 string: String) {
        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            guard let unboxed =  ISO8601DateFormatter.xmlCoderFormatter().date(from: string) else {
                return nil
            }
            self.init(unboxed, format: .iso8601)
        } else {
            fatalError("ISO8601DateFormatter is unavailable on this platform.")
        }
    }

    init?(xmlString: String, formatter: DateFormatter) {
        guard let date = formatter.date(from: xmlString) else {
            return nil
        }
        self.init(date, format: .formatter(formatter))
    }

    func xmlString(format: Format) -> String {
        switch format {
        case .secondsSince1970:
            let seconds = unboxed.timeIntervalSince1970
            return seconds.description
        case .millisecondsSince1970:
            let milliseconds = unboxed.timeIntervalSince1970 * 1000.0
            return milliseconds.description
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                return ISO8601DateFormatter.xmlCoderFormatter().string(from: self.unboxed)
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case let .formatter(formatter):
            return formatter.string(from: unboxed)
        }
    }
}

extension DateBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return xmlString(format: format)
    }
}

extension DateBox: SimpleBox {}

extension DateBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
