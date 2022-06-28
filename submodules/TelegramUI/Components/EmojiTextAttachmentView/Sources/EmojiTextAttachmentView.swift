import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import AccountContext
import YuvConversion
import TelegramCore
import Postbox
import AnimationCache
import LottieAnimationCache
import MultiAnimationRenderer
import ShimmerEffect

public final class InlineStickerItemLayer: MultiAnimationRenderTarget {
    public static let queue = Queue()
    
    public struct Key: Hashable {
        public var id: MediaId
        public var index: Int
        
        public init(id: MediaId, index: Int) {
            self.id = id
            self.index = index
        }
    }
    
    private let file: TelegramMediaFile
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    
    private var isInHierarchyValue: Bool = false
    public var isVisibleForAnimations: Bool = false {
        didSet {
            if self.isVisibleForAnimations != oldValue {
                self.updatePlayback()
            }
        }
    }
    private var displayLink: ConstantDisplayLinkAnimator?
    
    public init(context: AccountContext, groupId: String, attemptSynchronousLoad: Bool, file: TelegramMediaFile, cache: AnimationCache, renderer: MultiAnimationRenderer, placeholderColor: UIColor) {
        self.file = file
        
        super.init()
        
        if attemptSynchronousLoad {
            if !renderer.loadFirstFrameSynchronously(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation) {
                let size = CGSize(width: 24.0, height: 24.0)
                if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor) {
                    self.contents = image.cgImage
                }
            }
        }
        
        self.disposable = renderer.add(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation, fetch: { writer in
            let source = AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: nil, isVideo: false)
            
            let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
                guard let result = result else {
                    return
                }
                        
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                    writer.finish()
                    return
                }
                let scale = min(2.0, UIScreenScale)
                cacheLottieAnimation(data: data, width: Int(24 * scale), height: Int(24 * scale), writer: writer)
            })
            
            let fetchDisposable = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file)).start()
            
            return ActionDisposable {
                dataDisposable.dispose()
                fetchDisposable.dispose()
            }
        })
    }
    
    override public init(layer: Any) {
        preconditionFailure()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
        self.fetchDisposable?.dispose()
    }
    
    override public func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchyValue = true
        } else if event == kCAOnOrderOut {
            self.isInHierarchyValue = false
        }
        self.updatePlayback()
        return nullAction
    }
    
    private func updatePlayback() {
        let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
        
        self.shouldBeAnimating = shouldBePlaying
    }
}

public final class EmojiTextAttachmentView: UIView {
    private let contentLayer: InlineStickerItemLayer
    
    public init(context: AccountContext, file: TelegramMediaFile, cache: AnimationCache, renderer: MultiAnimationRenderer, placeholderColor: UIColor) {
        self.contentLayer = InlineStickerItemLayer(context: context, groupId: "textInputView", attemptSynchronousLoad: true, file: file, cache: cache, renderer: renderer, placeholderColor: placeholderColor)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.contentLayer.isVisibleForAnimations = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -2.0), size: CGSize(width: self.bounds.width - 0.0, height: self.bounds.height + 9.0))
    }
}
