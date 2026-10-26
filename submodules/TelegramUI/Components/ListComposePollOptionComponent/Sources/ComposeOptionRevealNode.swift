import UIKit
import AsyncDisplayKit
import Display
import ItemListUI

// The component owns layout and editing; ItemListUI owns the entire swipe lifetime.
final class ComposeOptionRevealNode: ItemListRevealOptionsItemNode {
    let contentNode = ASDisplayNode()
    let highlightedBackgroundNode = ASDisplayNode()
    var interactivelyOpened: (() -> Void)?
    var separatorAlphaUpdated: (() -> Void)?
    var deleteAction: (() -> Void)?
    private var option: ItemListRevealOption?
    private var actionCommitted = false

    init() {
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        self.clipsToBounds = true
        self.highlightedBackgroundNode.isUserInteractionEnabled = false
        self.highlightedBackgroundNode.alpha = 0
        self.addSubnode(self.contentNode)
    }

    func update(size: CGSize, option: ItemListRevealOption?, highlightColor: UIColor) {
        if (self.option == nil) != (option == nil) {
            self.actionCommitted = false
        }
        self.option = option
        self.frame = CGRect(origin: .zero, size: size)
        self.contentNode.bounds = CGRect(origin: .zero, size: size)
        self.contentNode.position = CGPoint(x: size.width / 2 + self.revealOffset, y: size.height / 2)
        self.highlightedBackgroundNode.backgroundColor = highlightColor
        self.updateRevealOptionsHighlightedBackgroundFrame(self.highlightedBackgroundNode, frame: CGRect(origin: .zero, size: size))
        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: false, transition: .immediate, aboveNodes: [])
        self.updateLayout(size: size, leftInset: 0, rightInset: 0)
        self.setRevealOptions((left: [], right: option.map { [$0] } ?? []))
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.contentNode.position = CGPoint(x: self.bounds.width / 2 + offset, y: self.bounds.height / 2)
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        // A tap on the shifted row closes it without editing text or toggling a quiz answer.
        self.contentNode.isUserInteractionEnabled = !isActive
        self.contentNode.view.accessibilityElementsHidden = isActive
    }

    override func revealOptionsSeparatorAlphaUpdated() {
        super.revealOptionsSeparatorAlphaUpdated()
        self.separatorAlphaUpdated?()
    }

    override func revealOptionsInteractivelyOpened() {
        self.interactivelyOpened?()
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The attachment sheet has a pan on a plain UIView. Let the row decide
        // horizontal intent before that pan starts; vertical movement fails our
        // recognizer at 10 pt and remains available to scrolling/sheet dismissal.
        if !(gestureRecognizer is UITapGestureRecognizer), otherGestureRecognizer is UIPanGestureRecognizer, !(otherGestureRecognizer is InteractiveTransitionGestureRecognizer), let ancestor = otherGestureRecognizer.view, ancestor !== self.view, self.view.isDescendant(of: ancestor) {
            return true
        }
        return super.gestureRecognizer(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer)
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        guard self.option?.key == option.key, !self.actionCommitted else { return }
        self.performDelete()
    }

    @discardableResult func performDelete() -> Bool {
        guard self.option != nil, !self.actionCommitted else { return false }
        self.actionCommitted = true
        self.setRevealOptionsOpened(false, animated: true)
        self.deleteAction?()
        return true
    }

    override func reuse() {
        super.reuse()
        self.actionCommitted = false
    }
}
