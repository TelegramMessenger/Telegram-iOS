import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import AnimatedTextComponent
import MultilineTextComponent
import LottieComponent

final class ProfileLevelRatingBarBadge: Component {
    final class TransitionHint {
        let animateText: Bool
        
        init(animateText: Bool) {
            self.animateText = animateText
        }
    }
    
    enum Icon {
        case rating
        case stars
    }
    
    let theme: PresentationTheme
    let title: String
    let suffix: String?
    let icon: Icon
    
    init(
        theme: PresentationTheme,
        title: String,
        suffix: String?,
        icon: Icon
    ) {
        self.theme = theme
        self.title = title
        self.suffix = suffix
        self.icon = icon
    }
    
    static func ==(lhs: ProfileLevelRatingBarBadge, rhs: ProfileLevelRatingBarBadge) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.suffix != rhs.suffix {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeView: UIImageView
        private let badgeShapeAnimation = ComponentView<Empty>()
        
        private let badgeForeground: SimpleLayer
        private let badgeIcon: UIImageView
        private var disappearingBadgeIcon: UIImageView?
        private let badgeLabel = ComponentView<Empty>()
        private let suffixLabel = ComponentView<Empty>()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private var component: ProfileLevelRatingBarBadge?
        private var isUpdating: Bool = false
        
        private var previousAvailableSize: CGSize?
        
        override init(frame: CGRect) {
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            self.badgeView.layer.anchorPoint = CGPoint()
            
            self.badgeShapeView = UIImageView()
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.addSubview(self.badgeShapeView)
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
            self.badgeForeground.anchorPoint = CGPoint()
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
            
            super.init(frame: frame)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            
            self.isUserInteractionEnabled = false
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.badgeView.frame.contains(point) {
                return self
            } else {
                return nil
            }
        }
                
        func update(component: ProfileLevelRatingBarBadge, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var labelsTransition = transition
            if let hint = transition.userData(TransitionHint.self), hint.animateText {
                labelsTransition = .spring(duration: 0.5)
            }
            
            let previousComponent = self.component
            if previousComponent == nil || (previousComponent?.title == "") != (component.title == "") {
                if !labelsTransition.animation.isImmediate, self.badgeIcon.image != nil {
                    if let disappearingBadgeIcon = self.disappearingBadgeIcon {
                        self.disappearingBadgeIcon = nil
                        disappearingBadgeIcon.removeFromSuperview()
                    }
                    let disappearingBadgeIcon = UIImageView()
                    disappearingBadgeIcon.contentMode = self.badgeIcon.contentMode
                    disappearingBadgeIcon.frame = self.badgeIcon.frame
                    disappearingBadgeIcon.image = self.badgeIcon.image
                    disappearingBadgeIcon.tintColor = self.badgeIcon.tintColor
                    
                    self.badgeView.insertSubview(disappearingBadgeIcon, aboveSubview: self.badgeIcon)
                    labelsTransition.setScale(view: disappearingBadgeIcon, scale: 0.001)
                    labelsTransition.setAlpha(view: disappearingBadgeIcon, alpha: 0.0, completion: { [weak self, weak disappearingBadgeIcon] _ in
                        guard let self, let disappearingBadgeIcon else {
                            return
                        }
                        disappearingBadgeIcon.removeFromSuperview()
                        if self.disappearingBadgeIcon === disappearingBadgeIcon {
                            self.disappearingBadgeIcon = nil
                        }
                    })
                    labelsTransition.animateScale(view: self.badgeIcon, from: 0.001, to: 1.0)
                    labelsTransition.animateAlpha(view: self.badgeIcon, from: 0.0, to: 1.0)
                }
                
                switch component.icon {
                case .rating:
                    if component.title.isEmpty {
                        self.badgeIcon.image = UIImage(bundleImageName: "Peer Info/ProfileLevelWarningIcon")?.withRenderingMode(.alwaysTemplate)
                    } else {
                        self.badgeIcon.image = UIImage(bundleImageName: "Peer Info/ProfileLevelProgressIcon")?.withRenderingMode(.alwaysTemplate)
                    }
                case .stars:
                    self.badgeIcon.image = UIImage(bundleImageName: "Premium/SendStarsStarSliderIcon")?.withRenderingMode(.alwaysTemplate)
                }
            }
             
            self.component = component
            self.badgeIcon.tintColor = component.theme.list.itemCheckColors.foregroundColor
            self.disappearingBadgeIcon?.tintColor = component.theme.list.itemCheckColors.foregroundColor
            
            let badgeLabelSize = self.badgeLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []),
                    color: component.theme.list.itemCheckColors.foregroundColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.title)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            
            let badgeSuffixSpacing: CGFloat = 0.0
            
