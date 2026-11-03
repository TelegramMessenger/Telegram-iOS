//
//  DateTimeFormattingType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes date and time formatting
public indirect enum DateTimeFormattingType: Codable, Equatable, Hashable {

    /// The time must be shown relative to the current time ([in ] X seconds, minutes, hours, days, months, years [ago])
    case dateTimeFormattingTypeRelative

    /// The date and time must be shown as absolute timestamps
    case dateTimeFormattingTypeAbsolute(DateTimeFormattingTypeAbsolute)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case dateTimeFormattingTypeRelative
        case dateTimeFormattingTypeAbsolute
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .dateTimeFormattingTypeRelative:
            self = .dateTimeFormattingTypeRelative
        case .dateTimeFormattingTypeAbsolute:
            let value = try DateTimeFormattingTypeAbsolute(from: decoder)
            self = .dateTimeFormattingTypeAbsolute(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .dateTimeFormattingTypeRelative:
            try container.encode(Kind.dateTimeFormattingTypeRelative, forKey: .type)
        case .dateTimeFormattingTypeAbsolute(let value):
            try container.encode(Kind.dateTimeFormattingTypeAbsolute, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The date and time must be shown as absolute timestamps
public struct DateTimeFormattingTypeAbsolute: Codable, Equatable, Hashable {

    /// The precision with which the date is shown
    public let datePrecision: DateTimePartPrecision

    /// True, if the day of week must be shown
    public let showDayOfWeek: Bool

    /// The precision with which hours, minutes and seconds are shown
    public let timePrecision: DateTimePartPrecision


    public init(
        datePrecision: DateTimePartPrecision,
        showDayOfWeek: Bool,
        timePrecision: DateTimePartPrecision
    ) {
        self.datePrecision = datePrecision
        self.showDayOfWeek = showDayOfWeek
        self.timePrecision = timePrecision
    }
}

