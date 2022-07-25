import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import ComponentDisplayAdapters
import BundleIconComponent

private final class BottomPanelIconComponent: Component {
    let imageName: String
    let isHighlighted: Bool
    let theme: PresentationTheme
    let action: () -> Void
    
    init(
        imageName: String,
        isHighlighted: Bool,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.isHighlighted = isHighlighted
        self.theme = theme
        self.action = action
    }
    
    static func ==(lhs: BottomPanelIconComponent, rhs: BottomPanelIconComponent) -> Bool {
        if lhs.imageName != rhs.imageName {
            return false
        }
        if lhs.isHighlighted != rhs.isHighlighted {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        let contentView: UIImageView
        
        var component: BottomPanelIconComponent?
        
        override init(frame: CGRect) {
            self.contentView = UIImageView()
            self.contentView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action()
            }
        }
        
        func update(component: BottomPanelIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.component?.imageName != component.imageName {
                self.contentView.image = UIImage(bundleImageName: component.imageName)
            }
            
            self.component = component
            
            let size = CGSize(width: 28.0, height: 28.0)
            
            let color = component.isHighlighted ? component.theme.chat.inputMediaPanel.panelHighlightedIconColor : component.theme.chat.inputMediaPanel.panelIconColor
            
            if self.contentView.tintColor != color {
                if !transition.animation.isImmediate {
                    UIView.animate(withDuration: 0.15, delay: 0.0, options: [], animations: {
                        self.contentView.tintColor = color
                    }, completion: nil)
                } else {
                    self.contentView.tintColor = color
                }
            }
            
            let contentSize = self.contentView.image?.size ?? size
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) / 2.0), y: (size.height - contentSize.height) / 2.0), size: contentSize))
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class EntityKeyboardBottomPanelComponent: Component {
    typealias EnvironmentType = PagerComponentPanelEnvironment<EntityKeyboardTopContainerPanelEnvironment>
    
    let theme: PresentationTheme
    let containerInsets: UIEdgeInsets
    let deleteBackwards: () -> Void
    
    init(
        theme: PresentationTheme,
        containerInsets: UIEdgeInsets,
        deleteBackwards: @escaping () -> Void
    ) {
        self.theme = theme
        self.containerInsets = containerInsets
        self.deleteBackwards = deleteBackwards
    }
    
    static func ==(lhs: EntityKeyboardBottomPanelComponent, rhs: EntityKeyboardBottomPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        private final class AccessoryButtonView {
            let id: AnyHashable
            var component: AnyComponent<Empty>
            let view: ComponentHostView<Empty>
            
            init(id: AnyHashable, component: AnyComponent<Empty>, view: ComponentHostView<Empty>) {
                self.id = id
                self.component = component
                self.view = view
            }
        }
        
        private let backgroundView: BlurredBackgroundView
        private let separatorView: UIView
        private var leftAccessoryButton: AccessoryButtonView?
        private var rightAccessoryButton: AccessoryButtonView?
        
        private var iconViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var highlightedIconBackgroundView: UIView
        
        private var component: EntityKeyboardBottomPanelComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            self.separatorView = UIView()
            self.separatorView.isUserInteractionEnabled = false
            
            self.highlightedIconBackgroundView = UIView()
            self.highlightedIconBackgroundView.isUserInteractionEnabled = false
            self.highlightedIconBackgroundView.layer.cornerRadius = 10.0
            self.highlightedIconBackgroundView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.highlightedIconBackgroundView)
            self.addSubview(self.separatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardBottomPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            if self.component?.theme !== component.theme {
                self.separatorView.backgroundColor = component.theme.chat.inputMediaPanel.panelSeparatorColor
                self.backgroundView.updateColor(color: component.theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(1.0), transition: .immediate)
                self.highlightedIconBackgroundView.backgroundColor = component.theme.chat.inputMediaPanel.panelHighlightedIconBackgroundColor
            }
            
            let intrinsicHeight: CGFloat = 34.0
            let height = intrinsicHeight + component.containerInsets.bottom
            
            let accessoryButtonOffset: CGFloat
            if component.containerInsets.bottom > 0.0 {
                accessoryButtonOffset = 2.0
            } else {
                accessoryButtonOffset = -2.0
            }
            
            let panelEnvironment = environment[PagerComponentPanelEnvironment<EntityKeyboardTopContainerPanelEnvironment>.self].value
            let activeContentId = panelEnvironment.activeContentId
            
            var leftAccessoryButtonComponent: AnyComponentWithIdentity<Empty>?
            for contentAccessoryLeftButton in panelEnvironment.contentAccessoryLeftButtons {
                if contentAccessoryLeftButton.id == activeContentId {
                    leftAccessoryButtonComponent = contentAccessoryLeftButton
                    break
                }
            }
            let previousLeftAccessoryButton = self.leftAccessoryButton
            
            if let leftAccessoryButtonComponent = leftAccessoryButtonComponent {
                var leftAccessoryButtonTransition = transition
                let leftAccessoryButton: AccessoryButtonView
                if let current = self.leftAccessoryButton, (current.id == leftAccessoryButtonComponent.id || current.component == leftAccessoryButtonComponent.component) {
                    leftAccessoryButton = current
                    leftAccessoryButton.component = leftAccessoryButtonComponent.component
                } else {
                    leftAccessoryButtonTransition = .immediate
                    leftAccessoryButton = AccessoryButtonView(id: leftAccessoryButtonComponent.id, component: leftAccessoryButtonComponent.component, view: ComponentHostView<Empty>())
                    self.leftAccessoryButton = leftAccessoryButton
                    self.addSubview(leftAccessoryButton.view)
                }
                
                let leftAccessoryButtonSize = leftAccessoryButton.view.update(
                    transition: leftAccessoryButtonTransition,
                    component: leftAccessoryButtonComponent.component,
                    environment: {},
                    containerSize: CGSize(width: .greatestFiniteMagnitude, height: intrinsicHeight)
                )
                leftAccessoryButtonTransition.setFrame(view: leftAccessoryButton.view, frame: CGRect(origin: CGPoint(x: component.containerInsets.left + 2.0, y: accessoryButtonOffset), size: leftAccessoryButtonSize))
            } else {
                self.leftAccessoryButton = nil
            }
            
            if previousLeftAccessoryButton?.view !== self.leftAccessoryButton?.view {
                if case .none = transition.animation {
                    previousLeftAccessoryButton?.view.removeFromSuperview()
                } else {
                    if let previousLeftAccessoryButton = previousLeftAccessoryButton {
                        let previousLeftAccessoryButtonView = previousLeftAccessoryButton.view
                        previousLeftAccessoryButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        previousLeftAccessoryButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousLeftAccessoryButtonView] _ in
                            previousLeftAccessoryButtonView?.removeFromSuperview()
                        })
                    }
                    
                    if let leftAccessoryButtonView = self.leftAccessoryButton?.view {
                        leftAccessoryButtonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        leftAccessoryButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            var rightAccessoryButtonComponent: AnyComponentWithIdentity<Empty>?
            for contentAccessoryRightButton in panelEnvironment.contentAccessoryRightButtons {
                if contentAccessoryRightButton.id == activeContentId {
                    rightAccessoryButtonComponent = contentAccessoryRightButton
                    break
                }
            }
            let previousRightAccessoryButton = self.rightAccessoryButton
            
            if let rightAccessoryButtonComponent = rightAccessoryButtonComponent {
                var rightAccessoryButtonTransition = transition
                let rightAccessoryButton: AccessoryButtonView
                if let current = self.rightAccessoryButton, (current.id == rightAccessoryButtonComponent.id || current.component == rightAccessoryButtonComponent.component) {
                    rightAccessoryButton = current
                    current.component = rightAccessoryButtonComponent.component
                } else {
                    rightAccessoryButtonTransition = .immediate
                    rightAccessoryButton = AccessoryButtonView(id: rightAccessoryButtonComponent.id, component: rightAccessoryButtonComponent.component, view: ComponentHostView<Empty>())
                    self.rightAccessoryButton = rightAccessoryButton
                    self.addSubview(rightAccessoryButton.view)
                }
                
                let rightAccessoryButtonSize = rightAccessoryButton.view.update(
                    transition: rightAccessoryButtonTransition,
                    component: rightAccessoryButtonComponent.component,
                    environment: {},
                    containerSize: CGSize(width: .greatestFiniteMagnitude, height: intrinsicHeight)
                )
                rightAccessoryButtonTransition.setFrame(view: rightAccessoryButton.view, frame: CGRect(origin: CGPoint(x: availableSize.width - component.containerInsets.right - 2.0 - rightAccessoryButtonSize.width, y: accessoryButtonOffset), size: rightAccessoryButtonSize))
            } else {
                self.rightAccessoryButton = nil
            }
            
            if previousRightAccessoryButton?.view !== self.rightAccessoryButton?.view {
                if case .none = transition.animation {
                    previousRightAccessoryButton?.view.removeFromSuperview()
                } else {
                    if let previousRightAccessoryButton = previousRightAccessoryButton {
                        let previousRightAccessoryButtonView = previousRightAccessoryButton.view
                        previousRightAccessoryButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        previousRightAccessoryButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousRightAccessoryButtonView] _ in
                            previousRightAccessoryButtonView?.removeFromSuperview()
                        })
                    }
                    
                    if let rightAccessoryButtonView = self.rightAccessoryButton?.view {
                        rightAccessoryButtonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        rightAccessoryButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            var validIconIds: [AnyHashable] = []
            var iconInfos: [AnyHashable: (size: CGSize, transition: Transition)] = [:]
            
            var iconTotalSize = CGSize()
            let iconSpacing: CGFloat = 22.0
            
            let navigateToContentId = panelEnvironment.navigateToContentId
            
            if panelEnvironment.contentIcons.count > 1 {
                for icon in panelEnvironment.contentIcons {
                    validIconIds.append(icon.id)
                    
                    var iconTransition = transition
                    let iconView: ComponentHostView<Empty>
                    if let current = self.iconViews[icon.id] {
                        iconView = current
                    } else {
                        iconTransition = .immediate
                        iconView = ComponentHostView<Empty>()
                        self.iconViews[icon.id] = iconView
                        self.addSubview(iconView)
                    }
                    
                    let iconSize = iconView.update(
                        transition: iconTransition,
                        component: AnyComponent(BottomPanelIconComponent(
                            imageName: icon.imageName,
                            isHighlighted: icon.id == activeContentId,
                            theme: component.theme,
                            action: {
                                navigateToContentId(icon.id)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: 28.0, height: 28.0)
                    )
                    
                    iconInfos[icon.id] = (size: iconSize, transition: iconTransition)
                    
                    if !iconTotalSize.width.isZero {
                        iconTotalSize.width += iconSpacing
                    }
                    iconTotalSize.width += iconSize.width
                    iconTotalSize.height = max(iconTotalSize.height, iconSize.height)
                }
            }
            
            var nextIconOrigin = CGPoint(x: floor((availableSize.width - iconTotalSize.width) / 2.0), y: floor((intrinsicHeight - iconTotalSize.height) / 2.0))
            if component.containerInsets.bottom > 0.0 {
                nextIconOrigin.y += 3.0
            }
            
            if panelEnvironment.contentIcons.count > 1 {
                for icon in panelEnvironment.contentIcons {
                    guard let iconInfo = iconInfos[icon.id], let iconView = self.iconViews[icon.id] else {
                        continue
                    }
                    
                    let iconFrame = CGRect(origin: nextIconOrigin, size: iconInfo.size)
                    iconInfo.transition.setFrame(view: iconView, frame: iconFrame, completion: nil)
                    
                    if let activeContentId = activeContentId, activeContentId == icon.id {
                        self.highlightedIconBackgroundView.isHidden = false
                        transition.setFrame(view: self.highlightedIconBackgroundView, frame: iconFrame)
                        
                        let cornerRadius: CGFloat
                        if icon.id == AnyHashable("emoji") {
                            cornerRadius = min(iconFrame.width, iconFrame.height) / 2.0
                        } else {
                            cornerRadius = 10.0
                        }
                        transition.setCornerRadius(layer: self.highlightedIconBackgroundView.layer, cornerRadius: cornerRadius)
                    }
                    
                    nextIconOrigin.x += iconInfo.size.width + iconSpacing
                }
            }
                                    
            if activeContentId == nil {
                self.highlightedIconBackgroundView.isHidden = true
            }
            
            var removedIconViewIds: [AnyHashable] = []
            for (id, iconView) in self.iconViews {
                if !validIconIds.contains(id) {
                    removedIconViewIds.append(id)
                    iconView.removeFromSuperview()
                }
            }
            for id in removedIconViewIds {
                self.iconViews.removeValue(forKey: id)
            }
            
            transition.setFrame(view: self.separatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height)))
            self.backgroundView.update(size: CGSize(width: availableSize.width, height: height), transition: transition.containedViewLayoutTransition)
            
            self.component = component
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
