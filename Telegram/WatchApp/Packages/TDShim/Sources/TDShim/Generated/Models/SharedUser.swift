//
//  SharedUser.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a user shared with a bot
public struct SharedUser: Codable, Equatable, Hashable {

    /// First name of the user; for bots only
    public let firstName: String

    /// Last name of the user; for bots only
    public let lastName: String

    /// Profile photo of the user; for bots only; may be null
    public let photo: Photo?

    /// User identifier
    public let userId: Int64

    /// Username of the user; for bots only
    public let username: String


    public init(
        firstName: String,
        lastName: String,
        photo: Photo?,
        userId: Int64,
        username: String
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.photo = photo
        self.userId = userId
        self.username = username
    }
}

