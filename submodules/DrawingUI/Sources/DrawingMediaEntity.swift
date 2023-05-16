import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import Photos

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
                self.addSubview(previewView)
            }
        }
    }
    
    init(context: AccountContext, entity: DrawingMediaEntity) {
        super.init(context: context, entity: entity)
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
