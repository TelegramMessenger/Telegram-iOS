import Foundation
import UIKit
import SwiftSignalKit
import Display
import ComponentFlow
import AnimatedTextComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

public final class WalletTransferCardComponent: Component {
    public let amount: Int64
    public let recipient: String
    public let fiatCurrency: WalletContext.FiatCurrency
    public let fiatRate: WalletContext.FiatRate?
    public let dateTimeFormat: PresentationDateTimeFormat
    public let amountText: String?
    public let recipientTitle: String?
    public let infoPressed: () -> Void

    public init(
        amount: Int64,
        recipient: String,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat,
        amountText: String? = nil,
        recipientTitle: String? = nil,
        infoPressed: @escaping () -> Void = {}
    ) {
        self.amount = amount
        self.recipient = recipient
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
        self.amountText = amountText
        self.recipientTitle = recipientTitle
        self.infoPressed = infoPressed
    }

    public static func ==(lhs: WalletTransferCardComponent, rhs: WalletTransferCardComponent) -> Bool {
        return lhs.amount == rhs.amount
            && lhs.recipient == rhs.recipient
            && lhs.fiatCurrency == rhs.fiatCurrency
            && lhs.fiatRate == rhs.fiatRate
            && lhs.dateTimeFormat == rhs.dateTimeFormat
            && lhs.amountText == rhs.amountText
            && lhs.recipientTitle == rhs.recipientTitle
    }

    public final class View: UIView {
        private let backgroundView = WalletCardBackgroundView()
        private let integralAmount = ComponentView<Empty>()
        private let fractionalAmount = ComponentView<Empty>()
        private let currency = ComponentView<Empty>()
        private let secondaryAmount = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let infoButton = ComponentView<Empty>()

        private var component: WalletTransferCardComponent?
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var deviceMotionDisposable: Disposable?
        private var reflectionRotation = WalletCardBackgroundRotation()

        public override var isHidden: Bool {
            didSet {
                if self.isHidden != oldValue {
                    self.updateAnimationState()
                }
            }
        }

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.backgroundView)

