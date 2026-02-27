import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import GiftItemComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import BundleIconComponent
import LottieComponent

private let cubeSide: CGFloat = 110.0

struct GiftItem: Equatable {
    let gift: StarGift.UniqueGift
    let reference: StarGiftReference
}

final class CraftTableComponent: Component {
    enum Result {
        case gift(ProfileGiftsContext.State.StarGift)
        case fail
    }
    
    let context: AccountContext
    let gifts: [Int32: GiftItem]
    let buttonColor: UIColor
    let isCrafting: Bool
    let result: Result?
    let select: (Int32) -> Void
    let remove: (Int32) -> Void
    let willFinish: (Bool) -> Void
    let finished: (UIView?) -> Void

    public init(
        context: AccountContext,
        gifts: [Int32: GiftItem],
        buttonColor: UIColor,
        isCrafting: Bool,
        result: Result?,
        select: @escaping (Int32) -> Void,
        remove: @escaping (Int32) -> Void,
        willFinish: @escaping (Bool) -> Void,
        finished: @escaping (UIView?) -> Void
    ) {
        self.context = context
        self.gifts = gifts
        self.buttonColor = buttonColor
        self.isCrafting = isCrafting
        self.result = result
        self.select = select
        self.remove = remove
        self.willFinish = willFinish
        self.finished = finished
    }

