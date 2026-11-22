//
//  Venue.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a venue
public struct Venue: Codable, Equatable, Hashable, Identifiable {

    /// Venue address; as defined by the sender
    public let address: String

    /// Identifier of the venue in the provider database; as defined by the sender
    public let id: String

    /// Venue location; as defined by the sender
    public let location: Location

    /// Provider of the venue database; as defined by the sender. Currently, only "foursquare" and "gplaces" (Google Places) need to be supported
    public let provider: String

    /// Venue name; as defined by the sender
    public let title: String

    /// Type of the venue in the provider database; as defined by the sender
    public let type: String


    public init(
        address: String,
        id: String,
        location: Location,
        provider: String,
        title: String,
        type: String
    ) {
        self.address = address
        self.id = id
        self.location = location
        self.provider = provider
        self.title = title
        self.type = type
    }
}

