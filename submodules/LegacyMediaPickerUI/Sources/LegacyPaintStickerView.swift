import UIKit
import Display
import TelegramCore
import AccountContext
import SwiftSignalKit
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import LegacyComponents

class LegacyPaintStickerView: UIView, TGPhotoPaintStickerRenderView {
    var started: ((Double) -> Void)?
    
    private let context: AccountContext
    private let file: TelegramMediaFile
    private var currentSize: CGSize?
    private var dimensions: CGSize?
    
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private var didSetUpAnimationNode = false
    private let stickerFetchedDisposable = MetaDisposable()
    
    private let cachedDisposable = MetaDisposable()
    
    init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
        
        self.imageNode = TransformImageNode()
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.imageNode)
        
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
        self.cachedDisposable.dispose()
    }
    
    func image() -> UIImage! {
        if self.imageNode.contents != nil {
            return UIImage(cgImage: self.imageNode.contents as! CGImage)
        } else {
            return nil
        }
    }
    
    func documentId() -> Int64 {
        return self.file.fileId.id
    }
    
    private func setup() {
        if let dimensions = self.file.dimensions {
            if self.file.isAnimatedSticker || self.file.isVideoSticker {
                if self.animationNode == nil {
                    let animationNode = AnimatedStickerNode()
                    self.animationNode = animationNode
                    animationNode.started = { [weak self, weak animationNode] in
                        self?.imageNode.isHidden = true
                        
                        if let animationNode = animationNode {
                            let _ = (animationNode.status
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] status in
                                self?.started?(status.duration)
                            })
                        }
                    }
                    self.addSubnode(animationNode)
                }
                let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, file: self.file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))))
                self.updateVisibility()
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: stickerPackFileReference(self.file), resource: self.file.resource).start())
            } else {
                if let animationNode = self.animationNode {
                    animationNode.visibility = false
                    self.animationNode = nil
                    animationNode.removeFromSupernode()
                    self.imageNode.isHidden = false
                    self.didSetUpAnimationNode = false
                }
                self.imageNode.setSignal(chatMessageSticker(account: self.context.account, file: self.file, small: false, synchronousLoad: false))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: stickerPackFileReference(self.file), resource: chatMessageStickerResource(file: self.file, small: false)).start())
            }
            
            self.dimensions = dimensions.cgSize
            self.setNeedsLayout()
        }
    }
    
    var isVisible: Bool = true
    func setIsVisible(_ visible: Bool) {
        self.isVisible = visible
        self.updateVisibility()
    }
    
    var isPlaying = false
    func updateVisibility() {
        let isPlaying = self.isVisible
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
            self.animationNode?.visibility = isPlaying
            if isPlaying && !self.didSetUpAnimationNode {
                self.didSetUpAnimationNode = true
                let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                let source = AnimatedStickerResourceSource(account: self.context.account, resource: self.file.resource, isVideo: self.file.isVideoSticker)
                self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .direct(cachePathPrefix: nil))
            
                self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
                |> deliverOn(Queue.concurrentDefaultQueue())).start())
            }
        }
    }
    
    func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(timestamp))
    }
    
    func play() {
        self.isVisible = true
        self.isPlaying = true
        self.animationNode?.play()
    }
    
    func pause() {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.pause()
    }
    
    func resetToStart() {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(0.0))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = size.width
            let boundingSize = CGSize(width: sideSize, height: sideSize)
            
            if let dimensions = self.dimensions {
                let imageSize = dimensions.aspectFitted(boundingSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
                if let animationNode = self.animationNode {
                    animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
                    animationNode.updateLayout(size: imageSize)
                }
            }
        }
    }
}
