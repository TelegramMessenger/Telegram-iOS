//
//  Messages.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains a list of messages
public struct Messages: Codable, Equatable, Hashable {

    /// List of messages; messages may be null
    public let messages: [Message]?

    /// Approximate total number of messages found
    public let totalCount: Int


    public init(
        messages: [Message]?,
        totalCount: Int
    ) {
        self.messages = messages
        self.totalCount = totalCount
    }
}

