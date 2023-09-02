import Foundation
import UIKit
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import ComponentFlow
import TinyThumbnail
import ImageBlur
import MediaResources
import Display
import TelegramPresentationData
import BundleIconComponent
import MultilineTextComponent
import AppBundle
import EmojiTextAttachmentView
import TextFormat
import AnimatedCountLabelNode
import LottieComponent
import LottieComponentResourceContent

final class StoryItemOverlaysView: UIView {
    static let counterFont: UIFont = {
        return Font.with(size: 17.0, design: .camera, weight: .semibold, traits: .monospacedNumbers)
    }()
    
    private static let shadowImage: UIImage = {
        return UIImage(bundleImageName: "Stories/ReactionShadow")!
    }()
    
    private static let coverImage: UIImage = {
        return UIImage(bundleImageName: "Stories/ReactionOutline")!
    }()
    
    private final class ItemView: HighlightTrackingButton {
        private let shadowView: UIImageView
        private let coverView: UIImageView
        
        private var directStickerView: ComponentView<Empty>?
        private var customEmojiView: EmojiTextAttachmentView?
        private var file: TelegramMediaFile?
        private var counterText: AnimatedCountLabelView?
        
        private var reaction: MessageReaction.Reaction?
        var activate: ((UIView, MessageReaction.Reaction) -> Void)?
        var requestUpdate: (() -> Void)?
        
        private var requestStickerDisposable: Disposable?
        private var resolvedFile: TelegramMediaFile?
        
        private var customEmojiLoadDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.shadowView = UIImageView(image: StoryItemOverlaysView.shadowImage)
            self.coverView = UIImageView(image: StoryItemOverlaysView.coverImage)
            
            super.init(frame: frame)
            