            let badgeSuffixSize = self.suffixLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(22.0),
                    color: component.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.6),
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.suffix ?? "")
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            
            var badgeWidth: CGFloat = 0.0
            if !component.title.isEmpty {
                badgeWidth += badgeLabelSize.width + 3.0 + 60.0
            } else {
                badgeWidth += 78.0
            }
            if component.suffix != nil {
                badgeWidth += badgeSuffixSize.width + badgeSuffixSpacing
            }
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 600.0, height: badgeFullSize.height + 10.0))
    
            let badgeIconFrame: CGRect
            if !component.title.isEmpty {
                badgeIconFrame = CGRect(x: 13.0, y: 8.0, width: 30.0, height: 30.0)
            } else {
                badgeIconFrame = CGRect(x: floor((badgeWidth - 30.0) * 0.5), y: 8.0, width: 30.0, height: 30.0)
            }
            labelsTransition.setFrame(view: self.badgeIcon, frame: badgeIconFrame)
            if let disappearingBadgeIcon = self.disappearingBadgeIcon {
                labelsTransition.setFrame(view: disappearingBadgeIcon, frame: badgeIconFrame)
            }
            
            self.badgeView.alpha = 1.0
            
            let size = badgeSize
            
            var badgeContentWidth: CGFloat = badgeLabelSize.width
            if component.suffix != nil {
                badgeContentWidth += badgeSuffixSpacing + badgeSuffixSize.width
            }
            
            let badgeLabelFrame = CGRect(origin: CGPoint(x: 15.0 + floorToScreenPixels((badgeFullSize.width - badgeContentWidth) / 2.0), y: 9.0), size: badgeLabelSize)
            if let badgeLabelView = self.badgeLabel.view {
                if badgeLabelView.superview == nil {
                    self.badgeView.addSubview(badgeLabelView)
                }
                labelsTransition.setFrame(view: badgeLabelView, frame: badgeLabelFrame)
            }
            if let suffixLabelView = self.suffixLabel.view {
                if suffixLabelView.superview == nil {
                    suffixLabelView.layer.anchorPoint = CGPoint()
                    self.badgeView.addSubview(suffixLabelView)
                }
                let badgeSuffixFrame = CGRect(origin: CGPoint(x: badgeLabelFrame.maxX + badgeSuffixSpacing, y: badgeLabelFrame.maxY - badgeSuffixSize.height), size: badgeSuffixSize)
                labelsTransition.setPosition(view: suffixLabelView, position: badgeSuffixFrame.origin)
                suffixLabelView.bounds = CGRect(origin: CGPoint(), size: badgeSuffixFrame.size)
            }
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
            }
            
            return size
        }
        
        func updateColors(background: UIColor) {
            self.badgeForeground.backgroundColor = background.cgColor
        }
        
        func adjustTail(size: CGSize, tailOffset: CGFloat, transition: ComponentTransition) {
            if self.badgeShapeView.image == nil {
                self.badgeShapeView.image = generateStretchableFilledCircleImage(diameter: 48.0, color: UIColor.white)
            }
            self.badgeShapeView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 48.0))
            
            let badgeShapeSize = CGSize(width: 78, height: 60)
            let _ = self.badgeShapeAnimation.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "badge_with_tail"),
                    color: .white,
                    placeholderColor: nil,
                    startingPosition: .begin,
                    size: badgeShapeSize,
                    renderingScale: UIScreenScale,
                    loop: false,
                    playOnce: nil
                )),
                environment: {},
                containerSize: badgeShapeSize
            )
            if let badgeShapeAnimationView = self.badgeShapeAnimation.view as? LottieComponent.View {
                if badgeShapeAnimationView.superview == nil {
                    badgeShapeAnimationView.layer.anchorPoint = CGPoint()
                    self.badgeMaskView.addSubview(badgeShapeAnimationView)
                }
                
                var shapeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: badgeShapeSize)
                
                let badgeShapeWidth = badgeShapeSize.width
                
                let midFrame = 359 / 2
                if tailOffset < badgeShapeWidth * 0.5 {
                    let frameIndex = Int(floor(CGFloat(midFrame) * tailOffset / (badgeShapeWidth * 0.5)))
                    badgeShapeAnimationView.setFrameIndex(index: frameIndex)
                } else if tailOffset >= size.width - badgeShapeWidth * 0.5 {
                    let endOffset = tailOffset - (size.width - badgeShapeWidth * 0.5)
                    let frameIndex = midFrame + Int(floor(CGFloat(359 - midFrame) * endOffset / (badgeShapeWidth * 0.5)))
                    badgeShapeAnimationView.setFrameIndex(index: frameIndex)
                    shapeFrame.origin.x = size.width - badgeShapeWidth
                } else {
                    badgeShapeAnimationView.setFrameIndex(index: midFrame)
                    shapeFrame.origin.x = tailOffset - badgeShapeWidth * 0.5
                }
                
                badgeShapeAnimationView.center = shapeFrame.origin
                badgeShapeAnimationView.bounds = CGRect(origin: CGPoint(), size: shapeFrame.size)
            }
            
            //let transition: ContainedViewLayoutTransition = .immediate
            //transition.updateAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: tailPositionFraction, y: 1.0))
        }
        
        func updateBadgeAngle(angle: CGFloat) {
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: self.badgeView, angle: angle)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
