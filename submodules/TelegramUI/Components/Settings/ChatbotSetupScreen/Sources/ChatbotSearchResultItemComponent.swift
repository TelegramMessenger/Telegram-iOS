import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AvatarNode
import BundleIconComponent
import TelegramPresentationData
import TelegramCore
import AccountContext
import ListSectionComponent
import PlainButtonComponent
import ShimmerEffect

final class ChatbotSearchResultItemComponent: Component {
    enum Content: Equatable {
        case searching
        case found(peer: EnginePeer, isInstalled: Bool)
        case notFound
    }

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let content: Content
    let installAction: () -> Void
    let removeAction: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        content: Content,
        installAction: @escaping () -> Void,
        removeAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.content = content
        self.installAction = installAction
        self.removeAction = removeAction
    }

    static func ==(lhs: ChatbotSearchResultItemComponent, rhs: ChatbotSearchResultItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private var notFoundLabel: ComponentView<Empty>?
        private let titleLabel = ComponentView<Empty>()
        private let subtitleLabel = ComponentView<Empty>()
        
        private var shimmerEffectNode: ShimmerEffectNode?
        
        private var avatarNode: AvatarNode?
        
        private var addButton: ComponentView<Empty>?
        private var removeButton: ComponentView<Empty>?
        
        private var component: ChatbotSearchResultItemComponent?
        private weak var state: EmptyComponentState?
        
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatbotSearchResultItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 10.0
            let avatarDiameter: CGFloat = 40.0
            let avatarTextSpacing: CGFloat = 12.0
            let titleSubtitleSpacing: CGFloat = 1.0
            let verticalInset: CGFloat = 11.0
            
            let maxTextWidth: CGFloat = availableSize.width - sideInset * 2.0 - avatarDiameter - avatarTextSpacing
            
            var addButtonSize: CGSize?
            if case .found(_, false) = component.content {
                let addButton: ComponentView<Empty>
                var addButtonTransition = transition
                if let current = self.addButton {
                    addButton = current
                } else {
                    addButtonTransition = addButtonTransition.withAnimation(.none)
                    addButton = ComponentView()
                    self.addButton = addButton
                }
                
                addButtonSize = addButton.update(
                    transition: addButtonTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.strings.ChatbotSetup_BotAddAction, font: Font.semibold(15.0), textColor: component.theme.list.itemCheckColors.foregroundColor))
                        )),
                        background: AnyComponent(RoundedRectangle(color: component.theme.list.itemCheckColors.fillColor, cornerRadius: nil)),
                        effectAlignment: .center,
                        minSize: nil,
                        contentInsets: UIEdgeInsets(top: 4.0, left: 8.0, bottom: 4.0, right: 8.0),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.installAction()
                        },
                        animateAlpha: true,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else {
                if let addButton = self.addButton {
                    self.addButton = nil
                    if let addButtonView = addButton.view {
                        if !transition.animation.isImmediate {
                            transition.setScale(view: addButtonView, scale: 0.001)
                            ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: addButtonView, alpha: 0.0, completion: { [weak addButtonView] _ in
                                addButtonView?.removeFromSuperview()
                            })
                        } else {
                            addButtonView.removeFromSuperview()
                        }
                    }
                }
            }
            
            var removeButtonSize: CGSize?
            if case .found(_, true) = component.content {
                let removeButton: ComponentView<Empty>
                var removeButtonTransition = transition
                if let current = self.removeButton {
                    removeButton = current
                } else {
                    removeButtonTransition = removeButtonTransition.withAnimation(.none)
                    removeButton = ComponentView()
                    self.removeButton = removeButton
                }
                
                removeButtonSize = removeButton.update(
                    transition: removeButtonTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Chat/Message/SideCloseIcon",
                            tintColor: component.theme.list.controlSecondaryColor
                        )),
                        effectAlignment: .center,
                        minSize: nil,
                        contentInsets: UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.removeAction()
                        },
                        animateAlpha: true,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else {
                if let removeButton = self.removeButton {
                    self.removeButton = nil
                    if let removeButtonView = removeButton.view {
                        if !transition.animation.isImmediate {
                            transition.setScale(view: removeButtonView, scale: 0.001)
                            ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: removeButtonView, alpha: 0.0, completion: { [weak removeButtonView] _ in
                                removeButtonView?.removeFromSuperview()
                            })
                        } else {
                            removeButtonView.removeFromSuperview()
                        }
                    }
                }
            }
            
            let titleValue: String
            let subtitleValue: String
            let isTextVisible: Bool
            switch component.content {
            case .searching, .notFound:
                isTextVisible = false
                titleValue = "AAAAAAAAA"
                subtitleValue = component.strings.Bot_GenericBotStatus
            case let .found(peer, _):
                isTextVisible = true
                titleValue = peer.displayTitle(strings: component.strings, displayOrder: .firstLast)
                subtitleValue = component.strings.Bot_GenericBotStatus
            }
            
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleValue, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: maxTextWidth, height: 100.0)
            )
            let subtitleSize = self.subtitleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitleValue, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: maxTextWidth, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: verticalInset * 2.0 + titleSize.height + titleSubtitleSpacing + subtitleSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: sideInset + avatarDiameter + avatarTextSpacing, y: verticalInset), size: titleSize)
            if let titleView = self.titleLabel.view {
                var titleTransition = transition
                if titleView.superview == nil {
                    titleTransition = .immediate
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                if titleView.isHidden != !isTextVisible {
                    titleTransition = .immediate
                }
                
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                titleTransition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.isHidden = !isTextVisible
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: sideInset + avatarDiameter + avatarTextSpacing, y: verticalInset + titleSize.height + titleSubtitleSpacing), size: subtitleSize)
            if let subtitleView = self.subtitleLabel.view {
                var subtitleTransition = transition
                if subtitleView.superview == nil {
                    subtitleTransition = .immediate
                    subtitleView.layer.anchorPoint = CGPoint()
                    self.addSubview(subtitleView)
                }
                if subtitleView.isHidden != !isTextVisible {
                    subtitleTransition = .immediate
                }
                
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                subtitleTransition.setPosition(view: subtitleView, position: subtitleFrame.origin)
                subtitleView.isHidden = !isTextVisible
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - avatarDiameter) * 0.5)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
            
            if case let .found(peer, _) = component.content {
                var avatarTransition = transition
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarTransition = .immediate
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 17.0))
                    self.avatarNode = avatarNode
                    self.addSubview(avatarNode.view)
                }
                avatarTransition.setFrame(view: avatarNode.view, frame: avatarFrame)
                avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, synchronousLoad: true, displayDimensions: avatarFrame.size)
                avatarNode.updateSize(size: avatarFrame.size)
            } else {
                if let avatarNode = self.avatarNode {
                    self.avatarNode = nil
                    avatarNode.view.removeFromSuperview()
                }
            }
            
            if case .notFound = component.content {
                let notFoundLabel: ComponentView<Empty>
                if let current = self.notFoundLabel {
                    notFoundLabel = current
                } else {
                    notFoundLabel = ComponentView()
                    self.notFoundLabel = notFoundLabel
                }
                let notFoundLabelSize = notFoundLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.ChatbotSetup_BotNotFoundStatus, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: maxTextWidth, height: 100.0)
                )
                let notFoundLabelFrame = CGRect(origin: CGPoint(x: floor((size.width - notFoundLabelSize.width) * 0.5), y: floor((size.height - notFoundLabelSize.height) * 0.5)), size: notFoundLabelSize)
                if let notFoundLabelView = notFoundLabel.view {
                    var notFoundLabelTransition = transition
                    if notFoundLabelView.superview == nil {
                        notFoundLabelTransition = .immediate
                        self.addSubview(notFoundLabelView)
                    }
                    notFoundLabelTransition.setPosition(view: notFoundLabelView, position: notFoundLabelFrame.center)
                    notFoundLabelView.bounds = CGRect(origin: CGPoint(), size: notFoundLabelFrame.size)
                }
            } else {
                if let notFoundLabel = self.notFoundLabel {
                    self.notFoundLabel = nil
                    notFoundLabel.view?.removeFromSuperview()
                }
            }
            
            if let addButton = self.addButton, let addButtonSize {
                var addButtonTransition = transition
                let addButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - addButtonSize.width, y: floor((size.height - addButtonSize.height) * 0.5)), size: addButtonSize)
                if let addButtonView = addButton.view {
                    if addButtonView.superview == nil {
                        addButtonTransition = addButtonTransition.withAnimation(.none)
                        self.addSubview(addButtonView)
                        if !transition.animation.isImmediate {
                            transition.animateScale(view: addButtonView, from: 0.001, to: 1.0)
                            ComponentTransition.easeInOut(duration: 0.2).animateAlpha(view: addButtonView, from: 0.0, to: 1.0)
                        }
                    }
                    addButtonTransition.setFrame(view: addButtonView, frame: addButtonFrame)
                }
            }
            
            if let removeButton = self.removeButton, let removeButtonSize {
                var removeButtonTransition = transition
                let removeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - removeButtonSize.width, y: floor((size.height - removeButtonSize.height) * 0.5)), size: removeButtonSize)
                if let removeButtonView = removeButton.view {
                    if removeButtonView.superview == nil {
                        removeButtonTransition = removeButtonTransition.withAnimation(.none)
                        self.addSubview(removeButtonView)
                        if !transition.animation.isImmediate {
                            transition.animateScale(view: removeButtonView, from: 0.001, to: 1.0)
                            ComponentTransition.easeInOut(duration: 0.2).animateAlpha(view: removeButtonView, from: 0.0, to: 1.0)
                        }
                    }
                    removeButtonTransition.setFrame(view: removeButtonView, frame: removeButtonFrame)
                }
            }
            
            if case .searching = component.content {
                let shimmerEffectNode: ShimmerEffectNode
                if let current = self.shimmerEffectNode {
                    shimmerEffectNode = current
                } else {
                    shimmerEffectNode = ShimmerEffectNode()
                    self.shimmerEffectNode = shimmerEffectNode
                    self.addSubview(shimmerEffectNode.view)
                }
                
                shimmerEffectNode.frame = CGRect(origin: CGPoint(), size: size)
                shimmerEffectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
                
                var shapes: [ShimmerEffectNode.Shape] = []
                
                let titleLineWidth: CGFloat = titleFrame.width
                let subtitleLineWidth: CGFloat = subtitleFrame.width
                let lineDiameter: CGFloat = 10.0
                
                shapes.append(.circle(avatarFrame))
                
                shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                
                shapes.append(.roundedRectLine(startPoint: CGPoint(x: subtitleFrame.minX, y: subtitleFrame.minY + floor((subtitleFrame.height - lineDiameter) / 2.0)), width: subtitleLineWidth, diameter: lineDiameter))
                
                shimmerEffectNode.update(backgroundColor: component.theme.list.itemBlocksBackgroundColor, foregroundColor: component.theme.list.mediaPlaceholderColor, shimmeringColor: component.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: size)
            } else {
                if let shimmerEffectNode = self.shimmerEffectNode {
                    self.shimmerEffectNode = nil
                    shimmerEffectNode.view.removeFromSuperview()
                }
            }
            
            self.separatorInset = 16.0
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