            self.addSubview(self.shadowView)
            self.addSubview(self.coverView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                
                if highlighted {
                    let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                    transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(0.9, 0.9, 1.0))
                } else {
                    let transition: Transition = .immediate
                    transition.setSublayerTransform(view: self, transform: CATransform3DIdentity)
                    var fromScale: Double = 0.9
                    if self.layer.animation(forKey: "sublayerTransform") != nil, let presentation = self.layer.presentation() {
                        let t = presentation.sublayerTransform
                        fromScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    }
                    self.layer.animateSpring(from: fromScale as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.requestStickerDisposable?.dispose()
            self.customEmojiLoadDisposable?.dispose()
        }
        
        @objc private func pressed() {
            guard let activate = self.activate, let reaction = self.reaction else {
                return
            }
            activate(self, reaction)
        }
        
        func update(
            context: AccountContext,
            reaction: MessageReaction.Reaction,
            flags: MediaArea.ReactionFlags,
            counter: Int,
            availableReactions: StoryAvailableReactions?,
            entityFiles: [MediaId: TelegramMediaFile],
            synchronous: Bool,
            size: CGSize
        ) {
            var transition = Transition(animation: .curve(duration: 0.18, curve: .easeInOut))
            if self.reaction == nil {
                transition = .immediate
            }
            
            self.reaction = reaction
            
            let insets = UIEdgeInsets(top: -0.08, left: -0.05, bottom: -0.01, right: -0.02)
            self.coverView.frame = CGRect(origin: CGPoint(x: size.width * insets.left, y: size.height * insets.top), size: CGSize(width: size.width - size.width * insets.left - size.width * insets.right, height: size.height - size.height * insets.top - size.height * insets.bottom))
            self.shadowView.frame = self.coverView.frame
            
            if flags.contains(.isFlipped) {
                self.coverView.transform = CGAffineTransformMakeScale(-1.0, 1.0)
                self.shadowView.transform = self.coverView.transform
            }
            self.coverView.tintColor = flags.contains(.isDark) ? UIColor(rgb: 0x000000, alpha: 0.5) : UIColor.white
            
            let minSide = floor(min(200.0, min(size.width, size.height)) * 0.65)
            let itemSize = CGSize(width: minSide, height: minSide)
            
            var file: TelegramMediaFile? = self.file
            if self.file == nil {
                switch reaction {
                case .builtin:
                    if let availableReactions {
                        for reactionItem in availableReactions.reactionItems {
                            if reactionItem.reaction.rawValue == reaction {
                                file = reactionItem.stillAnimation
                                break
                            }
                        }
                    }
                case let .custom(fileId):
                    if let resolvedFile = self.resolvedFile, resolvedFile.fileId.id == fileId {
                        file = resolvedFile
                    } else if let value = entityFiles[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] {
                        file = value
                    } else {
                        if self.requestStickerDisposable == nil {
                            self.requestStickerDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                            |> deliverOnMainQueue).start(next: { [weak self] result in
                                guard let self else {
                                    return
                                }
                                if let value = result[fileId] {
                                    self.resolvedFile = value
                                    self.requestUpdate?()
                                }
                            })
                        }
                    }
                }
            }
            
            if counter != 0 {
                var conterTransition = transition
                let counterText: AnimatedCountLabelView
                if let current = self.counterText {
                    counterText = current
                } else {
                    conterTransition = conterTransition.withAnimation(.none)
                    counterText = AnimatedCountLabelView(frame: CGRect())
                    counterText.isUserInteractionEnabled = false
                    self.counterText = counterText
                    self.addSubview(counterText)
                }
                
                var segments: [AnimatedCountLabelView.Segment] = []
                segments.append(.number(counter, NSAttributedString(string: "\(counter)", font: counterFont, textColor: flags.contains(.isDark) ? .white : .black)))
                let counterTextLayout = counterText.update(size: CGSize(width: 200.0, height: 200.0), segments: segments, transition: conterTransition.containedViewLayoutTransition)
                conterTransition.setPosition(view: counterText, position: CGPoint(x: size.width * 0.5, y: size.height * 0.765))
                conterTransition.setBounds(view: counterText, bounds: CGRect(origin: CGPoint(), size: counterTextLayout.size))
                
                let counterScale = max(0.01, min(1.8, size.width / 140.0))
                conterTransition.setScale(view: counterText, scale: counterScale)
                
                if !transition.animation.isImmediate && conterTransition.animation.isImmediate {
                    transition.animateAlpha(view: counterText, from: 0.0, to: 1.0)
                    transition.animateScale(view: counterText, from: 0.001, to: counterScale)
                }
            } else {
                if let counterText = self.counterText {
                    self.counterText = nil
                    transition.setAlpha(view: counterText, alpha: 0.0, completion: { [weak counterText] _ in
                        counterText?.removeFromSuperview()
                    })
                    transition.setScale(view: counterText, scale: 0.001)
                }
            }
            
            if self.file?.fileId != file?.fileId, let file {
                self.file = file
                
                let isBuiltinSticker = file.isAnimatedSticker && !file.isVideoSticker && !file.isVideoEmoji
                
                if isBuiltinSticker {
                    let directStickerView: ComponentView<Empty>
                    if let current = self.directStickerView {
                        directStickerView = current
                    } else {
                        directStickerView = ComponentView()
                        self.directStickerView = directStickerView
                        
                        self.customEmojiLoadDisposable?.dispose()
                        self.customEmojiLoadDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: file.resource)).start()
                    }
                    var color: UIColor?
                    if file.isCustomTemplateEmoji {
                        color = flags.contains(.isDark) ? .white : .black
                    }
                    let _ = directStickerView.update(
                        transition: .immediate,
                        component: AnyComponent(LottieComponent(
                            content: LottieComponent.ResourceContent(context: context, file: file, attemptSynchronously: synchronous),
                            color: color,
                            renderingScale: 2.0,
                            loop: true
                        )),
                        environment: {},
                        containerSize: itemSize
                    )
                } else {
                    if let directStickerView = self.directStickerView {
                        self.directStickerView = nil
                        directStickerView.view?.removeFromSuperview()
                    }
                }
                
                if !isBuiltinSticker {
                    let customEmojiView: EmojiTextAttachmentView
                    if let current = self.customEmojiView {
                        customEmojiView = current
                    } else {
                        customEmojiView = EmojiTextAttachmentView(
                            context: context,
                            userLocation: .other,
                            emoji: ChatTextInputTextCustomEmojiAttribute(
                                interactivelySelectedFromPackId: nil,
                                fileId: file.fileId.id,
                                file: file
                            ),
                            file: file,
                            cache: context.animationCache,
                            renderer: context.animationRenderer,
                            placeholderColor: flags.contains(.isDark) ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.1),
                            pointSize: CGSize(width: min(256, itemSize.width), height: min(256, itemSize.height))
                        )
                        customEmojiView.updateTextColor(flags.contains(.isDark) ? .white : .black)
                        
                        self.customEmojiLoadDisposable?.dispose()
                        self.customEmojiLoadDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: file.resource)).start()
                        
