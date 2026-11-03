//
//  DiceStickers.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains animated stickers which must be used for dice animation rendering
public indirect enum DiceStickers: Codable, Equatable, Hashable {

    /// A regular animated sticker
    case diceStickersRegular(DiceStickersRegular)

    /// Animated stickers to be combined into a slot machine
    case diceStickersSlotMachine(DiceStickersSlotMachine)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case diceStickersRegular
        case diceStickersSlotMachine
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .diceStickersRegular:
            let value = try DiceStickersRegular(from: decoder)
            self = .diceStickersRegular(value)
        case .diceStickersSlotMachine:
            let value = try DiceStickersSlotMachine(from: decoder)
            self = .diceStickersSlotMachine(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .diceStickersRegular(let value):
            try container.encode(Kind.diceStickersRegular, forKey: .type)
            try value.encode(to: encoder)
        case .diceStickersSlotMachine(let value):
            try container.encode(Kind.diceStickersSlotMachine, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A regular animated sticker
public struct DiceStickersRegular: Codable, Equatable, Hashable {

    /// The animated sticker with the dice animation
    public let sticker: Sticker


    public init(sticker: Sticker) {
        self.sticker = sticker
    }
}

/// Animated stickers to be combined into a slot machine
public struct DiceStickersSlotMachine: Codable, Equatable, Hashable {

    /// The animated sticker with the slot machine background. The background animation must start playing after all reel animations finish
    public let background: Sticker

    /// The animated sticker with the center reel
    public let centerReel: Sticker

    /// The animated sticker with the left reel
    public let leftReel: Sticker

    /// The animated sticker with the lever animation. The lever animation must play once in the initial dice state
    public let lever: Sticker

    /// The animated sticker with the right reel
    public let rightReel: Sticker


    public init(
        background: Sticker,
        centerReel: Sticker,
        leftReel: Sticker,
        lever: Sticker,
        rightReel: Sticker
    ) {
        self.background = background
        self.centerReel = centerReel
        self.leftReel = leftReel
        self.lever = lever
        self.rightReel = rightReel
    }
}

