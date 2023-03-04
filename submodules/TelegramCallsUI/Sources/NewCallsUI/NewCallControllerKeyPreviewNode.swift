import UIKit
import Display
import AsyncDisplayKit
import Emoji
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import EmojiTextAttachmentView
import TextFormat
import TelegramUIPreferences
import MultiAnimationRenderer
import AnimationCache


private class EmojiNode: ASDisplayNode {
    private let animatedEmojiStickers: [String: [StickerPackItem]]
    private let keyText: String
    private var files: [TelegramMediaFile] = []
    private var stickers: [InlineStickerItemLayer] = []
    private let accountContext: AccountContext
    private let animationRenderer: MultiAnimationRenderer
    private let animationCache: AnimationCache
    private let keyTextNode: ASTextNode
    private var isShowKeyText = false
    
    init(
        accountContext: AccountContext,
        animatedEmojiStickers: [String: [StickerPackItem]],
        keyText: String
    ) {
        self.accountContext = accountContext
        self.animationRenderer = accountContext.animationRenderer
        self.animationCache = accountContext.animationCache
        self.keyText = keyText
        self.animatedEmojiStickers = animatedEmojiStickers
        
        self.keyTextNode = ASTextNode()
        self.keyTextNode.displaysAsynchronously = false
        super.init()
        
        
        for key in keyText {
            let pack = animatedEmojiStickers["\(key)"]?.first
            
            if let file = pack?.file {
                files.append(file)
            } else {
                isShowKeyText = true
                break
            }
        }

        if isShowKeyText {
            self.keyTextNode.attributedText = NSAttributedString(string: keyText, attributes: [NSAttributedString.Key.font: Font.regular(36.0), NSAttributedString.Key.kern: 11.0 as NSNumber])
            self.addSubnode(keyTextNode)
        } else {
            for file in files {
                let animationLayer = InlineStickerItemLayer(
                    context: self.accountContext,
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                    file: file,
                    cache: animationCache,
                    renderer: animationRenderer,
                    placeholderColor: .clear,
                    pointSize: CGSize(width: 48, height: 48)
                )
                
                layer.addSublayer(animationLayer)
                stickers.append(animationLayer)
            }
        }
       
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGFloat {
        if isShowKeyText {
            let keyTextSize = self.keyTextNode.measure(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.keyTextNode, frame: CGRect(origin: CGPoint(x: 0, y: 0), size: keyTextSize))
            
            return keyTextSize.width
        } else {
            var contentX = 0.0
            for sticker in stickers {
                sticker.frame = CGRect(origin: CGPoint(x: contentX, y: 0), size: CGSize(width: 50, height: 50))
                contentX += 56
                sticker.isVisibleForAnimations = true
            }
            return contentX
        }
        
    }
}

final class NewCallControllerKeyPreviewNode: ASDisplayNode {
    private let modalContainer: ASDisplayNode
    private let backgroundLayer: SimpleLayer
    private let buttonBackgroundLayer: SimpleLayer
    private let separatorLayer: SimpleLayer
    
    private let contentNode: ASDisplayNode
    private let titleTextNode: ASTextNode
    private let infoTextNode: ASTextNode
    private let okButtonNode: ASButtonNode
    private let emojiNode: EmojiNode
    
    private var animationLayer: InlineStickerItemLayer?
    
    private let animatedEmojiStickers: [String: [StickerPackItem]]
    
    private let dismiss: () -> Void
    
    init(context: AccountContext, stikers: [String: [StickerPackItem]], keyText: String, infoText: String, dismiss: @escaping () -> Void) {
        self.backgroundLayer = SimpleLayer()
        self.buttonBackgroundLayer = SimpleLayer()
        self.separatorLayer = SimpleLayer()
        
        self.modalContainer = ASDisplayNode()
        self.modalContainer.displaysAsynchronously = false

        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.infoTextNode = ASTextNode()
        self.infoTextNode.displaysAsynchronously = false
        self.okButtonNode = ASButtonNode()
        self.okButtonNode.displaysAsynchronously = false
        okButtonNode.tintColor = .white
        self.emojiNode = EmojiNode(accountContext: context, animatedEmojiStickers: stikers, keyText: keyText)
        self.emojiNode.displaysAsynchronously = false
        
        self.dismiss = dismiss
        self.contentNode = ASDisplayNode()
        self.animatedEmojiStickers = stikers
        
        super.init()
    
        self.titleTextNode.attributedText = NSAttributedString(string: "This call is end-to end encrypted", font: Font.bold(16), textColor: UIColor.white, paragraphAlignment: .center)
        
        self.infoTextNode.attributedText = NSAttributedString(string: infoText, font: Font.regular(14.0), textColor: UIColor.white, paragraphAlignment: .center)
        
        self.okButtonNode.setTitle("OK", with: Font.regular(20), with: .white, for: .normal)
        self.layer.addSublayer(separatorLayer)
        self.contentNode.layer.addSublayer(backgroundLayer)
        self.contentNode.addSubnode(self.titleTextNode)
        self.contentNode.addSubnode(self.infoTextNode)
        
        
        modalContainer.addSubnode(contentNode)
        modalContainer.addSubnode(okButtonNode)
        self.okButtonNode.layer.addSublayer(buttonBackgroundLayer)
        self.addSubnode(modalContainer)
        self.addSubnode(self.emojiNode)
        okButtonNode.addTarget(self, action: #selector(okTap), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, hasVideo: Bool) {
        backgroundLayer.backgroundColor = hasVideo ? UIColor.black.withAlphaComponent(0.5).cgColor : UIColor.white.withAlphaComponent(0.25).cgColor
        separatorLayer.backgroundColor = UIColor.clear.cgColor
        buttonBackgroundLayer.backgroundColor = hasVideo ? UIColor.black.withAlphaComponent(0.5).cgColor : UIColor.white.withAlphaComponent(0.25).cgColor
        
        let contentNodeSize = self.contentNode.measure(CGSize(width: size.width - 90, height: 170))
        transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: 0, y: 0), size: contentNodeSize))
        
