import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import ShimmeringMask
import WalletContext

final class WalletTransactionAmountComponent: Component {
    let theme: PresentationTheme
    let dateTimeFormat: PresentationDateTimeFormat
    let amount: Int64
    let direction: WalletContext.Transaction.Direction
    let currency: WalletContext.Transaction.Currency
    let pending: Bool

    init(
        theme: PresentationTheme,
        dateTimeFormat: PresentationDateTimeFormat,
        amount: Int64,
        direction: WalletContext.Transaction.Direction,
        currency: WalletContext.Transaction.Currency,
        pending: Bool
    ) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.amount = amount
        self.direction = direction
        self.currency = currency
        self.pending = pending
    }

    static func ==(lhs: WalletTransactionAmountComponent, rhs: WalletTransactionAmountComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.amount != rhs.amount {
            return false
        }
        if lhs.direction != rhs.direction {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.pending != rhs.pending {
            return false
        }
        return true
    }

    final class View: UIView {
        private let contentContainer = UIView()
        private let shimmerView = ShimmeringMaskView(peakAlpha: 0.3, duration: 1.0)
        private let amount = ComponentView<Empty>()
        private let suffix = ComponentView<Empty>()
        private let iconView = UIImageView()
        private var currentIconName: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.contentContainer.isUserInteractionEnabled = false
            self.shimmerView.isUserInteractionEnabled = false
            self.iconView.isUserInteractionEnabled = false
            self.iconView.contentMode = .scaleAspectFit
            self.addSubview(self.contentContainer)
            self.contentContainer.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransactionAmountComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let formattedAmountText: String
            var normalizedAmount: Int64 = component.amount
            if case .outgoing = component.direction, normalizedAmount > 0 {
                normalizedAmount *= -1
            }
            let iconName: String?
            switch component.currency {
            case .ton:
                formattedAmountText = formatTonAmountText(
                    normalizedAmount,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 3
                )
                iconName = nil
            case .usdt:
                formattedAmountText = formatWalletTransactionTokenAmountText(
                    normalizedAmount,
                    decimalDigits: 6,
                    dateTimeFormat: component.dateTimeFormat
                )
                iconName = "Wallet/TransactionUsdtLarge"
            }
            if self.currentIconName != iconName {
                self.currentIconName = iconName
                self.iconView.image = iconName.flatMap { UIImage(bundleImageName: $0)?.withRenderingMode(.alwaysOriginal) }
            }

            let amountText: String
            let regularTextColor: UIColor
            switch component.direction {
            case .incoming:
                amountText = "+\(formattedAmountText)"
                if component.currency == .usdt {
                    regularTextColor = UIColor(rgb: 0x0B9696)
                } else {
                    regularTextColor = component.theme.list.itemDisclosureActions.constructive.fillColor
                }
            case .outgoing:
                amountText = "\(formattedAmountText)".replacingOccurrences(of: "-", with: "−")
                regularTextColor = component.theme.actionSheet.primaryTextColor
            case .unknown:
                amountText = formattedAmountText
                regularTextColor = component.theme.actionSheet.primaryTextColor
            }

            let textColor = component.pending ? component.theme.actionSheet.secondaryTextColor : regularTextColor
            let integralFont = Font.with(size: 48.0, design: .round, weight: .bold, traits: [])
            let fractionalFont = Font.with(size: 32.0, design: .round, weight: .bold)
            let amountAttributedString = tonAmountAttributedString(
                amountText,
                integralFont: integralFont,
                fractionalFont: fractionalFont,
                color: .white,
                decimalSeparator: component.dateTimeFormat.decimalSeparator
            )

            let displaysGramSuffix = component.currency == .ton
            let suffixSize: CGSize
            if displaysGramSuffix {
                suffixSize = self.suffix.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "GRAM",
                            font: fractionalFont,
                            textColor: UIColor(rgb: component.theme.overallDarkAppearance ? 0x30A1F5 : 0x0088ff)
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 100.0)
                )
            } else {
                suffixSize = .zero
            }
            let spacing: CGFloat = displaysGramSuffix ? 8.0 : 2.0 - UIScreenPixel
            let amountWidth = displaysGramSuffix
                ? availableSize.width - 60.0 - spacing - suffixSize.width
                : availableSize.width - 104.0
            let amountSize = self.amount.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(amountAttributedString),
                    maximumNumberOfLines: 1,
                    tintColor: textColor
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, amountWidth), height: 100.0)
            )
            let iconSize = (self.iconView.image?.size ?? CGSize()).aspectFitted(
                CGSize(width: 44.0, height: 44.0)
            )

            let suffixOffsetY = floorToScreenPixels(integralFont.ascender) - floorToScreenPixels(fractionalFont.ascender)
            let size = CGSize(
                width: amountSize.width + spacing + (displaysGramSuffix ? suffixSize.width : iconSize.width),
                height: max(amountSize.height, displaysGramSuffix ? suffixOffsetY + suffixSize.height : iconSize.height)
            )
            let bounds = CGRect(origin: .zero, size: size)
            let amountOriginY = floor((size.height - amountSize.height) / 2.0)

            self.contentContainer.frame = bounds
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    self.contentContainer.addSubview(amountView)
                }
                transition.setFrame(
                    view: amountView,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: amountOriginY),
                        size: amountSize
                    )
                )
            }
            if let suffixView = self.suffix.view {
                if suffixView.superview == nil {
                    self.contentContainer.addSubview(suffixView)
                }
                transition.setAlpha(view: suffixView, alpha: displaysGramSuffix ? (component.pending ? 0.5 : 1.0) : 0.0)
                if displaysGramSuffix {
                    transition.setFrame(view: suffixView, frame: CGRect(
                        origin: CGPoint(x: amountSize.width + spacing, y: amountOriginY + suffixOffsetY),
                        size: suffixSize
                    ))
                }
            }
            transition.setAlpha(view: self.iconView, alpha: displaysGramSuffix ? 0.0 : (component.pending ? 0.5 : 1.0))
            transition.setFrame(
                view: self.iconView,
                frame: CGRect(
                    origin: CGPoint(
                        x: amountSize.width + spacing,
                        y: floor((size.height - iconSize.height) / 2.0) + 5.0 + UIScreenPixel
                    ),
                    size: iconSize
                )
            )

            self.shimmerView.frame = bounds
            self.shimmerView.update(
                size: size,
                containerWidth: size.width,
                offsetX: 0.0,
                gradientWidth: 80.0,
                transition: .immediate
            )

            if component.pending {
                if self.shimmerView.superview == nil {
                    self.addSubview(self.shimmerView)
                }
                if self.contentContainer.superview !== self.shimmerView.contentView {
                    self.shimmerView.contentView.addSubview(self.contentContainer)
                }
            } else {
                if self.contentContainer.superview !== self {
                    self.addSubview(self.contentContainer)
                }
                self.shimmerView.removeFromSuperview()
            }

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
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

private func formatWalletTransactionTokenAmountText(
    _ value: Int64,
    decimalDigits: Int,
    dateTimeFormat: PresentationDateTimeFormat
) -> String {
    var digits = String(value.magnitude)
    while digits.count <= decimalDigits {
        digits.insert("0", at: digits.startIndex)
    }

    let fractionStart = digits.index(digits.endIndex, offsetBy: -decimalDigits)
    var integralPart = String(digits[..<fractionStart])
    var fractionalPart = String(digits[fractionStart...])
    while fractionalPart.last == "0" {
        fractionalPart.removeLast()
    }

    if let integralValue = Int32(integralPart) {
        integralPart = presentationStringsFormattedNumber(integralValue, dateTimeFormat.groupingSeparator)
    }

    var result = integralPart
    if !fractionalPart.isEmpty {
        result.append(dateTimeFormat.decimalSeparator)
        result.append(fractionalPart)
    }
    return result
}
