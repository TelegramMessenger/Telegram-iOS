import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import Photos

public final class DrawingMediaEntity: DrawingEntity, Codable {
    public enum Content: Equatable {
        case image(UIImage, PixelDimensions)
        case video(String, PixelDimensions)
        case asset(PHAsset)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, dimensions):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            }
        }
        
        public static func == (lhs: Content, rhs: Content) -> Bool {
            switch lhs {
            case let .image(lhsImage, lhsDimensions):
                if case let .image(rhsImage, rhsDimensions) = rhs {
                    return lhsImage === rhsImage && lhsDimensions == rhsDimensions
                } else {
                    return false
                }
            case let .video(lhsPath, lhsDimensions):
                if case let .video(rhsPath, rhsDimensions) = rhs {
                    return lhsPath == rhsPath && lhsDimensions == rhsDimensions
                } else {
                    return false
                }
            case let .asset(lhsAsset):
                if case let .asset(rhsAsset) = rhs {
                    return lhsAsset.localIdentifier == rhsAsset.localIdentifier
                } else {
                    return false
                }
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case image
        case videoPath
        case assetId
        case size
        case width
        case height
        case referenceDrawingSize
        case position
        case scale
        case rotation
        case mirrored
    }
    
    public let uuid: UUID
    public let content: Content
    public let size: CGSize
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var scale: CGFloat
    public var rotation: CGFloat
    public var mirrored: Bool
    
    public var color: DrawingColor = DrawingColor.clear
    public var lineWidth: CGFloat = 0.0
    
    public var center: CGPoint {
        return self.position
    }
    
    public var baseSize: CGSize {
        return self.size
    }
    
    public var isAnimated: Bool {
        switch self.content {
        case .image:
            return false
        case .video:
            return true
        case let .asset(asset):
            return asset.mediaType == .video
        }
    }
    
    public var isMedia: Bool {
        return true
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public init(content: Content, size: CGSize) {
        self.uuid = UUID()
        self.content = content
        self.size = size
        
        self.referenceDrawingSize = .zero
        self.position = CGPoint()
        self.scale = 1.0
        self.rotation = 0.0
        self.mirrored = false
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.size = try container.decode(CGSize.self, forKey: .size)
        let width = try container.decode(Int32.self, forKey: .width)
        let height = try container.decode(Int32.self, forKey: .height)
        if let videoPath = try container.decodeIfPresent(String.self, forKey: .videoPath) {
            self.content = .video(videoPath, PixelDimensions(width: width, height: height))
        } else if let imageData = try container.decodeIfPresent(Data.self, forKey: .image), let image = UIImage(data: imageData) {
            self.content = .image(image, PixelDimensions(width: width, height: height))
        } else if let _ = try container.decodeIfPresent(String.self, forKey: .assetId) {
            fatalError()
            //self.content = .asset()
        } else {
            fatalError()
        }
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.mirrored = try container.decode(Bool.self, forKey: .mirrored)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        switch self.content {
        case let .video(videoPath, dimensions):
            try container.encode(videoPath, forKey: .videoPath)
            try container.encode(dimensions.width, forKey: .width)
            try container.encode(dimensions.height, forKey: .height)
        case let .image(image, dimensions):
            try container.encodeIfPresent(image.jpegData(compressionQuality: 0.9), forKey: .image)
            try container.encode(dimensions.width, forKey: .width)
            try container.encode(dimensions.height, forKey: .height)
        case let .asset(asset):
            try container.encode(asset.localIdentifier, forKey: .assetId)
        }
        try container.encode(self.size, forKey: .size)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.mirrored, forKey: .mirrored)
    }
        
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingMediaEntity(content: self.content, size: self.size)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        newEntity.mirrored = self.mirrored
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingMediaEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.content != other.content {
            return false
        }
        if self.size != other.size {
            return false
        }
        if self.referenceDrawingSize != other.referenceDrawingSize {
            return false
        }
        if self.position != other.position {
            return false
        }
        if self.scale != other.scale {
            return false
        }
        if self.rotation != other.rotation {
            return false
        }
        if self.mirrored != other.mirrored {
            return false
        }
        return true
    }
}
