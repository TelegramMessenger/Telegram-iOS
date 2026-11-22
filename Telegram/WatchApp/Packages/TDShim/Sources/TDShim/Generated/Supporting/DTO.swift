//
//  DTO.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


public final class DTO<T: Codable>: Codable {
    let type: String
    var extra: String?
    let payload: T
    let encoder: JSONEncoder?

    public init(_ payload: T, encoder: JSONEncoder? = nil) {
        self.payload = payload
        self.encoder = encoder
        let swiftType = String(describing: T.self)
        self.type = tdLibTypeFromSwiftType(swiftType)  // TODO: replace with protocol
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        extra = try container.decodeIfPresent(String.self, forKey: .extra)
        payload = try T(from: decoder)
        encoder = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(extra, forKey: .extra)
        try payload.encode(to: encoder)
    }
}

extension DTO: TdQuery {

    public func make(with extra: String? = nil) throws -> Data {
        self.extra = extra
        let encoder = self.encoder ?? JSONEncoder()
        return try encoder.encode(self)
    }
}

// MARK: - Type Mapping Helpers
private func tdLibTypeFromSwiftType(_ swiftType: String) -> String {
    if let mapped = mapAmbiguousType(swiftType) {
        return mapped
    }
    return swiftType.prefix(1).lowercased() + swiftType.dropFirst()
}

private func mapAmbiguousType(_ tlType: String) -> String? {
    let mapping = [
        "TdData": "data",
    ]
    return mapping[tlType]
}

private func resolveAmbiguousType(_ tlType: String) -> String {
    return mapAmbiguousType(tlType) ?? tlType
}