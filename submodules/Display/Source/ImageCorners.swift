import Foundation
import UIKit
import CoreGraphics
import SwiftSignalKit

private enum Corner: Hashable {
    case TopLeft(Int), TopRight(Int), BottomLeft(Int), BottomRight(Int)
    
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

private enum Tail: Hashable {
    case BottomLeft(Int)
    case BottomRight(Int)
    
    var radius: Int {
        switch self {
            case let .BottomLeft(radius):
                return radius
            case let .BottomRight(radius):
                return radius
        }
    }
}

private var cachedCorners = Atomic<[Corner: DrawingContext]>(value: [:])

private func cornerContext(_ corner: Corner) -> DrawingContext {
    let cached: DrawingContext? = cachedCorners.with {
        return $0[corner]
    }
    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(corner.radius), height: CGFloat(corner.radius)), clear: true)
        
        context.withContext { c in
            c.clear(CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(corner.radius), height: CGFloat(corner.radius))))
            c.setFillColor(UIColor.black.cgColor)
            switch corner {
            case let .TopLeft(radius):
                let rect = CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(radius * 2), height: CGFloat(radius * 2)))
                c.fillEllipse(in: rect)
            case let .TopRight(radius):
                let rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: 0.0), size: CGSize(width: CGFloat(radius * 2), height: CGFloat(radius * 2)))
                c.fillEllipse(in: rect)
            case let .BottomLeft(radius):
                let rect = CGRect(origin: CGPoint(x: 0.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius * 2), height: CGFloat(radius * 2)))
                c.fillEllipse(in: rect)
            case let .BottomRight(radius):
                let rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius * 2), height: CGFloat(radius * 2)))
                c.fillEllipse(in: rect)
            }
        }
        
        let _ = cachedCorners.modify { current in
            var current = current
            current[corner] = context
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
        case let .Tail(radius, image):
            if radius > CGFloat.ulpOfOne {
                let color = context.colorAt(CGPoint(x: drawingRect.minX, y: drawingRect.maxY - 1.0))
                context.withContext { c in
                    c.clear(CGRect(x: drawingRect.minX - 4.0, y: 0.0, width: 4.0, height: drawingRect.maxY - 6.0))
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: 0.0, y: drawingRect.maxY - 7.0, width: 4.0, height: 7.0))
                    c.setBlendMode(.destinationIn)
                    let cornerRect = CGRect(origin: CGPoint(x: drawingRect.minX - 6.0, y: drawingRect.maxY - image.size.height), size: image.size)
                    c.translateBy(x: cornerRect.midX, y: cornerRect.midY)
                    c.scaleBy(x: 1.0, y: -1.0)
                    c.translateBy(x: -cornerRect.midX, y: -cornerRect.midY)
                    c.draw(image.cgImage!, in: cornerRect)
                    c.translateBy(x: cornerRect.midX, y: cornerRect.midY)
                    c.scaleBy(x: 1.0, y: -1.0)
                    c.translateBy(x: -cornerRect.midX, y: -cornerRect.midY)
                }
            }
    }
    
    switch corners.bottomRight {
        case let .Corner(radius):
            if radius > CGFloat.ulpOfOne {
                let corner = cornerContext(.BottomRight(Int(radius)))
                context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
            }
        case let .Tail(radius, image):
            if radius > CGFloat.ulpOfOne {
                let color = context.colorAt(CGPoint(x: drawingRect.maxX - 1.0, y: drawingRect.maxY - 1.0))
                context.withContext { c in
                    c.clear(CGRect(x: drawingRect.maxX, y: 0.0, width: 4.0, height: drawingRect.maxY - image.size.height))
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: drawingRect.maxX, y: drawingRect.maxY - 7.0, width: 5.0, height: 7.0))
                    c.setBlendMode(.destinationIn)
                    let cornerRect = CGRect(origin: CGPoint(x: drawingRect.maxX - image.size.width + 6.0, y: drawingRect.maxY - image.size.height), size: image.size)
                    c.translateBy(x: cornerRect.midX, y: cornerRect.midY)
                    c.scaleBy(x: 1.0, y: -1.0)
                    c.translateBy(x: -cornerRect.midX, y: -cornerRect.midY)
                    c.draw(image.cgImage!, in: cornerRect)
                    c.translateBy(x: cornerRect.midX, y: cornerRect.midY)
                    c.scaleBy(x: 1.0, y: -1.0)
                    c.translateBy(x: -cornerRect.midX, y: -cornerRect.midY)
                }
            }
    }
}
