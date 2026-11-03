import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ComponentFlow
import BundleIconComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import AccountContext
import ChatTitleView

final class ChatOverlayNavigationBar: ASDisplayNode {
    static let height: CGFloat = 64.0

    private let context: AccountContext
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let dateTimeFormat: PresentationDateTimeFormat
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let tapped: () -> Void
    private let close: () -> Void
    
    private let titleBackgroundView = GlassBackgroundView()
    private let titleButton = HighlightTrackingButton()
    private let titleComponent = ComponentView<Empty>()
    private let titleState = ComponentState()
    private let closeButton = ComponentView<Empty>()
    
    private var validLayout: CGSize?

    var titleContent: ChatTitleContent? {
        didSet {
            if self.titleContent != oldValue, let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }

    var titleActivities: ChatTitleComponent.Activities? {
        didSet {
            if self.titleActivities != oldValue, let size = self.validLayout {
                self.updateLayout(size: size, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    private var peerTitle: String = ""
    var title: String? {
        didSet {
            let title = self.title ?? ""
            if self.peerTitle != title {
                self.peerTitle = title
                if let size = self.validLayout {
                    self.updateLayout(size: size, transition: .immediate)
                }
            }
        }
    }
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, tapped: @escaping () -> Void, close: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.tapped = tapped
        self.close = close
        
        super.init()

        self.isOpaque = false
        self.titleComponent.parentState = self.titleState
        self.titleState._updated = { [weak self] transition, _ in
            guard let self, let size = self.validLayout else {
                return
            }
            self.updateLayout(size: size, transition: transition.containedViewLayoutTransition)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.titleBackgroundView)
        self.titleBackgroundView.contentView.addSubview(self.titleButton)
        self.titleButton.addTarget(self, action: #selector(self.handleTap), for: .touchUpInside)
        self.titleButton.isAccessibilityElement = true
        self.titleButton.accessibilityTraits = .button
    }
        
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        let componentTransition = ComponentTransition(transition)
        let sideInset: CGFloat = 10.0
        let buttonSize = CGSize(width: 44.0, height: 44.0)
        let controlOriginY = floorToScreenPixels((size.height - buttonSize.height) * 0.5)
        // Reserve the close button's width on both sides to keep the title centered.
        let maxTitleWidth = max(0.0, size.width - (sideInset + buttonSize.width + 8.0) * 2.0)

        let titleSize = self.titleComponent.update(
            transition: componentTransition,
            component: AnyComponent(ChatTitleComponent(
                context: self.context,
                theme: self.theme,
                preferClearGlass: false,
                strings: self.strings,
                dateTimeFormat: self.dateTimeFormat,
                nameDisplayOrder: self.nameDisplayOrder,
                displayBackground: false,
                content: self.titleContent ?? .custom(title: [ChatTitleContent.TitleTextItem(id: AnyHashable(0), content: .text(self.peerTitle))], subtitle: nil, isEnabled: true),
                activities: self.titleActivities,
                networkState: nil,
                tapped: {},
                longTapped: {}
            )),
            environment: {},
            containerSize: CGSize(width: maxTitleWidth, height: buttonSize.height)
        )
        if let titleView = self.titleComponent.view {
            if titleView.superview == nil {
                titleView.isUserInteractionEnabled = false
                self.titleButton.addSubview(titleView)
            }
            transition.updateFrame(view: titleView, frame: CGRect(origin: CGPoint(x: 0.0, y: -1.0), size: titleSize))
        }

        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) * 0.5), y: controlOriginY), size: titleSize)
        self.titleBackgroundView.isHidden = self.titleContent == nil && self.peerTitle.isEmpty
        self.titleBackgroundView.update(size: titleSize, cornerRadius: titleSize.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: componentTransition)
        transition.updateFrame(view: self.titleBackgroundView, frame: titleFrame)
        transition.updateFrame(view: self.titleButton, frame: CGRect(origin: .zero, size: titleSize))
        self.titleButton.accessibilityLabel = self.peerTitle

        let _ = self.closeButton.update(
            transition: componentTransition,
            component: AnyComponent(GlassBarButtonComponent(
                size: buttonSize,
                backgroundColor: nil,
                isDark: self.theme.overallDarkAppearance,
                state: .glass,
                component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(
                    name: "Navigation/Close",
                    tintColor: self.theme.chat.inputPanel.panelControlColor
                ))),
                action: { [weak self] _ in
                    self?.close()
                }
            )),
            environment: {},
            containerSize: buttonSize
        )
        if let closeButtonView = self.closeButton.view {
            if closeButtonView.superview == nil {
                self.view.addSubview(closeButtonView)
            }
            closeButtonView.accessibilityLabel = self.strings.Common_Close
            transition.updateFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: size.width - sideInset - buttonSize.width, y: controlOriginY), size: buttonSize))
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let closeButtonView = self.closeButton.view, closeButtonView.frame.contains(point) {
            return closeButtonView.hitTest(self.view.convert(point, to: closeButtonView), with: event)
        }
        if !self.titleBackgroundView.isHidden, self.titleBackgroundView.frame.contains(point) {
            return self.titleBackgroundView.hitTest(self.view.convert(point, to: self.titleBackgroundView), with: event)
        }
        return nil
    }
    
    @objc private func handleTap() {
        self.tapped()
    }
}
