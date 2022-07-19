import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ContextUI
import SolidRoundedButtonNode
import TelegramPresentationData
import AccountContext
import AppBundle

public enum StickerPreviewPeekItem: Equatable {
    case pack(TelegramMediaFile)
    case found(FoundStickerItem)
    
    public var file: TelegramMediaFile {
        switch self {
        case let .pack(file):
            return file
        case let .found(item):
            return item.file
        }
    }
}

public final class StickerPreviewPeekContent: PeekControllerContent {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    public let item: StickerPreviewPeekItem
    let isLocked: Bool
    let menu: [ContextMenuItem]
    let openPremiumIntro: () -> Void
    
    public init(account: Account, theme: PresentationTheme, strings: PresentationStrings, item: StickerPreviewPeekItem, isLocked: Bool = false, menu: [ContextMenuItem], openPremiumIntro: @escaping () -> Void) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.item = item
        self.isLocked = isLocked
        if isLocked {
            self.menu = []
        } else {
            self.menu = menu
        }
        self.openPremiumIntro = openPremiumIntro
    }
    
    public func presentation() -> PeekControllerContentPresentation {
        return .freeform
    }
    
    public func menuActivation() -> PeerControllerMenuActivation {
        return .press
    }
    
    public func menuItems() -> [ContextMenuItem] {
        return self.menu
    }
    
    public func node() -> PeekControllerContentNode & ASDisplayNode {
        return StickerPreviewPeekContentNode(account: self.account, item: self.item)
    }
    
    public func topAccessoryNode() -> ASDisplayNode? {
        return nil
    }
    
    public func fullScreenAccessoryNode(blurView: UIVisualEffectView) -> (PeekControllerAccessoryNode & ASDisplayNode)? {
        if self.isLocked {
            return PremiumStickerPackAccessoryNode(theme: self.theme, strings: self.strings, proceed: self.openPremiumIntro)
        } else {
            return nil
        }
    }
    
    public func isEqual(to: PeekControllerContent) -> Bool {
        if let to = to as? StickerPreviewPeekContent {
            return self.item == to.item
        } else {
            return false
        }
    }
}

public final class StickerPreviewPeekContentNode: ASDisplayNode, PeekControllerContentNode {
    private let account: Account
    private let item: StickerPreviewPeekItem
    
    private var textNode: ASTextNode
    public var imageNode: TransformImageNode
    public var animationNode: AnimatedStickerNode?
    public var additionalAnimationNode: AnimatedStickerNode?
    
    private let effectDisposable = MetaDisposable()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let _ready = Promise<Bool>()
    
    init(account: Account, item: StickerPreviewPeekItem) {
        self.account = account
        self.item = item
        
        self.textNode = ASTextNode()
        self.imageNode = TransformImageNode()
        
        for case let .Sticker(text, _, _) in item.file.attributes {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(32.0), textColor: .black)
            break
        }
        
        let isPremiumSticker = item.file.isPremiumSticker
        
