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
        case color
        case hasCustomColor
        case location
        case icon
        case queryId
        case resultId
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
        case custom
        case blur
    }
    
    
    public var uuid: UUID
    public var isAnimated: Bool {
        return false
    }
    
    public var title: String
    public var style: Style
    public var location: TelegramMediaMap
    public var icon: TelegramMediaFile?
    public var queryId: Int64?
    public var resultId: String?
    public var color: DrawingColor = DrawingColor(color: .white)  {
        didSet {
            if self.color.toUIColor().argb == UIColor.white.argb {
                self.style = .white
                self.hasCustomColor = false
            } else {
                self.style = .custom
                self.hasCustomColor = true
            }
        }
    }
    public var hasCustomColor = false
    public var lineWidth: CGFloat = 0.0
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var width: CGFloat
    public var scale: CGFloat {
        didSet {
            self.scale = min(2.5, self.scale)
        }
    }
    public var rotation: CGFloat
    
    public var center: CGPoint {
        return self.position
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(title: String, style: Style, location: TelegramMediaMap, icon: TelegramMediaFile?, queryId: Int64?, resultId: String?) {
        self.uuid = UUID()
        
        self.title = title
        self.style = style
        self.location = location
        self.icon = icon
        self.queryId = queryId
        self.resultId = resultId
        
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
        self.color = try container.decodeIfPresent(DrawingColor.self, forKey: .color) ?? DrawingColor(color: .white)
        self.hasCustomColor = try container.decodeIfPresent(Bool.self, forKey: .hasCustomColor) ?? false
        
        if let locationData = try container.decodeIfPresent(Data.self, forKey: .location) {
            self.location = PostboxDecoder(buffer: MemoryBuffer(data: locationData)).decodeRootObject() as! TelegramMediaMap
        } else {
            fatalError()
        }
        
        if let iconData = try container.decodeIfPresent(Data.self, forKey: .icon) {
            self.icon = PostboxDecoder(buffer: MemoryBuffer(data: iconData)).decodeRootObject() as? TelegramMediaFile
        }

        self.queryId = try container.decodeIfPresent(Int64.self, forKey: .queryId)
        self.resultId = try container.decodeIfPresent(String.self, forKey: .resultId)
        
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
        try container.encode(self.color, forKey: .color)
        try container.encode(self.hasCustomColor, forKey: .hasCustomColor)
        
        var encoder = PostboxEncoder()
        encoder.encodeRootObject(self.location)
        let locationData = encoder.makeData()
        try container.encode(locationData, forKey: .location)

        if let icon = self.icon {
            encoder = PostboxEncoder()
            encoder.encodeRootObject(icon)
            let iconData = encoder.makeData()
            try container.encode(iconData, forKey: .icon)
        }
        
        try container.encodeIfPresent(self.queryId, forKey: .queryId)
        try container.encodeIfPresent(self.resultId, forKey: .resultId)
        
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
        let newEntity = DrawingLocationEntity(title: self.title, style: self.style, location: self.location, icon: self.icon, queryId: self.queryId, resultId: self.resultId)
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
        if self.queryId != other.queryId {
            return false
        }
        if self.resultId != other.resultId {
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
