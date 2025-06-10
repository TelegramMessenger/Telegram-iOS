import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import AnimatedAvatarSetNode
import AccountContext
import TelegramCore
import MoreHeaderButton
import SemanticStatusNode
import SwiftSignalKit
import TelegramPresentationData
import AnimatedCountLabelNode
import MessageInputActionButtonComponent

public final class StoryFooterPanelComponent: Component {
    public final class AnimationHint {
        public let synchronousLoad: Bool
        
        public init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
    public struct MyReaction: Equatable {
        public let reaction: MessageReaction.Reaction
        public let file: TelegramMediaFile?
        public let animationFileId: Int64?
        
        public init(reaction: MessageReaction.Reaction, file: TelegramMediaFile?, animationFileId: Int64?) {
            self.reaction = reaction
            self.file = file
            self.animationFileId = animationFileId
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let peer: EnginePeer
    public let storyItem: EngineStoryItem
    public let myReaction: MyReaction?
    public let isChannel: Bool
    public let canViewChannelStats: Bool
    public let canShare: Bool
    public let externalViews: EngineStoryItem.Views?
    public let displayViews: Bool
    public let expandFraction: CGFloat
    public let expandViewStats: () -> Void
    public let deleteAction: () -> Void
    public let moreAction: (UIView, ContextGesture?) -> Void
    public let likeAction: () -> Void
    public let forwardAction: () -> Void
    public let repostAction: () -> Void
    public let cancelUploadAction: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        storyItem: EngineStoryItem,
        myReaction: MyReaction?,
        isChannel: Bool,
        canViewChannelStats: Bool,
        canShare: Bool,
        externalViews: EngineStoryItem.Views?,
        displayViews: Bool,
        expandFraction: CGFloat,
        expandViewStats: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void,
        likeAction: @escaping () -> Void,
        forwardAction: @escaping () -> Void,
        repostAction: @escaping () -> Void,
        cancelUploadAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.storyItem = storyItem
        self.myReaction = myReaction
        self.isChannel = isChannel
        self.canViewChannelStats = canViewChannelStats
        self.canShare = canShare
        self.externalViews = externalViews
        self.displayViews = displayViews
        self.expandViewStats = expandViewStats
        self.expandFraction = expandFraction
        self.deleteAction = deleteAction
        self.moreAction = moreAction
        self.likeAction = likeAction
        self.forwardAction = forwardAction
        self.repostAction = repostAction
        self.cancelUploadAction = cancelUploadAction
    }
    
    public static func ==(lhs: StoryFooterPanelComponent, rhs: StoryFooterPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.myReaction != rhs.myReaction {
            return false
        }
        if lhs.isChannel != rhs.isChannel {
            return false
        }
        if lhs.canViewChannelStats != rhs.canViewChannelStats {
            return false
        }
        if lhs.externalViews != rhs.externalViews {
            return false
        }
        if lhs.displayViews != rhs.displayViews {
            return false
        }
        if lhs.expandFraction != rhs.expandFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let viewStatsButton: HighlightTrackingButton
        private let viewStatsCountText: AnimatedCountLabelView
        private let viewStatsLabelText = ComponentView<Empty>()
        private let deleteButton = ComponentView<Empty>()
        
        private var likeButton: ComponentView<Empty>?
        private var likeStatsText: AnimatedCountLabelView?
        private var forwardButton: ComponentView<Empty>?
        private var repostButton: ComponentView<Empty>?
        private var forwardStatsText: AnimatedCountLabelView?
        
        private var reactionStatsIcon: UIImageView?
        private var reactionStatsText: AnimatedCountLabelView?
        
        private var repostStatsIcon: UIImageView?
        private var repostStatsText: AnimatedCountLabelView?
        
        private var statusButton: HighlightableButton?
        private var statusNode: SemanticStatusNode?
        private var uploadingText: ComponentView<Empty>?
        
        private let viewsIconView: UIImageView
        
        private let avatarsContext: AnimatedAvatarSetContext
        private let avatarsView: AnimatedAvatarSetView
        
        private var component: StoryFooterPanelComponent?
        private weak var state: EmptyComponentState?
        
        private var uploadProgress: Float = 0.0
        private var uploadProgressDisposable: Disposable?
        
        public let externalContainerView: UIView
        
        private weak var likeButtonTracingOffsetView: UIView?
        
        public var likeButtonView: UIView? {
            return self.likeButton?.view
        }
        
        override init(frame: CGRect) {
            self.viewStatsButton = HighlightTrackingButton()
            self.viewStatsCountText = AnimatedCountLabelView(frame: CGRect())
            
            self.viewsIconView = UIImageView()
            
            self.avatarsContext = AnimatedAvatarSetContext()
            self.avatarsView = AnimatedAvatarSetView()
            
            self.externalContainerView = UIView()
            
            super.init(frame: frame)
            
            self.viewsIconView.image = UIImage(bundleImageName: "Stories/EmbeddedViewIcon")
            self.externalContainerView.addSubview(self.viewsIconView)
            
            self.avatarsView.isUserInteractionEnabled = false
            self.externalContainerView.addSubview(self.avatarsView)
            self.addSubview(self.externalContainerView)
            self.addSubview(self.viewStatsButton)
            
            self.viewStatsButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.avatarsView.alpha = 0.7
                    self.viewStatsCountText.alpha = 0.7
                    self.viewStatsLabelText.view?.alpha = 0.7
                    self.viewsIconView.alpha = 0.7
                    self.reactionStatsIcon?.alpha = 0.7
                    self.reactionStatsText?.alpha = 0.7
                    self.repostStatsIcon?.alpha = 0.7
                    self.repostStatsText?.alpha = 0.7
                } else {
                    self.avatarsView.alpha = 1.0
                    self.viewStatsCountText.alpha = 1.0
                    self.viewStatsLabelText.view?.alpha = 1.0
                    self.viewsIconView.alpha = 1.0
                    self.reactionStatsIcon?.alpha = 1.0
                    self.reactionStatsText?.alpha = 1.0
                    self.repostStatsIcon?.alpha = 1.0
                    self.repostStatsText?.alpha = 1.0
                    
                    self.avatarsView.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.viewStatsCountText.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.viewStatsLabelText.view?.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.viewsIconView.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.reactionStatsIcon?.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.reactionStatsText?.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.repostStatsIcon?.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.repostStatsText?.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                }
            }
            self.viewStatsButton.addTarget(self, action: #selector(self.viewStatsPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.uploadProgressDisposable?.dispose()
        }
        
