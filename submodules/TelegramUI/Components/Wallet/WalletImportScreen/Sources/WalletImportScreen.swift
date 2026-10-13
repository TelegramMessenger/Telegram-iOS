import PasscodeCore
import Foundation
import LottieSettings
import UIKit
import Display
import AccountContext
import Markdown
import ComponentFlow
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent
import ButtonComponent
import SegmentControlComponent
import WalletContext
import SwiftSignalKit
import WalletAuthorizationUI
import AlertComponent

private func parseWalletPastedWords(_ text: String) -> [String] {
    let quotes = CharacterSet(charactersIn: "\"'“”‘’«»")
    let leadingFormatting = "•-–—*\"'“”‘’«»"
    func stripFormatting(_ token: String) -> String {
        return String(token.drop(while: { leadingFormatting.contains($0) }))
            .trimmingCharacters(in: quotes)
    }

    var words: [(number: Int?, word: String)] = []
    var pendingNumber: Int?
    var hasExtraNumbers = false
    for sourceToken in text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }) {
        var token = stripFormatting(String(sourceToken))
        guard !token.isEmpty else {
            continue
        }

        var numberToken = token[...]
        let closingBracket: Character?
        if numberToken.first == "(" {
            closingBracket = ")"
            numberToken = numberToken.dropFirst()
        } else if numberToken.first == "[" {
            closingBracket = "]"
            numberToken = numberToken.dropFirst()
        } else {
            closingBracket = nil
        }
        let digits = numberToken.prefix(while: { ("0" ... "9").contains($0) })
        if !digits.isEmpty {
            let suffix = numberToken.dropFirst(digits.count)
            var wordAfterNumber: Substring?
            if let closingBracket {
                if suffix.first == closingBracket {
                    wordAfterNumber = suffix.dropFirst()
                }
            } else if suffix.isEmpty {
                wordAfterNumber = suffix
            } else if suffix.first == "." || suffix.first == ")" || suffix.first == ":" {
                wordAfterNumber = suffix.dropFirst()
            }
            if let wordAfterNumber {
                if pendingNumber != nil {
                    hasExtraNumbers = true
                }
                // An overflowing number still counts as numbering, but cannot be sorted.
                pendingNumber = Int(digits) ?? 0
                token = stripFormatting(String(wordAfterNumber))
            }
        }

        if !token.isEmpty {
            words.append((number: pendingNumber, word: token.lowercased()))
            pendingNumber = nil
        }
    }

    // OCR may read two columns row by row. Only reorder a complete, unambiguous list.
    if (words.count == 12 || words.count == 24) && !hasExtraNumbers && pendingNumber == nil {
        let numbers = Set(words.compactMap { $0.number })
        if numbers == Set(1 ... words.count) {
            words.sort { ($0.number ?? 0) < ($1.number ?? 0) }
        }
    }
    return words.map { $0.word }
}

