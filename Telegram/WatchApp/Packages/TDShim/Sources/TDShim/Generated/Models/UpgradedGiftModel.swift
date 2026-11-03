//
//  UpgradedGiftModel.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a model of an upgraded gift
public struct UpgradedGiftModel: Codable, Equatable, Hashable {

    /// True, if the model can be obtained only through gift crafting
    public let isCrafted: Bool

    /// Name of the model
    public let name: String

    /// The rarity of the model
    public let rarity: UpgradedGiftAttributeRarity

    /// The sticker representing the upgraded gift
    public let sticker: Sticker


    public init(
        isCrafted: Bool,
        name: String,
        rarity: UpgradedGiftAttributeRarity,
        sticker: Sticker
    ) {
        self.isCrafted = isCrafted
        self.name = name
        self.rarity = rarity
        self.sticker = sticker
    }
}

