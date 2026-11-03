import Foundation
import UIKit
import CoreText
import Display
import ComponentFlow
import AnimatedTextComponent
import MultilineTextComponent
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import WalletContext

func walletSendInputText(
    amount: Int64,
    mode: WalletSendInputMode,
    rate: Double?,
    dateTimeFormat: PresentationDateTimeFormat
) -> String {
    guard amount > 0 else {
        return ""
    }
    switch mode {
    case .gram:
        return formatTonAmountText(
            amount,
            dateTimeFormat: PresentationDateTimeFormat(
                timeFormat: dateTimeFormat.timeFormat,
                dateFormat: dateTimeFormat.dateFormat,
                dateSeparator: "",
                dateSuffix: "",
                requiresFullYear: false,
                decimalSeparator: dateTimeFormat.decimalSeparator,
                groupingSeparator: ""
            ),
            maxDecimalPositions: 9
        )
    case .fiat:
        guard let rate, rate.isFinite, rate > 0.0 else {
            return ""
        }
        let value = Double(amount) / 1_000_000_000.0 * rate
        guard value.isFinite else {
            return ""
        }
        var text = String(
            format: "%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text.replacingOccurrences(
            of: ".",
            with: dateTimeFormat.decimalSeparator
        )
    }
}

func walletSendGroupedAmountText(_ text: String, dateTimeFormat: PresentationDateTimeFormat) -> String {
    return walletSendGroupedAmountText(text, decimalSeparator: dateTimeFormat.decimalSeparator, groupingSeparator: dateTimeFormat.groupingSeparator)
}

struct WalletSendAmountTextLayout {
    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.baseWritingDirection = .leftToRight
        return style
    }()

    let attributedText: NSAttributedString
    let groupingSeparator: NSAttributedString
    let groupingSeparatorSize: CGSize
    let groupingPositions: [CGFloat]
}

final class WalletSendAmountTextField: UITextField {
    private let groupingView = UIView()
    private var groupingLabels: [UILabel] = []
    private var textLayout: WalletSendAmountTextLayout?
    var interactionBegan: (() -> Void)?
    var emptyDeletion: (() -> Void)?
    var caretColor: UIColor = .clear {
        didSet {
            self.updateSelectionTintColor()
        }
    }
    var usesCustomCaret = false {
        didSet {
            self.updateSelectionTintColor()
            self.setNeedsLayout()
        }
    }
    var displaysNativeCaret = true {
        didSet {
            guard self.displaysNativeCaret != oldValue else { return }
            self.updateSelectionTintColor()
            self.setNeedsLayout()
        }
    }
    override var selectedTextRange: UITextRange? {
        didSet {
            self.updateSelectionTintColor()
        }
    }
    var rendersText = true {
        didSet {
            guard self.rendersText != oldValue, let layout = self.textLayout else { return }
            self.update(layout: layout, selection: self.selectionRange)
        }
    }

    private var displaysNativeSelection: Bool {
        return self.displaysNativeCaret && (!self.usesCustomCaret || self.selectedTextRange?.isEmpty == false)
    }

    private func updateSelectionTintColor() {
        let color: UIColor = self.displaysNativeSelection ? self.caretColor : .clear
        if self.tintColor != color {
            self.tintColor = color
        }
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        return self.displaysNativeSelection ? self.amountCaretRect(for: position) : .zero
    }

    func nativeCaretRect(for position: UITextPosition) -> CGRect {
        return super.caretRect(for: position)
    }

    func amountTextBaseline(font: UIFont) -> CGFloat {
        let centerY: CGFloat
        if (self.text ?? "").isEmpty {
            centerY = self.placeholderRect(forBounds: self.bounds).midY
        } else {
            let caret = self.nativeCaretRect(for: self.beginningOfDocument)
            if !caret.isNull, !caret.isInfinite, caret.height > 0.0 {
                centerY = caret.midY
            } else {
                let textRect = self.isEditing ? self.editingRect(forBounds: self.bounds) : self.textRect(forBounds: self.bounds)
                centerY = textRect.midY
            }
        }
        return centerY + (font.ascender + font.descender) / 2.0
    }

