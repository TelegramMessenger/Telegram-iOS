//
//  UpgradedGiftBackdrop.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a backdrop of an upgraded gift
public struct UpgradedGiftBackdrop: Codable, Equatable, Hashable, Identifiable {

    /// Colors of the backdrop
    public let colors: UpgradedGiftBackdropColors

    /// Unique identifier of the backdrop
    public let id: Int

    /// Name of the backdrop
    public let name: String

    /// The rarity of the backdrop
    public let rarity: UpgradedGiftAttributeRarity


    public init(
        colors: UpgradedGiftBackdropColors,
        id: Int,
        name: String,
        rarity: UpgradedGiftAttributeRarity
    ) {
        self.colors = colors
        self.id = id
        self.name = name
        self.rarity = rarity
    }
}

