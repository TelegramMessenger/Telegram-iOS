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

public final class StoryFooterPanelComponent: Component {
    public final class AnimationHint {
        public let synchronousLoad: Bool
        
        public init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
    public let context: AccountContext
    public let strings: PresentationStrings
    public let storyItem: EngineStoryItem?
    public let externalViews: EngineStoryItem.Views?
    public let expandFraction: CGFloat
    public let expandViewStats: () -> Void
    public let deleteAction: () -> Void
    public let moreAction: (UIView, ContextGesture?) -> Void
    
    public init(
        context: AccountContext,
        strings: PresentationStrings,
        storyItem: EngineStoryItem?,
        externalViews: EngineStoryItem.Views?,
        expandFraction: CGFloat,
        expandViewStats: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void
    ) {
        self.context = context
        self.strings = strings
        self.storyItem = storyItem
        self.externalViews = externalViews
        self.expandViewStats = expandViewStats
        self.expandFraction = expandFraction
        self.deleteAction = deleteAction
        self.moreAction = moreAction
    }
    
    public static func ==(lhs: StoryFooterPanelComponent, rhs: StoryFooterPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.externalViews != rhs.externalViews {
            return false
        }
        if lhs.expandFraction != rhs.expandFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let viewStatsButton: HighlightTrackingButton
        private let viewStatsText: AnimatedCountLabelView
        private let viewStatsExpandedText: AnimatedCountLabelView
        private let deleteButton = ComponentView<Empty>()
        
        private var statusButton: HighlightableButton?
        private var statusNode: SemanticStatusNode?
        private var uploadingText: ComponentView<Empty>?
        
        private let avatarsContext: AnimatedAvatarSetContext
        private let avatarsView: AnimatedAvatarSetView
        
        private var component: StoryFooterPanelComponent?
        private weak var state: EmptyComponentState?
        
        private var uploadProgress: Float = 0.0
        private var uploadProgressDisposable: Disposable?
        
        public let externalContainerView: UIView
        
        override init(frame: CGRect) {
            self.viewStatsButton = HighlightTrackingButton()
            self.viewStatsText = AnimatedCountLabelView(frame: CGRect())
            self.viewStatsExpandedText = AnimatedCountLabelView(frame: CGRect())
            
            self.avatarsContext = AnimatedAvatarSetContext()
            self.avatarsView = AnimatedAvatarSetView()
            
            self.externalContainerView = UIView()
            
            super.init(frame: frame)
            
            self.avatarsView.isUserInteractionEnabled = false
            self.externalContainerView.addSubview(self.avatarsView)
            self.addSubview(self.viewStatsButton)
            
            self.viewStatsButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.avatarsView.alpha = 0.7
                    self.viewStatsText.alpha = 0.7
                } else {
                    self.avatarsView.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    self.viewStatsText.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
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
            guard let storyItem = component.storyItem else {
                return
            }
            component.context.engine.messages.cancelStoryUpload(stableId: storyItem.id)
        }
        
        func update(component: StoryFooterPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            var synchronousLoad = true
            if let hint = transition.userData(AnimationHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            if self.component?.storyItem?.id != component.storyItem?.id || self.component?.storyItem?.isPending != component.storyItem?.isPending {
                self.uploadProgressDisposable?.dispose()
                self.uploadProgress = 0.0
                
                if let storyItem = component.storyItem, storyItem.isPending {
                    var applyState = false
                    self.uploadProgressDisposable = (component.context.engine.messages.storyUploadProgress(stableId: storyItem.id)
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
            
            var leftOffset: CGFloat = 16.0
            
            let avatarSpacing: CGFloat = 18.0
            
            let avatarsAlpha: CGFloat
            let baseViewCountAlpha: CGFloat
            if let storyItem = component.storyItem, storyItem.isPending {
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
                
                statusNode.transitionToState(.progress(value: CGFloat(max(0.08, self.uploadProgress)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 0.0, lineWidth: 2.0)))
                
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
                
                transition.setFrame(view: statusButton, frame: CGRect(origin: CGPoint(x: leftOffset, y: 0.0), size: CGSize(width: innerLeftOffset, height: size.height)))
                leftOffset += innerLeftOffset
                
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
            
            var peers: [EnginePeer] = []
            if let seenPeers = component.externalViews?.seenPeers ?? component.storyItem?.views?.seenPeers {
                peers = Array(seenPeers.prefix(3))
            }
            let avatarsContent = self.avatarsContext.update(peers: peers, animated: false)
            let avatarsSize = self.avatarsView.update(context: component.context, content: avatarsContent, itemSize: CGSize(width: 30.0, height: 30.0), animation: isFirstTime ? ListViewItemUpdateAnimation.None : ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .easeInOut, interactive: false)), synchronousLoad: synchronousLoad)
            
            let avatarsNodeFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - avatarsSize.height) * 0.5)), size: avatarsSize)
            self.avatarsView.center = avatarsNodeFrame.center
            self.avatarsView.bounds = CGRect(origin: CGPoint(), size: avatarsNodeFrame.size)
            transition.setAlpha(view: self.avatarsView, alpha: avatarsAlpha)
            if !avatarsSize.width.isZero {
                leftOffset = avatarsNodeFrame.maxX + avatarSpacing
            }
            
            var viewCount = 0
            if let views = component.externalViews ?? component.storyItem?.views, views.seenCount != 0 {
                viewCount = views.seenCount
            }
            
            let viewsText: String
            if viewCount == 0 {
                viewsText = component.strings.Story_Footer_NoViews
            } else {
                viewsText = component.strings.Story_Footer_Views(Int32(viewCount))
            }
            let _ = viewsText
            
            self.viewStatsButton.isEnabled = viewCount != 0
            
            //TODO:localize
            var regularSegments: [AnimatedCountLabelView.Segment] = []
            if viewCount != 0 {
                regularSegments.append(.number(viewCount, NSAttributedString(string: "\(viewCount)", font: Font.regular(15.0), textColor: .white)))
            }
            let viewPart: String
            if viewCount == 0 {
                viewPart = "No Views"
            } else if viewCount == 1 {
                viewPart = " View"
            } else {
                viewPart = " Views"
            }
            regularSegments.append(.text(1, NSAttributedString(string: viewPart, font: Font.regular(15.0), textColor: .white)))
            
            var expandedSegments: [AnimatedCountLabelView.Segment] = []
            if viewCount != 0 {
                expandedSegments.append(.number(viewCount, NSAttributedString(string: "\(viewCount)", font: Font.semibold(17.0), textColor: .white)))
            }
            expandedSegments.append(.text(1, NSAttributedString(string: viewPart, font: Font.semibold(17.0), textColor: .white)))
            
            let viewStatsTextLayout = self.viewStatsText.update(size: CGSize(width: availableSize.width, height: size.height), segments: regularSegments, transition: isFirstTime ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut))
            let expandedViewStatsTextLayout = self.viewStatsExpandedText.update(size: CGSize(width: availableSize.width, height: size.height), segments: expandedSegments, transition: isFirstTime ? .immediate : ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut))
            
