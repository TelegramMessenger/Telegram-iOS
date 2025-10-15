import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import ComponentDisplayAdapters
import BundleIconComponent
import GlassBackgroundComponent

private final class BottomPanelIconComponent: Component {
    let title: String
    let isHighlighted: Bool
    let theme: PresentationTheme
    let action: () -> Void
    
    init(
        title: String,
        isHighlighted: Bool,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isHighlighted = isHighlighted
        self.theme = theme
        self.action = action
    }
    
    static func ==(lhs: BottomPanelIconComponent, rhs: BottomPanelIconComponent) -> Bool {
        if lhs.title != rhs.title {
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
        let contentView: GlassBackgroundView.ContentImageView
        let tintMaskContainer: UIView
        
        var component: BottomPanelIconComponent?
        
        override init(frame: CGRect) {
            self.contentView = GlassBackgroundView.ContentImageView()
            self.contentView.isUserInteractionEnabled = false
            
            self.tintMaskContainer = UIView()
            self.tintMaskContainer.addSubview(self.contentView.tintMask)
            
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
        
        func update(component: BottomPanelIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.title != component.title {
                let text = NSAttributedString(string: component.title, font: Font.medium(15.0), textColor: .white)
                let textBounds = text.boundingRect(with: CGSize(width: 120.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                self.contentView.image = generateImage(CGSize(width: ceil(textBounds.width), height: ceil(textBounds.height)), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    text.draw(in: textBounds)
                    UIGraphicsPopContext()
                })?.withRenderingMode(.alwaysTemplate)
            }
            
            self.component = component
            
            let textInset: CGFloat = 12.0
            
            let textSize = self.contentView.image?.size ?? CGSize()
            let size = CGSize(width: textSize.width + textInset * 2.0, height: 28.0)
            
            let color = component.theme.chat.inputPanel.inputControlColor
            
            if self.contentView.tintColor != color {
                if !transition.animation.isImmediate {
                    UIView.animate(withDuration: 0.15, delay: 0.0, options: [], animations: {
                        self.contentView.tintColor = color
                    }, completion: nil)
                } else {
                    self.contentView.tintColor = color
                }
            }
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: (size.height - textSize.height) / 2.0 - 1.0), size: textSize))
            
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
    
    final class View: UIView, PagerTopPanelView {
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
        private let tintSeparatorView: UIView
        private var leftAccessoryButton: AccessoryButtonView?
        private var rightAccessoryButton: AccessoryButtonView?
        
        private var iconViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var highlightedIconBackgroundView: UIView
        private var highlightedTintIconBackgroundView: UIView
        
        let tintContentMask: UIView
        
        private var component: EntityKeyboardBottomPanelComponent?
        
        override init(frame: CGRect) {
            self.tintContentMask = UIView()
            
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true, customBlurRadius: 10.0)
            
            self.separatorView = UIView()
            self.separatorView.isUserInteractionEnabled = false
            self.tintSeparatorView = UIView()
            self.tintSeparatorView.isUserInteractionEnabled = false
            self.tintSeparatorView.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
            
            self.tintContentMask.addSubview(self.tintSeparatorView)
            
            self.highlightedIconBackgroundView = UIView()
            self.highlightedIconBackgroundView.isUserInteractionEnabled = false
            self.highlightedIconBackgroundView.layer.cornerRadius = 10.0
            self.highlightedIconBackgroundView.clipsToBounds = true
            
            self.highlightedTintIconBackgroundView = UIView()
            self.highlightedTintIconBackgroundView.isUserInteractionEnabled = false
            self.highlightedTintIconBackgroundView.layer.cornerRadius = 10.0
            self.highlightedTintIconBackgroundView.clipsToBounds = true
            self.highlightedTintIconBackgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
            
            self.tintContentMask.addSubview(self.highlightedTintIconBackgroundView)
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.highlightedIconBackgroundView)
            self.addSubview(self.separatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardBottomPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            if self.component?.theme !== component.theme {
                self.separatorView.backgroundColor = component.theme.list.itemPlainSeparatorColor.withMultipliedAlpha(0.5)
                
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
                let leftAccessoryButtonFrame = CGRect(origin: CGPoint(x: component.containerInsets.left + 2.0, y: accessoryButtonOffset), size: leftAccessoryButtonSize)
                leftAccessoryButtonTransition.setFrame(view: leftAccessoryButton.view, frame: leftAccessoryButtonFrame)
                if let leftAccessoryButtonView = leftAccessoryButton.view.componentView as? PagerTopPanelView {
                    if leftAccessoryButtonView.tintContentMask.superview == nil {
                        self.tintContentMask.addSubview(leftAccessoryButtonView.tintContentMask)
                    }
                    leftAccessoryButtonTransition.setFrame(view: leftAccessoryButtonView.tintContentMask, frame: leftAccessoryButtonFrame)
                }
            } else {
                self.leftAccessoryButton = nil
            }
            
            if previousLeftAccessoryButton?.view !== self.leftAccessoryButton?.view {
                if case .none = transition.animation {
                    previousLeftAccessoryButton?.view.removeFromSuperview()
                    if let previousLeftAccessoryButton = previousLeftAccessoryButton?.view.componentView as? PagerTopPanelView {
                        previousLeftAccessoryButton.tintContentMask.removeFromSuperview()
                    }
                } else {
                    if let previousLeftAccessoryButton = previousLeftAccessoryButton {
                        let previousLeftAccessoryButtonView = previousLeftAccessoryButton.view
                        previousLeftAccessoryButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        previousLeftAccessoryButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousLeftAccessoryButtonView] _ in
                            previousLeftAccessoryButtonView?.removeFromSuperview()
                            if let previousLeftAccessoryButton = previousLeftAccessoryButtonView?.componentView as? PagerTopPanelView {
                                previousLeftAccessoryButton.tintContentMask.removeFromSuperview()
                            }
                        })
                    }
                    
                    if let leftAccessoryButtonView = self.leftAccessoryButton?.view {
                        leftAccessoryButtonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        leftAccessoryButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                        if let leftAccessoryButtonView = leftAccessoryButtonView.componentView as? PagerTopPanelView {
                            leftAccessoryButtonView.tintContentMask.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                            leftAccessoryButtonView.tintContentMask.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
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
                
                let rightAccessoryButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - component.containerInsets.right - 2.0 - rightAccessoryButtonSize.width, y: accessoryButtonOffset), size: rightAccessoryButtonSize)
                rightAccessoryButtonTransition.setFrame(view: rightAccessoryButton.view, frame: rightAccessoryButtonFrame)
                if let rightAccessoryButtonView = rightAccessoryButton.view.componentView as? PagerTopPanelView {
                    if rightAccessoryButtonView.tintContentMask.superview == nil {
                        self.tintContentMask.addSubview(rightAccessoryButtonView.tintContentMask)
                    }
                    rightAccessoryButtonTransition.setFrame(view: rightAccessoryButtonView.tintContentMask, frame: rightAccessoryButtonFrame)
                }
            } else {
                self.rightAccessoryButton = nil
            }
            
            if previousRightAccessoryButton?.view !== self.rightAccessoryButton?.view {
                if case .none = transition.animation {
                    previousRightAccessoryButton?.view.removeFromSuperview()
                    if let previousRightAccessoryButtonView = previousRightAccessoryButton?.view.componentView as? PagerTopPanelView {
                        previousRightAccessoryButtonView.tintContentMask.removeFromSuperview()
                    }
                } else {
                    if let previousRightAccessoryButton = previousRightAccessoryButton {
                        let previousRightAccessoryButtonView = previousRightAccessoryButton.view
                        previousRightAccessoryButtonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        previousRightAccessoryButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousRightAccessoryButtonView] _ in
                            previousRightAccessoryButtonView?.removeFromSuperview()
                            if let previousRightAccessoryButtonView = previousRightAccessoryButtonView?.componentView as? PagerTopPanelView {
                                previousRightAccessoryButtonView.tintContentMask.removeFromSuperview()
                            }
                        })
                    }
                    