        let roundPath = UIBezierPath(
            roundedRect: contentNode.bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        let maskLayer = CAShapeLayer()
        maskLayer.path = roundPath.cgPath
        self.backgroundLayer.mask = maskLayer
        self.backgroundLayer.frame = contentNode.bounds
        
        let width = self.emojiNode.updateLayout(size: contentNodeSize, transition: transition)
        let keyTextSize = CGSize(width: width, height: 50)
        transition.updateFrame(node: self.emojiNode, frame: CGRect(origin: CGPoint(x: size.width / 2 - keyTextSize.width / 2, y: 150), size: keyTextSize))
        
        let titleTextSize = self.titleTextNode.measure(CGSize(width: contentNodeSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleTextNode, frame: CGRect(origin: CGPoint(x: floor((contentNodeSize.width - titleTextSize.width) / 2.0), y: 80), size: titleTextSize))
        
        let infoTextSize = self.infoTextNode.measure(CGSize(width: contentNodeSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.infoTextNode, frame: CGRect(origin: CGPoint(x: floor((contentNodeSize.width - infoTextSize.width) / 2.0), y: titleTextNode.frame.origin.y + titleTextNode.frame.height + 10), size: infoTextSize))
        
        transition.updateFrame(layer: separatorLayer, frame: CGRect(origin: CGPoint(x: size.width / 2 - contentNodeSize.width / 2, y: contentNode.frame.maxY), size: CGSize(width: contentNodeSize.width, height: 1)))
        
        transition.updateFrame(node: okButtonNode, frame: CGRect(origin: CGPoint(x: 0, y: separatorLayer.frame.origin.y + separatorLayer.frame.height), size: CGSize(width: contentNodeSize.width, height: 55)))
        
        let roundButtonPath = UIBezierPath(
            roundedRect: okButtonNode.bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        let buttomMaskLayer = CAShapeLayer()
        buttomMaskLayer.path = roundButtonPath.cgPath
        self.buttonBackgroundLayer.mask = buttomMaskLayer
        buttonBackgroundLayer.frame = okButtonNode.bounds
        modalContainer.frame = CGRect(origin: CGPoint(x: size.width / 2 - contentNodeSize.width / 2, y: frame.height * 0.15), size: CGSize(width: contentNodeSize.width, height: okButtonNode.frame.origin.y + okButtonNode.frame.height))
        transition.updateFrame(node: modalContainer, frame: CGRect(origin: CGPoint(x: size.width / 2 - contentNodeSize.width / 2, y: 130), size: CGSize(width: contentNodeSize.width, height: okButtonNode.frame.origin.y + okButtonNode.frame.height)))
    }
    
    func animateIn(from rect: CGRect, fromNode: ASDisplayNode) {
        self.modalContainer.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.modalContainer.layer.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        if let transitionView = fromNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.addSubview(transitionView)
            transitionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            transitionView.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.modalContainer.layer.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                transitionView?.removeFromSuperview()
            })
            transitionView.layer.animateScale(from: 1.0, to: 0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        
        modalContainer.layer.animateScale(from: 0, to: 1, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.modalContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        emojiNode.layer.animatePositionKeyframes(values: [CGPoint(x: rect.midX, y: rect.midY),
                                                          CGPoint(x: rect.maxX - 100, y: rect.maxY + 70),
                                                          self.emojiNode.layer.position], duration: 0.2)
        
        emojiNode.layer.animateScale(from: 0.4, to: 1, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        
        if let transitionView = fromNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.addSubview(transitionView)
            transitionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            transitionView.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.emojiNode.layer.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                transitionView?.removeFromSuperview()
            })
            transitionView.layer.animateScale(from: 1.0, to: self.emojiNode.frame.size.width / rect.size.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
    }
    
    func animateOut(to rect: CGRect, toNode: ASDisplayNode, completion: @escaping () -> Void) {
        self.modalContainer.layer.animatePosition(from: self.modalContainer.layer.position, to: CGPoint(x: rect.midX + 2.0, y: rect.midY), duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.modalContainer.layer.animateScale(from: 1.0, to: 0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.modalContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        self.emojiNode.layer.animatePosition(from: self.emojiNode.layer.position, to: CGPoint(x: rect.midX + 2.0, y: rect.midY), duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.emojiNode.layer.animateScale(from: 1.0, to: rect.size.width / (self.emojiNode.frame.size.width - 2.0), duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        
    }
    
    @objc func okTap() {
        dismiss()
    }
}


