import Foundation
import UIKit
import simd

public struct DrawingColor: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
        case position
    }
    
    public static var clear = DrawingColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat
    
    public var position: CGPoint?
    
    public var isClear: Bool {
        return self.red.isZero && self.green.isZero && self.blue.isZero && self.alpha.isZero
    }
    
    public init(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1.0,
        position: CGPoint? = nil
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.position = position
    }
    
    public init(color: UIColor) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        } else if color.getWhite(&red, alpha: &alpha) {
            self.init(red: red, green: red, blue: red, alpha: alpha)
        } else {
            self.init(red: 0.0, green: 0.0, blue: 0.0)
        }
    }
    
    public init(rgb: UInt32) {
        self.init(color: UIColor(rgb: rgb))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.red = try container.decode(CGFloat.self, forKey: .red)
        self.green = try container.decode(CGFloat.self, forKey: .green)
        self.blue = try container.decode(CGFloat.self, forKey: .blue)
        self.alpha = try container.decode(CGFloat.self, forKey: .alpha)
        self.position = try container.decodeIfPresent(CGPoint.self, forKey: .position)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.red, forKey: .red)
        try container.encode(self.green, forKey: .green)
        try container.encode(self.blue, forKey: .blue)
        try container.encode(self.alpha, forKey: .alpha)
        try container.encodeIfPresent(self.position, forKey: .position)
    }
 
    public func withUpdatedRed(_ red: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    public func withUpdatedGreen(_ green: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    public func withUpdatedBlue(_ blue: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: blue,
            alpha: self.alpha
        )
    }
    
    public func withUpdatedAlpha(_ alpha: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: alpha,
            position: self.position
        )
    }
    
    public func withUpdatedPosition(_ position: CGPoint) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha,
            position: position
        )
    }
    
    public func toUIColor() -> UIColor {
        return UIColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    public func toCGColor() -> CGColor {
        return self.toUIColor().cgColor
    }
    
    public func toFloat4() -> vector_float4 {
        return [
            simd_float1(self.red),
            simd_float1(self.green),
            simd_float1(self.blue),
            simd_float1(self.alpha)
        ]
    }
    
    public static func ==(lhs: DrawingColor, rhs: DrawingColor) -> Bool {
        if lhs.red != rhs.red {
            return false
        }
        if lhs.green != rhs.green {
            return false
        }
        if lhs.blue != rhs.blue {
            return false
        }
        if lhs.alpha != rhs.alpha {
            return false
        }
        return true
    }
}