    func amountCaretRect(for position: UITextPosition) -> CGRect {
        var rect = self.nativeCaretRect(for: position)
        if !rect.isNull, !rect.isInfinite {
            let width: CGFloat = 3.0
            var offset: CGFloat = self.offset(from: self.beginningOfDocument, to: position) == 0 ? 0.0 : 5.0
            if (self.text ?? "").isEmpty, let placeholder = self.attributedPlaceholder, placeholder.length > 0 {
                let line = CTLineCreateWithAttributedString(placeholder)
                rect.origin.x += CGFloat(CTLineGetOffsetForStringIndex(line, placeholder.length, nil))
                offset = 3.0
            } else if self.text == "0", offset > 0.0 {
                offset = 4.0
            }
            rect.origin.x = floorToScreenPixels(rect.midX - width / 2.0) + offset
            rect.size.width = width
        }

        let integralFont: UIFont?
        if let text = self.textLayout?.attributedText, text.length > 0 {
            integralFont = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? self.font
        } else {
            integralFont = self.font
        }
        guard !rect.isNull, !rect.isInfinite, rect.height > 0.0,
              let integralFont else { return rect }

        var caretFont = integralFont
        if let text = self.textLayout?.attributedText, text.length > 0 {
            let offset = self.offset(from: self.beginningOfDocument, to: position)
            let index = min(text.length - 1, max(0, offset - 1))
            caretFont = text.attribute(.font, at: index, effectiveRange: nil) as? UIFont ?? integralFont
        }
        let baseline = self.amountTextBaseline(font: integralFont)
        let height = caretFont.capHeight * 1.24
        return CGRect(
            x: rect.minX,
            y: baseline - caretFont.capHeight / 2.0 - height / 2.0,
            width: rect.width,
            height: height
        )
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.point(inside: point, with: event), event?.type == .touches {
            self.interactionBegan?()
        }
        return super.hitTest(point, with: event)
    }

    var selectionRange: NSRange? {
        guard let selection = self.selectedTextRange else { return nil }
        let start = self.offset(from: self.beginningOfDocument, to: selection.start)
        let end = self.offset(from: self.beginningOfDocument, to: selection.end)
        return NSRange(location: start, length: end - start)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.semanticContentAttribute = .forceLeftToRight
        self.defaultTextAttributes[.paragraphStyle] = WalletSendAmountTextLayout.paragraphStyle
        self.groupingView.isUserInteractionEnabled = false
        self.groupingView.accessibilityElementsHidden = true
        self.addSubview(self.groupingView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .leftToRight
    }

    override func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        super.setBaseWritingDirection(.leftToRight, for: range)
    }

