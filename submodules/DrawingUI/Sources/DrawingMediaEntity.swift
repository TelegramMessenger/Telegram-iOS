import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import Photos

public final class DrawingMediaEntity: DrawingEntity, Codable {
    public enum Content {
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
    
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingMediaEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
    }
}

public final class DrawingMediaEntityView: DrawingEntityView, DrawingEntityMediaView {
    private var mediaEntity: DrawingMediaEntity {
        return self.entity as! DrawingMediaEntity
    }
    
    var started: ((Double) -> Void)?
    
    private var currentSize: CGSize?
    private var isVisible = true
    private var isPlaying = false
    
    public var previewView: MediaEditorPreviewView? {
        didSet {
            if let previewView = self.previewView {
                previewView.isUserInteractionEnabled = false
                previewView.layer.allowsEdgeAntialiasing = true
                self.addSubview(previewView)
            }
        }
    }
    
    init(context: AccountContext, entity: DrawingMediaEntity) {
        super.init(context: context, entity: entity)
        
        self.layer.allowsEdgeAntialiasing = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {

    }
    
    override func play() {
        self.isVisible = true
        self.applyVisibility()
    }
    
    override func pause() {
        self.isVisible = false
        self.applyVisibility()
    }
    
    override func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        
    }
    
    override func resetToStart() {
        self.isVisible = false
        self.isPlaying = false
    }
    
    override func updateVisibility(_ visibility: Bool) {
        self.isVisible = visibility
        self.applyVisibility()
    }
    
    private func applyVisibility() {
        let isPlaying = self.isVisible
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
        }
    }
    
    private var didApplyVisibility = false
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
                
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            self.previewView?.frame = CGRect(origin: .zero, size: size)

            self.update(animated: false)
        }
    }
            
    public var updated: (() -> Void)?
    override func update(animated: Bool) {
        self.center = self.mediaEntity.position
        
        let size = self.mediaEntity.baseSize
        let scale = self.mediaEntity.scale
        
        self.bounds = CGRect(origin: .zero, size: size)
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.mediaEntity.rotation), scale, scale)
    
        self.previewView?.layer.transform = CATransform3DMakeScale(self.mediaEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)
        self.previewView?.frame = self.bounds
    
        super.update(animated: animated)
        
        self.updated?()
    }
    
    override func updateSelectionView() {

    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        return nil
    }
    
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let delta = gestureRecognizer.translation(in: self.superview)
        var updatedPosition = self.mediaEntity.position
        
        switch gestureRecognizer.state {
        case .began, .changed:
            updatedPosition.x += delta.x
            updatedPosition.y += delta.y
            
            gestureRecognizer.setTranslation(.zero, in: self.superview)
        default:
            break
        }
        
        self.mediaEntity.position = updatedPosition
        self.update(animated: false)
    }
    
    @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
            let scale = gestureRecognizer.scale
            self.mediaEntity.scale = self.mediaEntity.scale * scale
            self.update(animated: false)

            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        var updatedRotation = self.mediaEntity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            break
        default:
            break
        }
        
        self.mediaEntity.rotation = updatedRotation
        self.update(animated: false)
    }
}
