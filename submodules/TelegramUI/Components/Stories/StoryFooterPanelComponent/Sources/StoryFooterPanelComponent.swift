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

public final class StoryFooterPanelComponent: Component {
    public let context: AccountContext
    public let storyItem: EngineStoryItem?
    public let expandFraction: CGFloat
    public let expandViewStats: () -> Void
    public let deleteAction: () -> Void
    public let moreAction: (UIView, ContextGesture?) -> Void
    
    public init(
        context: AccountContext,
        storyItem: EngineStoryItem?,
        expandFraction: CGFloat,
        expandViewStats: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void
    ) {
        self.context = context
        self.storyItem = storyItem
        self.expandViewStats = expandViewStats
        self.expandFraction = expandFraction
        self.deleteAction = deleteAction
        self.moreAction = moreAction
    }
    
    public static func ==(lhs: StoryFooterPanelComponent, rhs: StoryFooterPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.expandFraction != rhs.expandFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let viewStatsButton: HighlightableButton
        private let viewStatsText = ComponentView<Empty>()
        private let viewStatsExpandedText = ComponentView<Empty>()
        private let deleteButton = ComponentView<Empty>()
        private var moreButton: MoreHeaderButton?
        
        private let avatarsContext: AnimatedAvatarSetContext
        private let avatarsNode: AnimatedAvatarSetNode
        
        private var component: StoryFooterPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.viewStatsButton = HighlightableButton()
            
            self.avatarsContext = AnimatedAvatarSetContext()
            self.avatarsNode = AnimatedAvatarSetNode()
            
            super.init(frame: frame)
            
            self.avatarsNode.view.isUserInteractionEnabled = false
            self.viewStatsButton.addSubview(self.avatarsNode.view)
            self.addSubview(self.viewStatsButton)
            
            self.viewStatsButton.addTarget(self, action: #selector(self.viewStatsPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func viewStatsPressed() {
            guard let component = self.component else {
                return
            }
            component.expandViewStats()
        }
        
        func update(component: StoryFooterPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 44.0
            let size = CGSize(width: availableSize.width, height: baseHeight)
            
            var leftOffset: CGFloat = 16.0
            
            let avatarSpacing: CGFloat = 18.0
            
            var peers: [EnginePeer] = []
            if let seenPeers = component.storyItem?.views?.seenPeers {
                peers = Array(seenPeers.prefix(3))
            }
            let avatarsContent = self.avatarsContext.update(peers: peers, animated: false)
            let avatarsSize = self.avatarsNode.update(context: component.context, content: avatarsContent, itemSize: CGSize(width: 30.0, height: 30.0), animated: false, synchronousLoad: true)
            
            let avatarsNodeFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - avatarsSize.height) * 0.5)), size: avatarsSize)
            self.avatarsNode.frame = avatarsNodeFrame
            //transition.setScale(view: self.avatarsNode.view, scale: CGFloat(1.0).interpolate(to: 0.001, amount: component.expandFraction))
            transition.setAlpha(view: self.avatarsNode.view, alpha: pow(1.0 - component.expandFraction, 1.0))
            if !avatarsSize.width.isZero {
                leftOffset = avatarsNodeFrame.maxX + avatarSpacing
            }
            
            var viewCount = 0
            if let views = component.storyItem?.views, views.seenCount != 0 {
                viewCount = views.seenCount
            }
            
            let viewsText: String
            if viewCount == 0 {
                viewsText = "No Views"
            } else if viewCount == 1 {
                viewsText = "1 view"
            } else {
                viewsText = "\(viewCount) views"
            }
            
            self.viewStatsButton.isEnabled = viewCount != 0
            
            let viewStatsTextSize = self.viewStatsText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: viewsText, font: Font.regular(15.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: size.height)
            )
            let viewStatsExpandedTextSize = self.viewStatsExpandedText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: viewsText, font: Font.semibold(17.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: size.height)
            )
            
            let viewStatsCollapsedFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - viewStatsTextSize.height) * 0.5)), size: viewStatsTextSize)
            let viewStatsExpandedFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - viewStatsExpandedTextSize.width) * 0.5), y: floor((size.height - viewStatsExpandedTextSize.height) * 0.5)), size: viewStatsExpandedTextSize)
            let viewStatsCurrentFrame = viewStatsCollapsedFrame.interpolate(to: viewStatsExpandedFrame, amount: component.expandFraction)
            
            let viewStatsTextCenter = viewStatsCollapsedFrame.center.interpolate(to: viewStatsExpandedFrame.center, amount: component.expandFraction)
            
            let viewStatsTextFrame = viewStatsCollapsedFrame.size.centered(around: viewStatsTextCenter)
            if let viewStatsTextView = self.viewStatsText.view {
                if viewStatsTextView.superview == nil {
                    viewStatsTextView.isUserInteractionEnabled = false
                    self.viewStatsButton.addSubview(viewStatsTextView)
                }
                transition.setPosition(view: viewStatsTextView, position: viewStatsTextFrame.center)
                transition.setBounds(view: viewStatsTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsTextFrame.size))
                transition.setAlpha(view: viewStatsTextView, alpha: pow(1.0 - component.expandFraction, 1.2))
                transition.setScale(view: viewStatsTextView, scale: viewStatsCurrentFrame.width / viewStatsTextFrame.width)
            }
            
            let viewStatsExpandedTextFrame = viewStatsExpandedFrame.size.centered(around: viewStatsTextCenter)
            if let viewStatsExpandedTextView = self.viewStatsExpandedText.view {
                if viewStatsExpandedTextView.superview == nil {
                    viewStatsExpandedTextView.isUserInteractionEnabled = false
                    self.viewStatsButton.addSubview(viewStatsExpandedTextView)
                }
                transition.setPosition(view: viewStatsExpandedTextView, position: viewStatsExpandedTextFrame.center)
                transition.setBounds(view: viewStatsExpandedTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsExpandedTextFrame.size))
                transition.setAlpha(view: viewStatsExpandedTextView, alpha: pow(component.expandFraction, 1.2))
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
                    self.addSubview(deleteButtonView)
                }
                transition.setFrame(view: deleteButtonView, frame: CGRect(origin: CGPoint(x: rightContentOffset - deleteButtonSize.width, y: floor((size.height - deleteButtonSize.height) * 0.5)), size: deleteButtonSize))
                rightContentOffset -= deleteButtonSize.width + 8.0
                
                transition.setAlpha(view: deleteButtonView, alpha: pow(1.0 - component.expandFraction, 1.0))
            }
            
            let moreButton: MoreHeaderButton
            if let current = self.moreButton {
                moreButton = current
            } else {
                if let moreButton = self.moreButton {
                    moreButton.removeFromSupernode()
                    self.moreButton = nil
                }
                
                moreButton = MoreHeaderButton(color: .white)
                moreButton.isUserInteractionEnabled = true
                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: .white)))
                moreButton.onPressed = { [weak self] in
                    guard let self, let component = self.component, let moreButton = self.moreButton else {
                        return
                    }
                    moreButton.play()
                    component.moreAction(moreButton.view, nil)
                }
                moreButton.contextAction = { [weak self] sourceNode, gesture in
                    guard let self, let component = self.component, let moreButton = self.moreButton else {
                        return
                    }
                    moreButton.play()
                    component.moreAction(moreButton.view, gesture)
                }
                self.moreButton = moreButton
                self.addSubnode(moreButton)
            }
            
            let buttonSize = CGSize(width: 32.0, height: 44.0)
            moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: .white)))
            transition.setFrame(view: moreButton.view, frame: CGRect(origin: CGPoint(x: rightContentOffset - buttonSize.width, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize))
            transition.setAlpha(view: moreButton.view, alpha: pow(1.0 - component.expandFraction, 1.0))
            
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