    override func deleteBackward() {
        if (self.text ?? "").isEmpty {
            self.emptyDeletion?()
        } else {
            super.deleteBackward()
        }
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        builder.remove(menu: .replace)
        builder.remove(menu: .lookup)
        builder.remove(menu: .learn)
        builder.remove(menu: .share)
        if #available(iOS 17.0, *) {
            builder.remove(menu: .autoFill)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if #available(iOS 15.0, *), action == #selector(captureTextFromCamera(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    func update(layout: WalletSendAmountTextLayout, selection: NSRange?) {
        self.textLayout = layout
        let renderedText = NSMutableAttributedString(attributedString: layout.attributedText)
        if !self.rendersText {
            renderedText.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: renderedText.length))
        }
        if self.attributedText?.isEqual(to: renderedText) != true {
            self.attributedText = renderedText
        }
        self.groupingView.isHidden = !self.rendersText
        if let selection {
            let textLength = layout.attributedText.length
            let start = min(textLength, max(0, selection.location))
            let end = start + min(textLength - start, max(0, selection.length))
            if self.selectionRange != NSRange(location: start, length: end - start),
               let startPosition = self.position(from: self.beginningOfDocument, offset: start),
               let endPosition = self.position(from: self.beginningOfDocument, offset: end) {
                self.selectedTextRange = self.textRange(from: startPosition, to: endPosition)
            }
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.groupingView.frame = self.bounds
        self.bringSubviewToFront(self.groupingView)
        guard let textLayout = self.textLayout else { return }
        while self.groupingLabels.count > textLayout.groupingPositions.count {
            self.groupingLabels.removeLast().removeFromSuperview()
        }
        while self.groupingLabels.count < textLayout.groupingPositions.count {
            let label = UILabel()
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            self.groupingView.addSubview(label)
            self.groupingLabels.append(label)
        }
        let startCaret = self.nativeCaretRect(for: self.beginningOfDocument)
        let textOriginX: CGFloat
        let centerY: CGFloat
        if !startCaret.isNull, !startCaret.isInfinite, startCaret.height > 0.0 {
            textOriginX = startCaret.minX
            centerY = startCaret.midY
        } else {
            let textRect = self.isEditing ? self.editingRect(forBounds: self.bounds) : self.textRect(forBounds: self.bounds)
            textOriginX = textRect.minX
            centerY = textRect.midY
        }
        for (index, position) in textLayout.groupingPositions.enumerated() {
            let label = self.groupingLabels[index]
            label.attributedText = textLayout.groupingSeparator
            label.frame = CGRect(
                x: textOriginX + position - textLayout.groupingSeparatorSize.width,
                y: centerY - textLayout.groupingSeparatorSize.height / 2.0,
                width: textLayout.groupingSeparatorSize.width,
                height: textLayout.groupingSeparatorSize.height
            )
        }
    }
}

class WalletSendAmountField: UIView, UITextFieldDelegate {
    let contentView = UIView()
    var gramIcon = ComponentView<Empty>()
    let fiatIcon = ComponentView<Empty>()
    let textField = WalletSendAmountTextField(frame: .zero)
    let suffix = ComponentView<Empty>()
    let integralFont = WalletSendAmountFonts.integral
    let fractionalFont = WalletSendAmountFonts.fractional

    private let gramIconLayoutSize = CGSize(width: 44.0, height: 44.0)
    var gramAnimationSize: CGSize { return CGSize(width: 48.0, height: 48.0) }
    var fiatSymbolFont: UIFont { return Font.with(size: 48.0, design: .round, weight: .bold, traits: [.alternateDollarSign]) }
    private var fiatIconSize: CGSize = .zero
    private var fiatSymbolInkBounds: CGRect = .zero
    private var suffixSize: CGSize = .zero

    private(set) var mode: WalletSendInputMode = .gram
    private var amount: Int64 = 0
    private var rate: Double?
    private(set) var dateTimeFormat: PresentationDateTimeFormat?
    private(set) var isApplyingText = false
    private(set) var amountTextColor: UIColor = .black

    var usesAnimatedPresentation: Bool { return false }

    var amountUpdated: ((Int64) -> Void)?
    var focusUpdated: ((Bool) -> Void)?

    var isInputActive: Bool {
        return self.textField.isFirstResponder
    }

    var hasInputText: Bool {
        return !(self.textField.text ?? "").isEmpty
    }

    private var canEditAmount: Bool {
        guard self.isUserInteractionEnabled,
              let dateTimeFormat = self.dateTimeFormat, !dateTimeFormat.decimalSeparator.isEmpty else {
            return false
        }
        if self.mode == .fiat {
            guard let rate = self.rate, rate.isFinite, rate > 0.0 else { return false }
        }
        return true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.contentView)

