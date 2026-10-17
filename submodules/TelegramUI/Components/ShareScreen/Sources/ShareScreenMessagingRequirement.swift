import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AppBundle

struct ShareScreenMessagingRequirement: Equatable {
    var requiresPremium: Bool = false
    var stars: StarsAmount?
}

// Use the same badge assets, typography and geometry as SelectablePeerNode in ShareController.
final class ShareScreenMessagingBadge: UIView {
    private let outline = UIImageView()
    private let background = UIImageView()
    private let label = ImmediateTextView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.addSubview(self.outline)
        self.addSubview(self.background)
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(requirement: ShareScreenMessagingRequirement, theme: PresentationTheme, avatarFrame: CGRect, selected: Bool, transition: ComponentTransition) {
        self.isHidden = !requirement.requiresPremium && (requirement.stars?.value ?? 0) <= 0
        guard !self.isHidden else { return }
        self.outline.tintColor = theme.list.modalPlainBackgroundColor
        if let stars = requirement.stars, stars.value > 0 {
            self.outline.image = PresentationResourcesChatList.shareAvatarStarsLockBadgeBackground(theme)
            self.background.image = PresentationResourcesChatList.shareAvatarStarsLockBadgeInnerBackground(theme)
            self.background.tintColor = theme.actionSheet.controlAccentColor
            self.label.isHidden = false
            let text = NSMutableAttributedString(string: "⭐️\(presentationStringsFormattedNumber(Int32(clamping: stars.value), " "))", font: Font.with(size: 9.0, design: .round, weight: .bold), textColor: theme.list.itemCheckColors.foregroundColor)
            let range = (text.string as NSString).range(of: "⭐️")
            if let image = UIImage(bundleImageName: "Premium/SendStarsPeerBadgeStarIcon") {
                text.addAttribute(.attachment, value: image, range: range)
                text.addAttribute(.baselineOffset, value: 1.5, range: range)
                text.addAttribute(.kern, value: -0.8, range: NSRange(location: 0, length: text.length))
            }
            self.label.attributedText = text
            let size = self.label.updateLayout(CGSize(width: 120.0, height: 20.0))
            let labelFrame = CGRect(x: floorToScreenPixels(avatarFrame.midX - size.width / 2.0) - (selected ? 15.0 : 0.0), y: avatarFrame.maxY - 13.0, width: size.width, height: size.height)
            let backgroundFrame = CGRect(x: labelFrame.minX - 2.0, y: labelFrame.minY - 3.0 - UIScreenPixel, width: labelFrame.width + 4.0, height: 16.0)
            transition.setFrame(view: self.background, frame: backgroundFrame)
            transition.setFrame(view: self.outline, frame: backgroundFrame.insetBy(dx: -2.0, dy: -2.0))
            transition.setFrame(view: self.label, frame: labelFrame.offsetBy(dx: -2.0, dy: 0.0))
        } else {
            self.label.isHidden = true
            self.outline.image = PresentationResourcesChatList.shareAvatarPremiumLockBadgeBackground(theme)
            self.background.image = PresentationResourcesChatList.shareAvatarPremiumLockBadge(theme)
            let frame = CGRect(x: avatarFrame.maxX - 20.0, y: avatarFrame.maxY - 20.0, width: 20.0, height: 20.0)
            transition.setFrame(view: self.background, frame: frame)
            transition.setFrame(view: self.outline, frame: frame.insetBy(dx: -2.0, dy: -2.0))
        }
    }
}

// Keeps search/community rows on the existing PeerListItemComponent.
final class ShareScreenRestrictedRowComponent: Component {
    let content: AnyComponent<Empty>
    let theme: PresentationTheme
    let requirement: ShareScreenMessagingRequirement

    init(content: AnyComponent<Empty>, theme: PresentationTheme, requirement: ShareScreenMessagingRequirement) {
        self.content = content
        self.theme = theme
        self.requirement = requirement
    }

    static func ==(lhs: ShareScreenRestrictedRowComponent, rhs: ShareScreenRestrictedRowComponent) -> Bool {
        return lhs.content == rhs.content && lhs.theme === rhs.theme && lhs.requirement == rhs.requirement
    }

    final class View: UIView {
        let content = ComponentView<Empty>()
        let badge = ShareScreenMessagingBadge(frame: .zero)
    }

    func makeView() -> View { return View() }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        let size = view.content.update(transition: transition, component: self.content, environment: {}, containerSize: availableSize)
        if let content = view.content.view {
            if content.superview == nil { view.addSubview(content) }
            content.frame = CGRect(origin: .zero, size: size)
        }
        if view.badge.superview == nil { view.addSubview(view.badge) }
        view.badge.frame = CGRect(origin: .zero, size: size)
        view.badge.update(requirement: self.requirement, theme: self.theme, avatarFrame: CGRect(x: 12.0, y: 8.0, width: 44.0, height: 44.0), selected: false, transition: transition)
        return size
    }
}
