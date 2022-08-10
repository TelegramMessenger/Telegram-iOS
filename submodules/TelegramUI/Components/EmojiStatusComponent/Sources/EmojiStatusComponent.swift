import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import AccountContext
import TelegramCore
import Postbox
import EmojiTextAttachmentView
import AppBundle
import TextFormat

public final class EmojiStatusComponent: Component {
    public typealias EnvironmentType = Empty
    
    public enum Content: Equatable {
        case none
        case premium(color: UIColor)
        case verified(fillColor: UIColor, foregroundColor: UIColor)
        case fake(color: UIColor)
        case scam(color: UIColor)
        case emojiStatus(status: PeerEmojiStatus, placeholderColor: UIColor)
    }
    
    public let context: AccountContext
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let content: Content
    public let action: (() -> Void)?
    public let longTapAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        content: Content,
        action: (() -> Void)?,
        longTapAction: (() -> Void)?
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.content = content
        self.action = action
        self.longTapAction = longTapAction
    }
    
    public static func ==(lhs: EmojiStatusComponent, rhs: EmojiStatusComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    public final class View: UIView {
        private weak var state: EmptyComponentState?
        private var component: EmojiStatusComponent?
        private var iconView: UIImageView?
        private var animationLayer: InlineStickerItemLayer?
        
        private var emojiFile: TelegramMediaFile?
        private var emojiFileDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.emojiFileDisposable?.dispose()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action?()
            }
        }
        
        @objc private func longPressGesture(_ recognizer: UITapGestureRecognizer) {
            if case .began = recognizer.state {
                self.component?.longTapAction?()
            }
        }
        
        func update(component: EmojiStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.state = state
            
            var iconImage: UIImage?
            var emojiFileId: Int64?
            var emojiPlaceholderColor: UIColor?
            
            /*
             if case .fake = credibilityIcon {
                 image = PresentationResourcesChatList.fakeIcon(presentationData.theme, strings: presentationData.strings, type: .regular)
             } else if case .scam = credibilityIcon {
                 image = PresentationResourcesChatList.scamIcon(presentationData.theme, strings: presentationData.strings, type: .regular)
             } else if case .verified = credibilityIcon {
                 if let backgroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconForeground") {
                     image = generateImage(backgroundImage.size, contextGenerator: { size, context in
                         if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                             context.clear(CGRect(origin: CGPoint(), size: size))
                             context.saveGState()
                             context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                             context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                             context.restoreGState()
                             
                             context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                             context.setFillColor(presentationData.theme.list.itemCheckColors.foregroundColor.cgColor)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                         }
                     }, opaque: false)
                     expandedImage = generateImage(backgroundImage.size, contextGenerator: { size, context in
                         if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                             context.clear(CGRect(origin: CGPoint(), size: size))
                             context.saveGState()
                             context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)
                             context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.75).cgColor)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                             context.restoreGState()
                             
                             context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                             context.setBlendMode(.clear)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                         }
                     }, opaque: false)
                 } else {
                     image = nil
                 }
             } else if case .premium = credibilityIcon {
                 if let sourceImage = UIImage(bundleImageName: "Peer Info/PremiumIcon") {
                     image = generateImage(sourceImage.size, contextGenerator: { size, context in
                         if let cgImage = sourceImage.cgImage {
                             context.clear(CGRect(origin: CGPoint(), size: size))
                             context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
                             
                             context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                         }
                     }, opaque: false)
                     expandedImage = generateImage(sourceImage.size, contextGenerator: { size, context in
                         if let cgImage = sourceImage.cgImage {
                             context.clear(CGRect(origin: CGPoint(), size: size))
                             context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
                             context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.75).cgColor)
                             context.fill(CGRect(origin: CGPoint(), size: size))
                         }
                     }, opaque: false)
                 } else {
                     image = nil
                 }
             }
             */
            
            if self.component?.content != component.content {
                switch component.content {
                case .none:
                    iconImage = nil
                case let .premium(color):
                    if let sourceImage = UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon") {
                        iconImage = generateImage(sourceImage.size, contextGenerator: { size, context in
                            if let cgImage = sourceImage.cgImage {
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                let imageSize = CGSize(width: sourceImage.size.width - 8.0, height: sourceImage.size.height - 8.0)
                                context.clip(to: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize), mask: cgImage)
                                
                                context.setFillColor(color.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                            }
                        }, opaque: false)
                    } else {
                        iconImage = nil
                    }
                case let .verified(fillColor, foregroundColor):
                    if let backgroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconForeground") {
                        iconImage = generateImage(backgroundImage.size, contextGenerator: { size, context in
                            if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.saveGState()
                                context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                                context.setFillColor(fillColor.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                                context.restoreGState()
                                
                                context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                                context.setFillColor(foregroundColor.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                            }
                        }, opaque: false)
                    } else {
                        iconImage = nil
                    }
                case .fake:
                    iconImage = nil
                case .scam:
                    iconImage = nil
                case let .emojiStatus(emojiStatus, placeholderColor):
                    iconImage = nil
                    emojiFileId = emojiStatus.fileId
                    emojiPlaceholderColor = placeholderColor
                    
                    if case let .emojiStatus(previousEmojiStatus, _) = self.component?.content {
                        if previousEmojiStatus.fileId != emojiStatus.fileId {
                            self.emojiFileDisposable?.dispose()
                            self.emojiFileDisposable = nil
                            
                            self.emojiFile = nil
                            
                            if let animationLayer = self.animationLayer {
                                self.animationLayer = nil
                                animationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak animationLayer] _ in
                                    animationLayer?.removeFromSuperlayer()
                                })
                                animationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                            }
                        }
                    }
                }
            } else {
                iconImage = self.iconView?.image
                if case let .emojiStatus(status, placeholderColor) = component.content {
                    emojiFileId = status.fileId
                    emojiPlaceholderColor = placeholderColor
                }
            }
            
            self.component = component
            
            var size = CGSize()
            
            if let iconImage = iconImage {
                let iconView: UIImageView
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    self.iconView = iconView
                    self.addSubview(iconView)
                    
                    iconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    iconView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
                iconView.image = iconImage
                size = iconImage.size.aspectFilled(availableSize)
                iconView.frame = CGRect(origin: CGPoint(), size: size)
            } else {
                if let iconView = self.iconView {
                    self.iconView = nil
                    
                    iconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak iconView] _ in
                        iconView?.removeFromSuperview()
                    })
                    iconView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            }
            
            if let emojiFileId = emojiFileId, let emojiPlaceholderColor = emojiPlaceholderColor {
                size = availableSize
                
                if let emojiFile = self.emojiFile {
                    self.emojiFileDisposable?.dispose()
                    self.emojiFileDisposable = nil
                    
                    let animationLayer: InlineStickerItemLayer
                    if let current = self.animationLayer {
                        animationLayer = current
                    } else {
                        animationLayer = InlineStickerItemLayer(
                            context: component.context,
                            attemptSynchronousLoad: false,
                            emoji: ChatTextInputTextCustomEmojiAttribute(stickerPack: nil, fileId: emojiFile.fileId.id, file: emojiFile),
                            file: emojiFile,
                            cache: component.animationCache,
                            renderer: component.animationRenderer,
                            placeholderColor: emojiPlaceholderColor,
                            pointSize: CGSize(width: 32.0, height: 32.0)
                        )
                        self.animationLayer = animationLayer
                        self.layer.addSublayer(animationLayer)
                        
                        animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        animationLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                    }
                    animationLayer.frame = CGRect(origin: CGPoint(), size: size)
                    animationLayer.isVisibleForAnimations = true
                } else {
                    if self.emojiFileDisposable == nil {
                        self.emojiFileDisposable = (component.context.engine.stickers.resolveInlineStickers(fileIds: [emojiFileId])
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.emojiFile = result[emojiFileId]
                            strongSelf.state?.updated(transition: .immediate)
                        })
                    }
                }
            } else {
                self.emojiFileDisposable?.dispose()
                self.emojiFileDisposable = nil
                
                if let animationLayer = self.animationLayer {
                    self.animationLayer = nil
                    
                    animationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak animationLayer] _ in
                        animationLayer?.removeFromSuperlayer()
                    })
                    animationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