    public static func ==(lhs: CraftTableComponent, rhs: CraftTableComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gifts != rhs.gifts {
            return false
        }
        if lhs.buttonColor != rhs.buttonColor {
            return false
        }
        if lhs.isCrafting != rhs.isCrafting {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var selectedGifts: [AnyHashable: ComponentView<Empty>] = [:]
        private var faces: [AnyHashable: ComponentView<Empty>] = [:]
        private let successFace = ComponentView<Empty>()
        
        private let anvilPlayOnce = ActionSlot<Void>()
        private let animationView = CubeAnimationView()
        private let craftFailPlayOnce = ActionSlot<Void>()
        
        private var didSetupFinishAnimation = false
        private var flipFaces = false

        private var isSuccess = false
        private var isFailed = false
        private var failDidStartCrossAnimation = false
        private var failDidBringToFront = false
        private var failWillFinish = false
        private var failDidFinish = false
        
        private var component: CraftTableComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.animationView)
            
            self.animationView.onStickerLaunch = {
                HapticFeedback().impact(.soft)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func setupFailureAnimation() {
            guard !self.didSetupFinishAnimation else {
                return
            }
            self.didSetupFinishAnimation = true
            
            self.animationView.onFinishApproach = { [weak self] isUpsideDown, isClockwise in
                guard let self, let component = self.component else {
                    return
                }
                self.isFailed = true
                self.animationView.setSticker(nil, face: 0, mirror: false)
                
                var availableStickers: [ComponentView<Empty>] = []
                for (id, gift) in self.selectedGifts {
                    if let id = id.base as? Int, component.gifts[Int32(id)] != nil {
                        availableStickers.append(gift)
                    }
                }
                let wrappingCount = min(2, availableStickers.count)
                for i in 0 ..< wrappingCount {
                    if let sticker = availableStickers[i].view {
                        let face: Int
                        if isClockwise {
                            face = i + 1
                        } else {
                            face = 3 - i
                        }
                        self.animationView.setSticker(sticker, face: face, mirror: isUpsideDown, animated: true)
                    }
                }
                
                self.flipFaces = isUpsideDown
                                
                Queue.mainQueue().after(0.3, {
                    self.failWillFinish = true
                    self.component?.willFinish(false)
                    
                    self.craftFailPlayOnce.invoke(Void())
                })
                
                Queue.mainQueue().after(0.5, {
                    self.failDidFinish = true
                    self.component?.finished(nil)
                })
                
                self.state?.updated(transition: .easeInOut(duration: 0.4))
            }
        }
        
        func setupSuccessAnimation(_ gift: StarGift.UniqueGift) {
            guard !self.didSetupFinishAnimation, let component = self.component else {
                return
            }
            self.didSetupFinishAnimation = true
            
            self.animationView.isSuccess = true
            
            self.animationView.onFinishApproach = { [weak self] isUpsideDown, isClockwise in
                guard let self else {
                    return
                }
                self.isSuccess = true
                
                var availableStickers: [ComponentView<Empty>] = []
                for (id, gift) in self.selectedGifts {
                    if let id = id.base as? Int, component.gifts[Int32(id)] != nil {
                        availableStickers.append(gift)
                    }
                }
                let wrappingCount = min(2, availableStickers.count)
                for i in 0 ..< wrappingCount {
                    if let sticker = availableStickers[i].view {
                        let face: Int
                        if isClockwise {
                            face = i + 1
                        } else {
                            face = 3 - i
                        }
                        self.animationView.setSticker(sticker, face: face, mirror: isUpsideDown, animated: true)
                    }
                }
                
                self.flipFaces = isUpsideDown
            
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let _ = self.successFace.update(
                    transition: .immediate,
                    component: AnyComponent(
                        GiftItemComponent(
                            context: component.context,
                            style: .glass,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            peer: nil,
                            subject: .uniqueGift(gift: gift, price: nil),
                            ribbon: nil,
                            resellPrice: nil,
                            isHidden: false,
                            isSelected: false,
                            isPinned: false,
                            isEditing: false,
                            mode: .grid,
                            cornerRadius: 28.0,
                            action: nil,
                            contextAction: nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: cubeSide, height: cubeSide)
                )
                if let successView = self.successFace.view as? GiftItemComponent.View {
                    let backgroundLayer = successView.backgroundLayer
                    if let patternView = successView.pattern {
                        backgroundLayer.opacity = 0.0
                        patternView.alpha = 0.0
                        Queue.mainQueue().after(1.0, {
                            let transition = ComponentTransition.easeInOut(duration: 0.3)
                            
                            transition.animateBlur(layer: backgroundLayer, fromRadius: 10.0, toRadius: 0.0)
                            transition.setAlpha(layer: backgroundLayer, alpha: 1.0)
                            
                            transition.setAlpha(view: patternView, alpha: 1.0)
                            transition.animateBlur(layer: patternView.layer, fromRadius: 10.0, toRadius: 0.0)
                            
                            Queue.mainQueue().after(1.0, {
                                self.component?.finished(successView)
                            })
                        })
                    }
                    
                    self.animationView.setSticker(successView, face: 0, mirror: isUpsideDown)
                }
                self.state?.updated()
            }
        }
        
        func update(component: CraftTableComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.animationView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            
            let permilleValue = component.gifts.reduce(0, { $0 + Int($1.value.gift.craftChancePermille ?? 0) })
            
            for index in 0 ..< 6 {
                let face: ComponentView<Empty>
                if let current = self.faces[index] {
                    face = current
                } else {
                    face = ComponentView<Empty>()
                    self.faces[index] = face
                }
                
                let faceComponent: AnyComponent<Empty>
                var faceItems: [AnyComponentWithIdentity<Empty>] = []
                if index == 0 {
                    faceItems.append(
                        AnyComponentWithIdentity(id: "background", component: AnyComponent(
                            CubeFaceComponent(color: component.buttonColor, cornerRadius: 28.0)
                        ))
                    )
                    if !component.isCrafting || self.isFailed {
                        faceItems.append(
                            AnyComponentWithIdentity(id: "glass", component: AnyComponent(
                                GlassBackgroundComponent(size: CGSize(width: cubeSide, height: cubeSide), cornerRadius: 28.0, isDark: true, tintColor: .init(kind: .custom(style: .default, color: component.buttonColor)))
                            ))
                        )
                    }
                    if self.isFailed {
                        faceItems.append(
                            AnyComponentWithIdentity(id: "faildial", component: AnyComponent(
                                DialIndicatorComponent(
                                    content: AnyComponentWithIdentity(id: "gift", component: AnyComponent(
                                        LottieComponent(
                                            content: LottieComponent.AppBundleContent(name: "CraftFail"),
                                            color: .white,
                                            size: CGSize(width: 52.0, height: 52.0),
                                            playOnce: self.craftFailPlayOnce
                                        )
                                    )),
                                    backgroundColor: .white.withAlphaComponent(0.1),
                                    foregroundColor: .white,
                                    diameter: 84.0,
                                    contentSize: CGSize(width: 44.0, height: 44.0),
                                    lineWidth: 5.0,
                                    fontSize: 18.0,
                                    progress: 0.0,
                                    value: component.gifts.count,
                                    suffix: "",
                                    isVisible: true,
                                    isFlipped: self.flipFaces
                                )
                            ))
                        )
                    } else if !self.isSuccess {
                        faceItems.append(
                            AnyComponentWithIdentity(id: "dial", component: AnyComponent(
                                DialIndicatorComponent(
                                    content: AnyComponentWithIdentity(id: "empty", component: AnyComponent(Rectangle(color: .clear))),
                                    backgroundColor: .white.withAlphaComponent(0.1),
                                    foregroundColor: .white,
                                    diameter: 84.0,
                                    lineWidth: 5.0,
                                    fontSize: 18.0,
                                    progress: CGFloat(permilleValue) / 10.0 / 100.0,
                                    value: permilleValue / 10,
                                    suffix: "%",
                                    isVisible: !component.isCrafting
                                )
                            ))
                        )
                        faceItems.append(
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                LottieComponent(
                                    content: LottieComponent.AppBundleContent(name: "Anvil"),
                                    size: CGSize(width: 52.0, height: 52.0),
                                    playOnce: self.anvilPlayOnce
                                )
                            ))
                        )
                    }
                } else {
                    faceItems.append(
                        AnyComponentWithIdentity(id: "background", component: AnyComponent(
                            CubeFaceComponent(color: component.buttonColor, cornerRadius: 28.0)
                        ))
                    )
                    faceItems.append(
                        AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                            BundleIconComponent(name: "Components/CubeSide", tintColor: nil, flipVertically: index < 4 ? self.flipFaces : false)
                        ))
                    )
                }
                faceComponent = AnyComponent(
                    ZStack(faceItems)
                )
                 
                let _ = face.update(
                    transition: transition,
                    component: faceComponent,
                    environment: {},
                    containerSize: CGSize(width: cubeSide, height: cubeSide)
                )
            }
            