        self.textField.font = self.integralFont
        self.textField.delegate = self
        self.textField.inputView = UIView(frame: .zero)
        self.textField.inputAssistantItem.leadingBarButtonGroups = []
        self.textField.inputAssistantItem.trailingBarButtonGroups = []
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.spellCheckingType = .no
        self.textField.smartQuotesType = .no
        self.textField.smartDashesType = .no
        self.textField.smartInsertDeleteType = .no
        self.textField.textContentType = nil
        if #available(iOS 17.0, *) {
            self.textField.inlinePredictionType = .no
        }
        if #available(iOS 18.0, *) {
            self.textField.writingToolsBehavior = .none
            self.textField.mathExpressionCompletionType = .no
        }
        self.textField.textAlignment = .left
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.textField.emptyDeletion = { [weak self] in
            let _ = self?.deleteBackward()
        }
        self.contentView.addSubview(self.textField)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.activateInput))
        self.addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func activateInput() {
        guard self.isUserInteractionEnabled else { return }
        self.textField.becomeFirstResponder()
    }

    @discardableResult
    func insertText(_ text: String) -> Bool {
        guard self.canEditAmount else { return false }
        self.activateInput()
        let range = self.textField.selectionRange ?? NSRange(location: (self.textField.text ?? "").utf16.count, length: 0)
        return self.replaceText(in: range, with: text)
    }

    @discardableResult
    func deleteBackward() -> Bool {
        guard self.canEditAmount else { return false }
        self.activateInput()
        let text = (self.textField.text ?? "") as NSString
        var range = self.textField.selectionRange ?? NSRange(location: text.length, length: 0)
        guard range.location != NSNotFound, range.location >= 0, range.location <= text.length,
              range.length >= 0, range.length <= text.length - range.location else { return false }
        if range.length == 0 {
            guard range.location > 0 else {
                if text.length == 0 {
                    self.inputRejected()
                }
                return false
            }
            range = text.rangeOfComposedCharacterSequence(at: range.location - 1)
        }
        return self.replaceText(in: range, with: "")
    }

    func inputRejected() {
    }

    func amountTextLayout(_ text: String) -> WalletSendAmountTextLayout {
        let textColor = self.amountTextColor
        let decimalSeparator = self.dateTimeFormat?.decimalSeparator ?? "."
        let groupingSeparator = self.dateTimeFormat?.groupingSeparator ?? ""
        let attributedText = NSMutableAttributedString(attributedString: tonAmountAttributedString(
            text,
            integralFont: self.integralFont,
            fractionalFont: self.fractionalFont,
            color: textColor,
            decimalSeparator: decimalSeparator
        ))
        attributedText.addAttribute(.paragraphStyle, value: WalletSendAmountTextLayout.paragraphStyle, range: NSRange(location: 0, length: attributedText.length))
        let separatorText = NSAttributedString(string: groupingSeparator, font: self.integralFont, textColor: textColor)
        let separatorLine = CTLineCreateWithAttributedString(separatorText)
        let separatorSize = CGSize(
            width: ceil(CGFloat(CTLineGetTypographicBounds(separatorLine, nil, nil, nil))),
            height: ceil(self.integralFont.lineHeight)
        )
        let decimalRange = (text as NSString).range(of: decimalSeparator)
        let integralLength = decimalRange.location == NSNotFound ? attributedText.length : decimalRange.location
        var groupingOffsets: [Int] = []
        if !groupingSeparator.isEmpty, integralLength > 3 {
            groupingOffsets = Array(stride(from: integralLength - 3, through: 1, by: -3).reversed())
            for offset in groupingOffsets {
                attributedText.addAttribute(.kern, value: separatorSize.width, range: NSRange(location: offset - 1, length: 1))
            }
        }
        var groupingPositions: [CGFloat] = []
        if !groupingOffsets.isEmpty {
            let line = CTLineCreateWithAttributedString(attributedText)
            for runValue in CTLineGetGlyphRuns(line) as NSArray {
                let run = runValue as! CTRun
                let glyphCount = CTRunGetGlyphCount(run)
                guard glyphCount > 0 else { continue }
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var indices = [CFIndex](repeating: 0, count: glyphCount)
                let range = CFRangeMake(0, glyphCount)
                CTRunGetPositions(run, range, &positions)
                CTRunGetStringIndices(run, range, &indices)
                for index in 0 ..< glyphCount where groupingOffsets.contains(indices[index]) {
                    groupingPositions.append(positions[index].x)
                }
            }
        }
        return WalletSendAmountTextLayout(
            attributedText: attributedText,
            groupingSeparator: separatorText,
            groupingSeparatorSize: separatorSize,
            groupingPositions: groupingPositions
        )
    }

    func willApplyText(_ text: String, selection: NSRange?) {
    }

    func inputAccepted(_ insertedText: String) {
    }

    private func applyText(_ text: String, selection: NSRange?) {
        self.isApplyingText = true
        self.willApplyText(text, selection: selection)
        self.textField.update(layout: self.amountTextLayout(text), selection: selection)
        self.isApplyingText = false
        self.setNeedsLayout()
    }

    @objc private func textChanged() {
        guard !self.isApplyingText, let dateTimeFormat = self.dateTimeFormat else {
            return
        }
        self.applyText(self.textField.text ?? "", selection: self.textField.selectionRange)
        if let amount = walletSendNanograms(
            text: self.textField.text ?? "",
            mode: self.mode,
            rate: self.rate,
            decimalSeparator: dateTimeFormat.decimalSeparator
        ) {
            self.amount = amount
            self.amountUpdated?(amount)
        }
        self.setNeedsLayout()
    }

    func setAmount(_ amount: Int64) {
        self.amount = amount
        guard let dateTimeFormat = self.dateTimeFormat else {
            return
        }
        let inputText = walletSendInputText(
            amount: amount,
            mode: self.mode,
            rate: self.rate,
            dateTimeFormat: dateTimeFormat
        )
        self.applyText(inputText, selection: NSRange(location: inputText.utf16.count, length: 0))
    }

    func update(
        mode: WalletSendInputMode,
        amount: Int64,
        rate: Double?,
        fiatCurrency: WalletContext.FiatCurrency,
        dateTimeFormat: PresentationDateTimeFormat,
        theme: PresentationTheme,
        isVisible: Bool,
        transition: ComponentTransition
    ) {
        let modeChanged = self.mode != mode
        let amountChanged = self.amount != amount
        let rateChanged = self.rate != rate
        let previousDecimalSeparator = self.dateTimeFormat?.decimalSeparator
        let decimalSeparatorChanged = self.dateTimeFormat?.decimalSeparator != dateTimeFormat.decimalSeparator
        let groupingSeparatorChanged = self.dateTimeFormat?.groupingSeparator != dateTimeFormat.groupingSeparator
        let textColorChanged = !self.amountTextColor.isEqual(theme.list.itemPrimaryTextColor)
        let previousSelection = self.textField.selectionRange
        self.mode = mode
        self.amount = amount
        self.rate = rate
        self.dateTimeFormat = dateTimeFormat

        if textColorChanged {
            self.amountTextColor = theme.list.itemPrimaryTextColor
            self.textField.textColor = theme.list.itemPrimaryTextColor
        }
        let currencyColor = UIColor(rgb: mode == .gram ? (theme.overallDarkAppearance ? 0x30A1F5 : 0x0088FF) : 0x219949)
        self.textField.caretColor = currencyColor
        
        self.textField.attributedPlaceholder = self.amountTextLayout("0").attributedText

        let suffixText: String
        switch mode {
        case .gram:
            suffixText = "GRAM"
        case .fiat:
            suffixText = fiatCurrency.code
        }

        let currencyTransition: ComponentTransition = self.gramIcon.view == nil ? .immediate : transition
        let iconBlurRadius: CGFloat = 6.0
        self.updateGramIcon(theme: theme, isVisible: isVisible, transition: currencyTransition)

        let currencySymbol = fiatCurrency.symbol
        self.fiatSymbolInkBounds = WalletSendAmountGlyphMetrics.inkBounds(currencySymbol, font: self.fiatSymbolFont)
        self.fiatIconSize = self.fiatIcon.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: currencySymbol,
                    font: self.fiatSymbolFont,
                    textColor: UIColor(rgb: 0x219949)
                )),
                maximumNumberOfLines: 1
            )),
            environment: {},
            containerSize: CGSize(width: 40.0, height: 74.0)
        )
        if let fiatIconView = self.fiatIcon.view {
            if fiatIconView.superview == nil {
                self.contentView.addSubview(fiatIconView)
            }
            if !self.usesAnimatedPresentation {
                currencyTransition.setAlpha(view: fiatIconView, alpha: mode == .fiat ? 1.0 : 0.0)
                currencyTransition.setBlur(layer: fiatIconView.layer, radius: mode == .fiat ? 0.0 : iconBlurRadius)
            }
        }

        self.suffixSize = self.suffix.update(
            transition: currencyTransition,
            component: AnyComponent(AnimatedTextComponent(
                font: self.fractionalFont,
                color: currencyColor,
                items: [
                    AnimatedTextComponent.Item(id: "currency", content: .text(suffixText))
                ],
                noDelay: true,
                blur: true
            )),
            environment: {},
            containerSize: CGSize(width: 150.0, height: 74.0)
        )
        if let suffixView = self.suffix.view, suffixView.superview == nil {
            self.contentView.addSubview(suffixView)
        }

        if modeChanged || ((amountChanged || rateChanged) && !self.textField.isFirstResponder) {
            self.setAmount(amount)
        } else if textColorChanged || decimalSeparatorChanged || groupingSeparatorChanged {
            var text = self.textField.text ?? ""
            var selection = previousSelection
            if decimalSeparatorChanged, let previousDecimalSeparator, !previousDecimalSeparator.isEmpty {
                let range = (text as NSString).range(of: previousDecimalSeparator)
                if range.location != NSNotFound {
                    text = (text as NSString).replacingCharacters(in: range, with: dateTimeFormat.decimalSeparator)
                    if let previousSelection = selection {
                        let replacementLength = dateTimeFormat.decimalSeparator.utf16.count
                        func updatedOffset(_ offset: Int) -> Int {
                            if offset <= range.location { return offset }
                            if offset < NSMaxRange(range) { return range.location + replacementLength }
                            return offset + replacementLength - range.length
                        }
                        let start = updatedOffset(previousSelection.location)
                        let end = updatedOffset(NSMaxRange(previousSelection))
                        selection = NSRange(location: start, length: end - start)
                    }
                }
            }
            self.applyText(text, selection: selection)
        }
        self.setNeedsLayout()
    }

    func updateGramIcon(theme: PresentationTheme, isVisible: Bool, transition: ComponentTransition) {
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var iconLayoutSize = CGSize(width: 40.0, height: 40.0)
        var iconSpacing: CGFloat = self.mode == .fiat ? 0.0 : 2.0
        let suffixSpacing: CGFloat = 3.0
        let displayText = (self.textField.text ?? "").isEmpty ? "0" : (self.textField.text ?? "")
        let displayTextBounds = self.amountTextLayout(displayText).attributedText.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.bounds.height),
            options: [],
            context: nil
        )
        let textWidth = max(31.0, ceil(displayTextBounds.width) + 5.0)
        let iconWidth = self.mode == .gram ? self.gramIconLayoutSize.width : self.fiatIconSize.width

        let usesFiatInkLayout = self.usesAnimatedPresentation && self.mode == .fiat && !self.fiatSymbolInkBounds.isEmpty
        if usesFiatInkLayout {
            self.textField.bounds = CGRect(x: 0.0, y: 0.0, width: textWidth, height: self.bounds.height)
            self.textField.layoutIfNeeded()
            let caret = self.textField.nativeCaretRect(for: self.textField.beginningOfDocument)
            let textRect = self.textField.isEditing ? self.textField.editingRect(forBounds: self.textField.bounds) : self.textField.textRect(forBounds: self.textField.bounds)
            let textInset = !caret.isNull && !caret.isInfinite && caret.height > 0.0 ? caret.minX : textRect.minX
            let firstDigitBounds = WalletSendAmountGlyphMetrics.inkBounds(String(displayText.prefix(1)), font: self.integralFont)
            iconLayoutSize.width = self.fiatSymbolInkBounds.width
            iconSpacing = 8.3 - max(0.0, firstDigitBounds.minX) - textInset
        }
        let iconLeadingInset = usesFiatInkLayout ? 0.0 : max(0.0, -floorToScreenPixels((iconLayoutSize.width - iconWidth) / 2.0))
        let totalWidth = iconLeadingInset + iconLayoutSize.width + iconSpacing + textWidth + suffixSpacing + self.suffixSize.width
        let scale = min(1.0, self.bounds.width / totalWidth)
        self.contentView.bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: self.bounds.height))
        self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)

        var x = iconLeadingInset
        let centerY = self.bounds.height / 2.0

        if let gramIconView = self.gramIcon.view {
            gramIconView.frame = CGRect(
                origin: CGPoint(
                    x: x + floorToScreenPixels((iconLayoutSize.width - self.gramAnimationSize.width) / 2.0) - 1.0,
                    y: floorToScreenPixels(centerY - self.gramAnimationSize.height / 2.0) - 1.0
                ),
                size: self.gramAnimationSize
            )
        }
        if let fiatIconView = self.fiatIcon.view {
            fiatIconView.frame = CGRect(
                origin: CGPoint(
                    x: usesFiatInkLayout ? x - self.fiatSymbolInkBounds.minX : x + floorToScreenPixels((iconLayoutSize.width - self.fiatIconSize.width) / 2.0),
                    y: floorToScreenPixels(centerY - self.fiatIconSize.height / 2.0)
                ),
                size: self.fiatIconSize
            )
        }
        x += iconLayoutSize.width + iconSpacing
        self.textField.frame = CGRect(
            origin: CGPoint(x: x, y: 0.0),
            size: CGSize(width: textWidth, height: self.bounds.height)
        )
        if self.usesAnimatedPresentation, let fiatIconView = self.fiatIcon.view as? TextView,
           let line = fiatIconView.cachedLayout?.linesRects().first {
            let amountBaseline = self.textField.frame.minY + self.textField.amountTextBaseline(font: self.integralFont)
            let symbolBaseline = amountBaseline - self.integralFont.capHeight / 2.0 + self.fiatSymbolFont.capHeight / 2.0 + 3.45
            fiatIconView.frame.origin.y = floorToScreenPixels(symbolBaseline - line.minY)
            if usesFiatInkLayout {
                fiatIconView.frame.origin.x -= line.minX
            }
        }
        x += textWidth + suffixSpacing
        if let suffixView = self.suffix.view {
            suffixView.frame = CGRect(
                origin: CGPoint(x: x, y: floorToScreenPixels(centerY - self.suffixSize.height / 2.0 + 6.0)),
                size: self.suffixSize
            )
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.setNeedsLayout()
        self.focusUpdated?(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.setNeedsLayout()
        self.focusUpdated?(false)
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        textField.setNeedsLayout()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        self.replaceText(in: range, with: string)
        return false
    }

    @discardableResult
    private func replaceText(in range: NSRange, with string: String) -> Bool {
        guard self.canEditAmount, let dateTimeFormat = self.dateTimeFormat else { return false }
        let text = self.textField.text ?? ""
        let length = (text as NSString).length
        guard range.location != NSNotFound, range.location >= 0, range.location <= length,
              range.length >= 0, range.length <= length - range.location,
              !string.isEmpty || range.length > 0 else { return false }

        if text == "0" + dateTimeFormat.decimalSeparator, range.location == length, range.length == 0,
           string == dateTimeFormat.decimalSeparator || string == "." || string == "," {
            return false
        }

        guard let edit = walletSendReplacingAmountText(
            text, range: range, replacement: string,
            mode: self.mode, rate: self.rate, decimalSeparator: dateTimeFormat.decimalSeparator
        ) else {
            self.inputRejected()
            return false
        }
        self.applyText(edit.text, selection: edit.selection)
        self.inputAccepted(string)
        self.textChanged()
        return true
    }
}