            let viewStatsTextSize = viewStatsTextLayout.size
            let viewStatsExpandedTextSize = expandedViewStatsTextLayout.size
            
            let viewStatsCollapsedFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - viewStatsTextSize.height) * 0.5)), size: viewStatsTextSize)
            let viewStatsExpandedFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - viewStatsExpandedTextSize.width) * 0.5), y: 3.0 + floor((size.height - viewStatsExpandedTextSize.height) * 0.5)), size: viewStatsExpandedTextSize)
            let viewStatsCurrentFrame = viewStatsCollapsedFrame.interpolate(to: viewStatsExpandedFrame, amount: component.expandFraction)
            
            let viewStatsTextCenter = viewStatsCollapsedFrame.center.interpolate(to: viewStatsExpandedFrame.center, amount: component.expandFraction)
            
            let viewStatsTextFrame = viewStatsCollapsedFrame.size.centered(around: viewStatsTextCenter)
            do {
                let viewStatsTextView = self.viewStatsText
                
                if viewStatsTextView.superview == nil {
                    viewStatsTextView.isUserInteractionEnabled = false
                    self.externalContainerView.addSubview(viewStatsTextView)
                }
                transition.setPosition(view: viewStatsTextView, position: viewStatsTextFrame.center)
                transition.setBounds(view: viewStatsTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsTextFrame.size))
                transition.setAlpha(view: viewStatsTextView, alpha: pow(1.0 - component.expandFraction, 1.2) * baseViewCountAlpha)
                transition.setScale(view: viewStatsTextView, scale: viewStatsCurrentFrame.width / viewStatsTextFrame.width)
            }
            
            let viewStatsExpandedTextFrame = viewStatsExpandedFrame.size.centered(around: viewStatsTextCenter)
            do {
                let viewStatsExpandedTextView = self.viewStatsExpandedText
                
                if viewStatsExpandedTextView.superview == nil {
                    viewStatsExpandedTextView.isUserInteractionEnabled = false
                    self.addSubview(viewStatsExpandedTextView)
                }
                transition.setPosition(view: viewStatsExpandedTextView, position: viewStatsExpandedTextFrame.center)
                transition.setBounds(view: viewStatsExpandedTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsExpandedTextFrame.size))
                transition.setAlpha(view: viewStatsExpandedTextView, alpha: pow(component.expandFraction, 1.2) * baseViewCountAlpha)
                transition.setScale(view: viewStatsExpandedTextView, scale: viewStatsCurrentFrame.width / viewStatsExpandedTextFrame.width)
            }
            
            transition.setFrame(view: self.viewStatsButton, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: viewStatsTextFrame.maxX, height: viewStatsTextFrame.maxY + 8.0)))
            self.viewStatsButton.isUserInteractionEnabled = component.expandFraction == 0.0
            
            var rightContentOffset: CGFloat = availableSize.width - 12.0
            
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
                        component.deleteAction()
                    }
                ).minSize(CGSize(width: 44.0, height: baseHeight))),
                environment: {},
                containerSize: CGSize(width: 44.0, height: baseHeight)
            )
            if let deleteButtonView = self.deleteButton.view {
                if deleteButtonView.superview == nil {
                    self.externalContainerView.addSubview(deleteButtonView)
                }
                transition.setFrame(view: deleteButtonView, frame: CGRect(origin: CGPoint(x: rightContentOffset - deleteButtonSize.width, y: floor((size.height - deleteButtonSize.height) * 0.5)), size: deleteButtonSize))
                rightContentOffset -= deleteButtonSize.width + 8.0
                
                transition.setAlpha(view: deleteButtonView, alpha: pow(1.0 - component.expandFraction, 1.0) * baseViewCountAlpha)
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
