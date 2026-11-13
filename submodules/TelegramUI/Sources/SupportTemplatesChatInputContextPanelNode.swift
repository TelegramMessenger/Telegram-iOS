import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatInputContextPanelNode
import ComponentFlow
import GlassBackgroundComponent
import SupportTemplates

private let hintHeight: CGFloat = 96.0
private let maximumListHeight: CGFloat = 300.0
private let cardSideInset: CGFloat = 8.0
private let cardCornerRadius: CGFloat = 20.0

private func textAlignment(for text: String) -> NSTextAlignment {
    for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0x0590 ... 0x08FF, 0xFB1D ... 0xFDFF, 0xFE70 ... 0xFEFF:
            return .right
        default:
            if scalar.properties.isAlphabetic {
                return .left
            }
        }
    }
    return .left
}

private final class SearchField: UITextField {
    var moveSelection: ((Int) -> Void)?
    var submit: (() -> Void)?
    var cancel: (() -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        let commands = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(self.upPressed)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(self.downPressed)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(self.cancelPressed)),
            UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(self.cancelPressed)),
            UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(self.cancelPressed)),
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(self.submitPressed))
        ]
        for command in commands {
            command.wantsPriorityOverSystemBehavior = true
        }
        return commands
    }

    @objc private func upPressed() {
        self.moveSelection?(-1)
    }

    @objc private func downPressed() {
        self.moveSelection?(1)
    }

    @objc private func cancelPressed() {
        self.cancel?()
    }

    @objc private func submitPressed() {
        self.submit?()
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 12.0, dy: 0.0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        var rect = bounds.insetBy(dx: 12.0, dy: 0.0)
        rect.size.width -= 22.0
        return rect
    }
}

private final class RowView: UIView {
    var activate: (() -> Void)?

    private let highlight = UIView()
    private let separator = UIView()
    private let question = UILabel()
    private let keys = UILabel()
    private let answer = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isAccessibilityElement = true
        self.addSubview(self.highlight)
        self.addSubview(self.separator)
        self.answer.numberOfLines = 2
        self.addSubview(self.question)
        self.addSubview(self.keys)
        self.addSubview(self.answer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        self.activate?()
        return true
    }

    func update(template: SupportTemplatesQuestion, isSelected: Bool, isLast: Bool, theme: PresentationTheme, fontSize: PresentationFontSize, width: CGFloat) -> CGFloat {
        self.question.font = Font.semibold(floor(fontSize.baseDisplaySize * 14.0 / 17.0))
        self.keys.font = Font.regular(floor(fontSize.baseDisplaySize * 13.0 / 17.0))
        self.answer.font = Font.regular(floor(fontSize.baseDisplaySize * 14.0 / 17.0))
        self.accessibilityLabel = template.question
        self.accessibilityValue = template.value
        self.accessibilityTraits = isSelected ? [.button, .selected] : .button

        self.highlight.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.highlight.isHidden = !isSelected
        self.separator.backgroundColor = theme.list.itemPlainSeparatorColor
        self.separator.isHidden = isLast

        self.question.textColor = theme.list.itemAccentColor
        self.keys.textColor = theme.list.itemSecondaryTextColor
        self.answer.textColor = theme.list.itemPrimaryTextColor

        let keys = template.originalKeys.joined(separator: ", ")
        self.question.text = template.question
        self.keys.text = keys
        self.answer.text = template.value
        self.question.textAlignment = textAlignment(for: template.question)
        self.keys.textAlignment = textAlignment(for: keys)
        self.answer.textAlignment = textAlignment(for: template.value)

        let textWidth = width - 32.0
        var y: CGFloat = 9.0
        for label in [self.question, self.keys, self.answer] {
            label.isHidden = label.text?.isEmpty ?? true
            if label.isHidden {
                continue
            }
            let height = ceil(label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
            label.frame = CGRect(x: 16.0, y: y, width: textWidth, height: height)
            y += height + 1.0
        }
        let height = y + 8.0
        self.highlight.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        self.separator.frame = CGRect(x: 16.0, y: height - UIScreenPixel, width: textWidth, height: UIScreenPixel)
        return height
    }
}

final class SupportTemplatesChatInputContextPanelNode: ChatInputContextPanelNode, UITextFieldDelegate {
    var chosen: ((SupportTemplatesQuestion) -> Void)?
    var cancelled: (() -> Void)?
    var lostFocus: (() -> Void)?