        if item.file.isAnimatedSticker || item.file.isVideoSticker {
            let animationNode = DefaultAnimatedStickerNodeImpl()
            animationNode.overrideVisibility = true
            self.animationNode = animationNode
            
            let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 400.0, height: 400.0))
            
            animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource, isVideo: item.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: isPremiumSticker ? .once : .loop, mode: .direct(cachePathPrefix: nil))
            animationNode.visibility = true
            animationNode.addSubnode(self.textNode)
            
            if isPremiumSticker, let effect = item.file.videoThumbnails.first {
                self.effectDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: .standalone(media: item.file), resource: effect.resource).start())
                
                let source = AnimatedStickerResourceSource(account: account, resource: effect.resource, fitzModifier: nil)
                let additionalAnimationNode = DefaultAnimatedStickerNodeImpl()
                additionalAnimationNode.setup(source: source, width: Int(fittedDimensions.width * 2.0), height: Int(fittedDimensions.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                additionalAnimationNode.visibility = true
                self.additionalAnimationNode = additionalAnimationNode
            }
        } else {
            self.imageNode.addSubnode(self.textNode)
            self.animationNode = nil
        }
        
        self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: false, fetched: true))
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
            
            if isPremiumSticker {
                animationNode.completed = { [weak self] _ in
                    if let strongSelf = self, let animationNode = strongSelf.animationNode, let additionalAnimationNode = strongSelf.additionalAnimationNode {
                        Queue.mainQueue().async {
                            animationNode.play(firstFrame: false, fromIndex: nil)
                            additionalAnimationNode.play(firstFrame: false, fromIndex: nil)
                        }
                    }
                }
            }
        } else {
            self.addSubnode(self.imageNode)
        }
        
        if let additionalAnimationNode = self.additionalAnimationNode {
            self.addSubnode(additionalAnimationNode)
        }
        
        if let animationNode = self.animationNode {
            animationNode.started = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf._ready.set(.single(true))
            }
        } else {
            self.imageNode.imageUpdated = { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf._ready.set(.single(true))
            }
        }
    }
    
    deinit {
        self.effectDisposable.dispose()
    }
    
    public func ready() -> Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let boundingSize: CGSize
        if let _ = self.additionalAnimationNode {
            boundingSize = CGSize(width: 240.0, height: 240.0).fitted(size)
        } else {
            boundingSize = CGSize(width: 180.0, height: 180.0).fitted(size)
        }
            
        if let dimensitons = self.item.file.dimensions {
            var topOffset: CGFloat = 0.0
            var textSpacing: CGFloat = 50.0
            
            if size.width == 292.0 {
                topOffset = 60.0
                textSpacing -= 10.0
            } else if size.width == 347.0 && size.height == 577.0 {
                topOffset = 60.0
                textSpacing -= 10.0
            }
            
            let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
            
            let imageSize = dimensitons.cgSize.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            var imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: textSize.height + textSpacing - topOffset), size: imageSize)
            var centerOffset: CGFloat = 0.0
            if self.item.file.isPremiumSticker {
                let originalImageFrame = imageFrame
                imageFrame.origin.x = size.width - imageFrame.width - 18.0
                centerOffset = imageFrame.minX - originalImageFrame.minX
            }
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
                
                if let additionalAnimationNode = self.additionalAnimationNode {
                    additionalAnimationNode.frame = imageFrame.offsetBy(dx: -imageFrame.width * 0.245 + 21.0, dy: -1.0).insetBy(dx: -imageFrame.width * 0.245, dy: -imageFrame.height * 0.245)
                    additionalAnimationNode.updateLayout(size: additionalAnimationNode.frame.size)
                }
            }
            
            self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0) - centerOffset, y: -textSize.height - textSpacing), size: textSize)
            
            return CGSize(width: size.width, height: imageFrame.height + textSize.height + textSpacing)
        } else {
            return CGSize(width: size.width, height: 10.0)
        }
    }
}

final class PremiumStickerPackAccessoryNode: SparseNode, PeekControllerAccessoryNode {
    var dismiss: () -> Void = {}
    let proceed: () -> Void
    
    let textNode: ImmediateTextNode
    let proceedButton: SolidRoundedButtonNode
    let cancelButton: HighlightableButtonNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, proceed: @escaping () -> Void) {
        self.proceed = proceed
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(string: strings.Premium_Stickers_Description, font: Font.regular(17.0), textColor: theme.actionSheet.secondaryTextColor)
        self.textNode.lineSpacing = 0.1
        
        self.proceedButton = SolidRoundedButtonNode(title: strings.Premium_Stickers_Proceed, theme: SolidRoundedButtonTheme(
            backgroundColor: .white,
            backgroundColors: [
            UIColor(rgb: 0x0077ff),
            UIColor(rgb: 0x6b93ff),
            UIColor(rgb: 0x8878ff),
            UIColor(rgb: 0xe46ace)
        ], foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: true)
        self.proceedButton.iconPosition = .right
        self.proceedButton.iconSpacing = 4.0
        self.proceedButton.animation = "premium_unlock"
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(strings.Common_Cancel, with: Font.regular(17.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.proceedButton)
        self.addSubnode(self.cancelButton)
        
        self.proceedButton.pressed = { [weak self] in
            self?.dismiss()
            self?.proceed()
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 16.0
        
        var bottomOffset: CGFloat = 0.0
        if size.width == 320.0 {
            bottomOffset = 30.0
        } else if size.width == 375.0 && size.height == 667.0 {
            bottomOffset = 30.0
        }
        
        let cancelSize = self.cancelButton.measure(size)
        self.cancelButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - cancelSize.width) / 2.0), y: size.height - cancelSize.height - 49.0 + bottomOffset), size: cancelSize)
        
        let buttonWidth = size.width - sideInset * 2.0
        let buttonHeight = self.proceedButton.updateLayout(width: buttonWidth, transition: transition)
        self.proceedButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - buttonWidth) / 2.0), y: size.height - cancelSize.height - 49.0 - buttonHeight - 23.0 + bottomOffset), size: CGSize(width: buttonWidth, height: buttonHeight))
        
        let textSideInset = size.width == 320.0 ? sideInset : sideInset * 2.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - textSideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - cancelSize.height - 48.0 - buttonHeight - 20.0 - textSize.height - 31.0 + bottomOffset), size: textSize)
    }
}