            if previousComponent == nil {
                var faceViews: [UIView] = []
                for index in 0 ..< 6 {
                    if let faceView = self.faces[index]?.view {
                        faceView.bounds = CGRect(origin: .zero, size: CGSize(width: cubeSide, height: cubeSide))
                        faceView.clipsToBounds = true
                        faceView.layer.rasterizationScale = UIScreenScale
                        faceView.layer.cornerRadius = 28.0
                        faceViews.append(faceView)
                    }
                }
                self.animationView.setFaces(faceViews)
            }
            
            var stickerViews: [UIView] = []
            for index in 0 ..< 4 {
                let itemId = AnyHashable(index)
                
                var itemTransition = transition
                let visibleItem: ComponentView<Empty>
                if let current = self.selectedGifts[itemId] {
                    visibleItem = current
                } else {
                    visibleItem = ComponentView()
                    self.selectedGifts[itemId] = visibleItem
                    itemTransition = .immediate
                }
                
                let gift = component.gifts[Int32(index)]
                
                let _ = visibleItem.update(
                    transition: itemTransition,
                    component: AnyComponent(
                        GiftSlotComponent(
                            context: component.context,
                            gift: gift,
                            buttonColor: component.buttonColor,
                            isCrafting: component.isCrafting,
                            action: {
                                component.select(Int32(index))
                            },
                            removeAction: index > 0 ? {
                                component.remove(Int32(index))
                            } : nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: cubeSide, height: cubeSide)
                )
                if let itemView = visibleItem.view {
                    stickerViews.append(itemView)
                }
            }
            
            if previousComponent == nil {
                self.animationView.setStickers(stickerViews)
            }
            
            if let previousComponent, previousComponent.isCrafting != component.isCrafting {
                var indices: [Int] = []
                for index in component.gifts.keys.sorted() {
                    indices.append(Int(index))
                }
                
                Queue.mainQueue().after(0.55) {
                    HapticFeedback().impact(.light)
                }
                
                self.anvilPlayOnce.invoke(Void())
                Queue.mainQueue().after(0.75, {
                    self.animationView.startStickerSequence(indices: indices)
                    
                    switch component.result {
                    case let .gift(gift):
                        if case let .unique(uniqueGift) = gift.gift {
                            self.setupSuccessAnimation(uniqueGift)
                        }
                    case .fail:
                        self.setupFailureAnimation()
                    default:
                        break
                    }
                })
            }
                        
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


final class GiftSlotComponent: Component {
    let context: AccountContext
    let gift: GiftItem?
    let buttonColor: UIColor
    let isCrafting: Bool
    let action: () -> Void
    let removeAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        gift: GiftItem?,
        buttonColor: UIColor,
        isCrafting: Bool,
        action: @escaping () -> Void,
        removeAction: (() -> Void)?
    ) {
        self.context = context
        self.gift = gift
        self.buttonColor = buttonColor
        self.isCrafting = isCrafting
        self.action = action
        self.removeAction = removeAction
    }

    public static func ==(lhs: GiftSlotComponent, rhs: GiftSlotComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.buttonColor != rhs.buttonColor {
            return false
        }
        if lhs.isCrafting != rhs.isCrafting {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let addIcon = UIImageView()
        private var icon: ComponentView<Empty>?
        private let button = HighlightTrackingButton()
        
        private var badge: ComponentView<Empty>?
        private var removeIcon: ComponentView<Empty>?
        private let removeButton = HighlightTrackingButton()
        
        private var component: GiftSlotComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.addIcon.image = generateAddIcon(backgroundColor: .white)

            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.addIcon)
            self.backgroundView.contentView.addSubview(self.button)
            self.addSubview(self.removeButton)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            self.removeButton.addTarget(self, action: #selector(self.removeButtonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            guard let _ = self.component?.removeAction else {
                return
            }
            self.component?.action()
        }
        
        @objc private func removeButtonPressed() {
            self.component?.removeAction?()
        }
        
        func update(component: GiftSlotComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let backgroundFrame = CGRect(origin: .zero, size: availableSize).insetBy(dx: 1.0, dy: 1.0)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: 28.0, isDark: true, tintColor: .init(kind: .custom(style: .default, color: component.buttonColor)), isInteractive: true, transition: .immediate)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            if component.gift == nil && component.isCrafting && previousComponent?.isCrafting == false {
                transition.setBlur(layer: self.backgroundView.layer, radius: 10.0)
                self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)
                transition.setBlur(layer: self.addIcon.layer, radius: 10.0)
            }
            transition.setAlpha(view: self.addIcon, alpha: component.isCrafting ? 0.0 : 1.0)
            
