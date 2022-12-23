import SnapKit
import UIKit

class TicketNumbersInputView: UIControl, UITextInputTraits {
    
    private struct Constants {
        static let firstNumbersCount = 5
        static let lastNumbersCount = 1
        static let firstNumbersRange = 1...69
        static let lastNumbersRange = 1...26
    }
    
    //  MARK: - UI Elements

    private let firstNumbersBackgroundImageView = UIImageView()
    private let firstNumbersLabel = UILabel()
    private let lastNumberBackgroundImageView = UIImageView()
    private let lastNumberLabel = UILabel()
    
    override var canBecomeFirstResponder: Bool { true }
    public var keyboardType: UIKeyboardType = .numberPad
    
    //  MARK: - Handlers
    
    var onInputNumbers: (([Int]?) -> Void)?
    
    //  MARK: - Logic
    
    private var enteredText = ""
    private var currentNumbers: [Int]?
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
        layoutUI()
        
        self.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        
        tryUpdateText(nexText: enteredText)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.point(inside: point, with: event) {
            return self
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    //  MARK: - Public Functions
    
    func getNumbers() -> [Int]? {
        return self.currentNumbers
    }

    func setNumbers(_ numbers: [Int]) {
        let newText = numbers
            .map { String(format: "%02d", $0) }
            .joined()
        tryUpdateText(nexText: newText)
    }
    
    func fillRandomly() {
        let firstNumbers = Constants.firstNumbersRange.shuffled().prefix(Constants.firstNumbersCount)
        let lastNumbers = Constants.lastNumbersRange.shuffled().prefix(Constants.lastNumbersCount)
        self.setNumbers(Array(firstNumbers) + Array(lastNumbers))
    }
}

extension TicketNumbersInputView: UIKeyInput {
    var hasText: Bool {
        return !enteredText.isEmpty
    }
    
    func insertText(_ text: String) {
        let newText = enteredText + text
        tryUpdateText(nexText: newText)
    }
    
    func deleteBackward() {
        let newText = enteredText.dropLast(1)
        tryUpdateText(nexText: String(newText))
    }
}

private extension TicketNumbersInputView {
    @objc func tapped() {
        self.becomeFirstResponder()
    }
}

private extension TicketNumbersInputView {
    func tryUpdateText(nexText: String) {
        let digits = nexText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let (first, remaining) = applyMask("XX XX XX XX XX", to: digits)
        let (last, unexpectedRemaining) = applyMask("XX", to: remaining)
        guard unexpectedRemaining.isEmpty else { return }
        
        if isNumbersValid(
            firstNumbers: extractNumbersAfterApplyingMask(first, padWithZeros: true),
            lastNumbers: extractNumbersAfterApplyingMask(last, padWithZeros: true)
        ) {
            firstNumbersLabel.attributedText = parseToAttrbutedString(first)
            lastNumberLabel.attributedText = parseToAttrbutedString(last)
            
            self.enteredText = digits
            
            let firstNumbers = extractNumbersAfterApplyingMask(first, padWithZeros: false)
            let lastNumbers = extractNumbersAfterApplyingMask(last, padWithZeros: false)
            let newNumbers: [Int]?
            if firstNumbers.count == Constants.firstNumbersCount,
               lastNumbers.count == Constants.lastNumbersCount {
                newNumbers = firstNumbers + lastNumbers
            } else {
                newNumbers = nil
            }
            self.currentNumbers = newNumbers
            self.onInputNumbers?(newNumbers)
        }
    }
    
    func parseToAttrbutedString(_ string: String) -> NSAttributedString {
        let attrbutedString = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor.lotteryForegroundTint
            ]
        )
        if let placeholderLeftIndex = string.firstIndex(of: "X"),
           let placeholderRightIndex = string.lastIndex(of: "X") {
            let range = NSRange(placeholderLeftIndex...placeholderRightIndex, in: string)
            attrbutedString.addAttributes(
                [
                    .foregroundColor: UIColor.lotteryForegroundTint.withAlphaComponent(0.3)
                ],
                range: range
            )
            attrbutedString.mutableString.replaceOccurrences(of: "X", with: "0", range: range)
        }
        return attrbutedString
    }
    
    func applyMask(_ mask: String, to text: String) -> (result: String, remaining: String) {
        var queue = text
        
        var result = ""
        for char in mask {
            if char == "X" {
                if let next = queue.first {
                    result += String(next)
                } else {
                    result += "X"
                }
                queue = String(queue.dropFirst(1))
            } else {
                result += String(char)
            }
        }
        
        return (result, queue)
    }
    
    func extractNumbersAfterApplyingMask(_ string: String, padWithZeros: Bool) -> [Int] {
        return string
            .prefix { $0 != "X" }
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
            .compactMap { str in
                if str == "0" {
                    return nil
                }
                let padding = 2 - str.count
                if padding > 0 {
                    if padWithZeros {
                        return Int(str + String(repeating: "0", count: padding))
                    } else {
                        return nil
                    }
                } else {
                    return Int(str)
                }
            }
    }
    
    func isNumbersValid(firstNumbers: [Int], lastNumbers: [Int]) -> Bool {
        return isFirstNumbersValid(firstNumbers) && isLastNumbersValid(lastNumbers)
    }
    
    func isFirstNumbersValid(_ numbers: [Int]) -> Bool {
        let satisfyLimits = numbers.allSatisfy { Constants.firstNumbersRange.contains($0) }
        let hasNoDuplicates = (Set(numbers).count == numbers.count)
        return satisfyLimits && hasNoDuplicates
    }
    
    func isLastNumbersValid(_ numbers: [Int]) -> Bool {
        return numbers.allSatisfy { Constants.lastNumbersRange.contains($0) }
    }
}


private extension TicketNumbersInputView {
    func setupUI() {
        layer.applyShadow(color: .black, alpha: 0.25, x: 0, y: 5, blur: 15)
        
        firstNumbersBackgroundImageView.image = UIImage(named: "ng.lottery.ticket.background.yellow")
        lastNumberBackgroundImageView.image = UIImage(named: "ng.lottery.ticket.background.white")
    }
    
    func layoutUI() {
       let firstNumbersContainer = UIView()
        
        firstNumbersContainer.addSubview(firstNumbersBackgroundImageView)
        firstNumbersBackgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        firstNumbersBackgroundImageView.setIntrinsicContentSizeMinimumPriority()
        
        firstNumbersContainer.addSubview(firstNumbersLabel)
        firstNumbersLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.top.trailing.bottom.equalToSuperview().inset(4)
        }
        
        let lastNumberContainer = UIView()
        
        lastNumberContainer.addSubview(lastNumberBackgroundImageView)
        lastNumberBackgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        lastNumberBackgroundImageView.setIntrinsicContentSizeMinimumPriority()
        
        lastNumberContainer.addSubview(lastNumberLabel)
        lastNumberLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }
        
        let stack = UIStackView(
            arrangedSubviews: [firstNumbersContainer, lastNumberContainer],
            axis: .horizontal,
            spacing: 4,
            alignment: .center
        )

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
