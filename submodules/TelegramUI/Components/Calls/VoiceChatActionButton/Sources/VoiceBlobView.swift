import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CallScreen
import MetalEngine

final class VoiceBlobView: UIView {
    //private let mediumBlob: BlobView
    //private let bigBlob: BlobView
    
    private let blobsLayer: CallBlobsLayer
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    var scaleUpdated: ((CGFloat) -> Void)? {
        didSet {
            //self.bigBlob.scaleUpdated = self.scaleUpdated
        }
    }
    
    private(set) var isAnimating = false
    
    public typealias BlobRange = (min: CGFloat, max: CGFloat)

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    init(
        frame: CGRect,
        maxLevel: CGFloat,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.maxLevel = maxLevel
        
        /*self.mediumBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 0.9,
            maxSpeed: 4.0,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max
        )
        self.bigBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max
        )*/
        
        self.blobsLayer = CallBlobsLayer()
        
        super.init(frame: frame)

        self.addSubnode(self.hierarchyTrackingNode)
        
        //self.addSubview(self.bigBlob)
        //self.addSubview(self.mediumBlob)
        self.layer.addSublayer(self.blobsLayer)
        
        self.displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }

            if !strongSelf.isCurrentlyInHierarchy {
                return
            }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            strongSelf.updateAudioLevel()
            
            //strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            //strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        //self.mediumBlob.setColor(color.withAlphaComponent(0.5))
        //self.bigBlob.setColor(color.withAlphaComponent(0.21))
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        //self.mediumBlob.updateSpeedLevel(to: normalizedLevel)
        //self.bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        self.audioLevel = normalizedLevel
        if immediately {
            self.presentationAudioLevel = normalizedLevel
        }
    }
    
    private func updateAudioLevel() {
        let additionalAvatarScale = CGFloat(max(0.0, min(self.presentationAudioLevel * 18.0, 5.0)) * 0.05)
        let blobAmplificationFactor: CGFloat = 2.0
        let blobScale = 1.0 + additionalAvatarScale * blobAmplificationFactor
        self.blobsLayer.transform = CATransform3DMakeScale(blobScale, blobScale, 1.0)
        
        self.scaleUpdated?(blobScale)
    }
    
    public func startAnimating() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        self.isAnimating = false
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        /*if self.isAnimating {
            if self.mediumBlob.frame.size != .zero {
                self.mediumBlob.startAnimating()
                self.bigBlob.startAnimating()
            }
        } else {
            self.mediumBlob.stopAnimating()
            self.bigBlob.stopAnimating()
        }*/
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        //self.mediumBlob.frame = bounds
        //self.bigBlob.frame = bounds
        
        let blobsFrame = bounds.insetBy(dx: floor(bounds.width * 0.12), dy: floor(bounds.height * 0.12))
        self.blobsLayer.position = blobsFrame.center
        self.blobsLayer.bounds = CGRect(origin: CGPoint(), size: blobsFrame.size)
        
        self.updateBlobsState()
    }
}

