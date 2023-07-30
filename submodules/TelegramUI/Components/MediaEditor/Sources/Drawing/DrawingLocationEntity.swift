import Foundation
import UIKit
import Display
import AccountContext
import TextFormat
import Postbox
import TelegramCore

public final class DrawingLocationEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case style
        case location
        case referenceDrawingSize
        case position
        case width
        case scale
        case rotation
        case renderImage
    }
    
    public enum Style: Codable, Equatable {
        case white
        case black
        case transparent
        case blur
    }
    
    
    public var uuid: UUID
    public var isAnimated: Bool {
        return false
    }
    
    public var title: String
    public var style: Style
    public var location: TelegramMediaMap
    public var color: DrawingColor = .clear
    public var lineWidth: CGFloat = 0.0
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var width: CGFloat
    public var scale: CGFloat
    public var rotation: CGFloat
    
    public var center: CGPoint {
        return self.position
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(title: String, style: Style, location: TelegramMediaMap) {
        self.uuid = UUID()
        
        self.title = title
        self.style = style
        self.location = location
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.width = 100.0
        self.scale = 1.0
        self.rotation = 0.0
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.title = try container.decode(String.self, forKey: .title)
        self.style = try container.decode(Style.self, forKey: .style)
        
        let locationData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .location)
        self.location = TelegramMediaMap(decoder: PostboxDecoder(buffer: MemoryBuffer(data: locationData.data)))
        
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.width = try container.decode(CGFloat.self, forKey: .width)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.style, forKey: .style)
//        try container.encode(PostboxEncoder().encodeObjectToRawData(self.location), forKey: .location)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.width, forKey: .width)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }

    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingLocationEntity(title: self.title, style: self.style, location: self.location)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingLocationEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.title != other.title {
            return false
        }
        if self.style != other.style {
            return false
        }
        if self.location != other.location {
            return false
        }
        if self.referenceDrawingSize != other.referenceDrawingSize {
            return false
        }
        if self.position != other.position {
            return false
        }
        if self.width != other.width {
            return false
        }
        if self.scale != other.scale {
            return false
        }
        if self.rotation != other.rotation {
            return false
        }
        return true
    }
}