                    if let rightAccessoryButtonView = self.rightAccessoryButton?.view {
                        rightAccessoryButtonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        rightAccessoryButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                        if let rightAccessoryButtonView = rightAccessoryButtonView.componentView as? PagerTopPanelView {
                            rightAccessoryButtonView.tintContentMask.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                            rightAccessoryButtonView.tintContentMask.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }
            
            var validIconIds: [AnyHashable] = []
            var iconInfos: [AnyHashable: (size: CGSize, transition: ComponentTransition)] = [:]
            
            var iconTotalSize = CGSize()
            let iconSpacing: CGFloat = 4.0
            
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
                            title: icon.title,
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
                    
                    if let iconView = iconView.componentView as? BottomPanelIconComponent.View {
                        if iconView.tintMaskContainer.superview == nil {
                            self.tintContentMask.addSubview(iconView.tintMaskContainer)
                        }
                        iconInfo.transition.setFrame(view: iconView.tintMaskContainer, frame: iconFrame, completion: nil)
                    }
                    
                    if let activeContentId = activeContentId, activeContentId == icon.id {
                        self.highlightedIconBackgroundView.isHidden = false
                        self.highlightedTintIconBackgroundView.isHidden = false
                        transition.setFrame(view: self.highlightedIconBackgroundView, frame: iconFrame)
                        transition.setFrame(view: self.highlightedTintIconBackgroundView, frame: iconFrame)
                        
                        let cornerRadius: CGFloat = min(iconFrame.width, iconFrame.height) / 2.0
                        transition.setCornerRadius(layer: self.highlightedIconBackgroundView.layer, cornerRadius: cornerRadius)
                        transition.setCornerRadius(layer: self.highlightedTintIconBackgroundView.layer, cornerRadius: cornerRadius)
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
            transition.setFrame(view: self.tintSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height)))
            //self.backgroundView.update(size: CGSize(width: availableSize.width, height: height), transition: transition.containedViewLayoutTransition)
            
            self.component = component
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