    private let templates: () -> SupportTemplates
    private let searchFont: UIFont
    private let searchAreaHeight: CGFloat

    private let cardView = UIView()
    private let backgroundView = GlassBackgroundView()
    private let contentView = UIView()
    private let searchField = SearchField()
    private let scrollView = UIScrollView()
    private let hintLabel = UILabel()

    private var rows: [SupportTemplatesQuestion] = []
    private var rowViews: [RowView] = []
    private var selectedIndex = 0
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat)?
    private var didAppear = false

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext, templates: @escaping () -> SupportTemplates) {
        self.templates = templates
        let searchFont = Font.regular(floor(fontSize.baseDisplaySize * 16.0 / 17.0))
        self.searchFont = searchFont
        self.searchAreaHeight = ceil(searchFont.lineHeight) + 32.0

        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)

        self.isOpaque = false

        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = cardCornerRadius

        self.searchField.delegate = self
        self.searchField.font = self.searchFont
        self.searchField.layer.cornerRadius = 10.0
        self.searchField.autocorrectionType = .no
        self.searchField.autocapitalizationType = .none
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.addTarget(self, action: #selector(self.searchTextChanged), for: .editingChanged)
        self.searchField.moveSelection = { [weak self] delta in
            self?.moveSelection(delta)
        }
        self.searchField.submit = { [weak self] in
            self?.submit()
        }
        self.searchField.cancel = { [weak self] in
            self?.cancelled?()
        }

        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollView.disablesInteractiveKeyboardGestureRecognizer = true
        self.scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.rowsTapped(_:))))

        self.hintLabel.text = self.strings.Support_Templates_PanelSearchHint
        self.hintLabel.font = Font.regular(floor(self.fontSize.baseDisplaySize * 14.0 / 17.0))
        self.hintLabel.textAlignment = .center
        self.hintLabel.numberOfLines = 2

        self.view.addSubview(self.cardView)
        self.cardView.addSubview(self.backgroundView)
        self.cardView.addSubview(self.contentView)
        self.contentView.addSubview(self.searchField)
        self.contentView.addSubview(self.scrollView)
        self.contentView.addSubview(self.hintLabel)

        self.applyTheme()
    }

    private func applyTheme() {
        let searchBar = self.theme.rootController.navigationSearchBar
        self.searchField.backgroundColor = searchBar.inputFillColor
        self.searchField.textColor = searchBar.inputTextColor
        self.searchField.tintColor = searchBar.accentColor
        self.searchField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.searchField.attributedPlaceholder = NSAttributedString(string: self.strings.Support_Templates_PanelSearchPlaceholder, font: self.searchFont, textColor: searchBar.inputPlaceholderTextColor)
        self.hintLabel.textColor = self.theme.list.itemSecondaryTextColor
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.submit()
        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.lostFocus?()
    }

    @objc private func searchTextChanged() {
        self.rows = self.templates().query(self.searchField.text ?? "")
        self.selectedIndex = 0
        self.scrollView.contentOffset = CGPoint()
        self.layoutCard(transition: .animated(duration: 0.2, curve: .easeInOut))
    }

    @objc private func rowsTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        let location = recognizer.location(in: self.scrollView)
        guard let index = self.rowViews.prefix(self.rows.count).firstIndex(where: { $0.frame.contains(location) }) else {
            return
        }
        self.submitRow(at: index)
    }

    private func submitRow(at index: Int) {
        self.selectedIndex = index
        self.submit()
    }

    private func moveSelection(_ delta: Int) {
        let index = self.selectedIndex + delta
        guard self.rows.indices.contains(index) else {
            return
        }
        self.selectedIndex = index
        self.layoutCard(transition: .immediate)
        self.scrollView.scrollRectToVisible(self.rowViews[index].frame, animated: false)
    }

    private func submit() {
        if self.rows.indices.contains(self.selectedIndex) {
            self.chosen?(self.rows[self.selectedIndex])
        }
    }

    private func layoutCard(transition: ContainedViewLayoutTransition) {
        guard let (size, leftInset, rightInset, bottomInset) = self.validLayout else {
            return
        }
        let cardWidth = max(0.0, size.width - leftInset - rightInset - cardSideInset * 2.0)

        while self.rowViews.count < self.rows.count {
            let rowView = RowView()
            self.rowViews.append(rowView)
            self.scrollView.addSubview(rowView)
        }
        var contentHeight: CGFloat = 0.0
        for (index, rowView) in self.rowViews.enumerated() {
            rowView.isHidden = index >= self.rows.count
            if rowView.isHidden {
                continue
            }
            rowView.activate = { [weak self] in
                self?.submitRow(at: index)
            }
            let height = rowView.update(template: self.rows[index], isSelected: index == self.selectedIndex, isLast: index == self.rows.count - 1, theme: self.theme, fontSize: self.fontSize, width: cardWidth)
            rowView.frame = CGRect(x: 0.0, y: contentHeight, width: cardWidth, height: height)
            contentHeight += height
        }
        self.scrollView.contentSize = CGSize(width: cardWidth, height: contentHeight)
        self.hintLabel.isHidden = !self.rows.isEmpty

        let listHeight = self.rows.isEmpty ? hintHeight : min(contentHeight, maximumListHeight)
        let cardMaxY = size.height - bottomInset - cardSideInset
        let availableHeight = max(0.0, cardMaxY - cardSideInset)
        let cardHeight = min(availableHeight, searchAreaHeight + listHeight)
        let cardFrame = CGRect(x: leftInset + cardSideInset, y: cardMaxY - cardHeight, width: cardWidth, height: cardHeight)

        transition.updateFrame(view: self.cardView, frame: cardFrame)
        let cardBounds = CGRect(origin: CGPoint(), size: cardFrame.size)
        transition.updateFrame(view: self.backgroundView, frame: cardBounds)
        self.backgroundView.update(size: cardFrame.size, cornerRadius: cardCornerRadius, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: ComponentTransition(transition))
        transition.updateFrame(view: self.contentView, frame: cardBounds)
        self.searchField.frame = CGRect(x: 8.0, y: 8.0, width: cardWidth - 16.0, height: self.searchAreaHeight - 16.0)
        let listFrame = CGRect(x: 0.0, y: searchAreaHeight, width: cardWidth, height: max(0.0, cardHeight - searchAreaHeight))
        transition.updateFrame(view: self.scrollView, frame: listFrame)
        self.hintLabel.frame = listFrame.insetBy(dx: 16.0, dy: 0.0)
    }

    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.applyTheme()
        }
        self.layoutCard(transition: self.didAppear ? transition : .immediate)

        if !self.didAppear {
            self.didAppear = true
            self.cardView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.cardView.layer.animatePosition(from: CGPoint(x: 0.0, y: 24.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.searchField.window != nil else {
                    return
                }
                if !self.searchField.becomeFirstResponder() {
                    self.lostFocus?()
                }
            }
        }
    }

    override func animateOut(completion: @escaping () -> Void) {
        self.cardView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 24.0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
        self.cardView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.cardView.frame.contains(point) else {
            return nil
        }
        return self.cardView.hitTest(self.view.convert(point, to: self.cardView), with: event)
    }
}
