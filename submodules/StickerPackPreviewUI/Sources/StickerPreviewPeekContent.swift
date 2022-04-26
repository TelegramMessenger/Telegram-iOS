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
    case pack(StickerPackItem)
    case found(FoundStickerItem)
    
    public var file: TelegramMediaFile {
        switch self {
        case let .pack(item):
            return item.file
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
    
    public init(account: Account, theme: PresentationTheme, strings: PresentationStrings, item: StickerPreviewPeekItem, isLocked: Bool = false, menu: [ContextMenuItem]) {
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
    
    public func fullScreenAccessoryNode() -> (PeekControllerAccessoryNode & ASDisplayNode)? {
        if self.isLocked {
            return PremiumStickerPackAccessoryNode(theme: self.theme, strings: self.strings)
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
            let animationNode = AnimatedStickerNode()
            self.animationNode = animationNode
            
            let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 400.0, height: 400.0))
            
            animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource, isVideo: item.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: isPremiumSticker ? .once : .loop, mode: .direct(cachePathPrefix: nil))
            animationNode.visibility = true
            animationNode.addSubnode(self.textNode)
            
            if isPremiumSticker, let effect = item.file.videoThumbnails.first {
                self.effectDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: .standalone(media: item.file), resource: effect.resource).start())
                
                let source = AnimatedStickerResourceSource(account: account, resource: effect.resource, fitzModifier: nil)
                let additionalAnimationNode = AnimatedStickerNode()
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
                        Queue.mainQueue().after(0.5, {
                            animationNode.play()
                            additionalAnimationNode.play()
                        })
                    }
                }
            }
        } else {
            self.addSubnode(self.imageNode)
        }
        
        if let additionalAnimationNode = self.additionalAnimationNode {
            self.addSubnode(additionalAnimationNode)
        }
    }
    
    deinit {
        self.effectDisposable.dispose()
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let boundingSize = CGSize(width: 180.0, height: 180.0).fitted(size)
        
        if let dimensitons = self.item.file.dimensions {
            let textSpacing: CGFloat = 10.0
            let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
            
            let imageSize = dimensitons.cgSize.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            var imageFrame = CGRect(origin: CGPoint(x: 0.0, y: textSize.height + textSpacing), size: imageSize)
            var centerOffset: CGFloat = 0.0
            if self.item.file.isPremiumSticker {
                centerOffset = floor(imageFrame.width * 0.33)
                imageFrame = imageFrame.offsetBy(dx: centerOffset, dy: 0.0)
            }
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
                
                if let additionalAnimationNode = self.additionalAnimationNode {
                    additionalAnimationNode.frame = imageFrame.offsetBy(dx: -imageFrame.width / 2.0, dy: 0.0).insetBy(dx: -imageFrame.width / 2.0, dy: -imageFrame.height / 2.0)
                    additionalAnimationNode.updateLayout(size: additionalAnimationNode.frame.size)
                }
            }
            
            self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0) - centerOffset, y: -textSize.height - textSpacing), size: textSize)
            
            return CGSize(width: imageFrame.width, height: imageFrame.height + textSize.height + textSpacing)
        } else {
            return CGSize(width: size.width, height: 10.0)
        }
    }
}

final class PremiumStickerPackAccessoryNode: ASDisplayNode, PeekControllerAccessoryNode {
    let textNode: ImmediateTextNode
    let proceedButton: SolidRoundedButtonNode
    let cancelButton: HighlightableButtonNode
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(string: strings.Premium_Stickers_Description, font: Font.regular(17.0), textColor: .black)
        self.textNode.lineSpacing = 0.1
        self.textNode.alpha = 0.4
        
        self.proceedButton = SolidRoundedButtonNode(title: strings.Premium_Stickers_Proceed, icon: UIImage(bundleImageName: "Premium/ButtonIcon"), theme: SolidRoundedButtonTheme(theme: theme), height: 50.0, cornerRadius: 11.0, gloss: true)
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(strings.Common_Cancel, with: Font.regular(17.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.proceedButton)
        self.addSubnode(self.cancelButton)
        
        self.proceedButton.pressed = {
            
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func cancelPressed() {
        
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 16.0
        
        let cancelSize = self.cancelButton.measure(size)
        self.cancelButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - cancelSize.width) / 2.0), y: size.height - cancelSize.height - 49.0), size: cancelSize)
        
        let buttonWidth = size.width - sideInset * 2.0
        let buttonHeight = self.proceedButton.updateLayout(width: buttonWidth, transition: transition)
        self.proceedButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - buttonWidth) / 2.0), y: size.height - cancelSize.height - 49.0 - buttonHeight - 23.0), size: CGSize(width: buttonWidth, height: buttonHeight))
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - sideInset * 4.0, height: CGFloat.greatestFiniteMagnitude))
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - cancelSize.height - 48.0 - buttonHeight - 20.0 - textSize.height - 31.0), size: textSize)
    }
}
