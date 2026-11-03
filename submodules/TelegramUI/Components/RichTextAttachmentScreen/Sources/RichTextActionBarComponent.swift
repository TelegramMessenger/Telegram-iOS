import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent
import GlassBackgroundComponent

class RichTextActionBarComponent: Component {
    final class Action: Equatable {
        let id: AnyHashable
        let icon: String
        let action: ((UIView) -> Void)?
        let isSelected: Bool
        let flipHorizontally: Bool
        let showsPremiumBadge: Bool

        init(id: AnyHashable, icon: String, action: ((UIView) -> Void)?, isSelected: Bool, flipHorizontally: Bool = false, showsPremiumBadge: Bool = false) {
            self.id = id
            self.icon = icon
            self.action = action
            self.isSelected = isSelected
            self.flipHorizontally = flipHorizontally
            self.showsPremiumBadge = showsPremiumBadge
        }

        static func ==(lhs: Action, rhs: Action) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.flipHorizontally != rhs.flipHorizontally {
                return false
            }
            if lhs.showsPremiumBadge != rhs.showsPremiumBadge {
                return false
            }
            return true
        }
    }
    
    let theme: PresentationTheme
    let actionsId: AnyHashable
    let actions: [Action]
    
    init(
        theme: PresentationTheme,
        actionsId: AnyHashable,
        actions: [Action]
    ) {
        self.theme = theme
        self.actionsId = actionsId
        self.actions = actions
    }
    
    static func ==(lhs: RichTextActionBarComponent, rhs: RichTextActionBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.actionsId != rhs.actionsId {
            return false
        }
        if lhs.actions != rhs.actions {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private final class ItemView {
        let item = ComponentView<Empty>()
        let selectionBackground = ComponentView<Empty>()
    }
    
    final class View: UIView {
        private let backgroundContainer: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private let scrollView: ScrollView
        private let selectionBackroundContainer: UIView
        
        private var itemViews: [AnyHashable: ItemView] = [:]
        
        private var component: RichTextActionBarComponent?
        
        override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            
            self.scrollView = ScrollView()
            self.scrollView.delaysContentTouches = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.clipsToBounds = true
            
            self.selectionBackroundContainer = UIView()
            
            super.init(frame: frame)
            
            self.disablesInteractiveTransitionGestureRecognizer = true
            
            self.addSubview(self.backgroundContainer)
            self.backgroundView.contentView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.selectionBackroundContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: RichTextActionBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let verticalInset: CGFloat = 4.0
            let horizontalInset: CGFloat = 4.0
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            let scrollFrame = CGRect(origin: CGPoint(x: horizontalInset, y: verticalInset), size: CGSize(width: size.width - horizontalInset * 2.0, height: size.height - verticalInset * 2.0))
            
            let itemSize = CGSize(width: 40.0, height: 36.0)
            let intrinsicContentWidth = itemSize.width * CGFloat(component.actions.count)
            let areaWidth = size.width - horizontalInset * 2.0
            let minSpacing: CGFloat = 0.0
            
            var spacing = minSpacing
            if intrinsicContentWidth + minSpacing * CGFloat(max(0, component.actions.count - 1)) <= areaWidth {
                spacing = floorToScreenPixels((areaWidth - intrinsicContentWidth) / CGFloat(max(1, component.actions.count - 1)))
            }
            
            var contentSize = CGSize(width: itemSize.width * CGFloat(component.actions.count) + spacing * CGFloat(max(0, component.actions.count - 1)), height: itemSize.height)
            if contentSize.width > scrollFrame.width {
                // The content overflows and scrolls. Calibrate the inter-item spacing so the scroll area's
                // trailing edge bisects an item at rest — a half item peeks past the edge as a "there's more,
                // scroll me" affordance. Ported from TextProcessingStyleSelectionComponent's half-item slot
                // calibration: round the natural fit DOWN to a half-integer item count (X.5) — rounding down
                // keeps the derived stride >= the item's own width, so spacing never goes negative — then
                // derive the slot stride from that target and turn the surplus into inter-item spacing.
                let viewport = scrollFrame.width
                let naturalVisible = viewport / itemSize.width
                let targetVisible = max(1.5, floor(naturalVisible - 0.5) + 0.5)
                let calibratedStride = viewport / targetVisible
                spacing = max(minSpacing, calibratedStride - itemSize.width)
                contentSize.width = itemSize.width * CGFloat(component.actions.count) + spacing * CGFloat(max(0, component.actions.count - 1))
            }
            
            let delayIncrement: Double = 0.02
            let maxAnimateBlur: CGFloat = "".isEmpty ? 0.0 : 1.0
            
            var animateIn = false
            if let previousComponent, component.actionsId != previousComponent.actionsId {
                animateIn = true
                var nextDelay: Double = 0.0
                for item in previousComponent.actions {
                    if let itemView = self.itemViews[item.id] {
                        if let itemComponentView = itemView.item.view {
                            transition.setAlpha(view: itemComponentView, alpha: 0.0, delay: nextDelay, completion: { [weak itemComponentView] _ in
                                itemComponentView?.removeFromSuperview()
                            })
                            transition.setScale(view: itemComponentView, scale: 0.001, delay: nextDelay)
                            if maxAnimateBlur != 0.0 {
                                transition.setBlur(layer: itemComponentView.layer, radius: maxAnimateBlur)
                            }
                        }
                        if let itemSelectionBackgroundView = itemView.selectionBackground.view {
                            transition.setAlpha(view: itemSelectionBackgroundView, alpha: 0.0, delay: nextDelay, completion: { [weak itemSelectionBackgroundView] _ in
                                itemSelectionBackgroundView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    nextDelay += delayIncrement
                }
                self.itemViews.removeAll()
            }
            
            var validIds: [AnyHashable] = []
            var nextAppearDelay: Double = delayIncrement * 2.0
            for (index, item) in component.actions.enumerated() {
                validIds.append(item.id)
                
                let itemView: ItemView
                var itemTransition: ComponentTransition = .immediate
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ItemView()
                    self.itemViews[item.id] = itemView
                }
                
                let _ = itemView.item.update(
                    transition: itemTransition,
                    component: AnyComponent(ActionItemComponent(
                        theme: component.theme,
                        icon: item.icon,
                        action: item.action,
                        isSelected: item.isSelected,
                        flipHorizontally: item.flipHorizontally,
                        showsPremiumBadge: item.showsPremiumBadge
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let _ = itemView.selectionBackground.update(
                    transition: transition,
                    component: AnyComponent(FilledRoundedRectangleComponent(
                        color: component.theme.list.itemCheckColors.fillColor,
                        cornerRadius: .minEdge,
                        smoothCorners: false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(index) * (itemSize.width + spacing), y: 0.0), size: itemSize)
                
                var selectionFrame = itemFrame
                if index + 1 < component.actions.count, component.actions[index + 1].isSelected {
                    let nextItemFrame = CGRect(origin: CGPoint(x: CGFloat(index + 1) * (itemSize.width + spacing), y: 0.0), size: itemSize)
                    selectionFrame = itemFrame.union(CGRect(origin: nextItemFrame.origin, size: CGSize(width: nextItemFrame.width - 4.0, height: nextItemFrame.height)))
                }
                
                if let itemSelectionBackgroundView = itemView.selectionBackground.view {
                    if itemSelectionBackgroundView.superview == nil {
                        self.selectionBackroundContainer.addSubview(itemSelectionBackgroundView)
                    }
                    itemTransition.setFrame(view: itemSelectionBackgroundView, frame: selectionFrame)
                    itemSelectionBackgroundView.isHidden = !item.isSelected
                    
                    if animateIn {
                        transition.animateAlpha(view: itemSelectionBackgroundView, from: 0.0, to: 1.0, delay: nextAppearDelay)
                    }
                }
                if let itemComponentView = itemView.item.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    
                    if animateIn {
                        transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0, delay: nextAppearDelay)
                        transition.animateScale(view: itemComponentView, from: 0.001, to: 1.0, delay: nextAppearDelay)
                        if maxAnimateBlur != 0.0 {
                            transition.animateBlur(layer: itemComponentView.layer, fromRadius: maxAnimateBlur, toRadius: 0.0)
                        }
                    }
                }
                
                nextAppearDelay += delayIncrement
            }
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    itemView.item.view?.removeFromSuperview()
                    itemView.selectionBackground.view?.removeFromSuperview()
                    removeIds.append(id)
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            self.scrollView.frame = scrollFrame
            self.scrollView.layer.cornerRadius = scrollFrame.height * 0.5
            self.scrollView.contentSize = contentSize
            
            self.backgroundContainer.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
            
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            
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

class ActionItemComponent: Component {
    let theme: PresentationTheme
    let icon: String
    let action: ((UIView) -> Void)?
    let isSelected: Bool
    let flipHorizontally: Bool
    let showsPremiumBadge: Bool

    init(
        theme: PresentationTheme,
        icon: String,
        action: ((UIView) -> Void)?,
        isSelected: Bool,
        flipHorizontally: Bool = false,
        showsPremiumBadge: Bool = false
    ) {
        self.theme = theme
        self.icon = icon
        self.action = action
        self.isSelected = isSelected
        self.flipHorizontally = flipHorizontally
        self.showsPremiumBadge = showsPremiumBadge
    }

    static func ==(lhs: ActionItemComponent, rhs: ActionItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.flipHorizontally != rhs.flipHorizontally {
            return false
        }
        if lhs.showsPremiumBadge != rhs.showsPremiumBadge {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let badge = ComponentView<Empty>()
        
        private var component: ActionItemComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action?(self)
            }
        }
        
        private func generateIconImage(name: String, showsPremiumBadge: Bool) -> UIImage? {
            guard let baseImage = UIImage(bundleImageName: name) else {
                return nil
            }
            guard showsPremiumBadge, let starMaskImage = UIImage(bundleImageName: "RichText/PremiumStarMask") else {
                return baseImage.withRenderingMode(.alwaysTemplate)
            }

            let imagePadding: CGFloat = 3.0
            let baseImageSize = baseImage.size
            let imageSize = CGSize(width: baseImageSize.width + imagePadding * 2.0, height: baseImageSize.height + imagePadding * 2.0)
            UIGraphicsBeginImageContextWithOptions(imageSize, false, baseImage.scale)

            let imageFrame = CGRect(origin: CGPoint(x: imagePadding, y: imagePadding), size: baseImageSize)
            baseImage.draw(in: imageFrame)

            let badgeOffset = CGPoint(x: 1.0 + UIScreenPixel, y: -5.0)
            let maskOffset = CGPoint(x: badgeOffset.x + 2.0 - UIScreenPixel, y: badgeOffset.y + 2.0 - UIScreenPixel)
            let maskFrame = CGRect(origin: CGPoint(x: imagePadding + baseImageSize.width - starMaskImage.size.width + maskOffset.x, y: imagePadding + baseImageSize.height - starMaskImage.size.height + maskOffset.y), size: starMaskImage.size)
            starMaskImage.draw(in: maskFrame, blendMode: .destinationOut, alpha: 1.0)

            let resultImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resultImage?.withRenderingMode(.alwaysTemplate)
        }

        func update(component: ActionItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let foregroundColor: UIColor
            if component.isSelected {
                foregroundColor = component.theme.list.itemCheckColors.foregroundColor
            } else {
                foregroundColor = component.theme.chat.inputPanel.panelControlColor.withMultipliedAlpha(component.action != nil ? 1.0 : 0.4)
            }
            
            let iconImage = self.generateIconImage(name: component.icon, showsPremiumBadge: component.showsPremiumBadge)
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(Image(
                    image: iconImage,
                    tintColor: foregroundColor,
                    size: iconImage?.size ?? .zero,
                    flipHorizontally: component.flipHorizontally
                )),
                environment: {},
                containerSize: availableSize
            )
            let iconFrame = iconSize.centered(in: CGRect(origin: CGPoint(), size: availableSize))
            if let iconView = self.icon.view {
                iconView.isHidden = false
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            if component.showsPremiumBadge {
                let badgeSize = self.badge.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "RichText/PremiumStar",
                        tintColor: nil
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let badgeOffset = CGPoint(x: -2.0 + UIScreenPixel, y: -8.0)
                let badgeFrame = CGRect(origin: CGPoint(x: iconFrame.maxX - badgeSize.width + badgeOffset.x, y: iconFrame.maxY - badgeSize.height + badgeOffset.y), size: badgeSize)
                if let badgeView = self.badge.view {
                    badgeView.isHidden = false
                    if badgeView.superview == nil {
                        badgeView.isUserInteractionEnabled = false
                        self.addSubview(badgeView)
                    }
                    transition.setFrame(view: badgeView, frame: badgeFrame)
                }
            } else if let badgeView = self.badge.view {
                badgeView.isHidden = true
            }

            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
