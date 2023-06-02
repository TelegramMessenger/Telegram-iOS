import Foundation
import UIKit
import Display
import AccountContext

public final class DrawingBubbleEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawType
        case color
        case lineWidth
        case referenceDrawingSize
        case position
        case size
        case rotation
        case tailPosition
        case renderImage
    }
    
    public enum DrawType: Codable {
        case fill
        case stroke
    }
    
    public let uuid: UUID
    public let isAnimated: Bool
    
    public var drawType: DrawType
    public var color: DrawingColor
    public var lineWidth: CGFloat
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat
    public var tailPosition: CGPoint
    
    public var center: CGPoint {
        return self.position
    }
    
    public var scale: CGFloat = 1.0
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(drawType: DrawType, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.isAnimated = false
                
        self.drawType = drawType
        self.color = color
        self.lineWidth = lineWidth
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.size = CGSize(width: 1.0, height: 1.0)
        self.rotation = 0.0
        self.tailPosition = CGPoint(x: 0.16, y: 0.18)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.isAnimated = false
        self.drawType = try container.decode(DrawType.self, forKey: .drawType)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.size = try container.decode(CGSize.self, forKey: .size)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.tailPosition = try container.decode(CGPoint.self, forKey: .tailPosition)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawType, forKey: .drawType)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.lineWidth, forKey: .lineWidth)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.size, forKey: .size)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.tailPosition, forKey: .tailPosition)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }
        
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingBubbleEntity(drawType: self.drawType, color: self.color, lineWidth: self.lineWidth)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.size = self.size
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingBubbleEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.drawType != other.drawType {
            return false
        }
        if self.color != other.color {
            return false
        }
        if self.lineWidth != other.lineWidth {
            return false
        }
        if self.referenceDrawingSize != other.referenceDrawingSize {
            return false
        }
        if self.position != other.position {
            return false
        }
        if self.size != other.size {
            return false
        }
        if self.rotation != other.rotation {
            return false
        }
        if self.tailPosition != other.tailPosition {
            return false
        }
        return true
    }
}
