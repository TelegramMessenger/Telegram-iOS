import Foundation
import UIKit
import Display
import AccountContext

public final class DrawingVectorEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case color
        case lineWidth
        case drawingSize
        case referenceDrawingSize
        case start
        case mid
        case end
        case renderImage
    }
    
    public enum VectorType: Codable {
        case line
        case oneSidedArrow
        case twoSidedArrow
    }
    
    public let uuid: UUID
    public let isAnimated: Bool
    
    public var type: VectorType
    public var color: DrawingColor
    public var lineWidth: CGFloat
    
    public var drawingSize: CGSize
    public var referenceDrawingSize: CGSize
    public var start: CGPoint
    public var mid: (CGFloat, CGFloat)
    public var end: CGPoint
        
    public var center: CGPoint {
        return self.start
    }
    
    public var scale: CGFloat = 1.0
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(type: VectorType, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.isAnimated = false
        
        self.type = type
        self.color = color
        self.lineWidth = lineWidth
        
        self.drawingSize = .zero
        self.referenceDrawingSize = .zero
        self.start = CGPoint()
        self.mid = (0.5, 0.0)
        self.end = CGPoint()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.isAnimated = false
        self.type = try container.decode(VectorType.self, forKey: .type)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.start = try container.decode(CGPoint.self, forKey: .start)
        let mid = try container.decode(CGPoint.self, forKey: .mid)
        self.mid = (mid.x, mid.y)
        self.end = try container.decode(CGPoint.self, forKey: .end)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.lineWidth, forKey: .lineWidth)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.start, forKey: .start)
        try container.encode(CGPoint(x: self.mid.0, y: self.mid.1), forKey: .mid)
        try container.encode(self.end, forKey: .end)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }
    
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingVectorEntity(type: self.type, color: self.color, lineWidth: self.lineWidth)
        newEntity.drawingSize = self.drawingSize
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.start = self.start
        newEntity.mid = self.mid
        newEntity.end = self.end
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingVectorEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.type != other.type {
            return false
        }
        if self.color != other.color {
            return false
        }
        if self.lineWidth != other.lineWidth {
            return false
        }
        if self.drawingSize != other.drawingSize {
            return false
        }
        if self.referenceDrawingSize != other.referenceDrawingSize {
            return false
        }
        if self.start != other.start {
            return false
        }
        if self.mid.0 != other.mid.0 || self.mid.1 != other.mid.1 {
            return false
        }
        if self.end != other.end {
            return false
        }
        return true
    }
}
