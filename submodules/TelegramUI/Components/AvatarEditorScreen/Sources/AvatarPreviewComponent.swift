import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources

final class AvatarPreviewComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let background: AvatarBackground
    let file: TelegramMediaFile?
    let tapped: () -> Void
    
    init(
        context: AccountContext,
        background: AvatarBackground,
        file: TelegramMediaFile?,
        tapped: @escaping () -> Void
    ) {
        self.context = context
        self.background = background
        self.file = file
        self.tapped = tapped
    }
    
    static func ==(lhs: AvatarPreviewComponent, rhs: AvatarPreviewComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let imageView: UIImageView
        
        private let imageNode: TransformImageNode
        private var animationNode: AnimatedStickerNode?
        
        private var component: AvatarPreviewComponent?
        private weak var state: EmptyComponentState?
        
        private let stickerFetchedDisposable = MetaDisposable()
        private let cachedDisposable = MetaDisposable()
        
        override init(frame: CGRect) {
            self.imageView = UIImageView()
            self.imageView.isUserInteractionEnabled = false
            
            self.imageNode = TransformImageNode()
                        
            super.init(frame: frame)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            self.addSubview(self.imageView)
            
            self.addSubnode(self.imageNode)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stickerFetchedDisposable.dispose()
            self.cachedDisposable.dispose()
        }
        
        @objc func tapped() {
            self.animationNode?.playOnce()
            self.component?.tapped()
        }
        
        func update(component: AvatarPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousBackground = self.component?.background
            
            let hadFile = self.component?.file != nil
            var fileUpdated = false
            if self.component?.file?.fileId != component.file?.fileId {
                fileUpdated = true
            }
            
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width * 0.66, height: availableSize.width * 0.66)
            
            var dimensions: CGSize?
            if let file = component.file, fileUpdated, let fileDimensions = file.dimensions?.cgSize {
                dimensions = fileDimensions
                
                if !self.imageNode.isHidden && hadFile, let snapshotView = self.imageNode.view.snapshotContentTree() {
                    self.imageNode.view.superview?.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    snapshotView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
                
                if let animationNode = self.animationNode {
                    self.animationNode = nil
                    
                    animationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    animationNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { [weak animationNode] _ in
                        animationNode?.removeFromSupernode()
                    })
                }
                
                self.imageNode.isHidden = false
                if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.autoplay = false
                        self.animationNode = animationNode
                        animationNode.started = { [weak self] in
                            self?.imageNode.isHidden = true
                        }
                        self.addSubnode(animationNode)
                    }
                    
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: component.context.account.postbox, userLocation: .other, file: file, small: false, size: fileDimensions.aspectFitted(CGSize(width: 256.0, height: 256.0))))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: component.context.account, userLocation: .other, file: file, small: false, synchronousLoad: false))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: false)).start())
                }
                
                if fileUpdated && hadFile {
                    self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.imageNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    if let animationNode = self.animationNode {
                        animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        animationNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            if let dimensions {
                let imageSize = dimensions.aspectFitted(size)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - imageSize.width) / 2.0), y: (availableSize.height - imageSize.height) / 2.0), size: imageSize)
                
                if let animationNode = self.animationNode {
                    animationNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - imageSize.width) / 2.0), y: (availableSize.height - imageSize.height) / 2.0), size: imageSize)
                    animationNode.updateLayout(size: imageSize)
                }
                
                if fileUpdated {
                    self.updateVisibility()
                }
            }
            
            self.imageView.frame = CGRect(origin: .zero, size: availableSize)
            if previousBackground != component.background {
                if let _ = previousBackground, !transition.animation.isImmediate {
                    UIView.transition(with: self.imageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                        self.imageView.image = component.background.generateImage(size: availableSize)
                    })
                } else {
                    self.imageView.image = component.background.generateImage(size: availableSize)
                }
                self.imageView.image = component.background.generateImage(size: availableSize)
            }
                                    
            return availableSize
        }
        
        private func updateVisibility() {
            guard let component = self.component, let file = component.file else {
                return
            }
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
            let source = AnimatedStickerResourceSource(account: component.context.account, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm")
            self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .count(1), mode: .direct(cachePathPrefix: nil))
            self.animationNode?.visibility = true
                        
            if let animationNode = self.animationNode as? DefaultAnimatedStickerNodeImpl {
                if file.isCustomTemplateEmoji {
                    animationNode.dynamicColor = .white
                } else {
                    animationNode.dynamicColor = nil
                }
            }
            
            self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
            |> deliverOn(Queue.concurrentDefaultQueue())).start())
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
