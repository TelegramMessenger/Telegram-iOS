import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import AvatarComponent
import MultilineTextComponent
import GlassBackgroundComponent
import NewsFeedSupport

/// A pressable area: dims and shrinks a little while pressed (Feed3 `PressScale`).
private final class NewsFeedbackPressableView: UIControl {
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != self.isHighlighted else {
                return
            }
            let highlighted = self.isHighlighted
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.alpha = highlighted ? 0.8 : 1.0
                self.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            })
        }
    }

    @objc private func pressed() {
        self.action?()
    }
}

/// Removes a settled blur, so the panel stops rendering offscreen.
private final class NewsFeedbackBlurCleanup: NSObject, CAAnimationDelegate {
    private weak var layer: CALayer?

    init(layer: CALayer) {
        self.layer = layer
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            self.layer?.filters = nil
        }
    }
}

private func newsFeedbackSymbol(_ name: String, size: CGFloat) -> UIImage? {
    return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))?.withRenderingMode(.alwaysTemplate)
}

/// The "Post hidden. Tell us more?" panel that takes a post's place after Not Interested (spec §4). Its choices are
/// inert: the screen's flow only hides things locally.
public final class NewsPostFeedbackPanelComponent: Component {
    public enum Tab: Equatable {
        case forYou
        case added
    }

    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let peer: EnginePeer
    public let tab: Tab
    public let phase: NewsPostFeedbackPhase
    /// Leaving (after Undo or after the confirmation): the card fades out in place.
    public let fading: Bool
    /// When Not Interested put the panel in: a panel created right after plays its appear.
    public let appearTime: Double?
    /// Under Reduce Motion the panel fades and unblurs without scaling.
    public let reduceMotion: Bool
    public let undo: () -> Void
    public let choose: (NewsPostFeedbackChoice) -> Void

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EnginePeer, tab: Tab, phase: NewsPostFeedbackPhase, fading: Bool, appearTime: Double?, reduceMotion: Bool, undo: @escaping () -> Void, choose: @escaping (NewsPostFeedbackChoice) -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.tab = tab
        self.phase = phase
        self.fading = fading
        self.appearTime = appearTime
        self.reduceMotion = reduceMotion
        self.undo = undo
        self.choose = choose
    }

    public static func ==(lhs: NewsPostFeedbackPanelComponent, rhs: NewsPostFeedbackPanelComponent) -> Bool {
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
        if lhs.tab != rhs.tab {
            return false
        }
        if lhs.phase != rhs.phase {
            return false
        }
        if lhs.fading != rhs.fading {
            return false
        }
        if lhs.appearTime != rhs.appearTime {
            return false
        }
        if lhs.reduceMotion != rhs.reduceMotion {
            return false
        }
        return true
    }

    /// The choices the tab offers, top to bottom.
    static func choices(tab: Tab) -> [NewsPostFeedbackChoice] {
        switch tab {
        case .forYou:
            return [.hideChannel, .fewerLikeThis]
        case .added:
            return [.removeChannelFromNews]
        }
    }

    public final class View: UIView {
        /// The glass card. Placed by bounds and center: its layer scales on appear.
        private let cardView = UIView()
        private let backgroundView = GlassBackgroundView()
        /// The header and the choices; blurs and fades out when a choice is made.
        private let askingView = UIView()
        /// The confirmation, in the same card.
        private let doneView = UIView()
        private let headerIconView = UIImageView()
        private let headerTitle = ComponentView<Empty>()
        private let undoButton = NewsFeedbackPressableView()
        private let undoTitle = ComponentView<Empty>()
        private var choiceButtons: [NewsFeedbackPressableView] = []
        private var choiceIconViews: [UIImageView] = []
        private var choiceTitles: [ComponentView<Empty>] = []
        private let avatar = ComponentView<Empty>()
        private let checkmarkView = UIImageView()
        private let confirmationText = ComponentView<Empty>()
        private var component: NewsPostFeedbackPanelComponent?
        private var isFadedOut = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.cardView)
            self.cardView.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.askingView)
            self.backgroundView.contentView.addSubview(self.doneView)
            self.headerIconView.image = newsFeedbackSymbol("eye.slash.fill", size: 15.0)
            self.headerIconView.contentMode = .center
            self.askingView.addSubview(self.headerIconView)
            self.askingView.addSubview(self.undoButton)
            self.checkmarkView.image = newsFeedbackSymbol("checkmark.circle.fill", size: 26.0)
            self.checkmarkView.contentMode = .center
            self.doneView.addSubview(self.checkmarkView)
            self.doneView.alpha = 0.0
            self.doneView.isUserInteractionEnabled = false
            self.undoButton.action = { [weak self] in
                self?.component?.undo()
            }
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: NewsPostFeedbackPanelComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previous = self.component
            self.component = component
            let theme = component.theme
            let strings = component.strings
            let channelTitle = component.peer.compactDisplayTitle
            let choices = NewsPostFeedbackPanelComponent.choices(tab: component.tab)

            // Feed3 `FeedbackPanel`: card inset 16/8, padding 12, header 4 pt in, choices 42 tall and 8 apart.
            let cardWidth = max(1.0, availableSize.width - 32.0)
            let padding: CGFloat = 12.0
            let headerInset: CGFloat = 4.0
            let spacing: CGFloat = 8.0
            let choiceHeight: CGFloat = 42.0

            // Header: icon, title, Undo.
            self.headerIconView.tintColor = theme.list.itemSecondaryTextColor
            let iconSize = self.headerIconView.image?.size ?? CGSize(width: 18.0, height: 15.0)
            let undoSize = self.undoTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Undo_Undo, font: Font.semibold(15.0), textColor: theme.list.itemAccentColor)))),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: 100.0)
            )
            let titleWidth = max(1.0, cardWidth - padding * 2.0 - headerInset * 2.0 - iconSize.width - spacing * 2.0 - undoSize.width)
            let titleSize = self.headerTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.News_Feedback_Hidden, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)), maximumNumberOfLines: 1)),
                environment: {},
                containerSize: CGSize(width: titleWidth, height: 100.0)
            )
            let headerHeight = max(20.0, titleSize.height, undoSize.height)
            let headerMinX = padding + headerInset
            self.headerIconView.frame = CGRect(x: headerMinX, y: padding + floor((headerHeight - iconSize.height) * 0.5), width: iconSize.width, height: iconSize.height)
            if let view = self.headerTitle.view {
                if view.superview == nil {
                    self.askingView.addSubview(view)
                }
                view.frame = CGRect(x: headerMinX + iconSize.width + spacing, y: padding + floor((headerHeight - titleSize.height) * 0.5), width: titleSize.width, height: titleSize.height)
                view.isAccessibilityElement = true
                view.accessibilityLabel = strings.News_Feedback_Hidden
                view.accessibilityTraits = .header
            }
            // The Undo hit area reaches 8 pt around its title.
            let undoFrame = CGRect(x: cardWidth - padding - headerInset - undoSize.width, y: padding + floor((headerHeight - undoSize.height) * 0.5), width: undoSize.width, height: undoSize.height).insetBy(dx: -8.0, dy: -8.0)
            self.undoButton.bounds = CGRect(origin: CGPoint(), size: undoFrame.size)
            self.undoButton.center = CGPoint(x: undoFrame.midX, y: undoFrame.midY)
            self.undoButton.accessibilityLabel = strings.Undo_Undo
            if let view = self.undoTitle.view {
                if view.superview == nil {
                    view.isUserInteractionEnabled = false
                    self.undoButton.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: undoSize)
            }

            // Choices.
            while self.choiceButtons.count < choices.count {
                let button = NewsFeedbackPressableView()
                button.layer.cornerRadius = 14.0
                button.layer.cornerCurve = .continuous
                let iconView = UIImageView()
                iconView.contentMode = .center
                iconView.isUserInteractionEnabled = false
                button.addSubview(iconView)
                self.askingView.addSubview(button)
                self.choiceButtons.append(button)
                self.choiceIconViews.append(iconView)
                self.choiceTitles.append(ComponentView<Empty>())
            }
            var y = padding + headerHeight + spacing
            for (index, choice) in choices.enumerated() {
                let button = self.choiceButtons[index]
                let iconView = self.choiceIconViews[index]
                let title: String
                var titleColor = theme.list.itemPrimaryTextColor
                var icon: UIImage?
                var iconColor = theme.list.itemSecondaryTextColor
                switch choice {
                case .hideChannel:
                    title = strings.News_Feedback_HideChannel(channelTitle).string
                case .fewerLikeThis:
                    title = strings.News_Feedback_FewerLikeThis
                    icon = newsFeedbackSymbol("hand.thumbsdown", size: 17.0)
                case .removeChannelFromNews:
                    title = strings.News_Feedback_RemoveFromNews(channelTitle).string
                    titleColor = theme.list.itemDestructiveColor
                    icon = newsFeedbackSymbol("minus.circle", size: 17.0)
                    iconColor = theme.list.itemDestructiveColor
                }
                let frame = CGRect(x: padding, y: y, width: cardWidth - padding * 2.0, height: choiceHeight)
                button.bounds = CGRect(origin: CGPoint(), size: frame.size)
                button.center = CGPoint(x: frame.midX, y: frame.midY)
                button.backgroundColor = theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.045)
                button.accessibilityLabel = title
                button.action = { [weak self] in
                    self?.component?.choose(choice)
                }
                let iconFrame = CGRect(x: 12.0, y: floor((choiceHeight - 24.0) * 0.5), width: 24.0, height: 24.0)
                if choice == .hideChannel {
                    iconView.isHidden = true
                    let avatarSize = CGSize(width: 22.0, height: 22.0)
                    let _ = self.avatar.update(
                        transition: .immediate,
                        component: AnyComponent(AvatarComponent(context: component.context, theme: theme, peer: component.peer, size: avatarSize, synchronousLoad: false)),
                        environment: {},
                        containerSize: avatarSize
                    )
                    if let avatarView = self.avatar.view {
                        if avatarView.superview !== button {
                            avatarView.isUserInteractionEnabled = false
                            button.addSubview(avatarView)
                        }
                        avatarView.frame = CGRect(x: iconFrame.midX - avatarSize.width * 0.5, y: iconFrame.midY - avatarSize.height * 0.5, width: avatarSize.width, height: avatarSize.height)
                    }
                } else {
                    iconView.isHidden = false
                    iconView.image = icon
                    iconView.tintColor = iconColor
                    iconView.frame = iconFrame
                }
                let titleSize = self.choiceTitles[index].update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: title, font: Font.regular(15.0), textColor: titleColor)), maximumNumberOfLines: 1)),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, frame.width - 12.0 - 24.0 - 10.0 - 12.0), height: choiceHeight)
                )
                if let view = self.choiceTitles[index].view {
                    if view.superview == nil {
                        view.isUserInteractionEnabled = false
                        button.addSubview(view)
                    }
                    view.frame = CGRect(x: 12.0 + 24.0 + 10.0, y: floor((choiceHeight - titleSize.height) * 0.5), width: titleSize.width, height: titleSize.height)
                }
                y += choiceHeight + spacing
            }
            let cardHeight = y - spacing + padding

            // The confirmation, centred in the same card.
            var confirmation = ""
            if case let .done(choice) = component.phase {
                switch choice {
                case .hideChannel:
                    confirmation = strings.News_Feedback_Done_HideChannel(channelTitle).string
                case .fewerLikeThis:
                    confirmation = strings.News_Feedback_Done_FewerLikeThis
                case .removeChannelFromNews:
                    confirmation = strings.News_Feedback_Done_RemoveFromNews(channelTitle).string
                }
            }
            self.checkmarkView.tintColor = theme.list.itemDisclosureActions.constructive.fillColor
            let checkSize = self.checkmarkView.image?.size ?? CGSize(width: 26.0, height: 26.0)
            let confirmationSize = self.confirmationText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: confirmation, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.8))), horizontalAlignment: .center, maximumNumberOfLines: 2)),
                environment: {},
                containerSize: CGSize(width: max(1.0, cardWidth - 40.0), height: 100.0)
            )
            let blockHeight = checkSize.height + spacing + confirmationSize.height
            let blockY = floor((cardHeight - blockHeight) * 0.5)
            self.checkmarkView.frame = CGRect(x: floor((cardWidth - checkSize.width) * 0.5), y: blockY, width: checkSize.width, height: checkSize.height)
            if let view = self.confirmationText.view {
                if view.superview == nil {
                    self.doneView.addSubview(view)
                }
                view.frame = CGRect(x: floor((cardWidth - confirmationSize.width) * 0.5), y: blockY + checkSize.height + spacing, width: confirmationSize.width, height: confirmationSize.height)
                view.isAccessibilityElement = !confirmation.isEmpty
                view.accessibilityLabel = confirmation
            }

            let cardFrame = CGRect(x: 16.0, y: 8.0, width: cardWidth, height: cardHeight)
            self.cardView.bounds = CGRect(origin: CGPoint(), size: cardFrame.size)
            self.cardView.center = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
            self.backgroundView.frame = CGRect(origin: CGPoint(), size: cardFrame.size)
            self.backgroundView.update(size: cardFrame.size, cornerRadius: 24.0, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: .immediate)
            self.askingView.bounds = CGRect(origin: CGPoint(), size: cardFrame.size)
            self.askingView.center = CGPoint(x: cardFrame.width * 0.5, y: cardFrame.height * 0.5)
            self.doneView.bounds = CGRect(origin: CGPoint(), size: cardFrame.size)
            self.doneView.center = CGPoint(x: cardFrame.width * 0.5, y: cardFrame.height * 0.5)

            let isDone: Bool
            if case .done = component.phase {
                isDone = true
            } else {
                isDone = false
            }
            if let previous, previous.phase == .asking, isDone {
                self.playDone(scales: !component.reduceMotion)
            } else if previous == nil {
                self.askingView.alpha = isDone ? 0.0 : 1.0
                self.askingView.isUserInteractionEnabled = !isDone
                self.doneView.alpha = isDone ? 1.0 : 0.0
            }
            // VoiceOver reads only the half that shows.
            self.askingView.accessibilityElementsHidden = isDone
            self.doneView.accessibilityElementsHidden = !isDone
            if previous == nil, let appearTime = component.appearTime, NewsFeedbackTiming.playsAppear(appearTime: appearTime, now: CACurrentMediaTime()) {
                self.playAppear(appearTime: appearTime, scales: !component.reduceMotion)
            }
            self.updateFading(component.fading, animated: previous != nil)
            return CGSize(width: availableSize.width, height: cardHeight + 16.0)
        }

        /// The card lenses in after 0.08 s: opacity and scale on `NewsSpring.lens`, the content's blur clearing (spec §4).
        /// Under Reduce Motion it does not scale.
        private func playAppear(appearTime: Double, scales: Bool) {
            let delay = max(0.0, appearTime + NewsFeedbackTiming.appearDelay - CACurrentMediaTime())
            let lens = NewsSpring.lens
            self.cardView.layer.add(lens.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber, delay: delay), forKey: "newsFeedbackAppearAlpha")
            if scales {
                self.cardView.layer.add(lens.makeAnimation(keyPath: "transform.scale", from: 0.94 as NSNumber, to: 1.0 as NSNumber, delay: delay), forKey: "newsFeedbackAppearScale")
            }
            // The lens's bounce would take a blur below zero: the blur settles on the same duration without it.
            if let filter = CALayer.blur() {
                filter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                self.askingView.layer.filters = [filter]
                let blur = NewsSpring(duration: 0.5, bounce: 0.0).makeAnimation(keyPath: "filters.gaussianBlur.inputRadius", from: 6.0 as NSNumber, to: 0.0 as NSNumber, delay: delay)
                blur.delegate = NewsFeedbackBlurCleanup(layer: self.askingView.layer)
                self.askingView.layer.add(blur, forKey: "newsFeedbackAppearBlur")
            }
            // Not Interested took the focused row away: VoiceOver moves to the panel's title, once the row is in place.
            DispatchQueue.main.async { [weak self] in
                UIAccessibility.post(notification: .layoutChanged, argument: self?.headerTitle.view)
            }
        }

        /// A choice was made: the choices blur and fade out, the confirmation comes in from 0.92 (`NewsSpring.rows`).
        /// Under Reduce Motion nothing scales.
        private func playDone(scales: Bool) {
            let rows = NewsSpring.rows
            self.askingView.isUserInteractionEnabled = false
            self.askingView.alpha = 0.0
            self.askingView.layer.add(rows.makeAnimation(keyPath: "opacity", from: 1.0 as NSNumber, to: 0.0 as NSNumber), forKey: "newsFeedbackDoneAlpha")
            if let filter = CALayer.blur() {
                filter.setValue(6.0 as NSNumber, forKey: "inputRadius")
                self.askingView.layer.filters = [filter]
                self.askingView.layer.add(rows.makeAnimation(keyPath: "filters.gaussianBlur.inputRadius", from: 0.0 as NSNumber, to: 6.0 as NSNumber), forKey: "newsFeedbackDoneBlur")
            }
            self.doneView.alpha = 1.0
            self.doneView.layer.add(rows.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber), forKey: "newsFeedbackDoneInAlpha")
            if scales {
                self.doneView.layer.add(rows.makeAnimation(keyPath: "transform.scale", from: 0.92 as NSNumber, to: 1.0 as NSNumber), forKey: "newsFeedbackDoneInScale")
                // The mockup's `.symbolEffect(.bounce)`, as a pop on `Motion.pop` (`.spring(0.5, bounce 0.35)`): symbol
                // effects need the iOS 17 Symbols framework, above this app's floor.
                self.checkmarkView.layer.add(NewsSpring(duration: 0.5, bounce: 0.35).makeAnimation(keyPath: "transform.scale", from: 0.7 as NSNumber, to: 1.0 as NSNumber), forKey: "newsFeedbackDonePop")
            }
            // The chosen button is gone: VoiceOver moves to the confirmation and reads it.
            DispatchQueue.main.async { [weak self] in
                UIAccessibility.post(notification: .layoutChanged, argument: self?.confirmationText.view)
            }
        }

        /// Leaving: the card fades out in place over 0.16 s. A panel created already leaving (scrolled in mid-fade) is
        /// just faded (`animated`).
        private func updateFading(_ fading: Bool, animated: Bool) {
            guard fading != self.isFadedOut else {
                return
            }
            self.isFadedOut = fading
            if fading && !animated {
                self.cardView.alpha = 0.0
            } else if fading {
                // An appear still running (Undo right after Not Interested) would win back over the fade once it ends
                // (both drive opacity): the fade replaces it, from where it is.
                let layer = self.cardView.layer
                let from = CGFloat(layer.presentation()?.opacity ?? layer.opacity)
                layer.removeAnimation(forKey: "newsFeedbackAppearAlpha")
                layer.removeAnimation(forKey: "newsFeedbackAppearScale")
                self.askingView.layer.removeAnimation(forKey: "newsFeedbackAppearBlur")
                self.askingView.layer.filters = nil
                self.cardView.alpha = 0.0
                layer.animateAlpha(from: from, to: 0.0, duration: NewsFeedbackTiming.fadeOut, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            } else {
                self.cardView.alpha = 1.0
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
