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
import StickerResources
import AnimationCache
import TelegramStringFormatting

private let shadowImage: UIImage = {
    return UIImage(bundleImageName: "Stories/ReactionShadow")!
}()

private let coverImage: UIImage = {
    return UIImage(bundleImageName: "Stories/ReactionOutline")!
}()

private let darkCoverImage: UIImage = {
    return generateTintedImage(image: UIImage(bundleImageName: "Stories/ReactionOutline"), color: UIColor(rgb: 0x000000, alpha: 0.5))!
}()

public func storyPreviewWithAddedReactions(
    context: AccountContext,
    storyItem: Stories.Item,
    signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    var reactionData: [Signal<(MessageReaction.Reaction, CGImage?), NoError>] = []
    
    let loadFile: (MessageReaction.Reaction, TelegramMediaFile) -> Signal<(MessageReaction.Reaction, CGImage?), NoError> = { reaction, file in
        return Signal { subscriber in
            let isTemplate = !"".isEmpty
            return context.animationRenderer.loadFirstFrameAsImage(cache: context.animationCache, itemId: file.resource.id.stringRepresentation, size: CGSize(width: 128.0, height: 128.0), fetch: animationCacheFetchFile(postbox: context.account.postbox, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: true, customColor: isTemplate ? .white : nil), completion: { result in
                subscriber.putNext((reaction, result))
                if result != nil {
                    subscriber.putCompletion()
                }
            })
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 !== rhs.1 {
                return false
            }
            return true
        })
    }
    
    var availableReactions: Promise<AvailableReactions?>?
    var processedReactions: [MessageReaction.Reaction] = []
    var customFileIds: [Int64] = []
    for mediaArea in storyItem.mediaAreas {
        if case let .reaction(_, reaction, _) = mediaArea {
            if processedReactions.contains(reaction) {
                continue
            }
            processedReactions.append(reaction)
            
            switch reaction {
            case .builtin:
                if availableReactions == nil {
                    availableReactions = Promise()
                    availableReactions?.set(context.engine.stickers.availableReactions())
                }
                reactionData.append(availableReactions!.get()
                |> take(1)
                |> mapToSignal { availableReactions -> Signal<(MessageReaction.Reaction, CGImage?), NoError> in
                    guard let availableReactions else {
                        return .single((reaction, nil))
                    }
                    for item in availableReactions.reactions {
                        if item.value == reaction {
                            guard let file = item.centerAnimation else {
                                break
                            }
                            return loadFile(reaction, file)
                        }
                    }
                    return .single((reaction, nil))
                })
            case let .custom(fileId):
                if !customFileIds.contains(fileId) {
                    customFileIds.append(fileId)
                }
            case .stars:
                break
            }
        }
    }
    
    if !customFileIds.isEmpty {
        let customFiles = Promise<[Int64: TelegramMediaFile]>()
        customFiles.set(context.engine.stickers.resolveInlineStickers(fileIds: customFileIds))
        
        for id in customFileIds {
            reactionData.append(customFiles.get()
            |> take(1)
            |> mapToSignal { customFiles -> Signal<(MessageReaction.Reaction, CGImage?), NoError> in
                let reaction: MessageReaction.Reaction = .custom(id)
                
                guard let file = customFiles[id] else {
                    return .single((reaction, nil))
                }
                
                return loadFile(reaction, file)
            })
        }
    }
    
    return combineLatest(
        signal,
        combineLatest(reactionData)
    )
    |> map { draw, reactionsData in
        return { arguments in
            guard let context = draw(arguments) else {
                return nil
            }
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            context.withContext { c in
                c.concatenate(c.ctm.inverted())
                c.scaleBy(x: context.scale, y: context.scale)
            }
             
            context.withFlippedContext { c in
                c.setBlendMode(.normal)
                
                for mediaArea in storyItem.mediaAreas {
                    c.saveGState()
                    defer {
                        c.restoreGState()
                    }
                    
                    if case let .reaction(coordinates, reaction, flags) = mediaArea {
                        let _ = reaction
                        let _ = flags
                        
                        let referenceSize = fittedRect.size
                        var areaSize = CGSize(width: coordinates.width / 100.0 * referenceSize.width, height: coordinates.height / 100.0 * referenceSize.height)
                        areaSize.width *= 0.97
                        areaSize.height *= 0.97
                        let targetFrame = CGRect(x: coordinates.x / 100.0 * referenceSize.width - areaSize.width * 0.5, y: coordinates.y / 100.0 * referenceSize.height - areaSize.height * 0.5, width: areaSize.width, height: areaSize.height)
                        if targetFrame.width < 2.0 || targetFrame.height < 2.0 {
                            continue
                        }
                        
                        c.saveGState()
                        
                        c.translateBy(x: targetFrame.midX, y: targetFrame.midY)
                        c.scaleBy(x: flags.contains(.isFlipped) ? -1.0 : 1.0, y: -1.0)
                        c.rotate(by: -coordinates.rotation * (CGFloat.pi / 180.0))
                        c.translateBy(x: -targetFrame.midX, y: -targetFrame.midY)
                        
                        let insets = UIEdgeInsets(top: -0.08, left: -0.05, bottom: -0.01, right: -0.02)
                        let coverFrame = CGRect(origin: CGPoint(x: targetFrame.width * insets.left, y: targetFrame.height * insets.top), size: CGSize(width: targetFrame.width - targetFrame.width * insets.left - targetFrame.width * insets.right, height: targetFrame.height - targetFrame.height * insets.top - targetFrame.height * insets.bottom)).offsetBy(dx: targetFrame.minX, dy: targetFrame.minY)
                        
                        c.draw(shadowImage.cgImage!, in: coverFrame)
                        
                        if flags.contains(.isDark) {
                            c.draw(darkCoverImage.cgImage!, in: coverFrame)
                        } else {
                            c.draw(coverImage.cgImage!, in: coverFrame)
                        }
                        
                        c.restoreGState()
                        
                        c.translateBy(x: targetFrame.midX, y: targetFrame.midY)
                        c.scaleBy(x: 1.0, y: -1.0)
                        c.rotate(by: -coordinates.rotation * (CGFloat.pi / 180.0))
                        c.translateBy(x: -targetFrame.midX, y: -targetFrame.midY)
                        
                        let minSide = floor(min(200.0, min(targetFrame.width, targetFrame.height)) * 0.5)
                        let itemSize = CGSize(width: minSide, height: minSide)
                        
                        if let (_, maybeImage) = reactionsData.first(where: { $0.0 == reaction }), let image = maybeImage {
                            var imageFrame = itemSize.centered(around: targetFrame.center.offsetBy(dx: -targetFrame.height * 0.015, dy: -targetFrame.height * 0.05))
                            if case .builtin = reaction {
                                imageFrame = imageFrame.insetBy(dx: -imageFrame.width * 0.5, dy: -imageFrame.height * 0.5)
                            }
                            
                            c.draw(image, in: imageFrame)
                        }
                    }
                }
            }
            
            context.withContext { c in
                c.concatenate(c.ctm.inverted())
                c.scaleBy(x: context.scale, y: context.scale)
                
                c.scaleBy(x: context.size.width * 0.5, y: context.size.height * 0.5)
                c.scaleBy(x: 1.0, y: -1.0)
                c.scaleBy(x: -context.size.width * 0.5, y: -context.size.height * 0.5)
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

private protocol ItemView: UIView {
    
}

final class StoryItemOverlaysView: UIView {
    static let counterFont: UIFont = {
        return Font.with(size: 17.0, design: .camera, weight: .semibold, traits: .monospacedNumbers)
    }()
    
    private final class ReactionView: HighlightTrackingButton, ItemView {
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
            self.shadowView = UIImageView(image: shadowImage)
            self.coverView = UIImageView(image: coverImage)
            
            super.init(frame: frame)
            
            self.addSubview(self.shadowView)
            self.addSubview(self.coverView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                
                if highlighted {
                    let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                    transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(0.9, 0.9, 1.0))
                } else {
                    let transition: ComponentTransition = .immediate
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
            size: CGSize,
            isActive: Bool
        ) {
            var transition = ComponentTransition(animation: .curve(duration: 0.18, curve: .easeInOut))
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
                case .stars:
                    if let availableReactions {
                        for reactionItem in availableReactions.reactionItems {
                            if reactionItem.reaction.rawValue == reaction {
                                file = reactionItem.stillAnimation
                                break
                            }
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
                    let placeholderColor = flags.contains(.isDark) ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.1)
                    let _ = directStickerView.update(
                        transition: .immediate,
                        component: AnyComponent(LottieComponent(
                            content: LottieComponent.ResourceContent(context: context, file: file, attemptSynchronously: synchronous, providesPlaceholder: true),
                            color: color,
                            placeholderColor: placeholderColor,
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
                        customEmojiView.clipsToBounds = true
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
                let stickerFrame = itemSize.centered(around: CGPoint(x: size.width * 0.49, y: size.height * (0.47 + counterFractionOffset)))
                
                stickerTransition.setPosition(view: customEmojiView, position: stickerFrame.center)
                stickerTransition.setBounds(view: customEmojiView, bounds: CGRect(origin: CGPoint(), size: stickerFrame.size))
                stickerTransition.setScale(view: customEmojiView, scale: stickerScale)
                customEmojiView.layer.cornerRadius = stickerFrame.size.width * 0.1
                
                customEmojiView.isActive = isActive
            }
            
            if let directStickerView = self.directStickerView?.view as? LottieComponent.View {
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
                let stickerFrame = itemSize.centered(around: CGPoint(x: size.width * 0.49, y: size.height * (0.47 + counterFractionOffset)))
                
                stickerTransition.setPosition(view: directStickerView, position: stickerFrame.center)
                stickerTransition.setBounds(view: directStickerView, bounds: CGRect(origin: CGPoint(), size: stickerFrame.size))
                stickerTransition.setScale(view: directStickerView, scale: stickerScale)
                
                directStickerView.externalShouldPlay = isActive
            }
        }
    }
    
    private final class WeatherView: UIView, ItemView {
        private let backgroundView = UIView()
        private let directStickerView = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        
        private var file: TelegramMediaFile?
        private var textFont: UIFont?
        
        private var customEmojiLoadDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.backgroundView.layer.cornerCurve = .continuous
            }
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.customEmojiLoadDisposable?.dispose()
        }
        
        func update(
            context: AccountContext,
            emoji: String,
            emojiFile: TelegramMediaFile?,
            temperature: Double,
            color: Int32,
            synchronous: Bool,
            size: CGSize,
            cornerRadius: CGFloat,
            isActive: Bool
        ) -> CGSize {
            let itemSize = CGSize(width: floor(size.height * 0.71), height: floor(size.height * 0.71))
            
            let backgroundColor = UIColor(argb: UInt32(bitPattern: color))
            let textColor: UIColor
            if backgroundColor.lightness > 0.705 {
                textColor = .black
            } else {
                textColor = .white
            }
            let placeholderColor = textColor.withAlphaComponent(0.1)
            
            if self.file?.fileId != emojiFile?.fileId, let file = emojiFile {
                self.file = file
                
                self.customEmojiLoadDisposable?.dispose()
                self.customEmojiLoadDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: file.resource)).start()
                
                let _ = self.directStickerView.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.ResourceContent(context: context, file: file, attemptSynchronously: synchronous, providesPlaceholder: true),
                        placeholderColor: placeholderColor,
                        renderingScale: 2.0,
                        loop: true
                    )),
                    environment: {},
                    containerSize: itemSize
                )
            }
            
            let textFont: UIFont
            if let current = self.textFont {
                textFont = current
            } else {
                textFont = Font.with(size: floorToScreenPixels(size.height * 0.69), design: .camera, weight: .semibold, traits: .monospacedNumbers)
                self.textFont = textFont
            }
            
            let string = NSMutableAttributedString(
                string: stringForTemperature(temperature),
                font: textFont,
                textColor: textColor
            )
            string.addAttribute(.kern, value: -(size.height / 38.0) as NSNumber, range: NSMakeRange(0, string.length))
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(string))
                ),
                environment: {},
                containerSize: CGSize(width: .greatestFiniteMagnitude, height: size.height)
            )
            
            let leftInset = size.height * 0.058
            let rightInset = size.height * 0.2
            let spacing = size.height * 0.205
            let contentWidth: CGFloat = leftInset + itemSize.width + spacing + textSize.width + rightInset
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: contentWidth - textSize.width - rightInset, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                let textTransition = ComponentTransition.immediate
                textTransition.setFrame(view: view, frame: textFrame)
            }
            
            if let directStickerView = self.directStickerView.view as? LottieComponent.View {
                if directStickerView.superview == nil {
                    self.addSubview(directStickerView)
                }
                
                let stickerFrame = itemSize.centered(around: CGPoint(x: size.height * 0.5 + leftInset, y: size.height * 0.5))
                
                let stickerTransition = ComponentTransition.immediate
                stickerTransition.setPosition(view: directStickerView, position: stickerFrame.center)
                stickerTransition.setBounds(view: directStickerView, bounds: CGRect(origin: CGPoint(), size: stickerFrame.size))
                
                directStickerView.externalShouldPlay = isActive
            }
            
            let contentSize = CGSize(width: contentWidth, height: size.height)
            
            self.backgroundView.backgroundColor = backgroundColor
            self.backgroundView.frame = CGRect(origin: .zero, size: contentSize)
            self.backgroundView.layer.cornerRadius = cornerRadius
            
            return contentSize
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
        isActive: Bool,
        transition: ComponentTransition
    ) {
        func getFrameAndRotation(coordinates: MediaArea.Coordinates, scale: CGFloat = 1.0) -> (frame: CGRect, rotation: CGFloat, cornerRadius: CGFloat)? {
            let referenceSize = size
            var areaSize = CGSize(width: coordinates.width / 100.0 * referenceSize.width, height: coordinates.height / 100.0 * referenceSize.height)
            areaSize.width *= scale
            areaSize.height *= scale
            let targetFrame = CGRect(x: coordinates.x / 100.0 * referenceSize.width - areaSize.width * 0.5, y: coordinates.y / 100.0 * referenceSize.height - areaSize.height * 0.5, width: areaSize.width, height: areaSize.height)
            if targetFrame.width < 5.0 || targetFrame.height < 5.0 {
                return nil
            }
            var cornerRadius: CGFloat = 0.0
            if let radius = coordinates.cornerRadius {
                cornerRadius = radius / 100.0 * areaSize.width
            }
            
            return (targetFrame, coordinates.rotation * (CGFloat.pi / 180.0), cornerRadius)
        }
        
        var nextId = 0
        for mediaArea in story.mediaAreas {
            switch mediaArea {
            case let .reaction(coordinates, reaction, flags):
                guard let (itemFrame, itemRotation, _) = getFrameAndRotation(coordinates: coordinates, scale: 0.97) else {
                    continue
                }
                
                let itemView: ReactionView
                let itemId = nextId
                if let current = self.itemViews[itemId] as? ReactionView {
                    itemView = current
                } else {
                    itemView = ReactionView(frame: CGRect())
                    itemView.activate = { [weak self] view, reaction in
                        self?.activate?(view, reaction)
                    }
                    itemView.requestUpdate = { [weak self] in
                        self?.requestUpdate?()
                    }
                    self.itemViews[itemId] = itemView
                    self.addSubview(itemView)
                }
                                
                transition.setPosition(view: itemView, position: itemFrame.center)
                transition.setBounds(view: itemView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                transition.setTransform(view: itemView, transform: CATransform3DMakeRotation(itemRotation, 0.0, 0.0, 1.0))
                
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
                    size: itemFrame.size,
                    isActive: isActive
                )
                
                nextId += 1
            case let .weather(coordinates, emoji, temperature, color):
                guard let (itemFrame, itemRotation, cornerRadius) = getFrameAndRotation(coordinates: coordinates) else {
                    continue
                }
                
                let itemView: WeatherView
                let itemId = nextId
                if let current = self.itemViews[itemId] as? WeatherView {
                    itemView = current
                } else {
                    itemView = WeatherView(frame: CGRect())
                    itemView.isUserInteractionEnabled = false
                    self.itemViews[itemId] = itemView
                    self.addSubview(itemView)
                }
                                                                
                let itemSize = itemView.update(
                    context: context,
                    emoji: emoji,
                    emojiFile: context.animatedEmojiStickersValue[emoji]?.first?.file,
                    temperature: temperature,
                    color: color,
                    synchronous: attemptSynchronous,
                    size: itemFrame.size,
                    cornerRadius: cornerRadius,
                    isActive: isActive
                )
                
                transition.setPosition(view: itemView, position: itemFrame.center)
                transition.setBounds(view: itemView, bounds: CGRect(origin: CGPoint(), size: itemSize))
                transition.setTransform(view: itemView, transform: CATransform3DMakeRotation(itemRotation, 0.0, 0.0, 1.0))
                
                nextId += 1
            default:
                break
            }
        }
    }
}