        public func setLikeButtonTracingOffset(view: UIView) {
            self.likeButtonTracingOffsetView = view
        }
        
        @objc private func viewStatsPressed() {
            guard let component = self.component else {
                return
            }
            component.expandViewStats()
        }
        
        @objc private func statusPressed() {
            guard let component = self.component else {
                return
            }
            component.cancelUploadAction()
        }
        
        func update(component: StoryFooterPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            let previousComponent = self.component
            
            self.isUserInteractionEnabled = component.expandFraction == 0.0
            
            var synchronousLoad = true
            if let hint = transition.userData(AnimationHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            if self.component?.storyItem.id != component.storyItem.id || self.component?.storyItem.isPending != component.storyItem.isPending {
                self.uploadProgressDisposable?.dispose()
                self.uploadProgress = 0.0
                
                if component.storyItem.isPending {
                    var applyState = false
                    self.uploadProgressDisposable = (component.context.engine.messages.storyUploadProgress(stableId: component.storyItem.id)
                    |> deliverOnMainQueue).start(next: { [weak self] progress in
                        guard let self else {
                            return
                        }
                        self.uploadProgress = progress
                        if applyState {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                    applyState = true
                }
            }
            
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 44.0
            let size = CGSize(width: availableSize.width, height: baseHeight)
            
            let sideContentMaxFraction: CGFloat = 0.2
            let sideContentFraction = min(component.expandFraction, sideContentMaxFraction) / sideContentMaxFraction
            
            let avatarsAlpha: CGFloat
            let baseViewCountAlpha: CGFloat
            if component.storyItem.isPending {
                baseViewCountAlpha = 0.0
                
                let statusButton: HighlightableButton
                if let current = self.statusButton {
                    statusButton = current
                } else {
                    statusButton = HighlightableButton()
                    statusButton.addTarget(self, action: #selector(self.statusPressed), for: .touchUpInside)
                    self.statusButton = statusButton
                    self.addSubview(statusButton)
                }
                
                let statusNode: SemanticStatusNode
                if let current = self.statusNode {
                    statusNode = current
                } else {
                    statusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white, image: nil, overlayForegroundNodeColor: nil, cutout: nil)
                    self.statusNode = statusNode
                    statusButton.addSubview(statusNode.view)
                }
                
                let uploadingText: ComponentView<Empty>
                if let current = self.uploadingText {
                    uploadingText = current
                } else {
                    uploadingText = ComponentView()
                    self.uploadingText = uploadingText
                }
                
                var innerLeftOffset: CGFloat = 0.0
                
                let statusSize = CGSize(width: 36.0, height: 36.0)
                statusNode.view.frame = CGRect(origin: CGPoint(x: innerLeftOffset, y: floor((size.height - statusSize.height) * 0.5)), size: statusSize)
                innerLeftOffset += statusSize.width + 10.0
                
                statusNode.transitionToState(.progress(value: CGFloat(max(0.08, self.uploadProgress)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 0.0, lineWidth: 2.0), animateRotation: true))
                
                let uploadingTextSize = uploadingText.update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: component.strings.Story_Footer_Uploading, font: Font.regular(15.0), color: .white)),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                let uploadingTextFrame = CGRect(origin: CGPoint(x: innerLeftOffset, y: floor((size.height - uploadingTextSize.height) * 0.5)), size: uploadingTextSize)
                if let uploadingTextView = uploadingText.view {
                    if uploadingTextView.superview == nil {
                        statusButton.addSubview(uploadingTextView)
                    }
                    uploadingTextView.frame = uploadingTextFrame
                }
                innerLeftOffset += uploadingTextSize.width + 8.0
                
                var statusButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: CGSize(width: innerLeftOffset, height: size.height))
                statusButtonFrame.origin.y += component.expandFraction * 45.0
                transition.setFrame(view: statusButton, frame: statusButtonFrame)
                
                transition.setAlpha(view: statusButton, alpha: 1.0 - sideContentFraction)
                
                avatarsAlpha = 0.0
            } else {
                if let statusNode = self.statusNode {
                    self.statusNode = nil
                    statusNode.view.removeFromSuperview()
                }
                if let uploadingText = self.uploadingText {
                    self.uploadingText = nil
                    uploadingText.view?.removeFromSuperview()
                }
                if let statusButton = self.statusButton {
                    self.statusButton = nil
                    statusButton.removeFromSuperview()
                }
                
                avatarsAlpha = pow(1.0 - component.expandFraction, 1.0)
                baseViewCountAlpha = 1.0
            }
            let _ = baseViewCountAlpha
            
            var peers: [EnginePeer] = []
            if !component.isChannel {
                if let seenPeers = component.externalViews?.seenPeers ?? component.storyItem.views?.seenPeers {
                    peers = Array(seenPeers.prefix(3))
                }
            }
            let avatarsContent = self.avatarsContext.update(peers: peers, animated: false)
            let avatarsSize = self.avatarsView.update(context: component.context, content: avatarsContent, itemSize: CGSize(width: 30.0, height: 30.0), animation: isFirstTime ? ListViewItemUpdateAnimation.None : ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .easeInOut, interactive: false)), synchronousLoad: synchronousLoad)
            
