import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import SearchBarNode
import ComponentFlow
import GlassBackgroundComponent

private let searchBarFont = Font.regular(17.0)

final class ChatRecentActionsSearchNavigationContentNode: NavigationBarContentNode {
    private var theme: PresentationTheme
    private var preferClearGlass: Bool
    private var strings: PresentationStrings

    private let cancel: () -> Void

    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let iconView: UIImageView
    private let searchBar: SearchBarNode
    private let close: (background: GlassBackgroundView, icon: UIImageView)

    private var queryUpdated: ((String) -> Void)?
    private var params: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?

    init(theme: PresentationTheme, preferClearGlass: Bool, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.strings = strings

        self.cancel = cancel

        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.iconView = UIImageView()
        self.backgroundView.contentView.addSubview(self.iconView)

        self.close = (GlassBackgroundView(), UIImageView())
        self.close.background.contentView.addSubview(self.close.icon)

        self.searchBar = SearchBarNode(theme: ChatRecentActionsSearchNavigationContentNode.searchBarTheme(theme), presentationTheme: theme, preferClearGlass: preferClearGlass, strings: strings, fieldStyle: .inlineNavigation, forceSeparator: false, displayBackground: false, cancelText: nil)
        let placeholderText = strings.Common_Search
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.chat.inputPanel.inputPlaceholderColor)

        super.init()

        self.view.addSubview(self.backgroundContainer)
        self.backgroundView.contentView.addSubview(self.searchBar.view)

        self.backgroundContainer.contentView.addSubview(self.close.background)
        self.close.background.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onCloseTapGesture(_:))))

        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }

        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
    }

    @objc private func onCloseTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.searchBar.cancel?()
        }
    }

    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }

    private static func searchBarTheme(_ theme: PresentationTheme) -> SearchBarNodeTheme {
        return SearchBarNodeTheme(
            background: .clear,
            separator: .clear,
            inputFill: .clear,
            primaryText: theme.chat.inputPanel.panelControlColor,
            placeholder: theme.chat.inputPanel.inputPlaceholderColor,
            inputIcon: theme.chat.inputPanel.inputControlColor,
            inputClear: theme.chat.inputPanel.panelControlColor,
            accent: theme.chat.inputPanel.panelControlAccentColor,
            keyboard: theme.rootController.keyboardColor
        )
    }

    func updateThemeAndStrings(theme: PresentationTheme, preferClearGlass: Bool, strings: PresentationStrings) {
        if self.theme !== theme || self.preferClearGlass != preferClearGlass || self.strings !== strings {
            self.theme = theme
            self.preferClearGlass = preferClearGlass
            self.strings = strings

            self.searchBar.updateThemeAndStrings(
                theme: ChatRecentActionsSearchNavigationContentNode.searchBarTheme(theme),
                presentationTheme: theme,
                preferClearGlass: preferClearGlass,
                strings: strings
            )
            self.searchBar.placeholderString = NSAttributedString(string: strings.Common_Search, font: searchBarFont, textColor: theme.chat.inputPanel.inputPlaceholderColor)
        }

        if let params = self.params {
            let _ = self.updateLayout(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate)
        }
    }

    override var nominalHeight: CGFloat {
        return 60.0
    }

    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.params = (size, leftInset, rightInset)

        let transition = ComponentTransition(transition)

        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: 6.0), size: CGSize(width: size.width - 16.0 * 2.0 - leftInset - rightInset - 44.0 - 8.0, height: 44.0))
        let closeFrame = CGRect(origin: CGPoint(x: size.width - 16.0 - rightInset - 44.0, y: backgroundFrame.minY), size: CGSize(width: 44.0, height: 44.0))

        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundContainer.update(size: size, isDark: self.theme.overallDarkAppearance, transition: transition)

        transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)

        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Navigation/Search")?.withRenderingMode(.alwaysTemplate)
        }
        transition.setTintColor(view: self.iconView, color: self.theme.rootController.navigationSearchBar.inputIconColor)

        if let image = self.iconView.image {
            let iconFraction: CGFloat = 0.8
            let imageSize = CGSize(width: image.size.width * iconFraction, height: image.size.height * iconFraction)
            let iconFrame = CGRect(origin: CGPoint(x: 12.0, y: floor((backgroundFrame.height - imageSize.height) * 0.5)), size: imageSize)
            transition.setPosition(view: self.iconView, position: iconFrame.center)
            transition.setBounds(view: self.iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
        }

        let searchBarFrame = CGRect(origin: CGPoint(x: 36.0, y: 0.0), size: CGSize(width: backgroundFrame.width - 36.0 - 4.0, height: 44.0))
        transition.setFrame(view: self.searchBar.view, frame: searchBarFrame)
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)

        if self.close.icon.image == nil {
            self.close.icon.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))

                context.setLineWidth(2.0)
                context.setLineCap(.round)
                context.setStrokeColor(UIColor.white.cgColor)

                context.beginPath()
                context.move(to: CGPoint(x: 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
                context.move(to: CGPoint(x: size.width - 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
                context.strokePath()
            })?.withRenderingMode(.alwaysTemplate)
        }

        if let image = self.close.icon.image {
            self.close.icon.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size))
        }
        self.close.icon.tintColor = self.theme.chat.inputPanel.panelControlColor

        transition.setFrame(view: self.close.background, frame: closeFrame)
        self.close.background.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)

        return size
    }

    func activate() {
        self.searchBar.activate()
    }

    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