private final class WalletImportScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let mode: WalletImportScreenMode
    let verificationIndices: [Int]
    let completion: (() -> Void)?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletImportScreenMode,
        verificationIndices: [Int],
        completion: (() -> Void)?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.mode = mode
        self.verificationIndices = verificationIndices
        self.completion = completion
    }

    static func ==(lhs: WalletImportScreenComponent, rhs: WalletImportScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.mode == rhs.mode
            && lhs.verificationIndices == rhs.verificationIndices
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private final class WordTextField: UITextField {
            var emptyBackspace: (() -> Void)?
            var pastedText: ((String) -> Bool)?
            var shouldBecomeFirstResponder: (() -> Bool)?

            override func becomeFirstResponder() -> Bool {
                guard self.shouldBecomeFirstResponder?() ?? true else {
                    return false
                }
                let shouldSelectAll = !self.isFirstResponder && self.text?.isEmpty == false
                let result = super.becomeFirstResponder()
                if result && shouldSelectAll {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.isFirstResponder else {
                            return
                        }
                        self.selectAll(nil)
                    }
                }
                return result
            }

            override func deleteBackward() {
                if self.text?.isEmpty != false {
                    self.emptyBackspace?()
                }
                super.deleteBackward()
            }

            override func paste(_ sender: Any?) {
                if let text = UIPasteboard.general.string, self.pastedText?(text) == true {
                    return
                }
                super.paste(sender)
            }
        }

        private final class WordFieldView: UIView, UITextFieldDelegate {
            let index: Int
            private var displayNumber: Int

            private let backgroundLayer = SimpleShapeLayer()
            private let numberText = ComponentView<Empty>()
            private let pasteButton = ComponentView<Empty>()
            let textField = WordTextField()

            var textChanged: ((Int, String) -> Void)?
            var editingChanged: ((Int, Bool) -> Void)?
            var shouldBeginEditing: ((Int) -> Bool)?
            var returnPressed: ((Int) -> Void)?
            var spacePressed: ((Int) -> Void)?
            var pasteWords: ((Int, [String]) -> Bool)?
            var emptyBackspace: ((Int) -> Void)?
            var pastePressed: (() -> Void)?

            init(index: Int, displayNumber: Int, wordCount: Int) {
                self.index = index
                self.displayNumber = displayNumber

                super.init(frame: CGRect())

                self.backgroundLayer.lineWidth = 1.0
                self.backgroundLayer.fillColor = UIColor.clear.cgColor
                self.backgroundLayer.strokeColor = UIColor.clear.cgColor
                self.layer.addSublayer(self.backgroundLayer)

                self.textField.delegate = self
                self.textField.font = Font.regular(17.0)
                self.textField.borderStyle = .none
                self.textField.backgroundColor = .clear
                self.textField.keyboardType = .asciiCapable
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .none
                self.textField.spellCheckingType = .no
                self.textField.clearButtonMode = .whileEditing
                self.textField.returnKeyType = index == wordCount - 1 ? .done : .next
                self.textField.enablesReturnKeyAutomatically = false
                if #available(iOS 11.0, *) {
                    self.textField.smartDashesType = .no
                    self.textField.smartQuotesType = .no
                    self.textField.smartInsertDeleteType = .no
                }
                self.textField.addTarget(self, action: #selector(self.textFieldTextChanged), for: .editingChanged)
                self.textField.shouldBecomeFirstResponder = { [weak self] in
                    guard let self else {
                        return true
                    }
                    return self.shouldBeginEditing?(self.index) ?? true
                }
                self.textField.emptyBackspace = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.emptyBackspace?(self.index)
                }
                self.textField.pastedText = { [weak self] text in
                    guard let self else {
                        return false
                    }
                    let words = parseWalletPastedWords(text)
                    guard !words.isEmpty else {
                        return true
                    }
                    return self.pasteWords?(self.index, words) ?? false
                }

                self.addSubview(self.textField)
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            func updateConfiguration(displayNumber: Int, wordCount: Int) {
                self.displayNumber = displayNumber
                self.textField.returnKeyType = self.index == wordCount - 1 ? .done : .next
            }

            func update(
                theme: PresentationTheme,
                strings: PresentationStrings,
                isInvalid: Bool,
                displaysPasteButton: Bool,
                size: CGSize
            ) {
                let transition = ComponentTransition.easeInOut(duration: 0.2)

                let backgroundFrame = CGRect(origin: .zero, size: size)
                transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
                transition.setShapeLayerPath(
                    layer: self.backgroundLayer,
                    path: UIBezierPath(roundedRect: backgroundFrame, cornerRadius: 26.0).cgPath
                )
                transition.setShapeLayerFillColor(
                    layer: self.backgroundLayer,
                    color: isInvalid
                        ? theme.list.itemInputField.backgroundColor.mixedWith(theme.list.itemDestructiveColor, alpha: 0.03)
                        : theme.list.itemInputField.backgroundColor
                )
                transition.setShapeLayerStrokeColor(
                    layer: self.backgroundLayer,
                    color: isInvalid ? theme.list.itemDestructiveColor : .clear
                )

                let numberColor = self.textField.isFirstResponder || self.textField.text?.isEmpty == false
                    ? theme.list.itemPrimaryTextColor
                    : theme.list.itemSecondaryTextColor
                self.textField.textColor = theme.list.itemPrimaryTextColor
                self.textField.tintColor = theme.list.itemAccentColor
                self.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance

                let numberInset: CGFloat = 10.0
                let numberWidth: CGFloat = 26.0
                let numberTextSpacing: CGFloat = 5.0
                let numberTextSize = self.numberText.update(
                    transition: transition,
                    component: AnyComponent(Text(
                        text: "\(self.displayNumber).",
                        font: Font.with(size: 17.0, traits: .monospacedNumbers),
                        color: .white,
                        tintColor: numberColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: numberWidth, height: size.height)
                )
                if let numberTextView = self.numberText.view {
                    if numberTextView.superview == nil {
                        self.insertSubview(numberTextView, belowSubview: self.textField)
                    }
                    numberTextView.frame = CGRect(
                        x: numberInset + numberWidth - numberTextSize.width,
                        y: floor((size.height - numberTextSize.height) / 2.0) + 1.0,
                        width: numberTextSize.width,
                        height: numberTextSize.height
                    )
                }
                let textFieldMinX = numberInset + numberWidth + numberTextSpacing
                var textFieldMaxX = size.width - 9.0
                if displaysPasteButton {
                    let pasteButtonHeight: CGFloat = 28.0
                    let pasteButtonSize = self.pasteButton.update(
                        transition: transition,
                        component: AnyComponent(ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .legacy,
                                color: theme.overallDarkAppearance
                                    ? theme.actionSheet.opaqueItemBackgroundColor
                                    : theme.list.plainBackgroundColor,
                                foreground: theme.list.itemAccentColor,
                                pressedColor: theme.list.itemInputField.backgroundColor,
                                cornerRadius: pasteButtonHeight / 2.0
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable("paste"),
                                component: AnyComponent(Text(
                                    text: strings.Common_Paste,
                                    font: Font.semibold(15.0),
                                    color: theme.list.itemAccentColor
                                ))
                            ),
                            restrictContentAnimations: true,
                            contentInsets: UIEdgeInsets(
                                top: 0.0,
                                left: 16.0,
                                bottom: 0.0,
                                right: 16.0
                            ),
                            fitToContentWidth: true,
                            isEnabled: true,
                            displaysProgress: false,
                            action: { [weak self] in
                                self?.pastePressed?()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(
                            width: max(1.0, size.width - 16.0),
                            height: pasteButtonHeight
                        )
                    )
                    if let pasteButtonView = self.pasteButton.view {
                        var transition = transition
                        if pasteButtonView.superview == nil {
                            transition = .immediate
                            self.addSubview(pasteButtonView)
                        }
                        let pasteButtonFrame = CGRect(
                            x: size.width - 12.0 - pasteButtonSize.width,
                            y: floor((size.height - pasteButtonSize.height) / 2.0),
                            width: pasteButtonSize.width,
                            height: pasteButtonSize.height
                        )
                        transition.setFrame(view: pasteButtonView, frame: pasteButtonFrame)
                        textFieldMaxX = pasteButtonFrame.minX - 4.0
                    }
                } else {
                    self.pasteButton.view?.removeFromSuperview()
                }
                self.textField.frame = CGRect(
                    x: textFieldMinX,
                    y: 0.0,
                    width: max(0.0, textFieldMaxX - textFieldMinX),
                    height: size.height
                )
            }

            func setText(_ text: String) {
                self.textField.text = text
            }

            @objc private func textFieldTextChanged() {
                let currentText = self.textField.text ?? ""
                let normalizedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if currentText != normalizedText {
                    self.textField.text = normalizedText
                }
                self.textChanged?(self.index, normalizedText)
            }

            func textFieldDidBeginEditing(_ textField: UITextField) {
                self.editingChanged?(self.index, true)
            }

            func textFieldDidEndEditing(_ textField: UITextField) {
                self.editingChanged?(self.index, false)
            }

            func textFieldShouldReturn(_ textField: UITextField) -> Bool {
                self.returnPressed?(self.index)
                return false
            }

            func textFieldShouldClear(_ textField: UITextField) -> Bool {
                self.textChanged?(self.index, "")
                return true
            }

            func textField(
                _ textField: UITextField,
                shouldChangeCharactersIn range: NSRange,
                replacementString string: String
            ) -> Bool {
                if string == " " {
                    self.spacePressed?(self.index)
                    return false
                }
                let containsWhitespace = string.contains(where: { $0.isWhitespace })
                guard string.count > 1 || containsWhitespace else {
                    return true
                }

                let words = parseWalletPastedWords(string)
                guard !words.isEmpty else {
                    return false
                }
                if containsWhitespace || words.count > 1 || words[0] != string.lowercased() {
                    return !(self.pasteWords?(self.index, words) ?? false)
                }
                return true
            }
        }

        private let scrollView = ScrollView()
        private let animation = ComponentView<Empty>()
        private let navigationTitle = ComponentView<Empty>()
        private let titleTransformContainer = UIView()
        private let body = ComponentView<Empty>()
        private let wordCountControl = ComponentView<Empty>()
        private var wordFields: [WordFieldView] = []
        private var wordSuggestionView: ComponentHostView<Empty>?
        private let button = ComponentView<Empty>()

        private let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        private var didRequestInitialFocus = false

        private weak var componentState: EmptyComponentState?
        private var environment: EnvironmentType?
        private var component: WalletImportScreenComponent?
        private let operationDisposable = MetaDisposable()
        private var flowSession: PasscodeSession?
        private var flowGeneration: UInt64 = 0
        private let discardDisposable = MetaDisposable()
        private var isImporting = false
        private var activePreparedRecoveryPhraseImport: WalletContext.PreparedRecoveryPhraseImport?
        private var preparedImportWords: [String]?
        private var didCompleteVerification = false
        private var isVerificationInProgress = false
        private var words = Array(repeating: "", count: 12)
        private var isImportPhraseValid = false
        private var mismatchedWordIndices = Set<Int>()
        private var activeWordIndex: Int?
        private var validationFocusIndex: Int?
        private var wordSuggestions: [String] = []
        private var hasInvalidWordSuggestion = false
        private var invalidWordSuggestionPulseId = 0
        private var wordSuggestionFrame: CGRect?
        private var hasPasteboardText = UIPasteboard.general.hasStrings
        private var scrollToBottomAfterPaste = false

        override init(frame: CGRect) {
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.keyboardDismissMode = .interactive
            self.scrollView.alwaysBounceVertical = true
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }

            self.titleTransformContainer.isUserInteractionEnabled = false

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIPasteboard.changedNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            self.setupWordInputFields(displayNumbers: Array(1 ... 12), preserving: [])
        }

        private func setupWordInputFields(
            displayNumbers: [Int],
            preserving existingWords: [String],
            preservingFocus: Bool = false
        ) {
            guard !displayNumbers.isEmpty else {
                return
            }
            let count = displayNumbers.count
            let preservedActiveWordIndex = preservingFocus
                ? self.wordFields.firstIndex(where: { $0.textField.isFirstResponder })
                : nil
            self.words = Array(repeating: "", count: count)
            for index in 0 ..< min(existingWords.count, count) {
                self.words[index] = existingWords[index]
            }
            self.updateImportPhraseValidity()
            self.mismatchedWordIndices.removeAll()
            if let preservedActiveWordIndex, preservedActiveWordIndex < count {
                self.activeWordIndex = preservedActiveWordIndex
            } else {
                self.activeWordIndex = nil
            }
            self.wordSuggestions = []
            self.hasInvalidWordSuggestion = false
            self.wordSuggestionFrame = nil

            if self.wordFields.count > count {
                for field in self.wordFields[count...] {
                    field.removeFromSuperview()
                }
                self.wordFields.removeSubrange(count...)
            }

            while self.wordFields.count < count {
                let index = self.wordFields.count
                let field = WordFieldView(
                    index: index,
                    displayNumber: displayNumbers[index],
                    wordCount: count
                )
                field.textChanged = { [weak self] index, text in
                    self?.wordTextChanged(index: index, text: text)
                }
                field.editingChanged = { [weak self] index, isEditing in
                    self?.wordEditingChanged(index: index, isEditing: isEditing)
                }
                field.shouldBeginEditing = { [weak self] index in
                    return self?.shouldBeginEditingWord(at: index) ?? true
                }
                field.returnPressed = { [weak self] index in
                    self?.handleReturn(from: index, submitOnLastField: true)
                }
                field.spacePressed = { [weak self] index in
                    self?.handleReturn(from: index, submitOnLastField: false)
                }
                field.pasteWords = { [weak self] index, words in
                    return self?.insertWords(words, from: index) ?? false
                }
                field.emptyBackspace = { [weak self] index in
                    self?.moveFocusBackward(from: index)
                }
                field.pastePressed = { [weak self] in
                    self?.pasteRecoveryPhrase()
                }
                self.wordFields.append(field)
            }

            for index in self.wordFields.indices {
                let field = self.wordFields[index]
                field.updateConfiguration(
                    displayNumber: displayNumbers[index],
                    wordCount: count
                )
                if field.textField.text != self.words[index] {
                    field.setText(self.words[index])
                }
            }
            if self.activeWordIndex != nil {
                self.updateWordSuggestions()
            }
        }

        private func setWordCount(_ count: Int) {
            guard (count == 12 || count == 24), count != self.words.count else {
                return
            }
            self.setupWordInputFields(
                displayNumbers: Array(1 ... count),
                preserving: self.words,
                preservingFocus: true
            )
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.flowSession?.invalidate()
            if let prepared = self.activePreparedRecoveryPhraseImport,
               let walletContext = self.component?.walletContext {
                let _ = walletContext.discardRecoveryPhraseImport(prepared).start()
            }
            NotificationCenter.default.removeObserver(self)
            self.titleTransformContainer.removeFromSuperview()
            self.operationDisposable.dispose()
            self.discardDisposable.dispose()
        }

        fileprivate func endWalletFlow() {
            self.flowGeneration &+= 1
            self.operationDisposable.set(nil)
            self.flowSession?.invalidate()
            self.flowSession = nil
            if let prepared = self.activePreparedRecoveryPhraseImport {
                self.discardPreparedRecoveryPhraseImport(prepared)
            }
        }

        private func walletFlowAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if let session = self.flowSession, session.isValid {
                return .single(session)
            }
            let generation = self.flowGeneration
            return component.walletContext.beginWalletFlow(reason: self.isBackupEnableMode ? "enableBackup" : "importWallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.flowGeneration == generation else { session.invalidate(); return .fail(.authorizationCancelled) }
                self.flowSession?.invalidate()
                self.flowSession = session
                return .single(session)
            }
        }

        @objc private func pasteboardDidChange(_ notification: Notification) {
            let hasPasteboardText = UIPasteboard.general.hasStrings
            guard self.hasPasteboardText != hasPasteboardText else {
                return
            }
            self.hasPasteboardText = hasPasteboardText
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func setVerificationInProgress(_ inProgress: Bool) {
            guard self.isVerificationMode, self.isVerificationInProgress != inProgress else {
                return
            }
            self.isVerificationInProgress = inProgress
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            self.updateScrolling(transition: .immediate)
        }

        private var isActionEnabled: Bool {
            guard let component = self.component else {
                return false
            }
            switch component.mode {
            case .importWallet, .enterRecoveryPhrase, .enableBackup:
                return self.words.allSatisfy { word in
                    return !word.isEmpty && component.walletContext.isMnemonicWord(word)
                }
            case .verify:
                return self.words.allSatisfy { !$0.isEmpty }
            }
        }

        private var isVerificationMode: Bool {
            guard let component = self.component else {
                return false
            }
            if case .verify = component.mode {
                return true
            } else {
                return false
            }
        }

        private var isBackupEnableMode: Bool {
            if case .enableBackup? = self.component?.mode { return true }
            return false
        }

        private func updateImportPhraseValidity() {
            guard let component = self.component else {
                self.isImportPhraseValid = false
                return
            }
            self.isImportPhraseValid = component.walletContext.isMnemonicValid(words: self.words)
        }

        private func updateWordSuggestions() {
            guard let component = self.component,
                  let activeWordIndex,
                  self.words.indices.contains(activeWordIndex),
                  self.words[activeWordIndex].count >= 2 else {
                self.wordSuggestions = []
                self.hasInvalidWordSuggestion = false
                return
            }
            let word = self.words[activeWordIndex]
            let suggestions = component.walletContext.mnemonicWordSuggestions(
                for: word,
                limit: 3
            )
            if suggestions.isEmpty && !component.walletContext.isMnemonicWord(word) {
                self.wordSuggestions = []
                self.hasInvalidWordSuggestion = true
            } else if suggestions.count == 1, suggestions[0] == word {
                self.wordSuggestions = []
                self.hasInvalidWordSuggestion = false
            } else {
                self.wordSuggestions = suggestions
                self.hasInvalidWordSuggestion = false
            }
        }

        private func isInvalidWord(at index: Int) -> Bool {
            guard let component = self.component,
                  self.words.indices.contains(index) else {
                return false
            }
            let word = self.words[index]
            return !word.isEmpty && !component.walletContext.isMnemonicWord(word)
        }

        private func rejectInvalidWord(at index: Int) {
            guard self.wordFields.indices.contains(index) else {
                return
            }
            self.updateWordSuggestions()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.wordFields[index].layer.addShakeAnimation()
            HapticFeedback().error()
        }

        private func shouldBeginEditingWord(at index: Int) -> Bool {
            guard self.validationFocusIndex != index,
                  let activeWordIndex = self.activeWordIndex,
                  activeWordIndex != index,
                  self.isInvalidWord(at: activeWordIndex) else {
                return true
            }
            self.rejectInvalidWord(at: activeWordIndex)
            return false
        }

        private func focusInvalidWord(at index: Int) {
            guard self.wordFields.indices.contains(index) else {
                return
            }
            // Validation must be able to focus the first error even if the current word is invalid.
            self.validationFocusIndex = index
            let didBecomeFirstResponder = self.wordFields[index].textField.becomeFirstResponder()
            self.validationFocusIndex = nil
            if didBecomeFirstResponder {
                self.activeWordIndex = index
                self.updateWordSuggestions()
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.wordFields.indices.contains(index),
                          self.wordFields[index].textField.isFirstResponder else {
                        return
                    }
                    self.wordFields[index].textField.selectAll(nil)
                }
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func selectSuggestedWord(_ word: String, at index: Int, advanceFocus: Bool = true) {
            guard self.activeWordIndex == index,
                  self.words.indices.contains(index),
                  self.wordFields.indices.contains(index) else {
                return
            }
            let word = self.normalizeWord(word)
            self.words[index] = word
            self.wordFields[index].setText(word)
            self.mismatchedWordIndices.remove(index)
            self.wordSuggestions = []
            self.hasInvalidWordSuggestion = false
            self.updateImportPhraseValidity()
            self.componentState?.updated(transition: .immediate)
            if advanceFocus {
                self.advanceFocus(from: index)
            }
        }

        private func wordTextChanged(index: Int, text: String) {
            guard self.words.indices.contains(index) else {
                return
            }
            let previousWord = self.words[index]
            let word = self.normalizeWord(text)
            self.words[index] = word
            self.updateImportPhraseValidity()
            self.mismatchedWordIndices.remove(index)
            self.updateWordSuggestions()
            if word.count > previousWord.count && self.hasInvalidWordSuggestion {
                self.invalidWordSuggestionPulseId += 1
                HapticFeedback().impact()
            }
            self.componentState?.updated(transition: .immediate)
        }

        private func wordEditingChanged(index: Int, isEditing: Bool) {
            guard self.words.indices.contains(index) else {
                return
            }

            if isEditing {
                self.activeWordIndex = index
                self.updateWordSuggestions()
            } else {
                if self.activeWordIndex == index {
                    self.activeWordIndex = nil
                }
                let normalizedWord = self.normalizeWord(self.wordFields[index].textField.text ?? "")
                self.words[index] = normalizedWord
                self.wordFields[index].setText(normalizedWord)
                self.updateImportPhraseValidity()
                self.updateWordSuggestions()
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func handleReturn(from index: Int, submitOnLastField: Bool) {
            guard self.wordFields.indices.contains(index),
                  !self.isImporting,
                  !self.isVerificationInProgress,
                  !self.didCompleteVerification else {
                return
            }
            if self.activeWordIndex == index,
               !self.hasInvalidWordSuggestion,
               let firstSuggestion = self.wordSuggestions.first {
                self.selectSuggestedWord(firstSuggestion, at: index, advanceFocus: false)
            }
            if submitOnLastField && index == self.wordFields.count - 1 && self.isActionEnabled {
                self.performAction()
            } else {
                self.advanceFocus(from: index)
            }
        }

        private func advanceFocus(from index: Int) {
            guard self.wordFields.indices.contains(index) else {
                return
            }
            let currentWord = self.normalizeWord(self.wordFields[index].textField.text ?? "")
            guard !currentWord.isEmpty else {
                self.wordFields[index].layer.addShakeAnimation()
                HapticFeedback().error()
                return
            }
            guard !self.isInvalidWord(at: index) else {
                self.rejectInvalidWord(at: index)
                return
            }

            if index + 1 < self.wordFields.count {
                let _ = self.wordFields[index + 1].textField.becomeFirstResponder()
            } else {
                self.wordFields[index].textField.resignFirstResponder()
            }
        }

        private func moveFocusBackward(from index: Int) {
            guard index > 0 else {
                return
            }
            let _ = self.wordFields[index - 1].textField.becomeFirstResponder()
        }

        private func insertWords(_ sourceWords: [String], from index: Int) -> Bool {
            let normalizedWords = sourceWords
                .map(self.normalizeWord)
                .filter { !$0.isEmpty }
            guard !normalizedWords.isEmpty else {
                return false
            }

            let startIndex: Int
            let insertedWords: [String]
            if self.isVerificationMode {
                guard self.words.indices.contains(index) else {
                    return false
                }
                startIndex = index
                insertedWords = Array(normalizedWords.prefix(self.words.count - index))
            } else {
                if normalizedWords.count > 1 {
                    guard normalizedWords.count == 12 || normalizedWords.count == 24 else {
                        self.presentInvalidPhraseLength(count: normalizedWords.count)
                        return true
                    }
                    if normalizedWords.count != self.words.count {
                        self.setupWordInputFields(
                            displayNumbers: Array(1 ... normalizedWords.count),
                            preserving: []
                        )
                    }
                }
                startIndex = normalizedWords.count > 1 ? 0 : index
                insertedWords = normalizedWords
            }
            guard self.words.indices.contains(startIndex), insertedWords.count <= self.words.count - startIndex else {
                return false
            }
            for offset in insertedWords.indices {
                let targetIndex = startIndex + offset
                let word = insertedWords[offset]
                self.words[targetIndex] = word
                self.wordFields[targetIndex].setText(word)
                self.mismatchedWordIndices.remove(targetIndex)
            }

            self.updateImportPhraseValidity()
            self.updateWordSuggestions()
            let insertedIndices = startIndex ..< startIndex + insertedWords.count
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))

            let nextIndex = insertedIndices.upperBound
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if let firstInvalidIndex = insertedIndices.first(where: { self.isInvalidWord(at: $0) }) {
                    self.focusInvalidWord(at: firstInvalidIndex)
                } else if nextIndex < self.wordFields.count {
                    let _ = self.wordFields[nextIndex].textField.becomeFirstResponder()
                } else {
                    self.endEditing(true)
                }
            }
            return true
        }

        private func pasteRecoveryPhrase() {
            guard !self.isVerificationMode, let component = self.component else {
                return
            }
            guard let text = UIPasteboard.general.string else {
                self.hasPasteboardText = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }

            let words = parseWalletPastedWords(text)
            guard !words.isEmpty else {
                return
            }
            guard words.count == 12 || words.count == 24 else {
                self.presentInvalidPhraseLength(count: words.count)
                return
            }
            guard component.walletContext.isMnemonicValid(words: words) else {
                self.presentInvalidMnemonic()
                return
            }

            for field in self.wordFields where field.textField.isFirstResponder {
                field.textField.resignFirstResponder()
            }
            self.setupWordInputFields(
                displayNumbers: Array(1 ... words.count),
                preserving: words
            )
            self.scrollToBottomAfterPaste = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func presentInvalidPhraseLength(count: Int) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            HapticFeedback().error()
            if let activeWordIndex, self.wordFields.indices.contains(activeWordIndex) {
                self.wordFields[activeWordIndex].layer.addShakeAnimation()
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            controller.present(textAlertController(
                context: component.context,
                title: strings.Wallet_Import_InvalidPhraseTitle,
                text: self.isBackupEnableMode
                    ? strings.Wallet_Import_InvalidCurrentPhraseLength(String(count)).string
                    : strings.Wallet_Import_InvalidPhraseLength(String(count)).string,
                actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {
                })]
            ), in: .window(.root))
        }

        private func presentInvalidMnemonic() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            HapticFeedback().error()
            controller.present(textAlertController(
                context: component.context,
                title: strings.Wallet_Import_InvalidPhraseTitle,
                text: strings.Wallet_Import_InvalidPhraseText,
                actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {
                })]
            ), in: .window(.root))
        }

        private func normalizeWord(_ word: String) -> String {
            return word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        private func dismiss() {
            self.environment?.controller()?.dismiss()
        }

        private func performAction() {
            guard self.isActionEnabled else {
                return
            }
            if self.isVerificationMode {
                self.continueVerification()
            } else {
                self.importWallet()
            }
        }

        private func continueVerification() {
            guard let component = self.component,
                  case let .verify(phraseWords, _, allowsRepeatedCompletion) = component.mode,
                  component.verificationIndices.count == self.words.count,
                  !self.didCompleteVerification,
                  !self.isVerificationInProgress else {
                return
            }

            var mismatchedIndices: [Int] = []
            for fieldIndex in self.words.indices {
                let phraseIndex = component.verificationIndices[fieldIndex]
                guard phraseWords.indices.contains(phraseIndex) else {
                    mismatchedIndices.append(fieldIndex)
                    continue
                }
                if self.normalizeWord(self.words[fieldIndex]) != self.normalizeWord(phraseWords[phraseIndex]) {
                    mismatchedIndices.append(fieldIndex)
                }
            }

            self.mismatchedWordIndices = Set(mismatchedIndices)
            if mismatchedIndices.isEmpty {
                self.didCompleteVerification = true
                component.completion?()
                if allowsRepeatedCompletion {
                    self.didCompleteVerification = false
                }
                return
            }

            HapticFeedback().error()
            if let firstIndex = mismatchedIndices.first {
                self.focusInvalidWord(at: firstIndex)
                self.wordFields[firstIndex].layer.addShakeAnimation()
            }
        }

        private func importWallet() {
            guard !self.isImporting else {
                return
            }
            guard self.isImportPhraseValid else {
                self.presentInvalidMnemonic()
                return
            }
            self.performImport(words: self.words)
        }

        private func performImport(words: [String]) {
            guard let component = self.component else {
                return
            }
            if case let .enableBackup(expectedAddress) = component.mode {
                self.enableBackup(words: words, expectedAddress: expectedAddress)
                return
            }
            if component.mode == .enterRecoveryPhrase {
                if let prepared = self.activePreparedRecoveryPhraseImport, self.preparedImportWords == words {
                    self.processRecoveryPhraseImport(prepared)
                    return
                }
                self.prepareRecoveryPhraseImport(words: words)
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard let controller = self.environment?.controller() else {
                return
            }
            self.operationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization() |> mapToSignal { session in
                        component.walletContext.importWallet(words: words, password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    self?.endWalletFlow()
                    if let completion = component.completion {
                        completion()
                    } else {
                        self?.dismiss()
                    }
                },
                failed: { [weak self] error in
                    self?.finishImportWithError(error: error)
                }
            ))
        }

        private func prepareRecoveryPhraseImport(words: [String]) {
            guard let component = self.component else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            let cleanup: Signal<Void, WalletContext.WalletError>
            if let previous = self.activePreparedRecoveryPhraseImport {
                cleanup = component.walletContext.discardRecoveryPhraseImport(previous)
                self.activePreparedRecoveryPhraseImport = nil
                self.preparedImportWords = nil
            } else {
                cleanup = .single(())
            }
            self.operationDisposable.set((cleanup
            |> mapToSignal { [weak self] _ -> Signal<PasscodeSession, WalletContext.WalletError> in
                self?.walletFlowAuthorization() ?? .fail(.authorizationCancelled)
            }
            |> mapToSignal { session in
                component.walletContext.prepareRecoveryPhraseImport(words: words, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self else {
                    return
                }
                self.activePreparedRecoveryPhraseImport = prepared
                self.preparedImportWords = words
                self.processRecoveryPhraseImport(prepared)
            }, error: { [weak self] error in
                self?.finishImportWithError(error: error)
            }))
        }

        private func enableBackup(words: [String], expectedAddress: String) {
            guard let component = self.component, !self.isImporting else { return }
            self.isImporting = true
            self.endEditing(true)
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.operationDisposable.set((self.walletFlowAuthorization()
            |> mapToSignal { session in
                component.walletContext.enableBackup(expectedAddress: expectedAddress, words: words, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else { return }
                self.isImporting = false
                self.endWalletFlow()
                self.setupWordInputFields(displayNumbers: Array(1 ... self.words.count), preserving: [])
                if let completion = component.completion { completion() } else { self.dismiss() }
            }, error: { [weak self] error in
                self?.finishBackupEnableWithError(error, expectedAddress: expectedAddress)
            }))
        }

        private func finishBackupEnableWithError(_ error: WalletContext.WalletError, expectedAddress: String) {
            self.isImporting = false
            self.endWalletFlow()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard error != .authorizationCancelled,
                  let component = self.component, let controller = self.environment?.controller() else { return }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            let message = walletBackupEnableErrorMessage(error, strings: strings)
            var actions = [TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {})]
            switch error {
            case .rotationNotFound, .proofExpired, .network:
                actions.append(TextAlertAction(type: .defaultAction, title: strings.Wallet_Retry, action: { [weak self] in
                    guard let self else { return }
                    self.enableBackup(words: self.words, expectedAddress: expectedAddress)
                }))
            default:
                break
            }
            switch error {
            case .walletKeyMismatch, .storage(.identityMismatch), .proofInvalid, .invalidMnemonic, .rotationNotFound:
                actions.append(TextAlertAction(type: .defaultAction, title: strings.Wallet_Backup_EnterCurrentPhrase, action: { [weak self] in
                    guard let self else { return }
                    self.setupWordInputFields(displayNumbers: Array(1 ... self.words.count), preserving: [])
                    self.componentState?.updated(transition: .immediate)
                    let _ = self.wordFields.first?.textField.becomeFirstResponder()
                }))
            default:
                break
            }
            controller.present(textAlertController(context: component.context, title: message.title, text: message.text, actions: actions), in: .window(.root))
        }

        private func processRecoveryPhraseImport(_ prepared: WalletContext.PreparedRecoveryPhraseImport) {
            switch prepared.disposition {
            case .currentWallet:
                self.completeRecoveryPhraseImport(prepared, password: nil)
            case .replacement:
                self.endWalletFlow()
                self.isImporting = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentWrongSecretPhrase()
            }
        }

        private func presentRecoveryPhraseAlert(_ alert: AlertScreen, clearWordsOnDismiss: Bool = false) {
            guard let controller = self.environment?.controller() else {
                return
            }
            self.endEditing(true)
            alert.dismissed = { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.component?.mode == .enterRecoveryPhrase,
                          let controller = self.environment?.controller(),
                          controller.navigationController?.topViewController === controller,
                          self.window != nil,
                          !self.words.isEmpty else {
                        return
                    }
                    self.scrollToBottomAfterPaste = false
                    if clearWordsOnDismiss {
                        self.setupWordInputFields(displayNumbers: Array(1 ... self.words.count), preserving: [])
                        self.componentState?.updated(transition: .immediate)
                    }
                    let index = self.words.firstIndex(where: { $0.isEmpty }) ?? (self.words.count - 1)
                    guard self.wordFields.indices.contains(index), self.wordFields[index].textField.window != nil else {
                        return
                    }
                    let _ = self.wordFields[index].textField.becomeFirstResponder()
                }
            }
            controller.present(alert, in: .window(.root))
        }

        private func presentRecoveryPhraseExplanation() {
            guard let component = self.component, component.mode == .enterRecoveryPhrase else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            self.presentRecoveryPhraseAlert(AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(allowInputInset: true),
                content: [
                    AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(
                        content: .plain(strings.Wallet_Import_RecoveryExplanation)
                    )))
                ],
                actions: [AlertScreen.Action(title: strings.Common_OK, type: .default)]
            ))
        }

        private func presentWrongSecretPhrase() {
            guard let component = self.component,
                  case let .wallet(info) = component.walletContext.stateValue.phase else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            HapticFeedback().error()
            let theme = component.context.sharedContext.currentPresentationData.with { $0.theme }
            let addressFont = Font.with(size: 14.0, design: .monospace)
            let addressText = NSMutableAttributedString(string: "")
            var addressIndex = info.address.startIndex
            var groupIndex = 0
            while addressIndex < info.address.endIndex {
                let endIndex = info.address.index(addressIndex, offsetBy: 4, limitedBy: info.address.endIndex) ?? info.address.endIndex
                if groupIndex != 0 {
                    addressText.append(NSAttributedString(
                        string: groupIndex.isMultiple(of: 6) ? "\n" : " ",
                        font: addressFont,
                        textColor: theme.actionSheet.primaryTextColor
                    ))
                }
                addressText.append(NSAttributedString(
                    string: String(info.address[addressIndex ..< endIndex]),
                    font: addressFont,
                    textColor: groupIndex.isMultiple(of: 2)
                        ? theme.actionSheet.primaryTextColor
                        : theme.actionSheet.secondaryTextColor
                ))
                addressIndex = endIndex
                groupIndex += 1
            }
            self.presentRecoveryPhraseAlert(AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(allowInputInset: true),
                content: [
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: strings.Wallet_Import_WrongPhraseTitle))),
                    AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(
                        content: .plain(strings.Wallet_Import_WrongPhraseText)
                    ))),
                    AnyComponentWithIdentity(id: "address", component: AnyComponent(AlertTextComponent(
                        content: .attributed(addressText),
                        alignment: .center,
                        style: .background(.small),
                        insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
                    )))
                ],
                actions: [AlertScreen.Action(title: strings.Common_OK, type: .default)]
            ), clearWordsOnDismiss: true)
        }

        private func completeRecoveryPhraseImport(
            _ prepared: WalletContext.PreparedRecoveryPhraseImport,
            password: String?
        ) {
            guard let component = self.component else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.operationDisposable.set((self.walletFlowAuthorization()
            |> mapToSignal { session in
                component.walletContext.completeRecoveryPhraseImport(prepared, password: password, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                self?.finishRecoveryPhraseImport()
            }, error: { [weak self] error in
                self?.finishImportWithError(error: error)
            }))
        }

        private func discardPreparedRecoveryPhraseImport(_ prepared: WalletContext.PreparedRecoveryPhraseImport) {
            guard let component = self.component else {
                return
            }
            self.activePreparedRecoveryPhraseImport = nil
            self.preparedImportWords = nil
            self.discardDisposable.set(component.walletContext.discardRecoveryPhraseImport(prepared).start())
        }

        private func finishRecoveryPhraseImport() {
            guard let component = self.component else {
                return
            }
            self.activePreparedRecoveryPhraseImport = nil
            self.preparedImportWords = nil
            self.endWalletFlow()
            self.isImporting = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if let completion = component.completion {
                completion()
            } else {
                self.dismiss()
            }
        }

        private func finishImportWithError(error: WalletContext.WalletError) {
            self.isImporting = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard error != .authorizationCancelled else {
                self.endWalletFlow()
                return
            }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            if error == .recoveryPhraseOutdated {
                if let prepared = self.activePreparedRecoveryPhraseImport {
                    self.discardPreparedRecoveryPhraseImport(prepared)
                }
                self.endWalletFlow()
                HapticFeedback().error()
                self.endEditing(true)
                let alert = AlertScreen(
                    context: component.context,
                    configuration: AlertScreen.Configuration(allowInputInset: true),
                    title: strings.Wallet_Import_PhraseChangedTitle,
                    text: strings.Wallet_Import_PhraseChangedText,
                    actions: [
                        AlertScreen.Action(title: strings.Wallet_Import_Proceed, type: .default)
                    ]
                )
                alert.dismissed = { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        guard let self,
                              let controller = self.environment?.controller(),
                              controller.navigationController?.topViewController === controller,
                              self.window != nil else {
                            return
                        }
                        self.scrollToBottomAfterPaste = false
                        self.setupWordInputFields(displayNumbers: Array(1 ... 24), preserving: [])
                        self.componentState?.updated(transition: .immediate)
                        let _ = self.wordFields.first?.textField.becomeFirstResponder()
                        self.scrollToTop()
                    }
                }
                controller.present(alert, in: .window(.root))
                return
            }
            let message = walletAuthorizationErrorMessage(error, strings: strings)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? strings.Wallet_Import_ErrorTitle,
                text: message?.text ?? strings.Wallet_Import_ErrorText,
                actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {
                })]
            ), in: .window(.root))
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment else {
                return
            }

            let titleCenterY = environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) * 0.5 + 3.0
            let titleTransformDistance: CGFloat = 20.0
            let titleY = max(
                titleCenterY,
                self.titleTransformContainer.center.y - self.scrollView.contentOffset.y
            )
            transition.setSublayerTransform(
                view: self.titleTransformContainer,
                transform: CATransform3DMakeTranslation(
                    0.0,
                    titleY - self.titleTransformContainer.center.y,
                    0.0
                )
            )

            let titleYDistance = titleY - titleCenterY
            let titleTransformFraction = 1.0 - max(
                0.0,
                min(1.0, titleYDistance / titleTransformDistance)
            )
            let titleMinScale: CGFloat = 17.0 / 28.0
            let titleScale = 1.0 * (1.0 - titleTransformFraction)
                + titleMinScale * titleTransformFraction
            if let navigationTitleView = self.navigationTitle.view {
                transition.setScale(view: navigationTitleView, scale: titleScale)
            }

            if let controller = environment.controller(),
               let navigationBar = controller.navigationBar,
               let edgeEffectView = navigationBar.edgeEffectView {
                let alphaDistance = max(
                    1.0,
                    self.titleTransformContainer.center.y - titleCenterY
                )
                let alpha = max(
                    0.0,
                    min(1.0, self.scrollView.contentOffset.y / alphaDistance)
                )
                transition.setAlpha(view: edgeEffectView, alpha: alpha)
            }
        }

        private func removeWordSuggestionView() {
            guard let wordSuggestionView = self.wordSuggestionView else {
                self.wordSuggestionFrame = nil
                return
            }
            self.wordSuggestionView = nil
            self.wordSuggestionFrame = nil
            wordSuggestionView.isUserInteractionEnabled = false
            wordSuggestionView.alpha = 0.0
            wordSuggestionView.layer.animateAlpha(
                from: 1.0,
                to: 0.0,
                duration: 0.25,
                removeOnCompletion: false,
                completion: { [weak wordSuggestionView] _ in
                    wordSuggestionView?.removeFromSuperview()
                }
            )
        }

        private func ensureActiveFieldVisible(
            availableSize: CGSize,
            navigationHeight: CGFloat,
            inputHeight: CGFloat
        ) {
            guard inputHeight > 0.0,
                  let activeWordIndex,
                  self.wordFields.indices.contains(activeWordIndex) else {
                return
            }

            var targetFrame = self.wordFields[activeWordIndex].frame
            if activeWordIndex >= max(0, self.wordFields.count - 3), let buttonView = self.button.view {
                targetFrame = targetFrame.union(buttonView.frame)
            }
            if let wordSuggestionFrame = self.wordSuggestionFrame {
                targetFrame = targetFrame.union(wordSuggestionFrame)
            }
            targetFrame = targetFrame.insetBy(dx: 0.0, dy: -12.0)

            let visibleTop = self.scrollView.contentOffset.y + navigationHeight
            let visibleBottom = self.scrollView.contentOffset.y
                + availableSize.height - inputHeight - 12.0
            var targetOffsetY = self.scrollView.contentOffset.y
            if targetFrame.maxY > visibleBottom {
                targetOffsetY += targetFrame.maxY - visibleBottom
            } else if targetFrame.minY < visibleTop {
                targetOffsetY -= visibleTop - targetFrame.minY
            }

            let maximumOffsetY = max(
                0.0,
                self.scrollView.contentSize.height
                    + self.scrollView.contentInset.bottom
                    - self.scrollView.bounds.height
            )
            targetOffsetY = max(0.0, min(maximumOffsetY, targetOffsetY))
            if abs(targetOffsetY - self.scrollView.contentOffset.y) > UIScreenPixel {
                self.scrollView.setContentOffset(
                    CGPoint(x: 0.0, y: targetOffsetY),
                    animated: true
                )
            }
        }

        func update(
            component: WalletImportScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let previousMode = self.component?.mode
            self.environment = environment
            self.component = component
            self.componentState = state

            if previousMode != component.mode {
                self.didPlayAnimation = false
                self.didRequestInitialFocus = false
                self.didCompleteVerification = false
                self.isVerificationInProgress = false
                switch component.mode {
                case .importWallet, .enterRecoveryPhrase, .enableBackup:
                    self.setupWordInputFields(displayNumbers: Array(1 ... 12), preserving: [])
                case .verify:
                    self.setupWordInputFields(
                        displayNumbers: component.verificationIndices.map { $0 + 1 },
                        preserving: []
                    )
                }
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.plainBackgroundColor

            let animationName: String
            let titleText: String
            let bodyContent: BalancedTextComponent.TextContent
            let buttonTitle: String
            let isVerificationMode: Bool
            switch component.mode {
            case .importWallet:
                isVerificationMode = false
                animationName = "WalletWordList"
                titleText = environment.strings.Wallet_Import_Title
                bodyContent = .plain(NSAttributedString(
                    string: environment.strings.Wallet_Import_Text,
                    font: Font.regular(16.0),
                    textColor: theme.list.itemPrimaryTextColor
                ))
                buttonTitle = environment.strings.Wallet_Import_Action
            case .enterRecoveryPhrase:
                isVerificationMode = false
                animationName = "WalletWordCheck"
                titleText = environment.strings.Wallet_SecretPhrase
                bodyContent = .markdown(
                    text: environment.strings.Wallet_Import_EnterPhraseText,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(16.0), textColor: theme.list.itemPrimaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor),
                        linkAttribute: { _ in ("WalletRecoveryPhraseExplanation", true) }
                    )
                )
                buttonTitle = environment.strings.Common_Done
            case .enableBackup:
                isVerificationMode = false
                animationName = "WalletWordCheck"
                titleText = environment.strings.Wallet_Settings_EnableBackup
                bodyContent = .plain(NSAttributedString(
                    string: environment.strings.Wallet_Import_EnableBackupText,
                    font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor
                ))
                buttonTitle = environment.strings.Wallet_Settings_EnableBackup
            case .verify:
                isVerificationMode = true
                animationName = "WalletWordCheck"
                titleText = environment.strings.Wallet_Import_TestTitle
                let displayedIndices = component.verificationIndices.map { String($0 + 1) }
                let formattedBodyText: String
                if displayedIndices.count == 3 {
                    formattedBodyText = environment.strings.Wallet_Import_TestText(displayedIndices[0], displayedIndices[1], displayedIndices[2]).string
                } else {
                    formattedBodyText = environment.strings.Wallet_Import_TestTextFallback
                }
                bodyContent = .markdown(
                    text: formattedBodyText,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(
                            font: Font.regular(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        bold: MarkdownAttributeSet(
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        link: MarkdownAttributeSet(
                            font: Font.regular(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        linkAttribute: { _ in nil }
                    )
                )
                buttonTitle = environment.strings.Wallet_Continue
            }

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )

            let contentSideInset = 48.0 + max(
                environment.safeInsets.left,
                environment.safeInsets.right
            )
            let contentWidth = max(
                0.0,
                min(430.0, availableSize.width - contentSideInset * 2.0)
            )
            var contentHeight = environment.navigationHeight - 28.0

            self.animation.parentState = state
            let animationSize = CGSize(width: 108.0, height: 108.0)
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: animationName),
                    startingPosition: .begin,
                    size: animationSize,
                    loop: false,
                    playOnce: self.playAnimation,
                    lottieSettings: component.context.lottieRenderingSettings
                )),
                environment: {},
                containerSize: animationSize
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.scrollView.addSubview(animationView)
                }
                transition.setFrame(
                    view: animationView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - animationSize.width) * 0.5),
                        y: contentHeight,
                        width: animationSize.width,
                        height: animationSize.height
                    )
                )
            }
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playAnimation.invoke(Void())
            }
            contentHeight += animationSize.height + 8.0

            self.navigationTitle.parentState = state
            let titleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(28.0),
                        textColor: theme.rootController.navigationBar.primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 100.0)
            )
            let titleFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5),
                y: contentHeight,
                width: titleSize.width,
                height: titleSize.height
            )
            let overlaySuperview: UIView
            if let controller = environment.controller(),
               let navigationBar = controller.navigationBar,
               let navigationBarSuperview = navigationBar.view.superview {
                overlaySuperview = navigationBarSuperview
            } else {
                overlaySuperview = self
            }
            if self.titleTransformContainer.superview !== overlaySuperview {
                self.titleTransformContainer.removeFromSuperview()
                if let controller = environment.controller(),
                   let navigationBar = controller.navigationBar,
                   overlaySuperview === navigationBar.view.superview {
                    overlaySuperview.insertSubview(
                        self.titleTransformContainer,
                        aboveSubview: navigationBar.view
                    )
                } else {
                    overlaySuperview.addSubview(self.titleTransformContainer)
                }
            }
            if let titleView = self.navigationTitle.view {
                if titleView.superview !== self.titleTransformContainer {
                    titleView.removeFromSuperview()
                    self.titleTransformContainer.addSubview(titleView)
                }
                transition.setPosition(
                    view: self.titleTransformContainer,
                    position: titleFrame.center
                )
                transition.setBounds(
                    view: self.titleTransformContainer,
                    bounds: CGRect(origin: CGPoint(), size: titleFrame.size)
                )
                transition.setPosition(
                    view: titleView,
                    position: CGPoint(
                        x: titleFrame.width * 0.5,
                        y: titleFrame.height * 0.5
                    )
                )
                transition.setBounds(
                    view: titleView,
                    bounds: CGRect(origin: CGPoint(), size: titleFrame.size)
                )
            }
            contentHeight += titleSize.height + 5.0

            self.body.parentState = state
            let bodySize = self.body.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: bodyContent,
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        let key = NSAttributedString.Key(rawValue: "WalletRecoveryPhraseExplanation")
                        return attributes[key] != nil ? key : nil
                    },
                    tapAction: { [weak self] attributes, _ in
                        guard attributes[NSAttributedString.Key(rawValue: "WalletRecoveryPhraseExplanation")] != nil else {
                            return
                        }
                        self?.presentRecoveryPhraseExplanation()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let bodyView = self.body.view {
                if bodyView.superview == nil {
                    self.scrollView.addSubview(bodyView)
                }
                transition.setFrame(
                    view: bodyView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - bodySize.width) * 0.5),
                        y: contentHeight,
                        width: bodySize.width,
                        height: bodySize.height
                    )
                )
            }
            contentHeight += bodySize.height + 14.0

            let fieldWidth = max(
                0.0,
                min(330.0, availableSize.width - contentSideInset * 2.0)
            )
            let fieldX = floorToScreenPixels((availableSize.width - fieldWidth) * 0.5)

            if isVerificationMode {
                self.wordCountControl.view?.removeFromSuperview()
            } else {
                self.wordCountControl.parentState = state

                let segmentedTheme = SegmentControlComponent.Theme(
                    backgroundColor: theme.list.itemInputField.backgroundColor,
                    legacyBackgroundColor: theme.list.itemInputField.backgroundColor,
                    foregroundColor: theme.overallDarkAppearance ? theme.actionSheet.opaqueItemBackgroundColor : theme.list.plainBackgroundColor,
                    textColor: theme.rootController.navigationBar.segmentedTextColor,
                    dividerColor: theme.rootController.navigationBar.segmentedDividerColor
                )

                let wordCountControlSize = self.wordCountControl.update(
                    transition: transition,
                    component: AnyComponent(SegmentControlComponent(
                        theme: segmentedTheme,
                        items: [
                            SegmentControlComponent.Item(id: AnyHashable(12), title: environment.strings.Wallet_Import_WordCount(12)),
                            SegmentControlComponent.Item(id: AnyHashable(24), title: environment.strings.Wallet_Import_WordCount(24))
                        ],
                        selectedId: AnyHashable(self.words.count),
                        fillWidth: false,
                        action: { [weak self] id in
                            guard let count = id.base as? Int else {
                                return
                            }
                            self?.setWordCount(count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: fieldWidth, height: 36.0)
                )
                if let wordCountControlView = self.wordCountControl.view {
                    if wordCountControlView.superview == nil {
                        self.scrollView.addSubview(wordCountControlView)
                    }
                    transition.setFrame(
                        view: wordCountControlView,
                        frame: CGRect(
                            x: floor((availableSize.width - wordCountControlSize.width) / 2.0),
                            y: contentHeight,
                            width: wordCountControlSize.width,
                            height: wordCountControlSize.height
                        )
                    )
                }
                contentHeight += wordCountControlSize.height + 32.0
            }

            let fieldHeight: CGFloat = 52.0
            let fieldSpacing: CGFloat = 14.0
            let displaysPasteButton = !isVerificationMode
                && self.hasPasteboardText
                && self.words.allSatisfy { $0.isEmpty }
            for index in self.wordFields.indices {
                var transition = transition
                let field = self.wordFields[index]
                if field.superview == nil {
                    transition = .immediate
                    self.scrollView.addSubview(field)
                }
                let fieldFrame = CGRect(
                    x: fieldX,
                    y: contentHeight,
                    width: fieldWidth,
                    height: fieldHeight
                )
                transition.setFrame(view: field, frame: fieldFrame)
                field.update(
                    theme: theme,
                    strings: environment.strings,
                    isInvalid: self.mismatchedWordIndices.contains(index),
                    displaysPasteButton: index == 0 && displaysPasteButton,
                    size: fieldFrame.size
                )
                contentHeight += fieldHeight
                if index != self.wordFields.count - 1 {
                    contentHeight += fieldSpacing
                }
            }
            if !self.didRequestInitialFocus {
                self.didRequestInitialFocus = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    let _ = self?.wordFields.first?.textField.becomeFirstResponder()
                }
            }
            contentHeight += 24.0

            let isButtonEnabled = self.isActionEnabled
            self.button.parentState = state
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(Text(
                            text: buttonTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: isButtonEnabled,
                    displaysProgress: isVerificationMode ? self.isVerificationInProgress : self.isImporting,
                    action: { [weak self] in
                        self?.performAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fieldWidth, height: 52.0)
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.scrollView.addSubview(buttonView)
                }
                transition.setFrame(
                    view: buttonView,
                    frame: CGRect(
                        x: fieldX,
                        y: contentHeight,
                        width: buttonSize.width,
                        height: buttonSize.height
                    )
                )
            }
            contentHeight += buttonSize.height + environment.safeInsets.bottom + 24.0

            if self.hasInvalidWordSuggestion || !self.wordSuggestions.isEmpty,
               let activeWordIndex = self.activeWordIndex,
               self.wordFields.indices.contains(activeWordIndex) {
                let wordSuggestionView: ComponentHostView<Empty>
                let animateIn: Bool
                if let current = self.wordSuggestionView {
                    wordSuggestionView = current
                    animateIn = false
                } else {
                    wordSuggestionView = ComponentHostView<Empty>()
                    self.wordSuggestionView = wordSuggestionView
                    self.scrollView.addSubview(wordSuggestionView)
                    animateIn = true
                }
                let suggestionTransition: ComponentTransition = animateIn
                    ? .immediate
                    : .easeInOut(duration: 0.2)

                let suggestionIndex = activeWordIndex
                let suggestionSize = wordSuggestionView.update(
                    transition: suggestionTransition,
                    component: AnyComponent(WalletWordSuggestionsComponent(
                        fieldIndex: activeWordIndex,
                        query: self.words[activeWordIndex],
                        words: self.hasInvalidWordSuggestion ? [environment.strings.Wallet_Import_InvalidWord] : self.wordSuggestions,
                        isInteractive: !self.hasInvalidWordSuggestion,
                        pulseId: self.hasInvalidWordSuggestion ? self.invalidWordSuggestionPulseId : 0,
                        action: { [weak self] word in
                            self?.selectSuggestedWord(word, at: suggestionIndex)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(
                        width: fieldWidth,
                        height: WalletWordSuggestionsComponent.height
                    )
                )
                let fieldFrame = self.wordFields[activeWordIndex].frame
                let suggestionX = floor(min(
                    fieldFrame.maxX - suggestionSize.width,
                    max(fieldFrame.minX, fieldFrame.midX - suggestionSize.width / 2.0)
                ))
                let suggestionFrame = CGRect(
                    x: suggestionX,
                    y: fieldFrame.maxY - WalletWordSuggestionsComponent.notchHeight,
                    width: suggestionSize.width,
                    height: suggestionSize.height
                )
                suggestionTransition.setFrame(view: wordSuggestionView, frame: suggestionFrame)
                self.wordSuggestionFrame = suggestionFrame
                self.scrollView.bringSubviewToFront(wordSuggestionView)
                if let componentView = wordSuggestionView.componentView as? WalletWordSuggestionsComponent.View {
                    componentView.adjustBackground(
                        relativePositionX: fieldFrame.midX - suggestionFrame.minX,
                        transition: suggestionTransition
                    )
                }
                if animateIn {
                    wordSuggestionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                }
            } else {
                self.removeWordSuggestionView()
            }

            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }

            let bottomContentInset = max(
                environment.safeInsets.bottom + 16.0,
                environment.inputHeight + 16.0
            )
            let contentInset = UIEdgeInsets(
                top: 0.0,
                left: 0.0,
                bottom: bottomContentInset,
                right: 0.0
            )
            if self.scrollView.contentInset != contentInset {
                self.scrollView.contentInset = contentInset
            }
            let scrollIndicatorInsets = UIEdgeInsets(
                top: environment.navigationHeight,
                left: 0.0,
                bottom: bottomContentInset,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollIndicatorInsets
            }

            if self.scrollToBottomAfterPaste && environment.inputHeight == 0.0 {
                self.scrollToBottomAfterPaste = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    let maximumOffsetY = max(
                        0.0,
                        self.scrollView.contentSize.height
                            + self.scrollView.contentInset.bottom
                            - self.scrollView.bounds.height
                    )
                    self.scrollView.setContentOffset(
                        CGPoint(x: 0.0, y: maximumOffsetY),
                        animated: true
                    )
                }
            }

            self.updateScrolling(transition: transition)
            self.ensureActiveFieldVisible(
                availableSize: availableSize,
                navigationHeight: environment.navigationHeight,
                inputHeight: environment.inputHeight
            )

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletImportScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletImportScreenMode,
        completion: (() -> Void)?
    ) {
        let verificationIndices: [Int]
        switch mode {
        case .importWallet, .enterRecoveryPhrase, .enableBackup:
            verificationIndices = []
        case let .verify(words, keyRotation, _):
            precondition(words.count >= 3)
            if keyRotation {
                precondition(words.count == 24)
                let anchorIndex = Int.random(in: 0 ..< 12)
                let signingIndices = Array((12 ..< 24).shuffled().prefix(2))
                verificationIndices = ([anchorIndex] + signingIndices).sorted()
            } else {
                verificationIndices = Array(words.indices.shuffled().prefix(3)).sorted()
            }
        }

        super.init(
            context: context,
            component: WalletImportScreenComponent(
                context: context,
                walletContext: walletContext,
                mode: mode,
                verificationIndices: verificationIndices,
                completion: completion
            ),
            navigationBarAppearance: .default,
            statusBarStyle: .default,
            theme: .default
        )

        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(
            title: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back,
            style: .plain,
            target: nil,
            action: nil
        )
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)

        self.scrollToTop = { [weak self] in
            guard let self,
                  let componentView = self.node.hostView.componentView as? WalletImportScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setVerificationInProgress(_ inProgress: Bool) {
        (self.node.hostView.componentView as? WalletImportScreenComponent.View)?.setVerificationInProgress(inProgress)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            (self.node.hostView.componentView as? WalletImportScreenComponent.View)?.endWalletFlow()
        }
    }
}