            var viewCount = 0
            var reactionCount = 0
            var forwardCount = 0
            if let views = component.externalViews ?? component.storyItem.views, views.seenCount != 0 {
                viewCount = views.seenCount
                reactionCount = views.reactedCount
                forwardCount = views.forwardCount
            }
            
            if component.isChannel {
                viewCount = max(1, viewCount)
                if component.storyItem.myReaction != nil {
                    reactionCount = max(1, reactionCount)
                }
            }
            
            var displayViewLists = false
            if case let .channel(channel) = component.peer, channel.flags.contains(.isCreator) || component.canViewChannelStats {
                displayViewLists = true
            } else {
                displayViewLists = viewCount != 0 && !component.isChannel
            }
            
            self.viewStatsButton.isEnabled = displayViewLists
            
            var regularSegments: [AnimatedCountLabelView.Segment] = []
            if viewCount != 0 {
                regularSegments.append(.number(viewCount, NSAttributedString(string: countString(Int64(viewCount)), font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white)))
            }
            
            let viewPart: String
            if !component.displayViews {
                viewPart = ""
            } else if component.isChannel {
                viewPart = ""
            } else if viewCount == 0 {
                viewPart = component.strings.Story_Footer_NoViews
            } else {
                var string = component.strings.Story_Footer_ViewCount(Int32(viewCount))
                if let range = string.range(of: "|") {
                    if let nextRange = string.range(of: "|", range: range.upperBound ..< string.endIndex) {
                        string.removeSubrange(string.startIndex ..< nextRange.upperBound)
                    }
                }
                viewPart = string
            }
            
            let viewStatsTextLayout = self.viewStatsCountText.update(size: CGSize(width: availableSize.width, height: size.height), segments: regularSegments, reducedLetterSpacing: true, transition: isFirstTime ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut))
            if self.viewStatsCountText.superview == nil {
                self.viewStatsCountText.isUserInteractionEnabled = false
                self.externalContainerView.addSubview(self.viewStatsCountText)
            }
            