                        customEmojiView.isUserInteractionEnabled = false
                        self.customEmojiView = customEmojiView
                        self.addSubview(customEmojiView)
                    }
                } else {
                    if let customEmojiView = self.customEmojiView {
                        self.customEmojiView = nil
                        customEmojiView.removeFromSuperview()
                    }
                }
            }
            
            if let customEmojiView = self.customEmojiView {
                var stickerTransition = transition
                if customEmojiView.bounds.isEmpty {
                    stickerTransition = stickerTransition.withAnimation(.none)
                }
                
                let counterFractionOffset: CGFloat
                let stickerScale: CGFloat
                if counter != 0 {
                    counterFractionOffset = -0.05
                    stickerScale = 0.8
                } else {
                    counterFractionOffset = 0.0
                    stickerScale = 1.0
                }
                let stickerFrame = itemSize.centered(around: CGPoint(x: size.width * 0.5, y: size.height * (0.47 + counterFractionOffset)))
                
                stickerTransition.setPosition(view: customEmojiView, position: stickerFrame.center)
                stickerTransition.setBounds(view: customEmojiView, bounds: CGRect(origin: CGPoint(), size: stickerFrame.size))
                stickerTransition.setScale(view: customEmojiView, scale: stickerScale)
            }
            
            if let directStickerView = self.directStickerView?.view {
                var stickerTransition = transition
                if directStickerView.superview == nil {
                    self.addSubview(directStickerView)
                    stickerTransition = stickerTransition.withAnimation(.none)
                }
                
                let counterFractionOffset: CGFloat
                let stickerScale: CGFloat
                if counter != 0 {
                    counterFractionOffset = -0.05
                    stickerScale = 0.8
                } else {
                    counterFractionOffset = 0.0
                    stickerScale = 1.0
                }
                let stickerFrame = itemSize.centered(around: CGPoint(x: size.width * 0.5, y: size.height * (0.47 + counterFractionOffset)))
                
                stickerTransition.setPosition(view: directStickerView, position: stickerFrame.center)
                stickerTransition.setBounds(view: directStickerView, bounds: CGRect(origin: CGPoint(), size: stickerFrame.size))
                stickerTransition.setScale(view: directStickerView, scale: stickerScale)
            }
        }
    }
    
    private var itemViews: [Int: ItemView] = [:]
    var activate: ((UIView, MessageReaction.Reaction) -> Void)?
    var requestUpdate: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (_, itemView) in self.itemViews {
            if let result = itemView.hitTest(self.convert(point, to: itemView), with: event) {
                return result
            }
        }
        return nil
    }
    
    func update(
        context: AccountContext,
        strings: PresentationStrings,
        peer: EnginePeer,
        story: EngineStoryItem,
        availableReactions: StoryAvailableReactions?,
        entityFiles: [MediaId: TelegramMediaFile],
        size: CGSize,
        isCaptureProtected: Bool,
        attemptSynchronous: Bool,
        transition: Transition
    ) {
        var nextId = 0
        for mediaArea in story.mediaAreas {
            switch mediaArea {
            case let .reaction(coordinates, reaction, flags):
                let referenceSize = size
                var areaSize = CGSize(width: coordinates.width / 100.0 * referenceSize.width, height: coordinates.height / 100.0 * referenceSize.height)
                areaSize.width *= 0.97
                areaSize.height *= 0.97
                let targetFrame = CGRect(x: coordinates.x / 100.0 * referenceSize.width - areaSize.width * 0.5, y: coordinates.y / 100.0 * referenceSize.height - areaSize.height * 0.5, width: areaSize.width, height: areaSize.height)
                if targetFrame.width < 5.0 || targetFrame.height < 5.0 {
                    continue
                }
                
                let itemView: ItemView
                let itemId = nextId
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemView = ItemView(frame: CGRect())
                    itemView.activate = { [weak self] view, reaction in
                        self?.activate?(view, reaction)
                    }
                    itemView.requestUpdate = { [weak self] in
                        self?.requestUpdate?()
                    }
                    self.itemViews[itemId] = itemView
                    self.addSubview(itemView)
                }
                                
                transition.setPosition(view: itemView, position: targetFrame.center)
                transition.setBounds(view: itemView, bounds: CGRect(origin: CGPoint(), size: targetFrame.size))
                transition.setTransform(view: itemView, transform: CATransform3DMakeRotation(coordinates.rotation * (CGFloat.pi / 180.0), 0.0, 0.0, 1.0))
                
                var counter = 0
                if let reactionData = story.views?.reactions.first(where: { $0.value == reaction }) {
                    counter = Int(reactionData.count)
                }
                
                itemView.update(
                    context: context,
                    reaction: reaction,
                    flags: flags,
                    counter: counter,
                    availableReactions: availableReactions,
                    entityFiles: entityFiles,
                    synchronous: attemptSynchronous,
                    size: targetFrame.size
                )
                
                nextId += 1
            default:
                break
            }
        }
    }
}
