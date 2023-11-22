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
        
    private var currentSize: CGSize?
    private var isVisible = true
    private var isPlaying = false
    
    public weak var previewView: MediaEditorPreviewView? {
        didSet {
            if let previewView = self.previewView {
                previewView.isUserInteractionEnabled = false
                previewView.layer.allowsEdgeAntialiasing = true
                self.addSubview(previewView)
            } else {
                oldValue?.removeFromSuperview()
            }
        }
    }
        
    private let snapTool = DrawingEntitySnapTool()
    
    init(context: AccountContext, entity: DrawingMediaEntity) {
        super.init(context: context, entity: entity)
        
        self.snapTool.onSnapUpdated = { [weak self] type, snapped in
            if let self {
                self.onSnapUpdated(type, snapped)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let previewView = self.previewView {
            previewView.removeFromSuperview()
            self.previewView = nil
        }
    }
    
    public override func play() {
        self.isVisible = true
        self.applyVisibility()
    }
    
    public override func pause() {
        self.isVisible = false
        self.applyVisibility()
    }
    
    public override func seek(to timestamp: Double) {
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
            if self.previewView?.superview === self {
                self.previewView?.frame = CGRect(origin: .zero, size: size)
            }
            self.update(animated: false)
        }
    }
            
    public var updated: (() -> Void)?
    public override func update(animated: Bool) {
        self.center = self.mediaEntity.position
        
        let size = self.mediaEntity.baseSize
        let scale = self.mediaEntity.scale
        
        self.bounds = CGRect(origin: .zero, size: size)
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.mediaEntity.rotation), scale, scale)
    
        if self.previewView?.superview === self {
            self.previewView?.layer.transform = CATransform3DMakeScale(self.mediaEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)
            self.previewView?.frame = self.bounds
        }
    
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
    
    private var beganRotating = false
    @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        var updatedRotation = self.mediaEntity.rotation
        var rotation: CGFloat = 0.0
        
        let velocity = gestureRecognizer.velocity
        
        switch gestureRecognizer.state {
        case .began:
            self.beganRotating = false
            self.snapTool.maybeSkipFromStart(entityView: self, rotation: self.mediaEntity.rotation)
        case .changed:
            rotation = gestureRecognizer.rotation
            if self.beganRotating {
                updatedRotation += rotation
                gestureRecognizer.rotation = 0.0
            } else if abs(rotation) >= 0.08 * .pi || abs(self.mediaEntity.rotation) >= 0.03 {
                self.beganRotating = true
                gestureRecognizer.rotation = 0.0
            }
            
            updatedRotation = self.snapTool.update(entityView: self, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
            self.mediaEntity.rotation = updatedRotation
            self.update(animated: false)
        case .ended, .cancelled:
            self.snapTool.rotationReset()
            self.beganRotating = false
        default:
            break
        }
    }
}
