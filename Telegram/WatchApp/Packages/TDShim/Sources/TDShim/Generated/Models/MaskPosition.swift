//
//  MaskPosition.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Position on a photo where a mask is placed
public struct MaskPosition: Codable, Equatable, Hashable {

    /// Part of the face, relative to which the mask is placed
    public let point: MaskPoint

    /// Mask scaling coefficient. (For example, 2.0 means a doubled size)
    public let scale: Double

    /// Shift by X-axis measured in widths of the mask scaled to the face size, from left to right. (For example, -1.0 will place the mask just to the left of the default mask position)
    public let xShift: Double

    /// Shift by Y-axis measured in heights of the mask scaled to the face size, from top to bottom. (For example, 1.0 will place the mask just below the default mask position)
    public let yShift: Double


    public init(
        point: MaskPoint,
        scale: Double,
        xShift: Double,
        yShift: Double
    ) {
        self.point = point
        self.scale = scale
        self.xShift = xShift
        self.yShift = yShift
    }
}

