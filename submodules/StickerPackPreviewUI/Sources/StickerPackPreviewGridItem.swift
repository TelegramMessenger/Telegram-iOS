import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramPresentationData
import ShimmerEffect
import StickerPeekUI
import TextFormat

final class StickerPackPreviewInteraction {
    var previewedItem: StickerPreviewPeekItem?
    var reorderingFileId: MediaId?
    var playAnimatedStickers: Bool
    
    let addStickerPack: (StickerPackCollectionInfo, [StickerPackItem]) -> Void
    let removeStickerPack: (StickerPackCollectionInfo) -> Void
    let emojiSelected: (String, ChatTextInputTextCustomEmojiAttribute) -> Void
    let emojiLongPressed: (String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void
    let addPressed: () -> Void
    
    init(playAnimatedStickers: Bool, addStickerPack: @escaping (StickerPackCollectionInfo, [StickerPackItem]) -> Void, removeStickerPack: @escaping (StickerPackCollectionInfo) -> Void, emojiSelected: @escaping (String, ChatTextInputTextCustomEmojiAttribute) -> Void, emojiLongPressed: @escaping (String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void, addPressed: @escaping () -> Void) {
        self.playAnimatedStickers = playAnimatedStickers
        self.addStickerPack = addStickerPack
        self.removeStickerPack = removeStickerPack
        self.emojiSelected = emojiSelected
        self.emojiLongPressed = emojiLongPressed
        self.addPressed = addPressed
    }
}

final class StickerPackPreviewGridItem: GridItem {
    let context: AccountContext
    let stickerItem: StickerPackItem?
    let interaction: StickerPackPreviewInteraction
    let theme: PresentationTheme
    let isPremium: Bool
    let isLocked: Bool
    let isEmpty: Bool
    let isEditable: Bool
    let isEditing: Bool
    let isAdd: Bool
    
    let section: GridSection? = nil
        
    init(context: AccountContext, stickerItem: StickerPackItem?, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, isPremium: Bool, isLocked: Bool, isEmpty: Bool, isEditable: Bool, isEditing: Bool, isAdd: Bool = false) {
        self.context = context
        self.stickerItem = stickerItem
        self.interaction = interaction
        self.theme = theme
        self.isPremium = isPremium
        self.isLocked = isLocked
        self.isEmpty = isEmpty
        self.isEditable = isEditable
        self.isEditing = isEditing
        self.isAdd = isAdd
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPackPreviewGridItemNode()
        node.setup(context: self.context, stickerItem: self.stickerItem, interaction: self.interaction, theme: self.theme, isLocked: self.isLocked, isPremium: self.isPremium, isEmpty: self.isEmpty, isEditable: self.isEditable, isEditing: self.isEditing, isAdd: self.isAdd)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPackPreviewGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(context: self.context, stickerItem: self.stickerItem, interaction: self.interaction, theme: self.theme, isLocked: self.isLocked, isPremium: self.isPremium, isEmpty: self.isEmpty, isEditable: self.isEditable, isEditing: self.isEditing, isAdd: self.isAdd)
    }
}

private let textFont = Font.regular(20.0)

final class StickerPackPreviewGridItemNode: GridItemNode {
    private var currentState: (AccountContext, StickerPackItem?, Bool, Bool)?
    private var isLocked: Bool?
    private var isPremium: Bool?
    private var isEditable: Bool?
    private var isEmpty: Bool?
    private let containerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    
    private var lockBackground: UIImageView?
    private var lockIconNode: ASImageNode?
    
    private var theme: PresentationTheme?
    
    private var isEditing = false
    private var averageColor: UIColor?
    
    override var isVisibleInGrid: Bool {
        didSet {
            let visibility = self.isVisibleInGrid && (self.interaction?.playAnimatedStickers ?? true)
            if visibility && self.setupTimestamp == nil {
                self.setupTimestamp = CACurrentMediaTime()
            }
            if let animationNode = self.animationNode {
                animationNode.visibility = visibility
            }
        }
    }
    
    private var currentIsPreviewing = false
    
    private let stickerFetchedDisposable = MetaDisposable()
    private let effectFetchedDisposable = MetaDisposable()
    
    var interaction: StickerPackPreviewInteraction?
        
    var stickerPackItem: StickerPackItem? {
        return self.currentState?.1
    }
    
    var isAdd: Bool {
        return self.currentState?.2 == true
    }
    
    override init() {
        self.containerNode = ASDisplayNode()
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self, let image else {
                return
            }
            
            if let stickerItem = strongSelf.currentState?.1 {
                if stickerItem.file.isVideoSticker || stickerItem.file.isAnimatedSticker {
                    strongSelf.removePlaceholder(animated: !firstTime)
                } else {
                    let current = CACurrentMediaTime()
                    if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                        strongSelf.removePlaceholder(animated: true)
                    } else {
                        strongSelf.removePlaceholder(animated: false)
                    }
                }
            }
            firstTime = false
            
            if let self, self.isPremium == true || self.isEditable == true, let averageColor = getAverageColor(image: image) {
                self.averageColor = averageColor
                self.lockBackground?.tintColor = averageColor
                self.lockBackground?.alpha = 1.0
            }
        }
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
        self.effectFetchedDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        guard self.placeholderNode.alpha != 0 else {
            return
        }
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.allowsGroupOpacity = true
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
                self?.placeholderNode.allowsGroupOpacity = false
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    @objc private func handleAddTap() {
        self.interaction?.addPressed()
    }
    
    private var setupTimestamp: Double?
    func setup(context: AccountContext, stickerItem: StickerPackItem?, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, isLocked: Bool, isPremium: Bool, isEmpty: Bool, isEditable: Bool, isEditing: Bool, isAdd: Bool) {
        self.interaction = interaction
        self.theme = theme
        
        let isFirstTime = self.currentState == nil
        if isAdd {
            if !isFirstTime {
                return
            }
            
            let color = theme.actionSheet.controlAccentColor
            self.imageNode.setSignal(.single({ arguments in
                let drawingContext = DrawingContext(size: arguments.imageSize, opaque: false)
                let size = arguments.imageSize
                drawingContext?.withContext({ context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    UIGraphicsPushContext(context)
                    
                    context.setFillColor(color.withMultipliedAlpha(0.1).cgColor)
                    context.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 4.0, dy: 4.0))
                    context.setFillColor(color.cgColor)
                    
                    let plusSize = CGSize(width: 3.0, height: 21.0)
                    context.addPath(UIBezierPath(roundedRect: CGRect(x: floorToScreenPixels((size.width - plusSize.width) / 2.0), y: floorToScreenPixels((size.height - plusSize.height) / 2.0), width: plusSize.width, height: plusSize.height), cornerRadius: plusSize.width / 2.0).cgPath)
                    context.addPath(UIBezierPath(roundedRect: CGRect(x: floorToScreenPixels((size.width - plusSize.height) / 2.0), y: floorToScreenPixels((size.height - plusSize.width) / 2.0), width: plusSize.height, height: plusSize.width), cornerRadius: plusSize.width / 2.0).cgPath)
                    context.fillPath()
                    
                    UIGraphicsPopContext()
                })
                return drawingContext
            }))
            
            self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleAddTap)))
            
            self.currentState = (context, nil, true, false)
            self.setNeedsLayout()
            
            return
        }
        
        if interaction.reorderingFileId != nil {
            self.isHidden = stickerItem?.file.fileId == interaction.reorderingFileId
        } else {
            self.isHidden = false
        }
        
        if self.currentState == nil || self.currentState!.0 !== context || self.currentState!.1 != stickerItem || self.isLocked != isLocked || self.isPremium != isPremium || self.isEmpty != isEmpty || self.isEditing != isEditing || self.isEditable != isEditable {
            self.isLocked = isLocked
            self.isPremium = isPremium
            self.isEditable = isEditable
                        
            if isPremium || isEditing {
                let lockBackground: UIImageView
                let lockIconNode: ASImageNode
                if let currentBackground = self.lockBackground, let currentIcon = self.lockIconNode {
                    lockBackground = currentBackground
                    lockIconNode = currentIcon
                } else {
                    lockBackground = UIImageView()
                    lockBackground.alpha = self.averageColor != nil ? 1.0 : 0.0
                    lockBackground.tintColor = self.averageColor ?? .white
                    lockBackground.clipsToBounds = true
                    lockBackground.isUserInteractionEnabled = false
                    lockIconNode = ASImageNode()
                    lockIconNode.displaysAsynchronously = false
                    
                    if isEditing {
                        lockIconNode.image = generateImage(CGSize(width: 24.0, height: 24.0), contextGenerator: { size, context in
                            context.clear(CGRect(origin: .zero, size: size))
                            context.setFillColor(UIColor.white.cgColor)
                                   
                            context.addEllipse(in: CGRect(x: 5.5, y: 11.0, width: 3.0, height: 3.0))
                            context.fillPath()
                            
                            context.addEllipse(in: CGRect(x: size.width / 2.0 - 1.5, y: 11.0, width: 3.0, height: 3.0))
                            context.fillPath()
                            
                            context.addEllipse(in: CGRect(x: size.width - 3.0 - 5.5, y: 11.0, width: 3.0, height: 3.0))
                            context.fillPath()
                        })
                    } else {
                        lockIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPremiumIcon"), color: .white)
                    }
                    
                    self.lockBackground = lockBackground
                    self.lockIconNode = lockIconNode
                    
                    self.view.addSubview(lockBackground)
                    lockBackground.addSubview(lockIconNode.view)
                    
                    if !isFirstTime {
                        lockBackground.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    }
                }
            } else if let lockBackground = self.lockBackground {
                self.lockBackground = nil
                self.lockIconNode = nil
                
                lockBackground.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                lockBackground.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    lockBackground.removeFromSuperview()
                })
            }
            
            if let stickerItem = stickerItem {
                let visibility = self.isVisibleInGrid && self.interaction?.playAnimatedStickers ?? true
                if visibility && self.setupTimestamp == nil {
                    self.setupTimestamp = CACurrentMediaTime()
                }
                
                let stickerItemFile = stickerItem.file._parse()
                
                if stickerItem.file.isAnimatedSticker || stickerItem.file.isVideoSticker {
                    let dimensions = stickerItem.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    if stickerItem.file.isVideoSticker {
                        self.imageNode.setSignal(chatMessageSticker(account: context.account, userLocation: .other, file: stickerItemFile, small: true, fetched: true))
                    } else {
                        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: context.account.postbox, userLocation: .other, file: stickerItemFile, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))))
                    }
                    
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        self.animationNode = animationNode
                        self.containerNode.insertSubnode(animationNode, aboveSubnode: self.imageNode)
                        animationNode.started = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            self?.imageNode.isHidden = true
                            
                            let current = CACurrentMediaTime()
                            if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                                if !strongSelf.placeholderNode.alpha.isZero {
                                    strongSelf.removePlaceholder(animated: true)
                                }
                            } else {
                                strongSelf.removePlaceholder(animated: false)
                            }
                        }
                    }
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                    self.animationNode?.setup(source: AnimatedStickerResourceSource(account: context.account, resource: stickerItemFile.resource, isVideo: stickerItem.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .cached)
                    
                    self.animationNode?.visibility = visibility
                                        
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: stickerPackFileReference(stickerItemFile), resource: stickerItemFile.resource).start())
                    
                    if stickerItem.file.isPremiumSticker, let effect = stickerItemFile.videoThumbnails.first {
                        self.effectFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: stickerPackFileReference(stickerItemFile), resource: effect.resource).start())
                    }
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: context.account, userLocation: .other, file: stickerItemFile, small: true))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: stickerPackFileReference(stickerItemFile), resource: chatMessageStickerResource(file: stickerItemFile, small: true)).start())
                }
            } else {
                if isEmpty {
                    if !self.placeholderNode.alpha.isZero {
                        self.placeholderNode.alpha = 0.0
                        self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                } else {
                    self.placeholderNode.alpha = 1.0
                }
            }
            
            self.animationNode?.alpha = isLocked ? 0.5 : 1.0
            self.imageNode.alpha = isLocked ? 0.5 : 1.0
            
            self.currentState = (context, stickerItem, false, isEditing)
            self.setNeedsLayout()
        }
        self.isEmpty = isEmpty
        
        if self.isEditing != isEditing {
            self.isEditing = isEditing
            if self.isEditing {
                self.startShaking()
            } else {
                self.containerNode.layer.removeAnimation(forKey: "shaking_position")
                self.containerNode.layer.removeAnimation(forKey: "shaking_rotation")
            }
        }
    }
    
    private func startShaking() {
        func degreesToRadians(_ x: CGFloat) -> CGFloat {
            return .pi * x / 180.0
        }

        let duration: Double = 0.4
        let displacement: CGFloat = 1.0
        let degreesRotation: CGFloat = 2.0
        
        let negativeDisplacement = -1.0 * displacement
        let position = CAKeyframeAnimation.init(keyPath: "position")
        position.beginTime = 0.8
        position.duration = duration
        position.values = [
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement)),
            NSValue(cgPoint: CGPoint(x: 0, y: 0)),
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: 0)),
            NSValue(cgPoint: CGPoint(x: 0, y: negativeDisplacement)),
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement))
        ]
        position.calculationMode = .linear
        position.isRemovedOnCompletion = false
        position.repeatCount = Float.greatestFiniteMagnitude
        position.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
        position.isAdditive = true

        let transform = CAKeyframeAnimation.init(keyPath: "transform")
        transform.beginTime = 2.6
        transform.duration = 0.3
        transform.valueFunction = CAValueFunction(name: CAValueFunctionName.rotateZ)
        transform.values = [
            degreesToRadians(-1.0 * degreesRotation),
            degreesToRadians(degreesRotation),
            degreesToRadians(-1.0 * degreesRotation)
        ]
        transform.calculationMode = .linear
        transform.isRemovedOnCompletion = false
        transform.repeatCount = Float.greatestFiniteMagnitude
        transform.isAdditive = true
        transform.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))

        self.containerNode.layer.add(position, forKey: "shaking_position")
        self.containerNode.layer.add(transform, forKey: "shaking_rotation")
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.containerNode.frame = bounds
        
        let boundsSide = min(bounds.size.width - 14.0, bounds.size.height - 14.0)
        var boundingSize = CGSize(width: boundsSide, height: boundsSide)
                
        if let (_, item, isAdd, _) = self.currentState {
            if isAdd {
                let imageSize = CGSize(width: 512, height: 512).aspectFitted(boundingSize)
                let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = imageFrame
                
                return
            } else if let item = item, let dimensions = item.file.dimensions?.cgSize {
                if item.file.isPremiumSticker {
                    boundingSize = CGSize(width: boundingSize.width * 1.1, height: boundingSize.width * 1.1)
                }
                
                let imageSize = dimensions.aspectFitted(boundingSize)
                let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = imageFrame
                if let animationNode = self.animationNode {
                    animationNode.frame = imageFrame
                    animationNode.updateLayout(size: imageSize)
                }
            }
        }
        
        let imageFrame = self.imageNode.frame
            
        let placeholderFrame = imageFrame
        self.placeholderNode.frame = imageFrame
    
        if let theme = self.theme, let (context, stickerItem, _, _) = self.currentState, let item = stickerItem {
            self.placeholderNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), data: item.file.immediateThumbnailData, size: placeholderFrame.size, enableEffect: context.sharedContext.energyUsageSettings.fullTranslucency)
        }
        
        if let lockBackground = self.lockBackground, let lockIconNode = self.lockIconNode {
            let lockSize: CGSize
            let lockBackgroundFrame: CGRect
            if let (_, _, _, isEditing) = self.currentState, isEditing {
                lockSize = CGSize(width: 24.0, height: 24.0)
                lockBackgroundFrame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: lockSize)
            } else {
                lockSize = CGSize(width: 16.0, height: 16.0)
                lockBackgroundFrame = CGRect(origin: CGPoint(x: bounds.width - lockSize.width - 1.0, y: bounds.height - lockSize.height - 1.0), size: lockSize)
            }
            if lockBackground.image == nil {
                lockBackground.image = generateFilledCircleImage(diameter: lockSize.width, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            lockBackground.frame = lockBackgroundFrame
            lockBackground.layer.cornerRadius = lockSize.width / 2.0
            if #available(iOS 13.0, *) {
                lockBackground.layer.cornerCurve = .circular
            }
            if let icon = lockIconNode.image {
                let iconSize = CGSize(width: icon.size.width - 4.0, height: icon.size.height - 4.0)
                lockIconNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((lockBackgroundFrame.width - iconSize.width) / 2.0), y: floorToScreenPixels((lockBackgroundFrame.height - iconSize.height) / 2.0)), size: iconSize)
            }
        }
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        self.placeholderNode.updateAbsoluteRect(absoluteRect, within: containerSize)
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, maybeItem, isAdd, _) = self.currentState, let interaction = self.interaction, let item = maybeItem {
            if isAdd {
                return
            }
            isPreviewing = interaction.previewedItem == .pack(item.file._parse())
        }
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                self.layer.sublayerTransform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            } else {
                self.layer.sublayerTransform = CATransform3DIdentity
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5)
                }
            }
        }
    }
}