            if let icon = self.addIcon.image {
                transition.setFrame(view: self.addIcon, frame: CGRect(origin: CGPoint(x: floor((backgroundFrame.width - icon.size.width) / 2.0), y: floor((backgroundFrame.height - icon.size.height) / 2.0)), size: icon.size))
            }
            
            if previousComponent?.gift?.gift.id != component.gift?.gift.id {
                if let iconView = self.icon?.view {
                    if transition.animation.isImmediate {
                        iconView.removeFromSuperview()
                    } else {
                        transition.setScale(view: iconView, scale: 0.01)
                        transition.setAlpha(view: iconView, alpha: 0.0, completion: { _ in
                            iconView.removeFromSuperview()
                        })
                    }
                }
                self.icon = nil
            }
            
            if (previousComponent?.gift?.gift.id == nil) != (component.gift?.gift.id == nil) || ((previousComponent?.isCrafting ?? false) != component.isCrafting && component.isCrafting) {
                if let badgeView = self.badge?.view {
                    if transition.animation.isImmediate {
                        badgeView.removeFromSuperview()
                    } else {
                        transition.setBlur(layer: badgeView.layer, radius: 10.0)
                        transition.setAlpha(view: badgeView, alpha: 0.0, completion: { _ in
                            badgeView.removeFromSuperview()
                        })
                    }
                }
                self.badge = nil
                
                if let removeButtonView = self.removeIcon?.view {
                    if transition.animation.isImmediate {
                        removeButtonView.removeFromSuperview()
                    } else {
                        transition.setBlur(layer: removeButtonView.layer, radius: 10.0)
                        transition.setAlpha(view: removeButtonView, alpha: 0.0, completion: { _ in
                            removeButtonView.removeFromSuperview()
                        })
                    }
                }
                self.removeIcon = nil
            }
            
