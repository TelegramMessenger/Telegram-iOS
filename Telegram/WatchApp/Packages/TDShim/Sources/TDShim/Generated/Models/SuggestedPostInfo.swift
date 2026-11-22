//
//  SuggestedPostInfo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a suggested post. If the post can be approved or declined, then changes to the post can be also suggested. Use sendMessage with reply to the message and suggested post information to suggest message changes. Use addOffer to suggest price or time changes
public struct SuggestedPostInfo: Codable, Equatable, Hashable {

    /// True, if the suggested post can be approved by the current user using approveSuggestedPost; updates aren't sent when value of this field changes
    public let canBeApproved: Bool

    /// True, if the suggested post can be declined by the current user using declineSuggestedPost; updates aren't sent when value of this field changes
    public let canBeDeclined: Bool

    /// Price of the suggested post; may be null if the post is non-paid
    public let price: SuggestedPostPrice?

    /// Point in time (Unix timestamp) when the post is expected to be published; 0 if the specific date isn't set yet
    public let sendDate: Int

    /// State of the post
    public let state: SuggestedPostState


    public init(
        canBeApproved: Bool,
        canBeDeclined: Bool,
        price: SuggestedPostPrice?,
        sendDate: Int,
        state: SuggestedPostState
    ) {
        self.canBeApproved = canBeApproved
        self.canBeDeclined = canBeDeclined
        self.price = price
        self.sendDate = sendDate
        self.state = state
    }
}

