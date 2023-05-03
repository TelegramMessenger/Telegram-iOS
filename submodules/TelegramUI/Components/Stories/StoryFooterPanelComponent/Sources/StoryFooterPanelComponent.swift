import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import ChatListHeaderComponent

public final class StoryFooterPanelComponent: Component {
    public let deleteAction: () -> Void
    public let moreAction: (UIView, ContextGesture?) -> Void
    
    public init(
        deleteAction: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void
    ) {
        self.deleteAction = deleteAction
        self.moreAction = moreAction
    }
    
    public static func ==(lhs: StoryFooterPanelComponent, rhs: StoryFooterPanelComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let viewStatsText = ComponentView<Empty>()
        private let deleteButton = ComponentView<Empty>()
        private var moreButton: MoreHeaderButton?
        
        private var component: StoryFooterPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryFooterPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 44.0
            let size = CGSize(width: availableSize.width, height: baseHeight)
            
            let viewStatsTextSize = self.viewStatsText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: "No views yet", font: Font.regular(15.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: size.height)
            )
            let viewStatsTextFrame = CGRect(origin: CGPoint(x: 16.0, y: floor((size.height - viewStatsTextSize.height) * 0.5)), size: viewStatsTextSize)
            if let viewStatsTextView = self.viewStatsText.view {
                if viewStatsTextView.superview == nil {
                    viewStatsTextView.layer.anchorPoint = CGPoint()
                    self.addSubview(viewStatsTextView)
                }
                transition.setPosition(view: viewStatsTextView, position: viewStatsTextFrame.origin)
                transition.setBounds(view: viewStatsTextView, bounds: CGRect(origin: CGPoint(), size: viewStatsTextFrame.size))
            }
            
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
                rightContentOffset -= deleteButtonSize.width - 8.0
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