            if let gift = component.gift {
                let icon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.icon {
                    icon = current
                } else {
                    iconTransition = .immediate
                    icon = ComponentView()
                    self.icon = icon
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let iconSize = icon.update(
                    transition: iconTransition,
                    component: AnyComponent(
                        GiftItemComponent(
                            context: component.context,
                            style: .glass,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            peer: nil,
                            subject: .uniqueGift(gift: gift.gift, price: nil),
                            ribbon: nil,
                            resellPrice: nil,
                            isHidden: false,
                            isSelected: false,
                            isPinned: false,
                            isEditing: false,
                            mode: .grid,
                            cornerRadius: 28.0,
                            action: nil,
                            contextAction: nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: iconSize)
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        if let badgeView = self.badge?.view {
                            self.backgroundView.contentView.insertSubview(iconView, belowSubview: badgeView)
                        } else {
                            self.backgroundView.contentView.addSubview(iconView)
                        }
                        
                        if !transition.animation.isImmediate {
                            transition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                            transition.animateScale(view: iconView, from: 0.01, to: 1.0)
                        }
                    }
                    iconTransition.setFrame(view: iconView, frame: iconFrame)
                }
                
                if !component.isCrafting {
                    var buttonColor: UIColor = component.buttonColor
                    if let backdropAttribute = gift.gift.attributes.first(where: { attribute in
                        if case .backdrop = attribute {
                            return true
                        } else {
                            return false
                        }
                    }), case let .backdrop(_, _, innerColor, _, _, _, _) = backdropAttribute {
                        buttonColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultipliedBrightnessBy(0.65)
                    }
                    
                    let badge: ComponentView<Empty>
                    var badgeTransition = transition
                    if let current = self.badge {
                        badge = current
                    } else {
                        badgeTransition = .immediate
                        badge = ComponentView()
                        self.badge = badge
                    }
                    
                    let badgeSize = badge.update(
                        transition: badgeTransition,
                        component: AnyComponent(
                            ZStack([
                                AnyComponentWithIdentity(id: "background", component: AnyComponent(
                                    RoundedRectangle(color: buttonColor, cornerRadius: 13.5, size: CGSize(width: 54.0, height: 27.0))
                                )),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    Text(text: "\((gift.gift.craftChancePermille ?? 0) / 10)%", font: Font.semibold(17.0), color: .white)
                                ))
                            ])
                        ),
                        environment: {},
                        containerSize: CGSize(width: 54.0, height: 27.0)
                    )
                    let badgeFrame = CGRect(origin: CGPoint(x: -6.0, y: -6.0 - UIScreenPixel), size: badgeSize)
                    if let badgeView = badge.view {
                        if badgeView.superview == nil {
                            badgeView.isUserInteractionEnabled = false
                            self.backgroundView.contentView.addSubview(badgeView)
                            
                            if !transition.animation.isImmediate {
                                transition.animateAlpha(view: badgeView, from: 0.0, to: 1.0)
                                transition.animateScale(view: badgeView, from: 0.01, to: 1.0)
                            }
                        }
                        badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                    }
                    
                    
                    if let _ = component.removeAction {
                        let removeButton: ComponentView<Empty>
                        var removeButtonTransition = transition
                        if let current = self.removeIcon {
                            removeButton = current
                        } else {
                            removeButtonTransition = .immediate
                            removeButton = ComponentView()
                            self.removeIcon = removeButton
                        }
                        
                        let removeButtonSize = removeButton.update(
                            transition: removeButtonTransition,
                            component: AnyComponent(
                                ZStack([
                                    AnyComponentWithIdentity(id: "background", component: AnyComponent(
                                        RoundedRectangle(color: buttonColor, cornerRadius: 13.5, size: CGSize(width: 27.0, height: 27.0))
                                    )),
                                    AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                        BundleIconComponent(name: "Media Gallery/PictureInPictureClose", tintColor: .white)
                                    ))
                                ])
                            ),
                            environment: {},
                            containerSize: CGSize(width: 27.0, height: 27.0)
                        )
                        let removeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - 21.0, y: -6.0 - UIScreenPixel), size: removeButtonSize)
                        if let removeButtonView = removeButton.view {
                            if removeButtonView.superview == nil {
                                removeButtonView.isUserInteractionEnabled = false
                                self.backgroundView.contentView.addSubview(removeButtonView)
                                
                                if !transition.animation.isImmediate {
                                    transition.animateAlpha(view: removeButtonView, from: 0.0, to: 1.0)
                                    transition.animateScale(view: removeButtonView, from: 0.01, to: 1.0)
                                }
                            }
                            removeButtonTransition.setFrame(view: removeButtonView, frame: removeButtonFrame)
                        }
                    }
                }
            }
            
            self.isUserInteractionEnabled = !component.isCrafting
            self.button.frame = CGRect(origin: .zero, size: availableSize)
            
            self.removeButton.isUserInteractionEnabled = component.removeAction != nil
            if let removeIcon = self.removeIcon?.view {
                self.removeButton.frame = removeIcon.frame.insetBy(dx: -8.0, dy: -8.0)
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateAddIcon(backgroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 46.0, height: 46.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        context.setBlendMode(.clear)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)
        
        context.move(to: CGPoint(x: 23.0, y: 13.0))
        context.addLine(to: CGPoint(x: 23.0, y: 33.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 13.0, y: 23.0))
        context.addLine(to: CGPoint(x: 33.0, y: 23.0))
        context.strokePath()
    })
}

private final class CubeFaceComponent: Component {
    private let color: UIColor
    private let cornerRadius: CGFloat
    
    public init(color: UIColor, cornerRadius: CGFloat) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    public static func ==(lhs: CubeFaceComponent, rhs: CubeFaceComponent) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        override public init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerCurve = .continuous
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        transition.setBackgroundColor(view: view, color: self.color)
        transition.setCornerRadius(layer: view.layer, cornerRadius: self.cornerRadius)
    
        return availableSize
    }
}
