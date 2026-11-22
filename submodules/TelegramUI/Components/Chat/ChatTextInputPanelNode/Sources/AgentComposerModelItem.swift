import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import AccountContext

/// A model row of the agent composer's menu: the model's title over its description and a check at the trailing edge. The standard action item puts the check in front and cuts the
/// description at the standard menu width.
final class AgentComposerModelItem: ContextMenuCustomItem {
    private let model: AgentChatPlaceholderOptions.Model
    private let isSelected: Bool
    private let action: () -> Void
    /// How long the menu stays open after a pick: the menu must not fold back sooner after opening than its morph can
    /// follow (`ContextMenuCooldown`).
    private let dismissDelay: () -> Double

    init(model: AgentChatPlaceholderOptions.Model, isSelected: Bool, action: @escaping () -> Void, dismissDelay: @escaping () -> Double) {
        self.model = model
        self.isSelected = isSelected
        self.action = action
        self.dismissDelay = dismissDelay
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return AgentComposerModelItemNode(presentationData: presentationData, model: self.model, isSelected: self.isSelected, action: { [action = self.action, dismissDelay = self.dismissDelay] in
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay()) {
                actionSelected(.default)
            }
        })
    }
}

private final class AgentComposerModelItemNode: ASDisplayNode, ContextMenuCustomNode {
    private static let width: CGFloat = 300.0
    private static let height: CGFloat = 61.0
    private static let sideInset: CGFloat = 18.0
    private static let checkSize: CGFloat = 18.0

    private var presentationData: PresentationData
    private let model: AgentChatPlaceholderOptions.Model
    private let isSelected: Bool
    private let action: () -> Void

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView()

    var needsSeparator: Bool {
        return false
    }

    init(presentationData: PresentationData, model: AgentChatPlaceholderOptions.Model, isSelected: Bool, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.model = model
        self.isSelected = isSelected
        self.action = action

        super.init()

        self.isAccessibilityElement = true
        self.accessibilityLabel = model.title
        self.accessibilityValue = model.subtitle
        self.accessibilityTraits = isSelected ? [.button, .selected] : .button

        self.updateColors()
    }

    override func didLoad() {
        super.didLoad()

        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.subtitleLabel)
        self.view.addSubview(self.checkView)
    }

    private func updateColors() {
        let theme = self.presentationData.theme
        self.titleLabel.attributedText = NSAttributedString(string: self.model.title, font: Font.regular(17.0), textColor: theme.contextMenu.primaryColor)
        self.subtitleLabel.attributedText = NSAttributedString(string: self.model.subtitle, font: Font.regular(13.0), textColor: theme.contextMenu.secondaryColor)
        self.checkView.image = self.isSelected ? generateCheckImage(color: theme.contextMenu.primaryColor) : nil
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.updateColors()
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        return (CGSize(width: Self.width, height: Self.height), { [weak self] size, transition in
            guard let self else {
                return
            }
            let checkX = size.width - Self.sideInset - Self.checkSize
            transition.updateFrame(view: self.checkView, frame: CGRect(x: checkX, y: floor((size.height - Self.checkSize) * 0.5), width: Self.checkSize, height: Self.checkSize))

            let textWidth = checkX - 12.0 - Self.sideInset
            transition.updateFrame(view: self.titleLabel, frame: CGRect(x: Self.sideInset, y: 10.0, width: textWidth, height: 22.0))
            transition.updateFrame(view: self.subtitleLabel, frame: CGRect(x: Self.sideInset, y: 33.0, width: textWidth, height: 18.0))
        })
    }

    func canBeHighlighted() -> Bool {
        return true
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
        self.action()
    }
}

/// An 18 pt tick stroked 1.98 pt with round ends.
private func generateCheckImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.98)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 2.7, y: 9.45))
        context.addLine(to: CGPoint(x: 7.02, y: 13.77))
        context.addLine(to: CGPoint(x: 15.3, y: 4.05))
        context.strokePath()
    })
}
