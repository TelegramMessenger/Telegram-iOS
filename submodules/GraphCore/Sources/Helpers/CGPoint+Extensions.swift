//
//  CGPoint+Extensions.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension CGPoint {
    public init(vector: CGVector) {
        self.init(x: vector.dx, y: vector.dy)
    }
    
    
    public init(angle: CGFloat) {
        self.init(x: cos(angle), y: sin(angle))
    }
    
    
    public mutating func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        x += dx
        y += dy
        return self
    }
    
    public func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    public func lengthSquared() -> CGFloat {
        return x*x + y*y
    }
    
    func normalized() -> CGPoint {
        let len = length()
        return len>0 ? self / len : CGPoint.zero
    }
    
    public mutating func normalize() -> CGPoint {
        self = normalized()
        return self
    }
    
    public func distanceTo(_ point: CGPoint) -> CGFloat {
        return (self - point).length()
    }
    
    public var angle: CGFloat {
        return atan2(y, x)
    }
    
    public var cgSize: CGSize {
        return CGSize(width: x, height: y)
    }
    
    func rotate(origin: CGPoint, angle: CGFloat) -> CGPoint {
        let point = self - origin
        let s = sin(angle)
        let c = cos(angle)
        return CGPoint(x: c * point.x - s * point.y,
                       y: s * point.x + c * point.y) + origin
    }
}

extension CGSize {
    public var cgPoint: CGPoint {
        return CGPoint(x: width, y: height)
    }
    
    public init(point: CGPoint) {
        self.init(width: point.x, height: point.y)
    }
}

public func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

public func += (left: inout CGPoint, right: CGPoint) {
    left = left + right
}

public func + (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

public func += (left: inout CGPoint, right: CGVector) {
    left = left + right
}

public func - (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x - right.x, y: left.y - right.y) }
public func - (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width - right.width, height: left.height - right.height) }
public func - (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width - right.x, height: left.height - right.x) }
public func - (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x - right.width, y: left.y - right.height) }

public func -= (left: inout CGPoint, right: CGPoint) {
    left = left - right
}

public func - (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

public func -= (left: inout CGPoint, right: CGVector) {
    left = left - right
}

public func *= (left: inout CGPoint, right: CGPoint) {
    left = left * right
}

public func * (point: CGPoint, scalar: CGFloat) -> CGPoint { return CGPoint(x: point.x * scalar, y: point.y * scalar) }
public func * (point: CGSize, scalar: CGFloat) -> CGSize { return CGSize(width: point.width * scalar, height: point.height * scalar) }

public func *= (point: inout CGPoint, scalar: CGFloat) { point = point * scalar }

public func * (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x * right.dx, y: left.y * right.dy)
}

public func *= (left: inout CGPoint, right: CGVector) {
    left = left * right
}

public func / (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x / right.x, y: left.y / right.y) }
public func / (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width / right.width, height: left.height / right.height) }
public func / (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x / right.width, y: left.y / right.height) }
public func / (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width / right.x, height: left.height / right.y) }
public func /= (left: inout CGPoint, right: CGPoint) { left = left / right }
public func /= (left: inout CGSize, right: CGSize) { left = left / right }
public func /= (left: inout CGSize, right: CGPoint) { left = left / right }
public func /= (left: inout CGPoint, right: CGSize) { left = left / right }


public func / (point: CGPoint, scalar: CGFloat) -> CGPoint { return CGPoint(x: point.x / scalar, y: point.y / scalar) }
public func / (point: CGSize, scalar: CGFloat) -> CGSize { return CGSize(width: point.width / scalar, height: point.height / scalar) }

public func /= (point: inout CGPoint, scalar: CGFloat) {
    point = point / scalar
}

public func / (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x / right.dx, y: left.y / right.dy)
}

public func / (left: CGSize, right: CGVector) -> CGSize {
    return CGSize(width: left.width / right.dx, height: left.height / right.dy)
}

public func /= (left: inout CGPoint, right: CGVector) {
    left = left / right
}

public func * (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x * right.x, y: left.y * right.y) }
public func * (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x * right.width, y: left.y * right.height) }
public func *= (left: inout CGPoint, right: CGSize) { left = left * right }
public func * (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width * right.width, height: left.height * right.height) }
public func *= (left: inout CGSize, right: CGSize) { left = left * right }
public func * (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width * right.x, height: left.height * right.y) }
public func *= (left: inout CGSize, right: CGPoint) { left = left * right }


public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
    return start + (end - start) * t
}

public func abs(_ point: CGPoint) -> CGPoint {
    return CGPoint(x: abs(point.x), y: abs(point.y))
}

extension CGSize {
    var isValid: Bool {
        return width > 0 && height > 0 && width != .infinity && height != .infinity && width != .nan && height != .nan
    }
    
    var ratio: CGFloat {
        return width / height
    }
}


extension CGRect {
    static var identity: CGRect {
        return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    var center: CGPoint {
        return origin + size.cgPoint / 2
    }
    
    var rounded: CGRect {
        return CGRect(x: origin.x.rounded(),
                      y: origin.y.rounded(),
                      width: width.rounded(.up),
                      height: height.rounded(.up))
    }
    
    var mirroredVertically: CGRect {
        return CGRect(x: origin.x,
                      y: 1.0 - (origin.y + height),
                      width: width,
                      height: height)
    }
}

extension CGAffineTransform {
    func inverted(with size: CGSize) -> CGAffineTransform {
        var transform = self
        let transformedSize = CGRect(origin: .zero, size: size).applying(transform).size
        transform.tx /= transformedSize.width;
        transform.ty /= transformedSize.height;
        transform = transform.inverted()
        transform.tx *= transformedSize.width;
        transform.ty *= transformedSize.height;
        return transform
    }
}
