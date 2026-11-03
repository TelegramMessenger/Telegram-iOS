//
//  UpgradedGiftBackdropColors.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes colors of a backdrop of an upgraded gift
public struct UpgradedGiftBackdropColors: Codable, Equatable, Hashable {

    /// A color in the center of the backdrop in the RGB format
    public let centerColor: Int

    /// A color on the edges of the backdrop in the RGB format
    public let edgeColor: Int

    /// A color to be applied for the symbol in the RGB format
    public let symbolColor: Int

    /// A color for the text on the backdrop in the RGB format
    public let textColor: Int


    public init(
        centerColor: Int,
        edgeColor: Int,
        symbolColor: Int,
        textColor: Int
    ) {
        self.centerColor = centerColor
        self.edgeColor = edgeColor
        self.symbolColor = symbolColor
        self.textColor = textColor
    }
}

