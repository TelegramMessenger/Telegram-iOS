import Foundation
import UIKit
import CoreGraphics
import SwiftSignalKit

private enum Corner: Hashable {
    case TopLeft(Int), TopRight(Int), BottomLeft(Int), BottomRight(Int)
    
    var hashValue: Int {
        switch self {
            case let .TopLeft(radius):
                return radius | (1 << 24)
            case let .TopRight(radius):
                return radius | (2 << 24)
            case let .BottomLeft(radius):
                return radius | (3 << 24)
            case let .BottomRight(radius):
                return radius | (4 << 24)
        }
    }
    
    var radius: Int {
        switch self {
            case let .TopLeft(radius):
                return radius
            case let .TopRight(radius):
                return radius
            case let .BottomLeft(radius):
                return radius
            case let .BottomRight(radius):
                return radius
        }
    }
}

private func ==(lhs: Corner, rhs: Corner) -> Bool {
    switch lhs {
        case let .TopLeft(lhsRadius):
            switch rhs {
                case let .TopLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .TopRight(lhsRadius):
            switch rhs {
                case let .TopRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomLeft(lhsRadius):
            switch rhs {
                case let .BottomLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomRight(lhsRadius):
            switch rhs {
                case let .BottomRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
    }
}

private enum Tail: Hashable {
    case BottomLeft(Int)
    case BottomRight(Int)
    
    var hashValue: Int {
        switch self {
            case let .BottomLeft(radius):
                return radius | (1 << 24)
            case let .BottomRight(radius):
                return radius | (2 << 24)
        }
    }
    
    var radius: Int {
        switch self {
            case let .BottomLeft(radius):
                return radius
            case let .BottomRight(radius):
                return radius
        }
    }
}

private func ==(lhs: Tail, rhs: Tail) -> Bool {
    switch lhs {
        case let .BottomLeft(lhsRadius):
            switch rhs {
                case let .BottomLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomRight(lhsRadius):
            switch rhs {
                case let .BottomRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
    }
}

private var cachedCorners = Atomic<[Corner: DrawingContext]>(value: [:])
private var cachedTails = Atomic<[Tail: DrawingContext]>(value: [:])

private func cornerContext(_ corner: Corner) -> DrawingContext {
    let cached: DrawingContext? = cachedCorners.with {
        return $0[corner]
    }
    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(corner.radius), height: CGFloat(corner.radius)), clear: true)
        
        context.withContext { c in
            c.setBlendMode(.copy)
            c.setFillColor(UIColor.black.cgColor)
            let rect: CGRect
            switch corner {
                case let .TopLeft(radius):
                    rect = CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .TopRight(radius):
                    rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: 0.0), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .BottomLeft(radius):
                    rect = CGRect(origin: CGPoint(x: 0.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .BottomRight(radius):
                    rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
            }
            c.fillEllipse(in: rect)
        }
        
        let _ = cachedCorners.modify { current in
            var current = current
            current[corner] = context
            return current
        }
        
        return context
    }
}

private func tailContext(_ tail: Tail) -> DrawingContext {
    let cached: DrawingContext? = cachedTails.with {
        return $0[tail]
    }
    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(tail.radius) + 3.0, height: CGFloat(tail.radius)), clear: true)
        
        context.withContext { c in
            c.setBlendMode(.copy)
            c.setFillColor(UIColor.black.cgColor)
            let rect: CGRect
            switch tail {
                case let .BottomLeft(radius):
                    rect = CGRect(origin: CGPoint(x: 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                    c.move(to: CGPoint(x: 3.0, y: 1.0))
                    c.addLine(to: CGPoint(x: 3.0, y: 11.0))
                    c.addLine(to: CGPoint(x: 2.3, y: 13.0))
                    c.addLine(to: CGPoint(x: 0.0, y: 16.6))
                    c.addLine(to: CGPoint(x: 4.5, y: 15.5))
                    c.addLine(to: CGPoint(x: 6.5, y: 14.3))
                    c.addLine(to: CGPoint(x: 9.0, y: 12.5))
                    c.closePath()
                    c.fillPath()
                case let .BottomRight(radius):
                    rect = CGRect(origin: CGPoint(x: 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                    c.translateBy(x: context.size.width / 2.0, y: context.size.height / 2.0)
                    c.scaleBy(x: -1.0, y: 1.0)
                    c.translateBy(x: -context.size.width / 2.0, y: -context.size.height / 2.0)
                
                    c.move(to: CGPoint(x: 3.0, y: 1.0))
                    c.addLine(to: CGPoint(x: 3.0, y: 11.0))
                    c.addLine(to: CGPoint(x: 2.3, y: 13.0))
                    c.addLine(to: CGPoint(x: 0.0, y: 16.6))
                    c.addLine(to: CGPoint(x: 4.5, y: 15.5))
                    c.addLine(to: CGPoint(x: 6.5, y: 14.3))
                    c.addLine(to: CGPoint(x: 9.0, y: 12.5))
                    c.closePath()
                    c.fillPath()
            }
            c.fillEllipse(in: rect)
        }
        
        let _ = cachedTails.modify { current in
            var current = current
            current[tail] = context
            return current
        }
        return context
    }
}

public func addCorners(_ context: DrawingContext, arguments: TransformImageArguments) {
    let corners = arguments.corners
    let drawingRect = arguments.drawingRect
    if case let .Corner(radius) = corners.topLeft, radius > CGFloat.ulpOfOne {
        let corner = cornerContext(.TopLeft(Int(radius)))
        context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.minY))
    }
    
    if case let .Corner(radius) = corners.topRight, radius > CGFloat.ulpOfOne {
        let corner = cornerContext(.TopRight(Int(radius)))
        context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.minY))
    }
    
    switch corners.bottomLeft {
        case let .Corner(radius):
            if radius > CGFloat.ulpOfOne {
                let corner = cornerContext(.BottomLeft(Int(radius)))
                context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.maxY - radius))
            }
        case let .Tail(radius, enabled):
            if radius > CGFloat.ulpOfOne {
                if enabled {
                    let tail = tailContext(.BottomLeft(Int(radius)))
                    let color = context.colorAt(CGPoint(x: drawingRect.minX, y: drawingRect.maxY - 1.0))
                    context.withContext { c in
                        c.clear(CGRect(x: drawingRect.minX - 3.0, y: 0.0, width: 3.0, height: drawingRect.maxY - 6.0))
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: 0.0, y: drawingRect.maxY - 6.0, width: 3.0, height: 6.0))
                    }
                    context.blt(tail, at: CGPoint(x: drawingRect.minX - 3.0, y: drawingRect.maxY - radius))
                } else {
                    let corner = cornerContext(.BottomLeft(Int(radius)))
                    context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.maxY - radius))
                }
            }
        
    }
    
    switch corners.bottomRight {
        case let .Corner(radius):
            if radius > CGFloat.ulpOfOne {
                let corner = cornerContext(.BottomRight(Int(radius)))
                context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
            }
        case let .Tail(radius, enabled):
            if radius > CGFloat.ulpOfOne {
                if enabled {
                    let tail = tailContext(.BottomRight(Int(radius)))
                    let color = context.colorAt(CGPoint(x: drawingRect.maxX - 1.0, y: drawingRect.maxY - 1.0))
                    context.withContext { c in
                        c.clear(CGRect(x: drawingRect.maxX, y: 0.0, width: 3.0, height: drawingRect.maxY - 6.0))
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: drawingRect.maxX, y: drawingRect.maxY - 6.0, width: 3.0, height: 6.0))
                    }
                    context.blt(tail, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
                } else {
                    let corner = cornerContext(.BottomRight(Int(radius)))
                    context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
                }
            }
    }
}
