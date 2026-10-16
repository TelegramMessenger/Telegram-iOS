import Foundation
import UIKit
import Display
import ComponentFlow
import SideColumnLayout

/// One content of the bar (the primary, or the secondary sliding in over it): back, buttons and title. Its
/// button containers live in the bar view's capsules and column; the bar view moves them between contents.
final class NavigationBarContentView: UIView {
    let backPressed: () -> Void
    /// Hosts screens' nodes only while they are lent to it (`NavigationBarNodeLoan`): glass drawn outside the bar.
    var borrowsNodes = false

    let leftButtonsContainer: UIView
    private(set) var leftButtonViews: [AnyHashable: ComponentView<NavigationButtonEnvironment>] = [:]
    private(set) var rightButtonViews: [AnyHashable: ComponentView<NavigationButtonEnvironment>] = [:]
    /// The row's right pills (`NavigationBarButtonPlacement.rowRightSections`), outermost first: each one's items, in a
    /// container the bar view hosts in that pill's glass. Containers are kept (emptied) when the pills get fewer.
    private(set) var rightPillContainers: [UIView] = []
    /// Width (at least 44 pt), tint and number of buttons of each pill shown, outermost first.
    private(set) var rightPillWidths: [CGFloat] = []
    private(set) var rightPillTints: [NavigationBarComponent.Button.Tint] = []
    private(set) var rightPillButtonCounts: [Int] = []
    private(set) var backButtonView: NavigationBarBackButtonView?
    /// Morph only: whether the last update held the back button steady (`updateMorphTransition`).
    /// iPhone Duo: this content's part of the side column; the bar view hosts them.
    let columnBackContainer: UIView
    let columnButtonsContainer: UIView
    /// iPhone Duo: this content's confirming button (the Done checkmark) in the column's own circle; the bar view
    /// hosts it.
    let columnTrailingContainer: UIView
    private(set) var trailingCircleTint: NavigationBarComponent.Button.Tint = .generic
    private(set) var leftCapsuleTint: NavigationBarComponent.Button.Tint = .generic
    private(set) var columnLayout: SideColumnItemsLayout?
    private var overflowButtonView: ComponentView<NavigationButtonEnvironment>?
    private var overflowItems: [NavigationBarComponent.OverflowItem] = []
    private var openOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)?

    let titleOffsetContainer: UIView
    let titleScaleContainer: UIView
    let titleTextView: ImmediateTextView
    private(set) var titleContentView: ComponentView<Empty>?
    private(set) var customTitleView: ComponentView<NavigationBarTitleEnvironment>?

    private(set) var centerContentLeftInset: CGFloat = 0.0
    private(set) var centerContentRightInset: CGFloat = 0.0

    private(set) var leftButtonsWidth: CGFloat = 0.0

    var leftButtonCount: Int {
        var count = self.leftButtonViews.values.filter { $0.view?.superview === self.leftButtonsContainer }.count
        if let backButtonView = self.backButtonView, backButtonView.superview === self.leftButtonsContainer {
            count += 1
        }
        return count
    }
    /// Pill `index`'s items container, made on first use.
    func rightPillContainer(at index: Int) -> UIView {
        while self.rightPillContainers.count <= index {
            self.rightPillContainers.append(UIView())
        }
        return self.rightPillContainers[index]
    }

    /// Whether a button view is in the row (the side column is hit-tested by its host).
    private func isInRow(_ view: UIView) -> Bool {
        if view.superview === self.leftButtonsContainer {
            return true
        }
        return self.rightPillContainers.contains(where: { $0 === view.superview })
    }

    init(backPressed: @escaping () -> Void) {
        self.backPressed = backPressed

        self.leftButtonsContainer = UIView()
        self.columnBackContainer = UIView()
        self.columnButtonsContainer = UIView()
        self.columnTrailingContainer = UIView()

        self.titleOffsetContainer = UIView()
        self.titleScaleContainer = UIView()

        self.titleTextView = ImmediateTextView()

        super.init(frame: CGRect())

        self.addSubview(self.titleOffsetContainer)
        self.titleOffsetContainer.addSubview(self.titleScaleContainer)

        self.titleScaleContainer.addSubview(self.titleTextView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let backButtonView = self.backButtonView, self.isInRow(backButtonView) {
            if let result = backButtonView.hitTest(self.convert(point, to: backButtonView), with: event) {
                return result
            }
        }
        for (_, buttonView) in self.leftButtonViews {
            if let view = buttonView.view, self.isInRow(view), let result = view.hitTest(self.convert(point, to: view), with: event) {
                return result
            }
        }
        for (_, buttonView) in self.rightButtonViews {
            if let view = buttonView.view, self.isInRow(view), let result = view.hitTest(self.convert(point, to: view), with: event) {
                return result
            }
        }
        if let view = self.titleContentView?.view, let result = view.hitTest(self.convert(point, to: view), with: event) {
            return result
        }
        // A custom title is laid out over the whole row: what it draws takes touches, its container never does.
        if let view = self.customTitleView?.view, let result = view.hitTest(self.convert(point, to: view), with: event), result !== view {
            return result
        }
        return nil
    }

    /// Hands over what `container` shows now (its buttons, the back button), live, in a new view at the container's
    /// frame, and forgets those views, so the next `update` builds the items anew: what leaves while a side's items
    /// change. Never a still copy, which freezes what animates and shows nothing for items not drawn yet.
    func extractItems(of container: UIView) -> UIView {
        let extracted = UIView(frame: container.frame)
        extracted.isUserInteractionEnabled = false
        for view in container.subviews {
            extracted.addSubview(view)
        }
        if let backButtonView = self.backButtonView, backButtonView.superview === extracted {
            self.backButtonView = nil
        }
        self.leftButtonViews = self.leftButtonViews.filter { $0.value.view?.superview !== extracted }
        self.rightButtonViews = self.rightButtonViews.filter { $0.value.view?.superview !== extracted }
        if let overflowButtonView = self.overflowButtonView, overflowButtonView.view?.superview === extracted {
            self.overflowButtonView = nil
        }
        return extracted
    }

    /// The in-bar slide, as the content being covered: its buttons fade and blur, its title slides out left.
    func updateTransitionAsPrevious(width: CGFloat, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
        let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)
        alphaTransition.setAlpha(view: self.leftButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
        alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: fraction * 10.0)
        for container in self.rightPillContainers {
            alphaTransition.setAlpha(view: container, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: container.layer, radius: fraction * 10.0)
        }
        alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(1.0 - fraction, 2.0))
        alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
        alphaTransition.setAlpha(view: self.columnTrailingContainer, alpha: pow(1.0 - fraction, 2.0))
        alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: fraction * 10.0)

        if let backButtonView = self.backButtonView {
            let offsetX: CGFloat = backButtonView.superview === self.leftButtonsContainer ? fraction * self.bounds.width * 0.5 : 0.0
            transition.setBounds(view: backButtonView, bounds: CGRect(origin: CGPoint(x: offsetX, y: 0.0), size: backButtonView.bounds.size), completion: { _ in
                completion()
            })
        }

        let totalOffset = -width * fraction

        transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: totalOffset * fraction, y: 0.0), size: self.titleOffsetContainer.bounds.size))
        transition.setAlpha(view: self.titleOffsetContainer, alpha: pow(1.0 - fraction, 2.0))
    }

    /// The in-bar slide, as the content sliding in: its title comes in from the right, its buttons fade in.
    func updateTransitionAsNext(fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
        let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

        transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: -(1.0 - fraction) * self.bounds.width, y: 0.0), size: self.titleOffsetContainer.bounds.size), completion: { _ in
            completion()
        })
        for container in self.rightPillContainers {
            alphaTransition.setAlpha(view: container, alpha: pow(fraction, 2.0))
            alphaTransition.setBlur(layer: container.layer, radius: (1.0 - fraction) * 10.0)
        }

        alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
        alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(fraction, 2.0))
        alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(fraction, 2.0))
        alphaTransition.setAlpha(view: self.columnTrailingContainer, alpha: pow(fraction, 2.0))
        alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
    }

    /// Updates the view of `button` and puts it into `container` at `frame(size)`; returns its size.
    /// A view moving between the row and the side column (folding, unfolding) is placed without
    /// animation, so it never flies across the screen.
    private func updateButtonView(_ button: NavigationBarComponent.Button, isLeft: Bool, container: UIView, theme: NavigationBarTheme, rowWidth: CGFloat?, availableHeight: CGFloat, transition: ComponentTransition, alphaTransition: ComponentTransition, frame: (CGSize) -> CGRect) -> CGSize {
        var buttonTransition = transition
        var animateButtonIn = false
        let buttonView: ComponentView<NavigationButtonEnvironment>
        if let current = isLeft ? self.leftButtonViews[button.id] : self.rightButtonViews[button.id] {
            buttonView = current
        } else {
            buttonTransition = .immediate
            animateButtonIn = true
            buttonView = ComponentView<NavigationButtonEnvironment>()
            if isLeft {
                self.leftButtonViews[button.id] = buttonView
            } else {
                self.rightButtonViews[button.id] = buttonView
            }
        }
        let buttonSize = buttonView.update(
            transition: buttonTransition,
            component: AnyComponent(NavigationButtonComponent(
                content: button.content,
                color: navigationButtonContentColor(theme: theme, tint: button.tint, isEnabled: button.isEnabled, isText: button.content.isText),
                isEnabled: button.isEnabled,
                pressed: button.action,
                contextAction: button.contextAction,
                borrowsNode: self.borrowsNodes
            )),
            environment: {
                NavigationButtonEnvironment(theme: theme)
            },
            containerSize: CGSize(width: navigationButtonContainerWidth(content: button.content, rowWidth: rowWidth), height: availableHeight)
        )
        if let buttonComponentView = buttonView.view {
            if buttonComponentView.superview !== container {
                buttonTransition = .immediate
                container.addSubview(buttonComponentView)
            }
            if let accessibilityLabel = button.overflow?.title {
                buttonComponentView.accessibilityLabel = accessibilityLabel
            }
            buttonTransition.setFrame(view: buttonComponentView, frame: frame(buttonSize))
            if animateButtonIn {
                alphaTransition.animateBlur(layer: buttonComponentView.layer, fromRadius: 10.0, toRadius: 0.0)
                alphaTransition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
            }
        }
        return buttonSize
    }

    /// `itemsTransition` (default: `transition`) places the back button and the buttons: the bar passes `.immediate`
    /// while it animates a change of its capsules' items itself (`startInPlaceChange`).
    func update(theme: NavigationBarTheme, strings: NavigationBarStrings, content: NavigationBarComponent.Content, leftInset: CGFloat, rightInset: CGFloat, size: CGSize, columnLength: CGFloat?, openOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)?, transition: ComponentTransition, itemsTransition: ComponentTransition? = nil) {
        let itemsTransition = itemsTransition ?? transition
        let alphaTransition: ComponentTransition = itemsTransition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

        transition.setPosition(view: self.titleOffsetContainer, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: self.titleOffsetContainer.bounds.origin, size: size))

        transition.setPosition(view: self.titleScaleContainer, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        transition.setBounds(view: self.titleScaleContainer, bounds: CGRect(origin: self.titleScaleContainer.bounds.origin, size: size))

        var titleString = ""
        if case let .text(text) = content.title {
            titleString = text
        }
        let titleText = NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: theme.primaryTextColor)
        let titleTextUpdated = self.titleTextView.attributedText != titleText
        self.titleTextView.attributedText = titleText
        self.titleTextView.isAccessibilityElement = !titleString.isEmpty
        self.titleTextView.accessibilityLabel = titleString
        self.titleTextView.accessibilityTraits = .header

        var nextLeftButtonX: CGFloat = 0.0

        self.openOverflow = openOverflow

        // iPhone Duo: back and the icon buttons go into the side column (a left icon button
        // first, then the right ones); text buttons stay in the row. Without a column, or when it
        // cannot hold what must stay, every button is in the row.
        let displayBackButton = content.back != nil
        let placement = navigationBarButtonPlacement(leftButton: content.leftButton, rightButtons: content.rightButtons, hasBack: displayBackButton, columnLength: columnLength)
        let columnLayout = placement.columnLayout
        self.columnLayout = columnLayout

        if displayBackButton {
            var backButtonTransition = itemsTransition
            let backButtonView: NavigationBarBackButtonView
            if let current = self.backButtonView {
                backButtonView = current
            } else {
                backButtonTransition = .immediate
                backButtonView = NavigationBarBackButtonView(onPressed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.backPressed()
                })
                self.backButtonView = backButtonView
            }
            let backContainer: UIView = columnLayout?.backFrame != nil ? self.columnBackContainer : self.leftButtonsContainer
            if backButtonView.superview !== backContainer {
                backButtonTransition = .immediate
                backContainer.addSubview(backButtonView)
            }
            if let backFrame = columnLayout?.backFrame {
                // In the column the badge sits on the circle's corner (NavigationBarComponent.View).
                let backButtonSize = backButtonView.update(kind: content.back == .close ? .close : .back, badge: nil, contextAction: content.backContextAction, theme: theme, strings: strings, availableSize: backFrame.size, transition: backButtonTransition)
                backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: floor((backFrame.width - backButtonSize.width) / 2.0), y: floor((backFrame.height - backButtonSize.height) / 2.0)), size: backButtonSize))
            } else {
                let backButtonSize = backButtonView.update(kind: content.back == .close ? .close : .back, badge: content.badge, contextAction: content.backContextAction, theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: size.height), transition: backButtonTransition)
                backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: nextLeftButtonX, y: floor((size.height - backButtonSize.height) / 2.0)), size: backButtonSize))
                nextLeftButtonX += backButtonSize.width
            }
        } else if let backButtonView = self.backButtonView {
            self.backButtonView = nil
            backButtonView.removeFromSuperview()
        }

        var validLeftButtons = Set<AnyHashable>()
        if let leftButton = placement.rowLeftButton {
            validLeftButtons.insert(leftButton.id)
            let originX = nextLeftButtonX
            let buttonSize = self.updateButtonView(leftButton, isLeft: true, container: self.leftButtonsContainer, theme: theme, rowWidth: size.width, availableHeight: size.height, transition: itemsTransition, alphaTransition: alphaTransition, frame: { buttonSize in
                return CGRect(origin: CGPoint(x: originX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
            })
            nextLeftButtonX += buttonSize.width
        }

        var validRightButtons = Set<AnyHashable>()
        var rightPillWidths: [CGFloat] = []
        for (index, section) in placement.rowRightSections.enumerated() {
            let container = self.rightPillContainer(at: index)
            var nextX: CGFloat = 0.0
            // Laid out left to right: the pill's innermost button first.
            for button in section.reversed() {
                validRightButtons.insert(button.id)
                let originX = nextX
                let buttonSize = self.updateButtonView(button, isLeft: false, container: container, theme: theme, rowWidth: size.width, availableHeight: size.height, transition: itemsTransition, alphaTransition: alphaTransition, frame: { buttonSize in
                    return CGRect(origin: CGPoint(x: originX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                })
                nextX += buttonSize.width
            }
            rightPillWidths.append(max(44.0, nextX))
        }
        self.rightPillWidths = rightPillWidths
        self.rightPillTints = placement.rowRightSections.map(navigationBarCapsuleTint)
        self.rightPillButtonCounts = placement.rowRightSections.map(\.count)

        if let columnLayout {
            for (cellIndex, itemIndex) in columnLayout.visibleItems.enumerated() {
                let item = placement.columnItems[itemIndex]
                let isLeft = placement.leftButtonInColumn && itemIndex == 0
                if isLeft {
                    validLeftButtons.insert(item.id)
                } else {
                    validRightButtons.insert(item.id)
                }
                let cellFrame = columnLayout.cellFrames[cellIndex]
                let _ = self.updateButtonView(item, isLeft: isLeft, container: self.columnButtonsContainer, theme: theme, rowWidth: nil, availableHeight: cellFrame.height, transition: itemsTransition, alphaTransition: alphaTransition, frame: { buttonSize in
                    return CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - buttonSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - buttonSize.height) / 2.0)), size: buttonSize)
                })
            }
        }
        if let columnLayout, let trailingItem = placement.trailingCircleItem, let trailingFrame = columnLayout.trailingFrame {
            validRightButtons.insert(trailingItem.id)
            let _ = self.updateButtonView(trailingItem, isLeft: false, container: self.columnTrailingContainer, theme: theme, rowWidth: nil, availableHeight: trailingFrame.height, transition: itemsTransition, alphaTransition: alphaTransition, frame: { buttonSize in
                return CGRect(origin: CGPoint(x: floor((trailingFrame.width - buttonSize.width) / 2.0), y: floor((trailingFrame.height - buttonSize.height) / 2.0)), size: buttonSize)
            })
        }
        self.trailingCircleTint = placement.trailingCircleItem?.tint ?? .generic
        self.overflowItems = navigationBarOverflowItems(placement: placement)

        if let columnLayout, !columnLayout.overflowItems.isEmpty, let cellFrame = columnLayout.cellFrames.last {
            var overflowButtonTransition = itemsTransition
            let overflowButtonView: ComponentView<NavigationButtonEnvironment>
            if let current = self.overflowButtonView {
                overflowButtonView = current
            } else {
                overflowButtonTransition = .immediate
                overflowButtonView = ComponentView<NavigationButtonEnvironment>()
                self.overflowButtonView = overflowButtonView
            }
            let overflowButtonSize = overflowButtonView.update(
                transition: overflowButtonTransition,
                component: AnyComponent(NavigationButtonComponent(
                    content: .more,
                    color: theme.buttonColor,
                    isEnabled: true,
                    pressed: { [weak self] sourceView in
                        guard let self else {
                            return
                        }
                        self.openOverflow?(sourceView, self.overflowItems)
                    },
                    contextAction: nil
                )),
                environment: {
                    NavigationButtonEnvironment(theme: theme)
                },
                containerSize: CGSize(width: 100.0, height: cellFrame.height)
            )
            if let overflowButtonComponentView = overflowButtonView.view {
                if overflowButtonComponentView.superview !== self.columnButtonsContainer {
                    overflowButtonTransition = .immediate
                    self.columnButtonsContainer.addSubview(overflowButtonComponentView)
                    alphaTransition.animateAlpha(view: overflowButtonComponentView, from: 0.0, to: 1.0)
                }
                overflowButtonComponentView.accessibilityLabel = strings.more
                overflowButtonTransition.setFrame(view: overflowButtonComponentView, frame: CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - overflowButtonSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - overflowButtonSize.height) / 2.0)), size: overflowButtonSize))
            }
        } else if let overflowButtonView = self.overflowButtonView {
            self.overflowButtonView = nil
            if let overflowButtonComponentView = overflowButtonView.view {
                alphaTransition.setAlpha(view: overflowButtonComponentView, alpha: 0.0, completion: { [weak overflowButtonComponentView] _ in
                    overflowButtonComponentView?.removeFromSuperview()
                })
            }
        }

        var removeLeftButtons: [AnyHashable] = []
        for (id, buttonView) in self.leftButtonViews {
            if !validLeftButtons.contains(id) {
                if let buttonComponentView = buttonView.view {
                    alphaTransition.setBlur(layer: buttonComponentView.layer, radius: 10.0)
                    alphaTransition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                        buttonComponentView?.removeFromSuperview()
                    })
                }
                removeLeftButtons.append(id)
            }
        }
        for id in removeLeftButtons {
            self.leftButtonViews.removeValue(forKey: id)
        }

        var removeRightButtons: [AnyHashable] = []
        for (id, buttonView) in self.rightButtonViews {
            if !validRightButtons.contains(id) {
                if let buttonComponentView = buttonView.view {
                    alphaTransition.setBlur(layer: buttonComponentView.layer, radius: 10.0)
                    alphaTransition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                        buttonComponentView?.removeFromSuperview()
                    })
                }
                removeRightButtons.append(id)
            }
        }
        for id in removeRightButtons {
            self.rightButtonViews.removeValue(forKey: id)
        }

        self.leftButtonsWidth = nextLeftButtonX

        // The old glass bar tinted the left capsule from its left button only; a back button (alone or with a left
        // button) keeps the panel glass.
        let backInRow = displayBackButton && columnLayout?.backFrame == nil
        self.leftCapsuleTint = backInRow ? .generic : navigationBarCapsuleTint(placement.rowLeftButton.map { [$0] } ?? [])

        let leftExtent = leftInset + nextLeftButtonX
        let rightExtent = rightInset + navigationBarRightButtonsExtent(navigationBarRightPillMetrics(widths: rightPillWidths))
        let remainingWidth = navigationBarTitleAvailableWidth(rowWidth: size.width, leftExtent: leftExtent, rightExtent: rightExtent)

        let titleTextSize = self.titleTextView.updateLayout(CGSize(width: remainingWidth, height: size.height))
        let titleFrame = navigationBarCenteredFrame(size: titleTextSize, rowSize: size)
        if titleTextUpdated {
            self.titleTextView.frame = titleFrame
        } else {
            transition.setFrame(view: self.titleTextView, frame: titleFrame)
        }

        if case let .component(titleComponent) = content.title {
            var titleContentTransition = transition
            let titleContentView: ComponentView<Empty>
            if let current = self.titleContentView {
                titleContentView = current
            } else {
                titleContentTransition = .immediate
                titleContentView = ComponentView<Empty>()
                self.titleContentView = titleContentView
            }
            let titleContentSize = titleContentView.update(
                transition: titleContentTransition,
                component: titleComponent,
                environment: {},
                containerSize: CGSize(width: remainingWidth, height: size.height)
            )

            if let titleContentComponentView = titleContentView.view {
                if titleContentComponentView.superview == nil {
                    self.titleScaleContainer.addSubview(titleContentComponentView)
                }
                titleContentTransition.setFrame(view: titleContentComponentView, frame: navigationBarCenteredFrame(size: titleContentSize, rowSize: size))
            }
        } else if let titleContentView = self.titleContentView {
            self.titleContentView = nil
            titleContentView.view?.removeFromSuperview()
        }

        if case let .custom(customTitle) = content.title {
            var customTitleFrameTransition = transition
            let customTitleView: ComponentView<NavigationBarTitleEnvironment>
            if let current = self.customTitleView {
                customTitleView = current
            } else {
                customTitleFrameTransition = .immediate
                customTitleView = ComponentView<NavigationBarTitleEnvironment>()
                self.customTitleView = customTitleView
            }
            // The title gets the outer transition (the chat-list title animates its own layout with it); only its
            // container is placed without animation when it first appears.
            let _ = customTitleView.update(
                transition: transition,
                component: customTitle,
                environment: {
                    NavigationBarTitleEnvironment(theme: theme, leftButtonsExtent: leftExtent, rightButtonsExtent: rightExtent)
                },
                containerSize: size
            )
            if let customTitleComponentView = customTitleView.view {
                if customTitleComponentView.superview == nil {
                    self.titleScaleContainer.addSubview(customTitleComponentView)
                }
                customTitleFrameTransition.setFrame(view: customTitleComponentView, frame: CGRect(origin: CGPoint(), size: size))
            }
        } else if let customTitleView = self.customTitleView {
            self.customTitleView = nil
            customTitleView.view?.removeFromSuperview()
        }

        let centerContentInsets = navigationBarCenterContentInsets(leftExtent: leftExtent, rightExtent: rightExtent)
        self.centerContentLeftInset = centerContentInsets.left
        self.centerContentRightInset = centerContentInsets.right

        self.titleTextView.isHidden = self.titleContentView != nil || self.customTitleView != nil
    }
}

/// The width a button is measured against. In the row a text or node button gets the row's width, as
/// `NavigationBarImpl` measured them (a long localized title is not truncated); everything else, and every column
/// cell, keeps the chat list's 100pt.
func navigationButtonContainerWidth(content: NavigationBarComponent.Button.Content, rowWidth: CGFloat?) -> CGFloat {
    guard let rowWidth else {
        return 100.0
    }
    switch content {
    case .text, .node:
        return max(100.0, rowWidth)
    default:
        return 100.0
    }
}