            let viewStatsLabelSize = self.viewStatsLabelText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: viewPart, font: Font.regular(15.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            
            var reactionsIconSize: CGSize?
            var reactionsTextSize: CGSize?
            
            var repostsIconSize: CGSize?
            var repostsTextSize: CGSize?
            
            if reactionCount != 0 && !component.isChannel {
                var reactionsTransition = transition
                let reactionStatsIcon: UIImageView
                if let current = self.reactionStatsIcon {
                    reactionStatsIcon = current
                } else {
                    reactionsTransition = reactionsTransition.withAnimation(.none)
                    reactionStatsIcon = UIImageView()
                    reactionStatsIcon.image = UIImage(bundleImageName: "Stories/InputLikeOn")?.withRenderingMode(.alwaysTemplate)
                    
                    self.reactionStatsIcon = reactionStatsIcon
                    self.externalContainerView.addSubview(reactionStatsIcon)
                }
                
                transition.setTintColor(view: reactionStatsIcon, color: UIColor(rgb: 0xFF3B30).mixedWith(.white, alpha: component.expandFraction))
                
                let reactionStatsText: AnimatedCountLabelView
                if let current = self.reactionStatsText {
                    reactionStatsText = current
                } else {
                    reactionStatsText = AnimatedCountLabelView(frame: CGRect())
                    reactionStatsText.isUserInteractionEnabled = false
                    self.reactionStatsText = reactionStatsText
                    self.externalContainerView.addSubview(reactionStatsText)
                }
                
                let reactionStatsLayout = reactionStatsText.update(
                    size: CGSize(width: availableSize.width, height: size.height),
                    segments: [
                        .number(reactionCount, NSAttributedString(string: "\(reactionCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white))
                    ],
                    reducedLetterSpacing: true,
                    transition: (isFirstTime || reactionsTransition.animation.isImmediate) ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                )
                reactionsTextSize = reactionStatsLayout.size
                
                let imageSize = CGSize(width: 23.0, height: 23.0)
                reactionsIconSize = imageSize
            } else {
                if let reactionStatsIcon = self.reactionStatsIcon {
                    self.reactionStatsIcon = nil
                    reactionStatsIcon.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionStatsIcon] _ in
                        reactionStatsIcon?.removeFromSuperview()
                    })
                }
                
                if let reactionStatsText = self.reactionStatsText {
                    self.reactionStatsText = nil
                    reactionStatsText.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionStatsText] _ in
                        reactionStatsText?.removeFromSuperview()
                    })
                }
            }
            
            if forwardCount != 0 && !component.isChannel {
                var repostTransition = transition
                let repostStatsIcon: UIImageView
                if let current = self.repostStatsIcon {
                    repostStatsIcon = current
                } else {
                    repostTransition = repostTransition.withAnimation(.none)
                    repostStatsIcon = UIImageView()
                    repostStatsIcon.image = UIImage(bundleImageName: "Stories/InputRepost")?.withRenderingMode(.alwaysTemplate)
                    
                    self.repostStatsIcon = repostStatsIcon
                    self.externalContainerView.addSubview(repostStatsIcon)
                }
                
                transition.setTintColor(view: repostStatsIcon, color: UIColor(rgb: 0x34c759).mixedWith(.white, alpha: component.expandFraction))
                
                let repostStatsText: AnimatedCountLabelView
                if let current = self.repostStatsText {
                    repostStatsText = current
                } else {
                    repostStatsText = AnimatedCountLabelView(frame: CGRect())
                    repostStatsText.isUserInteractionEnabled = false
                    self.repostStatsText = repostStatsText
                    self.externalContainerView.addSubview(repostStatsText)
                }
                
                let repostStatsLayout = repostStatsText.update(
                    size: CGSize(width: availableSize.width, height: size.height),
                    segments: [
                        .number(forwardCount, NSAttributedString(string: "\(forwardCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white))
                    ],
                    reducedLetterSpacing: true,
                    transition: (isFirstTime || repostTransition.animation.isImmediate) ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                )
                repostsTextSize = repostStatsLayout.size
                
                let imageSize = CGSize(width: 23.0, height: 23.0)
                repostsIconSize = imageSize
            } else {
                if let repostStatsIcon = self.repostStatsIcon {
                    self.repostStatsIcon = nil
                    repostStatsIcon.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak repostStatsIcon] _ in
                        repostStatsIcon?.removeFromSuperview()
                    })
                }
                
                if let repostStatsText = self.repostStatsText {
                    self.repostStatsText = nil
                    repostStatsText.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak repostStatsText] _ in
                        repostStatsText?.removeFromSuperview()
                    })
                }
            }
            
            let viewsReactionsCollapsedSpacing: CGFloat = 6.0
            let viewsReactionsExpandedSpacing: CGFloat = 8.0
            let viewsReactionsSpacing = viewsReactionsCollapsedSpacing.interpolate(to: viewsReactionsExpandedSpacing, amount: component.expandFraction)
            
            let avatarViewsSpacing: CGFloat = 18.0
            let viewsIconSpacing: CGFloat = 2.0
            
            let reactionsIconSpacing: CGFloat = component.isChannel ? 5.0 : 2.0
            
            var contentWidth: CGFloat = 0.0
            
            contentWidth += (avatarsSize.width + avatarViewsSpacing) * (1.0 - component.expandFraction)
            if let image = self.viewsIconView.image {
                if component.isChannel {
                    contentWidth += image.size.width + viewsIconSpacing
                } else {
                    if viewCount != 0 {
                        contentWidth += (image.size.width + viewsIconSpacing) * component.expandFraction
                    }
                }
            }
            
            if viewCount == 0 {
                contentWidth += viewStatsTextLayout.size.width * (1.0 - component.expandFraction)
            } else {
                contentWidth += viewStatsTextLayout.size.width
            }
            if !component.isChannel {
                contentWidth += viewStatsLabelSize.width * (1.0 - component.expandFraction)
            }
            
            if component.isChannel {
                /*if let reactionsIconSize {
                    contentWidth += viewsReactionsSpacing
                    contentWidth += reactionsIconSize.width
                }*/
            } else {
                if let reactionsIconSize, let reactionsTextSize {
                    contentWidth += viewsReactionsSpacing
                    contentWidth += reactionsIconSize.width
                    contentWidth += reactionsIconSpacing
                    contentWidth += reactionsTextSize.width
                }
                if let repostsIconSize, let repostsTextSize {
                    contentWidth += viewsReactionsSpacing
                    contentWidth += repostsIconSize.width
                    contentWidth += reactionsIconSpacing
                    contentWidth += repostsTextSize.width
                }
            }
            
            let minContentX: CGFloat = 16.0
            let maxContentX: CGFloat = (availableSize.width - contentWidth) * 0.5
            var contentX: CGFloat = minContentX.interpolate(to: maxContentX, amount: component.expandFraction)
            
            let avatarsNodeFrame = CGRect(origin: CGPoint(x: contentX, y: floor((size.height - avatarsSize.height) * 0.5)), size: avatarsSize)
            transition.setPosition(view: self.avatarsView, position: avatarsNodeFrame.center)
            transition.setBounds(view: self.avatarsView, bounds: CGRect(origin: CGPoint(), size: avatarsNodeFrame.size))
            transition.setAlpha(view: self.avatarsView, alpha: avatarsAlpha)
            transition.setScale(view: self.avatarsView, scale: CGFloat(1.0).interpolate(to: CGFloat(0.1), amount: component.expandFraction))
            
            if let image = self.viewsIconView.image {
                let viewsIconFrame = CGRect(origin: CGPoint(x: contentX, y: floor((size.height - image.size.height) * 0.5)), size: image.size)
                transition.setPosition(view: self.viewsIconView, position: viewsIconFrame.center)
                transition.setBounds(view: self.viewsIconView, bounds: CGRect(origin: CGPoint(), size: viewsIconFrame.size))
                
                if component.isChannel {
                    transition.setAlpha(view: self.viewsIconView, alpha: 1.0)
                    transition.setScale(view: self.viewsIconView, scale: 1.0)
                } else {
                    if viewCount == 0 {
                        transition.setAlpha(view: self.viewsIconView, alpha: 0.0)
                    } else {
                        transition.setAlpha(view: self.viewsIconView, alpha: component.expandFraction)
                    }
                    transition.setScale(view: self.viewsIconView, scale: CGFloat(1.0).interpolate(to: CGFloat(0.1), amount: 1.0 - component.expandFraction))
                }
            }
            
            if component.isChannel {
                if let image = self.viewsIconView.image {
                    contentX += image.size.width + viewsIconSpacing
                }
            } else {
                if !avatarsSize.width.isZero {
                    contentX += (avatarsSize.width + avatarViewsSpacing) * (1.0 - component.expandFraction)
                }
                if let image = self.viewsIconView.image {
                    contentX += (image.size.width + viewsIconSpacing) * component.expandFraction
                }
            }
            
            transition.setFrame(view: self.viewStatsCountText, frame: CGRect(origin: CGPoint(x: contentX, y: floor((size.height - viewStatsTextLayout.size.height) * 0.5)), size: viewStatsTextLayout.size))
            if viewCount == 0 {
                contentX += viewStatsTextLayout.size.width * component.expandFraction
                transition.setAlpha(view: self.viewStatsCountText, alpha: component.expandFraction)
            } else {
                contentX += viewStatsTextLayout.size.width
                transition.setAlpha(view: self.viewStatsCountText, alpha: 1.0)
            }
            
            let viewStatsLabelTextFrame = CGRect(origin: CGPoint(x: contentX, y: floor((size.height - viewStatsLabelSize.height) * 0.5)), size: viewStatsLabelSize)
            if let viewStatsLabelTextView = self.viewStatsLabelText.view {
                if viewStatsLabelTextView.superview == nil {
                    viewStatsLabelTextView.isUserInteractionEnabled = false
                    viewStatsLabelTextView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
                    self.externalContainerView.addSubview(viewStatsLabelTextView)
                }
                transition.setPosition(view: viewStatsLabelTextView, position: CGPoint(x: viewStatsLabelTextFrame.minX, y: viewStatsLabelTextFrame.midY))
                transition.setBounds(view: viewStatsLabelTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsLabelTextFrame.size))
                transition.setAlpha(view: viewStatsLabelTextView, alpha: 1.0 - component.expandFraction)
                transition.setScale(view: viewStatsLabelTextView, scale: CGFloat(1.0).interpolate(to: CGFloat(0.1), amount: component.expandFraction))
            }
            if !component.isChannel {
                contentX += viewStatsLabelSize.width * (1.0 - component.expandFraction)
            }
            
            if let reactionStatsIcon = self.reactionStatsIcon, let reactionsIconSize, let reactionStatsText = self.reactionStatsText, let reactionsTextSize {
                contentX += viewsReactionsSpacing
                
                transition.setFrame(view: reactionStatsIcon, frame: CGRect(origin: CGPoint(x: contentX, y: floor((size.height - reactionsIconSize.height) * 0.5)), size: reactionsIconSize))
                contentX += reactionsIconSize.width
                contentX += reactionsIconSpacing
                
                transition.setFrame(view: reactionStatsText, frame: CGRect(origin: CGPoint(x: contentX, y: floor((size.height - reactionsTextSize.height) * 0.5)), size: reactionsTextSize))
                contentX += reactionsTextSize.width
            }
            
            if let repostStatsIcon = self.repostStatsIcon, let repostsIconSize, let repostStatsText = self.repostStatsText, let repostsTextSize {
                contentX += viewsReactionsSpacing
                
                transition.setFrame(view: repostStatsIcon, frame: CGRect(origin: CGPoint(x: contentX, y: floor((size.height - repostsIconSize.height) * 0.5)), size: repostsIconSize))
                contentX += repostsIconSize.width
                contentX += reactionsIconSpacing
                
                transition.setFrame(view: repostStatsText, frame: CGRect(origin: CGPoint(x: contentX, y: floor((size.height - repostsTextSize.height) * 0.5)), size: repostsTextSize))
                contentX += repostsTextSize.width
            }
            
            var rightContentOffset: CGFloat = availableSize.width - 12.0
            
            if component.isChannel {
                var likeStatsTransition = transition
                var forwardStatsTransition = transition
                
                if transition.animation.isImmediate, !isFirstTime, let previousComponent, previousComponent.storyItem.id == component.storyItem.id, previousComponent.expandFraction == component.expandFraction {
                    likeStatsTransition = .easeInOut(duration: 0.2)
                    forwardStatsTransition = .easeInOut(duration: 0.2)
                }
                
                let likeStatsText: AnimatedCountLabelView
                if let current = self.likeStatsText {
                    likeStatsText = current
                } else {
                    likeStatsTransition = likeStatsTransition.withAnimation(.none)
                    likeStatsText = AnimatedCountLabelView(frame: CGRect())
                    likeStatsText.isUserInteractionEnabled = false
                    self.likeStatsText = likeStatsText
                }
                
                let reactionStatsLayout = likeStatsText.update(
                    size: CGSize(width: availableSize.width, height: size.height),
                    segments: [
                        .number(reactionCount, NSAttributedString(string: "\(reactionCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white))
                    ],
                    transition: (isFirstTime || likeStatsTransition.animation.isImmediate) ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                )
                var likeStatsFrame = CGRect(origin: CGPoint(x: rightContentOffset - reactionStatsLayout.size.width, y: floor((size.height - reactionStatsLayout.size.height) * 0.5)), size: reactionStatsLayout.size)
                likeStatsFrame.origin.y += component.expandFraction * 45.0
                //likeStatsFrame.origin.x = (1.0 - component.expandFraction) * likeStatsFrame.origin.x + component.expandFraction * (contentX)
                
                likeStatsTransition.setPosition(view: likeStatsText, position: likeStatsFrame.center)
                likeStatsTransition.setBounds(view: likeStatsText, bounds: CGRect(origin: CGPoint(), size:    likeStatsFrame.size))
                var likeStatsAlpha: CGFloat = (1.0 - component.expandFraction)
                if reactionCount == 0 {
                    likeStatsAlpha = 0.0
                }
                likeStatsTransition.setAlpha(view: likeStatsText, alpha: likeStatsAlpha)
                likeStatsTransition.setScale(view: likeStatsText, scale: reactionCount == 0 ? 0.001 : 1.0)
                
                if reactionCount != 0 {
                    rightContentOffset -= reactionStatsLayout.size.width + 1.0
                }
                
                let likeButton: ComponentView<Empty>
                if let current = self.likeButton {
                    likeButton = current
                } else {
                    likeButton = ComponentView()
                    self.likeButton = likeButton
                }
                                
                let likeButtonSize = likeButton.update(
                    transition: likeStatsTransition,
                    component: AnyComponent(MessageInputActionButtonComponent(
                        mode: .like(reaction: component.myReaction?.reaction, file: component.myReaction?.file, animationFileId: component.myReaction?.animationFileId),
                        storyId: component.storyItem.id,
                        action: { [weak self] _, action, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard case .up = action else {
                                return
                            }
                            component.likeAction()
                        },
                        longPressAction: nil,
                        switchMediaInputMode: {
                        },
                        updateMediaCancelFraction: { _ in
                        },
                        lockMediaRecording: {
                        },
                        stopAndPreviewMediaRecording: {
                        },
                        moreAction: { _, _ in },
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        presentController: { _ in },
                        audioRecorder: nil,
                        videoRecordingStatus: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 33.0, height: 33.0)
                )
                if let likeButtonView = likeButton.view as? MessageInputActionButtonComponent.View {
                    if likeButtonView.superview == nil {
                        self.addSubview(likeButtonView)
                    }
                    var likeButtonFrame = CGRect(origin: CGPoint(x: rightContentOffset - likeButtonSize.width, y: floor((size.height - likeButtonSize.height) * 0.5)), size: likeButtonSize)
                    likeButtonFrame.origin.y += component.expandFraction * 45.0
                    
                    if let likeButtonTracingOffsetView = self.likeButtonTracingOffsetView {
                        let difference = CGPoint(x: likeButtonFrame.midX - likeButtonView.layer.position.x, y: likeButtonFrame.midY - likeButtonView.layer.position.y)
                        if difference != CGPoint() {
                            likeStatsTransition.setPosition(view: likeButtonTracingOffsetView, position: likeButtonTracingOffsetView.layer.position.offsetBy(dx: difference.x, dy: difference.y))
                        }
                    }
                    
                    likeStatsTransition.setPosition(view: likeButtonView, position: likeButtonFrame.center)
                    likeStatsTransition.setBounds(view: likeButtonView, bounds: CGRect(origin: CGPoint(), size: likeButtonFrame.size))
                    likeStatsTransition.setAlpha(view: likeButtonView, alpha: 1.0 - component.expandFraction)
                    
                    rightContentOffset -= likeButtonSize.width + 14.0
                    
                    if likeStatsText.superview == nil {
                        likeButtonView.button.view.addSubview(likeStatsText)
                    }
                    
                    likeStatsFrame.origin.x -= likeButtonFrame.minX
                    likeStatsFrame.origin.y -= likeButtonFrame.minY
                    likeStatsTransition.setPosition(view: likeStatsText, position: likeStatsFrame.center)
                    likeStatsTransition.setBounds(view: likeStatsText, bounds: CGRect(origin: CGPoint(), size: likeStatsFrame.size))
                }
                
                if component.canShare {
                    let forwardStatsText: AnimatedCountLabelView
                    if let current = self.forwardStatsText {
                        forwardStatsText = current
                    } else {
                        forwardStatsTransition = forwardStatsTransition.withAnimation(.none)
                        forwardStatsText = AnimatedCountLabelView(frame: CGRect())
                        forwardStatsText.isUserInteractionEnabled = false
                        self.forwardStatsText = forwardStatsText
                    }
                    
                    let forwardStatsLayout = forwardStatsText.update(
                        size: CGSize(width: availableSize.width, height: size.height),
                        segments: [
                            .number(forwardCount, NSAttributedString(string: "\(forwardCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white))
                        ],
                        transition: (isFirstTime || likeStatsTransition.animation.isImmediate) ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                    )
                    var forwardStatsFrame = CGRect(origin: CGPoint(x: rightContentOffset - forwardStatsLayout.size.width, y: floor((size.height - forwardStatsLayout.size.height) * 0.5)), size: forwardStatsLayout.size)
                    forwardStatsFrame.origin.y += component.expandFraction * 45.0
                    
                    var forwardStatsAlpha: CGFloat = (1.0 - component.expandFraction)
                    if forwardCount == 0 {
                        forwardStatsAlpha = 0.0
                    }
                    forwardStatsTransition.setAlpha(view: forwardStatsText, alpha: forwardStatsAlpha)
                    forwardStatsTransition.setScale(view: forwardStatsText, scale: forwardCount == 0 ? 0.001 : 1.0)
                    
                    if forwardCount != 0 {
                        rightContentOffset -= forwardStatsLayout.size.width + 1.0
                    }
                    
                    let repostButton: ComponentView<Empty>
                    if let current = self.repostButton {
                        repostButton = current
                    } else {
                        repostButton = ComponentView()
                        self.repostButton = repostButton
                    }
                    
                    let forwardButton: ComponentView<Empty>
                    if let current = self.forwardButton {
                        forwardButton = current
                    } else {
                        forwardButton = ComponentView()
                        self.forwardButton = forwardButton
                    }
                    
                    let repostButtonSize = repostButton.update(
                        transition: likeStatsTransition,
                        component: AnyComponent(MessageInputActionButtonComponent(
                            mode: .repost,
                            storyId: component.storyItem.id,
                            action: { [weak self] _, action, _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                guard case .up = action else {
                                    return
                                }
                                component.repostAction()
                            },
                            longPressAction: nil,
                            switchMediaInputMode: {
                            },
                            updateMediaCancelFraction: { _ in
                            },
                            lockMediaRecording: {
                            },
                            stopAndPreviewMediaRecording: {
                            },
                            moreAction: { _, _ in },
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            presentController: { _ in },
                            audioRecorder: nil,
                            videoRecordingStatus: nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: 33.0, height: 33.0)
                    )
                    if let repostButtonView = repostButton.view as? MessageInputActionButtonComponent.View {
                        if repostButtonView.superview == nil {
                            self.addSubview(repostButtonView)
                        }
                        var repostButtonFrame = CGRect(origin: CGPoint(x: rightContentOffset - repostButtonSize.width, y: floor((size.height - repostButtonSize.height) * 0.5)), size: repostButtonSize)
                        repostButtonFrame.origin.y += component.expandFraction * 45.0
                        
                        forwardStatsTransition.setPosition(view: repostButtonView, position: repostButtonFrame.center)
                        forwardStatsTransition.setBounds(view: repostButtonView, bounds: CGRect(origin: CGPoint(), size: repostButtonFrame.size))
                        forwardStatsTransition.setAlpha(view: repostButtonView, alpha: 1.0 - component.expandFraction)
                        
                        rightContentOffset -= repostButtonSize.width + 14.0
                        
                        if forwardStatsText.superview == nil {
                            repostButtonView.button.view.addSubview(forwardStatsText)
                        }
                        
                        forwardStatsFrame.origin.x -= repostButtonFrame.minX
                        forwardStatsFrame.origin.y -= repostButtonFrame.minY
                        forwardStatsTransition.setPosition(view: forwardStatsText, position: forwardStatsFrame.center)
                        forwardStatsTransition.setBounds(view: forwardStatsText, bounds: CGRect(origin: CGPoint(), size: forwardStatsFrame.size))
                    }
                    
                    let forwardButtonSize = forwardButton.update(
                        transition: likeStatsTransition,
                        component: AnyComponent(MessageInputActionButtonComponent(
                            mode: .forward,
                            storyId: component.storyItem.id,
                            action: { [weak self] _, action, _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                guard case .up = action else {
                                    return
                                }
                                component.forwardAction()
                            },
                            longPressAction: nil,
                            switchMediaInputMode: {
                            },
                            updateMediaCancelFraction: { _ in
                            },
                            lockMediaRecording: {
                            },
                            stopAndPreviewMediaRecording: {
                            },
                            moreAction: { _, _ in },
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            presentController: { _ in },
                            audioRecorder: nil,
                            videoRecordingStatus: nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: 33.0, height: 33.0)
                    )
                    if let forwardButtonView = forwardButton.view {
                        if forwardButtonView.superview == nil {
                            self.addSubview(forwardButtonView)
                        }
                        var forwardButtonFrame = CGRect(origin: CGPoint(x: rightContentOffset - likeButtonSize.width, y: floor((size.height - forwardButtonSize.height) * 0.5)), size: forwardButtonSize)
                        forwardButtonFrame.origin.y += component.expandFraction * 45.0
                        
                        likeStatsTransition.setPosition(view: forwardButtonView, position: forwardButtonFrame.center)
                        likeStatsTransition.setBounds(view: forwardButtonView, bounds: CGRect(origin: CGPoint(), size: forwardButtonFrame.size))
                        likeStatsTransition.setAlpha(view: forwardButtonView, alpha: 1.0 - component.expandFraction)
                        
                        rightContentOffset -= forwardButtonSize.width + 8.0
                    }
                } else {
                    if let repostButton = self.repostButton {
                        self.repostButton = nil
                        repostButton.view?.removeFromSuperview()
                    }
                    if let forwardButton = self.forwardButton {
                        self.forwardButton = nil
                        forwardButton.view?.removeFromSuperview()
                    }
                }
            } else {
                if let likeButton = self.likeButton {
                    self.likeButton = nil
                    likeButton.view?.removeFromSuperview()
                }
                if let repostButton = self.repostButton {
                    self.repostButton = nil
                    repostButton.view?.removeFromSuperview()
                }
                if let forwardButton = self.forwardButton {
                    self.forwardButton = nil
                    forwardButton.view?.removeFromSuperview()
                }
            }
            
            let statsButtonWidth = availableSize.width - 80.0

            transition.setFrame(view: self.viewStatsButton, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: statsButtonWidth, height: baseHeight)))
            self.viewStatsButton.isUserInteractionEnabled = component.expandFraction == 0.0
            
            let isPending = component.storyItem.isPending
            self.viewsIconView.isHidden = isPending
            self.viewStatsCountText.isHidden = isPending
            self.viewStatsLabelText.view?.isHidden = isPending
            
            let deleteButtonSize = self.deleteButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Input/Accessory Panels/MessageSelectionTrash",
                        tintColor: .white
                    )),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        if component.storyItem.isPending {
                            component.cancelUploadAction()
                        } else {
                            component.deleteAction()
                        }
                    }
                ).minSize(CGSize(width: 44.0, height: baseHeight))),
                environment: {},
                containerSize: CGSize(width: 44.0, height: baseHeight)
            )
            if let deleteButtonView = self.deleteButton.view {
                if deleteButtonView.superview == nil {
                    self.addSubview(deleteButtonView)
                }
                var deleteButtonFrame = CGRect(origin: CGPoint(x: rightContentOffset - deleteButtonSize.width, y: floor((size.height - deleteButtonSize.height) * 0.5)), size: deleteButtonSize)
                deleteButtonFrame.origin.y += component.expandFraction * 45.0
                transition.setPosition(view: deleteButtonView, position: deleteButtonFrame.center)
                transition.setBounds(view: deleteButtonView, bounds: CGRect(origin: CGPoint(), size: deleteButtonFrame.size))
                
                transition.setAlpha(view: deleteButtonView, alpha: 1.0 - sideContentFraction)
                transition.setScale(view: deleteButtonView, scale: CGFloat(1.0).interpolate(to: CGFloat(0.1), amount: sideContentFraction))
                
                if component.isChannel {
                    deleteButtonView.isHidden = true
                } else {
                    deleteButtonView.isHidden = false
                    rightContentOffset -= deleteButtonSize.width + 8.0
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