            self.clipsToBounds = true
            self.layer.cornerRadius = 20.0
            if #available(iOS 13.0, *) {
                self.layer.cornerCurve = .continuous
            }

            NotificationCenter.default.addObserver(self, selector: #selector(self.updateAnimationState), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.stopAnimation), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateAnimationState), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.displayLink?.invalidate()
            self.deviceMotionDisposable?.dispose()
            NotificationCenter.default.removeObserver(self)
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window != nil {
                self.reflectionRotation.reset(to: WalletCardBackgroundMotion.shared.currentRotation)
            }
            self.updateAnimationState()
            if self.window != nil {
                self.backgroundView.renderStaticFrame(reflectionRotation: self.reflectionRotation.value)
            }
        }

        @objc private func updateAnimationState() {
            guard self.component != nil, self.window != nil, !self.isHidden,
                  UIApplication.shared.applicationState == .active, !UIAccessibility.isReduceMotionEnabled else {
                self.stopAnimation()
                return
            }
            if self.deviceMotionDisposable == nil {
                self.deviceMotionDisposable = WalletCardBackgroundMotion.shared.subscribe()
                self.updateBackgroundMotion(isResuming: true)
            }
            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                    self?.updateBackgroundMotion()
                }
            }
            self.updateBackgroundMotion()
        }

        @objc private func stopAnimation() {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.deviceMotionDisposable?.dispose()
            self.deviceMotionDisposable = nil
        }

        private func updateBackgroundMotion(isResuming: Bool = false) {
            guard self.deviceMotionDisposable != nil, let window = self.window else { return }
            let time = CACurrentMediaTime()
            let rotation = Double(WalletCardBackgroundMotion.shared.rotation(
                at: time,
                orientation: window.windowScene?.interfaceOrientation ?? .portrait
            ))
            let previousRotation = self.reflectionRotation.value
            if isResuming {
                self.reflectionRotation.resume(at: time, to: rotation)
            }
            self.reflectionRotation.update(at: time, to: rotation)
            guard self.reflectionRotation.value != previousRotation else { return }
            self.backgroundView.renderStaticFrame(reflectionRotation: self.reflectionRotation.value)
        }

        func update(
            component: WalletTransferCardComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let referenceSize = CGSize(width: 361.0, height: 220.0)
            let width = max(1.0, availableSize.width)
            let scale = width / referenceSize.width
            let size = CGSize(width: width, height: referenceSize.height * scale)

            self.layer.cornerRadius = 20.0 * width / 336.0

            let formattedAmount = component.amountText ?? formatTonAmountText(
                component.amount,
                dateTimeFormat: component.dateTimeFormat,
                maxDecimalPositions: 9
            )

            let amountIntegralText: String
            let amountFractionalText: String
            let isTextAmount = component.amountText?.unicodeScalars.contains(where: CharacterSet.letters.contains) == true
            if isTextAmount || (component.amount == 0 && component.amountText == nil) {
                amountIntegralText = formattedAmount
                amountFractionalText = ""
            } else if let decimalRange = formattedAmount.range(of: component.dateTimeFormat.decimalSeparator) {
                amountIntegralText = String(formattedAmount[..<decimalRange.lowerBound])
                var fractionalDigits = String(formattedAmount[decimalRange.upperBound...])
                while fractionalDigits.count < 2 {
                    fractionalDigits.append("0")
                }
                amountFractionalText = component.dateTimeFormat.decimalSeparator + fractionalDigits
            } else {
                amountIntegralText = formattedAmount
                amountFractionalText = component.dateTimeFormat.decimalSeparator + "00"
            }

            let mainColor = UIColor.white
            let secondaryColor = UIColor(rgb: 0x6ddcff)
            let integralSize = self.integralAmount.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(
                            id: "gramIcon",
                            content: .icon("Wallet/CardGram", tint: false, offset: CGPoint(x: 0.0, y: -1.0))
                        ),
                        AnimatedTextComponent.Item(
                            id: "gramIntegral",
                            content: .text("−\(amountIntegralText)")
                        )
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let fractionalSize = self.fractionalAmount.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 18.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramFraction", content: .text(amountFractionalText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let currencySize = self.currency.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramCurrency", content: .text(isTextAmount ? "" : "GRAM"))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )

            let mainCenterY = 94.0
            let integralOriginY = floor(mainCenterY - integralSize.height * 0.5)
            let integralBottomY = integralOriginY + integralSize.height
            var mainOriginX = 20.0
            if let integralView = self.integralAmount.view {
                if integralView.superview == nil {
                    self.addSubview(integralView)
                }
                transition.setFrame(
                    view: integralView,
                    frame: CGRect(
                        origin: CGPoint(x: mainOriginX, y: integralOriginY),
                        size: integralSize
                    )
                )
            }
            mainOriginX += integralSize.width
            if !amountFractionalText.isEmpty {
                mainOriginX += 1.0
            }
            if let fractionalView = self.fractionalAmount.view {
                if fractionalView.superview == nil {
                    self.addSubview(fractionalView)
                }
                transition.setFrame(
                    view: fractionalView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: mainOriginX,
                            y: floor(integralBottomY - fractionalSize.height - 2.0) - 1.0 - UIScreenPixel
                        ),
                        size: fractionalSize
                    )
                )
            }
            mainOriginX += fractionalSize.width
            mainOriginX += 5.0
            if let currencyView = self.currency.view {
                if currencyView.superview == nil {
                    self.addSubview(currencyView)
                }
                transition.setFrame(
                    view: currencyView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: mainOriginX,
                            y: floor(integralBottomY - currencySize.height - 2.0)
                        ),
                        size: currencySize
                    )
                )
            }

            let secondaryText: String
            if let fiatRate = component.fiatRate, component.amountText == nil {
                secondaryText = formatTonFiatValue(
                    component.amount,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: component.amount == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                secondaryText = "—"
            }
            let secondarySize = self.secondaryAmount.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 14.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "secondaryAmount", content: .text(secondaryText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            if let secondaryView = self.secondaryAmount.view {
                if secondaryView.superview == nil {
                    self.addSubview(secondaryView)
                }
                transition.setFrame(
                    view: secondaryView,
                    frame: CGRect(
                        origin: CGPoint(x: 24.0, y: 114.0),
                        size: secondarySize
                    )
                )
            }

            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.recipientTitle ?? formattedWalletTransferAddress(component.recipient),
                        font: Font.with(size: 13.0 * scale, design: .monospace, weight: .semibold),
                        textColor: .white
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: width - 48.0 * scale, height: 42.0 * scale)
            )
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                transition.setFrame(
                    view: addressView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: 24.0 * scale,
                            y: floor(178.0 * scale - addressSize.height * 0.5)
                        ),
                        size: addressSize
                    )
                )
            }

            let infoSize = self.infoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/CardInfo",
                        tintColor: nil,
                        scaleFactor: scale
                    )),
                    minSize: CGSize(width: 50.0, height: 38.0),
                    action: { [weak self] in
                        self?.component?.infoPressed()
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: 80.0 * scale, height: 80.0)
            )
            if let infoView = self.infoButton.view {
                if infoView.superview == nil {
                    self.addSubview(infoView)
                }
                transition.setFrame(
                    view: infoView,
                    frame: CGRect(
                        origin: CGPoint(x: width - 32.0 - infoSize.width, y: 82.0 * scale),
                        size: infoSize
                    )
                )
            }

            let projectionPadding = WalletCardBackgroundView.projectionPadding
            transition.setFrame(
                view: self.backgroundView,
                frame: CGRect(
                    x: -projectionPadding,
                    y: -projectionPadding,
                    width: size.width + projectionPadding * 2.0,
                    height: size.height + projectionPadding * 2.0
                )
            )
            self.backgroundView.update(cardSize: size, cornerRadius: 20.0 * scale)
            self.updateAnimationState()
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            transition: transition
        )
    }
}

private func formattedWalletTransferAddress(_ address: String) -> String {
    var groups: [String] = []
    var currentIndex = address.startIndex
    while currentIndex < address.endIndex {
        let endIndex = address.index(currentIndex, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        groups.append(String(address[currentIndex ..< endIndex]))
        currentIndex = endIndex
    }
    let splitIndex = min(6, groups.count)
    let firstLine = groups[..<splitIndex].joined(separator: " ")
    let secondLine = groups.dropFirst(splitIndex).joined(separator: " ")
    if secondLine.isEmpty {
        return firstLine
    } else {
        return firstLine + "\n" + secondLine
    }
}
