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

final class StoryItemOverlaysView: UIView {
    private static let coverImage: UIImage = {
        return UIImage(bundleImageName: "Stories/ReactionOutline")!
    }()
    
    private final class ItemView: HighlightTrackingButton {
        private let coverView: UIImageView
        private var stickerView: EmojiTextAttachmentView?
        private var file: TelegramMediaFile?
        
        private var reaction: MessageReaction.Reaction?
        var activate: ((UIView, MessageReaction.Reaction) -> Void)?
        
        override init(frame: CGRect) {
            self.coverView = UIImageView(image: StoryItemOverlaysView.coverImage)
            
            super.init(frame: frame)
            
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
                    self.layer.animateSpring(from: 0.9 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
            availableReactions: StoryAvailableReactions?,
            synchronous: Bool,
            size: CGSize
        ) {
            self.reaction = reaction
            
            let insets = UIEdgeInsets(top: -0.08, left: -0.05, bottom: -0.01, right: -0.02)
            self.coverView.frame = CGRect(origin: CGPoint(x: size.width * insets.left, y: size.height * insets.top), size: CGSize(width: size.width - size.width * insets.left - size.width * insets.right, height: size.height - size.height * insets.top - size.height * insets.bottom))
            
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
                    let _ = fileId
                }
            }
            
            if self.file?.fileId != file?.fileId, let file {
                self.file = file
                
                let stickerView: EmojiTextAttachmentView
                if let current = self.stickerView {
                    stickerView = current
                } else {
                    stickerView = EmojiTextAttachmentView(
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
                        placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                        pointSize: CGSize(width: itemSize.width, height: itemSize.height)
                    )
                    stickerView.isUserInteractionEnabled = false
                    self.stickerView = stickerView
                    self.addSubview(stickerView)
                }
                
                stickerView.frame = itemSize.centered(around: CGPoint(x: size.width * 0.5, y: size.height * 0.47))
            }
        }
    }
    
    private var itemViews: [Int: ItemView] = [:]
    var activate: ((UIView, MessageReaction.Reaction) -> Void)?
    
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
        size: CGSize,
        isCaptureProtected: Bool,
        attemptSynchronous: Bool,
        transition: Transition
    ) {
        var nextId = 0
        for mediaArea in story.mediaAreas {
            switch mediaArea {
            case let .reaction(coordinates, reaction):
                let referenceSize = size
                let areaSize = CGSize(width: coordinates.width / 100.0 * referenceSize.width, height: coordinates.height / 100.0 * referenceSize.height)
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
                    self.itemViews[itemId] = itemView
                    self.addSubview(itemView)
                }
                
                transition.setPosition(view: itemView, position: targetFrame.center)
                transition.setBounds(view: itemView, bounds: CGRect(origin: CGPoint(), size: targetFrame.size))
                transition.setTransform(view: itemView, transform: CATransform3DMakeRotation(coordinates.rotation * (CGFloat.pi / 180.0), 0.0, 0.0, 1.0))
                itemView.update(
                    context: context,
                    reaction: reaction,
                    availableReactions: availableReactions,
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
