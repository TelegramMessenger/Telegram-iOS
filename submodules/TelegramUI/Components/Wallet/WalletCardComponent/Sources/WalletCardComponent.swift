import Foundation
import UIKit
import SwiftSignalKit
import QuartzCore
import simd
import Metal
import MetalEngine
import Display
import ComponentFlow
import AnimatedTextComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import PremiumDiamondComponent
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

private class WalletCardContentView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) {
            return true
        }
        return self.subviews.contains { view in
            view.isUserInteractionEnabled && !view.isHidden && view.alpha > 0.01
                && view.point(inside: view.convert(point, from: self), with: event)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}

private final class WalletCardTransformView: WalletCardContentView {
    override class var layerClass: AnyClass {
        return CATransformLayer.self
    }
}

public final class WalletCardComponent: Component {
    public let theme: PresentationTheme
    public let balance: Int64?
    public let fiatCurrency: WalletContext.FiatCurrency
    public let fiatRate: WalletContext.FiatRate?
    public let dateTimeFormat: PresentationDateTimeFormat
    public let name: String
    public let address: String
    public let isVisible: Bool
    public let cardPressed: (() -> Void)?
    public let qrPressed: () -> Void

    public init(
        theme: PresentationTheme = defaultDarkPresentationTheme,
        balance: Int64?,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat,
        name: String,
        address: String,
        isVisible: Bool,
        cardPressed: (() -> Void)? = nil,
        qrPressed: @escaping () -> Void
    ) {
        self.theme = theme
        self.balance = balance
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
        self.name = name
        self.address = address
        self.isVisible = isVisible
        self.cardPressed = cardPressed
        self.qrPressed = qrPressed
    }

    public static func ==(lhs: WalletCardComponent, rhs: WalletCardComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.fiatCurrency != rhs.fiatCurrency || lhs.fiatRate != rhs.fiatRate {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if (lhs.cardPressed == nil) != (rhs.cardPressed == nil) {
            return false
        }
        return true
    }

    public final class View: UIView {
        private static let maxPitch = 0.20
        private static let maxOverscrollPitch = 12.0 * Double.pi / 180.0
        private static let maxOverscrollScale = 1.05
        private static let maxYaw = 0.30
        private static let thickness: CGFloat = 9.0
        private static let gyroGain = 0.9
        private static let foregroundZPosition: CGFloat = 128.0
        private static let maximumLiftShadowOpacity: Float = 0.16

        private let shadowView = UIView()
        private let backgroundView = WalletCardBackgroundView()
        private let foregroundView = UIControl()
        private let scrollShadingLayer = CAGradientLayer()
        private let balanceTransitionView = WalletCardContentView()
        private weak var balanceTransitionContainer: UIView?

        private let primaryBalanceCollapseContainerView = WalletCardTransformView()
        private let secondaryBalanceCollapseContainerView = WalletCardTransformView()
        private let primaryBalanceContainerView = WalletCardTransformView()
        private let secondaryBalanceContainerView = WalletCardTransformView()

        public private(set) var renderedCardFrame: CGRect = .zero
        public var renderedCardBottomEdge: (left: CGPoint, right: CGPoint) {
            let bounds = self.foregroundView.bounds
            return (
                left: self.foregroundView.convert(CGPoint(x: bounds.minX, y: bounds.maxY), to: self),
                right: self.foregroundView.convert(CGPoint(x: bounds.maxX, y: bounds.maxY), to: self)
            )
        }
        public private(set) var gramIconFrame: CGRect = .zero
        public private(set) var primaryBalanceSourceFrame: CGRect = .zero
        public private(set) var secondaryBalanceSourceFrame: CGRect = .zero
        public var balanceGeometryUpdated: (() -> Void)?

        private var gramIconContentFrame: CGRect = .zero
        private var integralBalanceContentFrame: CGRect = .zero
        private var fractionalBalanceContentFrame: CGRect = .zero
        private var primaryBalanceBaseFrame: CGRect = .zero
        private var secondaryBalanceBaseFrame: CGRect = .zero
        private var primaryBalanceScale: CGFloat = 1.0
        private var balanceTransitionFraction: CGFloat = 0.0
        private var balanceCollapseFraction: CGFloat = 0.0
        private var balanceScrollTransform = CATransform3DIdentity
        private var balanceSourceTransform = CATransform3DIdentity
        private var scrollTransform = CATransform3DIdentity

        private var scrollPitchFraction: CGFloat {
            let pitch = max(0.0, atan2(self.scrollTransform.m23, self.scrollTransform.m22))
            return max(0.0, min(1.0, pitch / (CGFloat.pi / 3.0)))
        }

        private let diamondClipView = WalletCardContentView()
        private let gramDiamond = ComponentView<Empty>()
        private let integralBalance = ComponentView<Empty>()
        private let fractionalBalance = ComponentView<Empty>()
        private let currency = ComponentView<Empty>()
        private let secondaryBalance = ComponentView<Empty>()
        private let name = ComponentView<Empty>()
        private let addressOutline = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let qrButton = ComponentView<Empty>()
        private var qrFrame = CGRect.zero
        private var qrAlpha: CGFloat = 1.0
        private var qrBlurRadius: CGFloat = 0.0

        private var deviceMotionDisposable: Disposable?
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var reflectionRotation = WalletCardBackgroundRotation()
        private var isAnimationVisible = false
        private var isDiamondRenderingEnabled: Bool {
            return self.isAnimationVisible && (self.isScrollVisible || self.balanceTransitionContainer != nil)
        }

        private var gyroPitch = 0.0
        private var gyroRoll = 0.0
        private var panPitch = 0.0
        private var panRoll = 0.0
        private var diamondRotation: Double?
        private var previousDiamondRotation: Double?
        private var diamondRate = 0.0
        private var diamondRoll = 0.0
        private var panTilt = 0.0
        private var overscrollPitch = 0.0
        private var isPanning = false
        private let panGestureRecognizer = UIPanGestureRecognizer()

        private var currentCardX = 0.0
        private var currentCardY = 0.0
        private var currentDepthX = 0.0
        private var currentDepthY = 0.0
        private var currentScale = 1.0
        private var targetScale = 1.0
        private var elapsedTime = 0.0
        private var currentSize = CGSize.zero
        private var isScrollVisible = true

        private var component: WalletCardComponent?

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.shadowView.isUserInteractionEnabled = false
            self.shadowView.backgroundColor = .clear
            self.shadowView.clipsToBounds = false
            self.shadowView.layer.masksToBounds = false
            self.shadowView.layer.shadowColor = UIColor.black.cgColor
            self.shadowView.layer.shadowOpacity = 0.0
            self.shadowView.layer.shadowRadius = 12.0
            self.shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 7.0)
            self.addSubview(self.shadowView)

            self.addSubview(self.backgroundView)
            self.foregroundView.backgroundColor = .clear
            self.foregroundView.clipsToBounds = false
            self.foregroundView.layer.masksToBounds = false
            self.foregroundView.layer.allowsEdgeAntialiasing = true
            self.foregroundView.addTarget(self, action: #selector(self.cardPressed), for: .touchUpInside)
            self.addSubview(self.foregroundView)

            self.scrollShadingLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.scrollShadingLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            self.scrollShadingLayer.colors = [
                UIColor(rgb: 0x001e4d, alpha: 0.22).cgColor,
                UIColor(rgb: 0x001e4d, alpha: 0.03).cgColor
            ]
            self.scrollShadingLayer.locations = [0.0, 1.0]
            self.scrollShadingLayer.opacity = 0.0
            self.scrollShadingLayer.masksToBounds = true
            self.scrollShadingLayer.allowsEdgeAntialiasing = true
            self.foregroundView.layer.addSublayer(self.scrollShadingLayer)

            self.balanceTransitionView.clipsToBounds = false
            self.balanceTransitionView.layer.allowsEdgeAntialiasing = true
            self.balanceTransitionView.layer.zPosition = Self.foregroundZPosition

            self.primaryBalanceCollapseContainerView.clipsToBounds = false
            self.secondaryBalanceCollapseContainerView.clipsToBounds = false
            self.secondaryBalanceCollapseContainerView.isUserInteractionEnabled = false
            self.diamondClipView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.diamondClipView.layer.cornerCurve = .continuous
            }
            self.primaryBalanceContainerView.clipsToBounds = false
            self.secondaryBalanceContainerView.clipsToBounds = false
            self.foregroundView.addSubview(self.primaryBalanceCollapseContainerView)
            self.foregroundView.addSubview(self.secondaryBalanceCollapseContainerView)
            self.primaryBalanceCollapseContainerView.addSubview(self.primaryBalanceContainerView)
            self.secondaryBalanceCollapseContainerView.addSubview(self.secondaryBalanceContainerView)

            self.shadowView.layer.zPosition = -Self.foregroundZPosition
            self.backgroundView.layer.zPosition = 0.0
            self.foregroundView.layer.zPosition = Self.foregroundZPosition

            self.backgroundColor = .clear
            self.clipsToBounds = false
            self.layer.masksToBounds = false
            self.layer.allowsEdgeAntialiasing = true
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true

            self.panGestureRecognizer.addTarget(self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(self.panGestureRecognizer)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.reduceMotionChanged),
                name: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil
            )
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.balanceTransitionView.removeFromSuperview()
            self.displayLink?.invalidate()
            self.deviceMotionDisposable?.dispose()
            NotificationCenter.default.removeObserver(self)
        }

        override public func didMoveToWindow() {
            super.didMoveToWindow()

            self.isAnimationVisible = self.window != nil
            if self.window != nil {
                self.reflectionRotation.reset(to: WalletCardBackgroundMotion.shared.currentRotation)
            }
            self.updateAnimationState()
            if self.window != nil {
                self.renderCurrentFrame()
            }
        }

        override public func willMove(toSuperview newSuperview: UIView?) {
            if newSuperview == nil {
                self.setBalanceTransitionContainer(nil)
            }
            super.willMove(toSuperview: newSuperview)
        }

        func update(
            component: WalletCardComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            if let previousComponent = self.component, previousComponent.isVisible != component.isVisible {
                self.isAnimationVisible = component.isVisible
            }
            self.component = component

            let referenceSize = CGSize(width: 370.0, height: 220.0)
            let width = max(0.0, availableSize.width)
            let scale = width / referenceSize.width
            let size = CGSize(width: width, height: referenceSize.height * scale)
            let cornerRadius = 20.0 * scale

            self.backgroundColor = .clear
            self.clipsToBounds = false
            self.layer.masksToBounds = false
            self.currentSize = size

            for view in [self.integralBalance.view, self.fractionalBalance.view].compactMap({ $0 }) {
                ComponentTransition.immediate.setTransform(view: view, transform: CATransform3DMakeScale(self.primaryBalanceScale, self.primaryBalanceScale, 1.0))
            }
            if let diamondView = self.gramDiamond.view {
                ComponentTransition.immediate.setTransform(view: diamondView, transform: CATransform3DIdentity)
            }

            self.shadowView.bounds = CGRect(origin: .zero, size: size)
            self.shadowView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.shadowView.layer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            self.shadowView.layer.shadowRadius = 12.0 * scale
            self.shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 7.0 * scale)
            self.shadowView.layer.shadowPath = UIBezierPath(
                roundedRect: self.shadowView.bounds,
                cornerRadius: cornerRadius
            ).cgPath

            self.foregroundView.bounds = CGRect(origin: .zero, size: size)
            self.foregroundView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.foregroundView.layer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.scrollShadingLayer.frame = self.foregroundView.bounds
            self.scrollShadingLayer.cornerRadius = cornerRadius
            CATransaction.commit()

            for collapseContainerView in [self.primaryBalanceCollapseContainerView, self.secondaryBalanceCollapseContainerView] {
                ComponentTransition.immediate.setBounds(
                    view: collapseContainerView,
                    bounds: CGRect(origin: CGPoint(), size: size)
                )
                ComponentTransition.immediate.setPosition(
                    view: collapseContainerView,
                    position: CGPoint(x: size.width * 0.5, y: size.height * 0.5)
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
            self.backgroundView.update(cardSize: size, cornerRadius: cornerRadius)

            let formattedBalance: String
            if let balance = component.balance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                formattedBalance = "0"
            }

            let integralText: String
            let fractionalText: String
            if component.balance == nil || component.balance == 0 {
                integralText = formattedBalance
                fractionalText = ""
            } else if let decimalRange = formattedBalance.range(of: component.dateTimeFormat.decimalSeparator) {
                integralText = String(formattedBalance[..<decimalRange.lowerBound])
                fractionalText = String(formattedBalance[decimalRange.lowerBound...])
            } else {
                integralText = formattedBalance
                fractionalText = ""
            }

            let secondaryText: String
            if let balance = component.balance, let fiatRate = component.fiatRate {
                secondaryText = formatTonFiatValue(
                    balance,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: balance == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                secondaryText = "—"
            }

            let mainColor = UIColor.white
            let secondaryColor = UIColor(rgb: 0x6ddcff)
            let qrSize = self.qrButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/CardQr",
                        tintColor: nil,
                        scaleFactor: scale
                    )),
                    minSize: CGSize(width: 50.0, height: 38.0),
                    action: { [weak self] in
                        self?.component?.qrPressed()
                    },
                    animateAlpha: false,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: 80.0 * scale, height: 80.0)
            )
            let qrFrame = CGRect(
                origin: CGPoint(x: width - qrSize.width - 47.0 * scale, y: 82.0 * scale),
                size: qrSize
            )
            self.qrFrame = qrFrame
            let balanceRightEdge = qrFrame.minX - 10.0 * scale
            let integralFont = Font.with(
                size: 22.0 * scale,
                design: .round,
                weight: .semibold,
                traits: .monospacedNumbers
            )
            let fractionalFont = Font.with(
                size: 18.0 * scale,
                design: .round,
                weight: .semibold,
                traits: .monospacedNumbers
            )
            let currencyFont = Font.with(
                size: 22.0 * scale,
                design: .round,
                weight: .semibold
            )
            let unscaledIntegralTextSize = self.integralBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: integralFont,
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramIntegral", content: .text(integralText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let unscaledFractionalSize = self.fractionalBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: fractionalFont,
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramFraction", content: .text(fractionalText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let unscaledCurrencySize = self.currency.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: currencyFont,
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramCurrency", content: .text("GRAM"))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )

            let balanceOriginX = 20.0 * scale
            let unscaledBalanceWidth = (33.25 + (fractionalText.isEmpty ? 0.0 : 1.0) + 5.0) * scale
                + unscaledIntegralTextSize.width + unscaledFractionalSize.width + unscaledCurrencySize.width
            let balanceScale = min(1.0, max(0.0, balanceRightEdge - balanceOriginX) / max(1.0, unscaledBalanceWidth))
            self.primaryBalanceScale = balanceScale
            let balanceContentScale = scale * balanceScale
            let integralTextSize = CGSize(width: unscaledIntegralTextSize.width * balanceScale, height: unscaledIntegralTextSize.height * balanceScale)
            let fractionalSize = CGSize(width: unscaledFractionalSize.width * balanceScale, height: unscaledFractionalSize.height * balanceScale)
            let currencySize = CGSize(width: unscaledCurrencySize.width * balanceScale, height: unscaledCurrencySize.height * balanceScale)
            let gramIconSize = CGSize(width: 30.0 * balanceContentScale, height: 30.0 * balanceContentScale)
            let gramIconSpacing = gramIconSize.width + 3.25 * balanceContentScale
            let integralSize = CGSize(
                width: gramIconSpacing + integralTextSize.width,
                height: max(gramIconSize.height, integralTextSize.height)
            )
            let mainCenterY = 94.0 * scale
            let integralOriginY = floor(mainCenterY - integralSize.height * 0.5)
            
            let mainBaselineY = integralOriginY + floorToScreenPixels(integralFont.ascender) * balanceScale
            var mainOriginX = balanceOriginX
            let integralFrame = CGRect(
                origin: CGPoint(x: mainOriginX, y: integralOriginY),
                size: integralSize
            )
            mainOriginX += integralSize.width
            if !fractionalText.isEmpty {
                mainOriginX += 1.0 * balanceContentScale
            }
            let fractionalFrame = CGRect(
                origin: CGPoint(
                    x: mainOriginX,
                    y: mainBaselineY - floorToScreenPixels(fractionalFont.ascender) * balanceScale
                ),
                size: fractionalSize
            )
            mainOriginX += fractionalSize.width
            mainOriginX += 5.0 * balanceContentScale
            let currencyFrame = CGRect(
                origin: CGPoint(x: mainOriginX, y: mainBaselineY - floorToScreenPixels(currencyFont.ascender) * balanceScale),
                size: currencySize
            )

            var primaryBalanceBaseFrame = integralFrame
            if !fractionalFrame.isEmpty {
                primaryBalanceBaseFrame = primaryBalanceBaseFrame.union(fractionalFrame)
            }
            self.primaryBalanceBaseFrame = primaryBalanceBaseFrame
            self.integralBalanceContentFrame = CGRect(
                origin: CGPoint(x: gramIconSpacing, y: integralFrame.minY - primaryBalanceBaseFrame.minY),
                size: integralTextSize
            )
            self.fractionalBalanceContentFrame = fractionalFrame.offsetBy(
                dx: -primaryBalanceBaseFrame.minX,
                dy: -primaryBalanceBaseFrame.minY
            )
            ComponentTransition.immediate.setBounds(
                view: self.primaryBalanceContainerView,
                bounds: CGRect(origin: CGPoint(), size: primaryBalanceBaseFrame.size)
            )
            ComponentTransition.immediate.setPosition(
                view: self.primaryBalanceContainerView,
                position: primaryBalanceBaseFrame.center
            )

            self.gramIconContentFrame = CGRect(
                origin: CGPoint(
                    x: integralFrame.minX - primaryBalanceBaseFrame.minX - balanceContentScale,
                    y: mainCenterY - primaryBalanceBaseFrame.minY - gramIconSize.height * 0.5 - 3.0 * balanceContentScale
                ),
                size: gramIconSize
            )
            if let integralView = self.integralBalance.view {
                integralView.isUserInteractionEnabled = false
                if integralView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(integralView)
                }
                transition.setBounds(view: integralView, bounds: CGRect(origin: .zero, size: unscaledIntegralTextSize))
                transition.setPosition(view: integralView, position: self.integralBalanceContentFrame.center)
                transition.setScale(view: integralView, scale: balanceScale)
            }
            if let fractionalView = self.fractionalBalance.view {
                fractionalView.isUserInteractionEnabled = false
                if fractionalView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(fractionalView)
                }
                transition.setBounds(view: fractionalView, bounds: CGRect(origin: .zero, size: unscaledFractionalSize))
                transition.setPosition(view: fractionalView, position: self.fractionalBalanceContentFrame.center)
                transition.setScale(view: fractionalView, scale: balanceScale)
            }
            if let currencyView = self.currency.view {
                currencyView.isUserInteractionEnabled = false
                if currencyView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(currencyView)
                }
                transition.setBounds(view: currencyView, bounds: CGRect(origin: .zero, size: unscaledCurrencySize))
                transition.setPosition(
                    view: currencyView,
                    position: currencyFrame.offsetBy(
                        dx: -primaryBalanceBaseFrame.minX,
                        dy: -primaryBalanceBaseFrame.minY
                    ).center
                )
                transition.setScale(view: currencyView, scale: balanceScale)
            }

            let unscaledSecondarySize = self.secondaryBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 14.0 * scale,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "secondaryBalance", content: .text(secondaryText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let secondaryScale = min(1.0, max(0.0, balanceRightEdge - 24.0 * scale) / max(1.0, unscaledSecondarySize.width))
            let secondarySize = CGSize(width: unscaledSecondarySize.width * secondaryScale, height: unscaledSecondarySize.height * secondaryScale)
            self.secondaryBalanceBaseFrame = CGRect(
                origin: CGPoint(x: 24.0 * scale, y: 114.0 * scale),
                size: secondarySize
            )
            let diamondSize = CGSize(width: 96.0 * balanceContentScale, height: 96.0 * balanceContentScale)
            let _ = self.gramDiamond.update(
                transition: .immediate,
                component: AnyComponent(InteractiveDiamondComponent(
                    size: diamondSize,
                    diamondWidth: 26.0 * 1.09 * 0.8 * balanceContentScale,
                    isVisible: self.isDiamondRenderingEnabled,
                    theme: component.theme,
                    appearance: .white,
                    expansionStyle: .wallet,
                    tapToSpin: true
                )),
                environment: {},
                containerSize: diamondSize
            )
            if let diamondView = self.gramDiamond.view as? InteractiveDiamondComponent.View {
                if diamondView.superview == nil {
                    self.primaryBalanceContainerView.addSubview(self.diamondClipView)
                    self.diamondClipView.addSubview(diamondView)
                    self.panGestureRecognizer.require(toFail: diamondView.pressGesture)
                    diamondView.onExpansionChanged = { [weak self] isExpanded in
                        guard let self else { return }
                        if isExpanded {
                            self.primaryBalanceCollapseContainerView.superview?.bringSubviewToFront(self.primaryBalanceCollapseContainerView)
                        } else {
                            self.backgroundView.updateLens(nil)
                        }
                        self.updateDiamondRefraction()
                    }
                    diamondView.onMotionUpdated = { [weak self] motion in
                        self?.diamondRotation = motion.map { Double($0.rotation) }
                    }
                    diamondView.onRefractionUpdated = { [weak self, weak diamondView] geometry in
                        guard let self, let diamondView else { return }
                        guard let geometry, self.balanceTransitionFraction == 0.0,
                              self.isScrollVisible, self.isAnimationVisible,
                              UIApplication.shared.applicationState == .active else {
                            self.backgroundView.updateLens(nil)
                            return
                        }
                        self.backgroundView.updateLens(WalletCardLens(
                            center: diamondView.convert(geometry.center, to: self.foregroundView),
                            hull: geometry.hull.map { diamondView.convert($0, to: self.foregroundView) },
                            strength: geometry.strength, spin: geometry.rotation
                        ))
                    }
                }
                ComponentTransition.immediate.setFrame(view: self.diamondClipView, frame: CGRect(
                    x: -primaryBalanceBaseFrame.minX, y: -primaryBalanceBaseFrame.minY,
                    width: size.width, height: size.height
                ))
                self.diamondClipView.layer.cornerRadius = 20.0 * scale
                transition.setFrame(view: diamondView, frame: CGRect(
                    x: primaryBalanceBaseFrame.minX + self.gramIconContentFrame.midX - diamondSize.width * 0.5,
                    y: primaryBalanceBaseFrame.minY + self.gramIconContentFrame.midY - diamondSize.height * 0.5,
                    width: diamondSize.width,
                    height: diamondSize.height
                ))
                self.primaryBalanceContainerView.bringSubviewToFront(self.diamondClipView)
            }

            ComponentTransition.immediate.setBounds(
                view: self.secondaryBalanceContainerView,
                bounds: CGRect(origin: CGPoint(), size: secondarySize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.secondaryBalanceContainerView,
                position: self.secondaryBalanceBaseFrame.center
            )
            if let secondaryView = self.secondaryBalance.view {
                if secondaryView.superview !== self.secondaryBalanceContainerView {
                    self.secondaryBalanceContainerView.addSubview(secondaryView)
                }
                transition.setBounds(view: secondaryView, bounds: CGRect(origin: .zero, size: unscaledSecondarySize))
                transition.setPosition(view: secondaryView, position: CGPoint(x: secondarySize.width * 0.5, y: secondarySize.height * 0.5))
                transition.setScale(view: secondaryView, scale: secondaryScale)
            }

            let nameSize = self.name.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.name,
                        font: Font.with(size: 14.0 * scale, design: .monospace, weight: .semibold),
                        textColor: mainColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: width - 96.0 * scale, height: 50.0)
            )
            if let nameView = self.name.view {
                nameView.isUserInteractionEnabled = false
                if nameView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(nameView)
                }
                transition.setFrame(
                    view: nameView,
                    frame: CGRect(
                        origin: CGPoint(x: 24.0 * scale, y: size.height - nameSize.height - 19.0 * scale),
                        size: nameSize
                    )
                )
            }
            if let qrView = self.qrButton.view {
                if qrView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(qrView)
                }
                transition.setFrame(
                    view: qrView,
                    frame: qrFrame
                )
            }

            let addressText = formattedWalletAddress(component.address)

            let _ = self.addressOutline.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0 * scale),
                        textColor: UIColor(rgb: 0xffffff, alpha: 0.1)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: -0.05 * scale
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0 * scale),
                        textColor: UIColor(rgb: 0x055ac4, alpha: 0.8)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: -0.05 * scale
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            if let addressView = self.addressOutline.view {
                addressView.isUserInteractionEnabled = false
                if addressView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - addressSize.height - 7.0 * scale, y: size.height * 0.5 + 1.0)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }
            if let addressView = self.address.view {
                addressView.isUserInteractionEnabled = false
                if addressView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - addressSize.height - 7.0 * scale, y: size.height * 0.5)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }

            self.updateAnimationState()
            self.renderCurrentFrame()
            self.updateDiamondRefraction()

            return size
        }

        private func updateDiamondRefraction() {
            guard let diamond = self.gramDiamond.view as? InteractiveDiamondComponent.View else { return }
            guard diamond.isExpanded else {
                diamond.updateRefractionSource(nil)
                return
            }
            let textViews = [self.integralBalance.view, self.fractionalBalance.view, self.currency.view].compactMap { $0 }
            let sourceRect = textViews.reduce(CGRect.null) { rect, view in
                rect.union(view.convert(view.bounds, to: self.primaryBalanceContainerView))
            }.insetBy(dx: -2.0, dy: -2.0).integral
            guard !sourceRect.isNull, !sourceRect.isInfinite else {
                diamond.updateRefractionSource(nil)
                return
            }
            let scale = UIScreen.main.scale
            let width = Int(ceil(sourceRect.width * scale))
            let height = Int(ceil(sourceRect.height * scale))
            guard width > 0, height > 0,
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                  let bytes = context.data else {
                diamond.updateRefractionSource(nil)
                return
            }
            context.clear(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
            context.translateBy(x: 0.0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            for view in textViews {
                let frame = view.convert(view.bounds, to: self.primaryBalanceContainerView)
                context.saveGState()
                context.translateBy(x: frame.minX - sourceRect.minX, y: frame.minY - sourceRect.minY)
                context.scaleBy(x: self.primaryBalanceScale, y: self.primaryBalanceScale)
                view.layer.render(in: context)
                context.restoreGState()
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = .shaderRead
            guard let texture = MetalEngine.shared.device.makeTexture(descriptor: descriptor) else {
                diamond.updateRefractionSource(nil)
                return
            }
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: context.bytesPerRow)
            let rect = self.primaryBalanceContainerView.convert(sourceRect, to: diamond)
                .offsetBy(dx: -diamond.bounds.midX, dy: -diamond.bounds.midY)
            diamond.updateRefractionSource(InteractiveDiamondComponent.RefractionSource(
                texture: texture, uv: SIMD4(0.0, 0.0, 1.0, 1.0), rect: rect, preservesColors: true
            ))
        }

        private func displayLinkDidFire(_ frameDuration: CGFloat) {
            let deltaTime = min(max(Double(frameDuration), 0.0), 1.0 / 30.0)
            guard deltaTime > 0.0 else {
                return
            }
            if !UIAccessibility.isReduceMotionEnabled {
                self.elapsedTime += deltaTime
            }
            self.updateDeviceMotion(at: CACurrentMediaTime())

            if !self.isPanning {
                let decay = exp(-deltaTime * 4.0)
                self.panPitch *= decay
                self.panRoll *= decay
            }

            if !UIAccessibility.isReduceMotionEnabled, let rotation = self.diamondRotation {
                if let previousRotation = self.previousDiamondRotation {
                    let delta = atan2(sin(rotation - previousRotation), cos(rotation - previousRotation))
                    self.diamondRate += (delta / deltaTime - self.diamondRate) * min(1.0, deltaTime * 3.0)
                }
                self.previousDiamondRotation = rotation
            } else {
                self.previousDiamondRotation = nil
                self.diamondRate = 0.0
            }
            let baseSpin = 2.0 * Double.pi / 26.0
            let extraSpin = self.diamondRate - baseSpin * (self.diamondRate >= 0.0 ? 1.0 : -1.0)
            let rollTarget = Self.clamp(
                0.006 * (abs(self.diamondRate) > baseSpin * 1.5 ? extraSpin : 0.0), Self.maxYaw * 0.18
            )
            self.diamondRoll += (rollTarget - self.diamondRoll) * (1.0 - exp(-deltaTime * 2.5))
            let panTarget = min(1.0, hypot(self.panPitch / Self.maxPitch, self.panRoll / Self.maxYaw))
            self.panTilt += (panTarget - self.panTilt) * (1.0 - exp(-deltaTime * 8.0))

            let cardTargetX = Self.clamp(self.panPitch, Self.maxPitch)
            let cardTargetY = Self.clamp(self.panRoll + self.diamondRoll, Self.maxYaw)
            let depthTargetX = Self.clamp(
                self.gyroPitch + self.panPitch,
                Self.maxPitch + 0.03
            )
            let depthTargetY = Self.clamp(
                self.gyroRoll + self.panRoll + self.diamondRoll,
                Self.maxYaw + 0.03
            )
            let smoothing = 1.0 - exp(-deltaTime * 8.0)
            self.currentCardX += (cardTargetX - self.currentCardX) * smoothing
            self.currentCardY += (cardTargetY - self.currentCardY) * smoothing
            self.currentDepthX += (depthTargetX - self.currentDepthX) * smoothing
            self.currentDepthY += (depthTargetY - self.currentDepthY) * smoothing
            self.currentScale += (self.targetScale - self.currentScale) * (1.0 - exp(-deltaTime * 12.0))

            self.renderCurrentFrame()
        }

        private func updateDeviceMotion(at time: CFTimeInterval, isResuming: Bool = false) {
            guard self.deviceMotionDisposable != nil else { return }
            let motion = WalletCardBackgroundMotion.shared
            let rotation = Double(motion.rotation(
                at: time,
                orientation: self.window?.windowScene?.interfaceOrientation ?? .portrait
            ))
            if isResuming {
                self.reflectionRotation.resume(at: time, to: rotation)
            }
            self.reflectionRotation.update(at: time, to: rotation)
            self.gyroPitch = Self.clamp(motion.surfaceTilt.x * Self.gyroGain, Self.maxPitch * 0.85)
            self.gyroRoll = Self.clamp(motion.surfaceTilt.y * Self.gyroGain, Self.maxYaw * 0.8)
        }

        private func updateAnimationState() {
            if let diamond = self.gramDiamond.view as? InteractiveDiamondComponent.View {
                diamond.isRenderingEnabled = self.isDiamondRenderingEnabled
                self.updateDiamondInteraction()
            }
            guard self.component != nil, self.isAnimationVisible,
                  self.isScrollVisible,
                  self.window != nil,
                  UIApplication.shared.applicationState == .active else {
                self.stopAnimation()
                return
            }

            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] frameDuration in
                    self?.displayLinkDidFire(frameDuration)
                }
            }
            if UIAccessibility.isReduceMotionEnabled {
                self.deviceMotionDisposable?.dispose()
                self.deviceMotionDisposable = nil
            } else if self.deviceMotionDisposable == nil {
                self.deviceMotionDisposable = WalletCardBackgroundMotion.shared.subscribe()
                self.updateDeviceMotion(at: CACurrentMediaTime(), isResuming: true)
                self.renderCurrentFrame()
            }
        }

        private func stopAnimation() {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.deviceMotionDisposable?.dispose()
            self.deviceMotionDisposable = nil
            self.gyroPitch = 0.0
            self.gyroRoll = 0.0
            self.previousDiamondRotation = nil
            self.diamondRate = 0.0
            self.diamondRoll = 0.0
            self.backgroundView.updateLens(nil)
        }

        public func updateScrollVisibility(_ isVisible: Bool) {
            guard self.isScrollVisible != isVisible else {
                return
            }
            self.isScrollVisible = isVisible
            self.updateAnimationState()
        }

        private func updateDiamondInteraction() {
            (self.gramDiamond.view as? InteractiveDiamondComponent.View)?.isUserInteractionEnabled =
                self.component?.isVisible == true && self.isAnimationVisible && self.isScrollVisible && self.balanceTransitionFraction == 0.0
        }

        public func updateScrollTransform(_ transform: CATransform3D) {
            guard !CATransform3DEqualToTransform(self.scrollTransform, transform) else {
                return
            }
            self.scrollTransform = transform
            self.renderCurrentFrame(notifyBalanceGeometry: false)
        }

        public func updateOverscroll(distance: CGFloat) {
            let pitch = -Self.maxOverscrollPitch * Double(min(1.0, max(0.0, distance) / 120.0))
            guard self.overscrollPitch != pitch else {
                return
            }
            self.overscrollPitch = pitch
            self.renderCurrentFrame()
        }

        public func setBalanceTransitionContainer(_ container: UIView?) {
            let foregroundView: UIView = container == nil ? self.foregroundView : self.balanceTransitionView
            guard self.balanceTransitionContainer !== container || self.primaryBalanceCollapseContainerView.superview !== foregroundView else {
                return
            }
            self.balanceTransitionContainer = container
            if let container {
                container.addSubview(self.balanceTransitionView)
            }
            foregroundView.addSubview(self.primaryBalanceCollapseContainerView)
            foregroundView.addSubview(self.secondaryBalanceCollapseContainerView)
            if container == nil {
                self.balanceTransitionView.removeFromSuperview()
                self.updateScrollTransform(CATransform3DIdentity)
                self.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: 0.0,
                    collapseFraction: 0.0,
                    transition: .immediate
                )
            } else {
                self.updateBalanceTransitionGeometry()
                self.updateProjectedBalanceFrames()
            }
        }

        private func updateBalanceTransitionGeometry() {
            guard self.balanceTransitionContainer != nil else {
                return
            }

            ComponentTransition.immediate.setBounds(view: self.balanceTransitionView, bounds: self.foregroundView.bounds)
            ComponentTransition.immediate.setPosition(view: self.balanceTransitionView, position: self.foregroundView.layer.position)

            let fraction = 1.0 - max(0.0, min(1.0, self.balanceCollapseFraction))
            var sourceTransform = self.balanceSourceTransform
            if !CATransform3DIsIdentity(self.balanceScrollTransform) {
                sourceTransform.m13 = 0.0
                sourceTransform.m23 = 0.0
                sourceTransform.m33 = 1.0
                sourceTransform.m43 = 0.0
            }
            var transform = CATransform3DConcat(sourceTransform, self.balanceScrollTransform)
            transform.m11 = 1.0 + (transform.m11 - 1.0) * fraction
            transform.m12 *= fraction
            transform.m13 *= fraction
            transform.m14 *= fraction
            transform.m21 *= fraction
            transform.m22 = 1.0 + (transform.m22 - 1.0) * fraction
            transform.m23 *= fraction
            transform.m24 *= fraction
            transform.m31 *= fraction
            transform.m32 *= fraction
            transform.m33 = 1.0 + (transform.m33 - 1.0) * fraction
            transform.m34 *= fraction
            transform.m41 *= fraction
            transform.m42 *= fraction
            transform.m43 *= fraction
            transform.m44 = 1.0 + (transform.m44 - 1.0) * fraction
            ComponentTransition.immediate.setTransform(view: self.balanceTransitionView, transform: transform)
        }

        public func updateBalanceTransition(
            primaryFrame: CGRect?,
            secondaryFrame: CGRect?,
            primaryCollapsedFrame: CGRect?,
            secondaryCollapsedFrame: CGRect?,
            fraction: CGFloat,
            collapseFraction: CGFloat,
            scrollTransform: CATransform3D = CATransform3DIdentity,
            primaryContentTarget: (size: CGSize, text: CGRect, icon: CGRect)? = nil,
            contentFraction: CGFloat = 0.0,
            transition: ComponentTransition
        ) {
            let fraction = max(0.0, min(1.0, fraction))
            self.balanceTransitionFraction = fraction
            self.updateDiamondInteraction()
            self.balanceCollapseFraction = collapseFraction
            self.balanceScrollTransform = scrollTransform
            self.updateBalanceTransitionGeometry()

            self.updateBalanceContainer(
                self.primaryBalanceCollapseContainerView,
                self.primaryBalanceContainerView,
                baseFrame: self.primaryBalanceBaseFrame,
                targetFrame: primaryFrame,
                collapsedFrame: primaryCollapsedFrame,
                collapseFraction: collapseFraction
            )
            self.updateBalanceContainer(
                self.secondaryBalanceCollapseContainerView,
                self.secondaryBalanceContainerView,
                baseFrame: self.secondaryBalanceBaseFrame,
                targetFrame: secondaryFrame,
                collapsedFrame: secondaryCollapsedFrame,
                collapseFraction: collapseFraction
            )
            if let balanceTransitionContainer = self.balanceTransitionContainer,
               let primaryFrame, !primaryFrame.isEmpty,
               let secondaryFrame, !secondaryFrame.isEmpty,
               primaryCollapsedFrame == nil, secondaryCollapsedFrame == nil {
                let primaryRenderedFrame = self.primaryBalanceContainerView.convert(self.primaryBalanceContainerView.bounds, to: balanceTransitionContainer)
                let secondaryRenderedFrame = self.secondaryBalanceContainerView.convert(self.secondaryBalanceContainerView.bounds, to: balanceTransitionContainer)
                let targetSpacing = max(0.0, secondaryFrame.minY - primaryFrame.maxY)
                let spacingAdjustment = (secondaryRenderedFrame.minY - primaryRenderedFrame.maxY - targetSpacing) * 0.5
                for (containerView, offset) in [(self.primaryBalanceContainerView, spacingAdjustment), (self.secondaryBalanceContainerView, -spacingAdjustment)] {
                    let center = self.balanceTransitionView.convert(containerView.center, to: balanceTransitionContainer)
                    ComponentTransition.immediate.setPosition(
                        view: containerView,
                        position: self.balanceTransitionView.convert(CGPoint(x: center.x, y: center.y + offset), from: balanceTransitionContainer)
                    )
                }
                let renderedFrame = self.primaryBalanceContainerView.convert(self.primaryBalanceContainerView.bounds, to: balanceTransitionContainer).union(
                    self.secondaryBalanceContainerView.convert(self.secondaryBalanceContainerView.bounds, to: balanceTransitionContainer)
                )
                let targetFrame = primaryFrame.union(secondaryFrame)
                ComponentTransition.immediate.setPosition(
                    view: self.balanceTransitionView,
                    position: CGPoint(
                        x: self.balanceTransitionView.layer.position.x + targetFrame.midX - renderedFrame.midX,
                        y: self.balanceTransitionView.layer.position.y + targetFrame.midY - renderedFrame.midY
                    )
                )
            }
            self.updateBalanceContent(target: primaryContentTarget, fraction: contentFraction)
            self.updateCardScrollAppearance()
            self.updateProjectedBalanceFrames()
        }

        private func updateBalanceContent(target: (size: CGSize, text: CGRect, icon: CGRect)?, fraction: CGFloat) {
            let textFrame = self.fractionalBalanceContentFrame.isEmpty
                ? self.integralBalanceContentFrame
                : self.integralBalanceContentFrame.union(self.fractionalBalanceContentFrame)
            guard !textFrame.isEmpty, !self.gramIconContentFrame.isEmpty else {
                return
            }

            func contentFrame(_ source: CGRect, targetFrame: CGRect?) -> CGRect {
                guard let target, let targetFrame, target.size.width > 0.0, target.size.height > 0.0 else {
                    return source
                }
                let scaleX = self.primaryBalanceBaseFrame.width / target.size.width
                let scaleY = self.primaryBalanceBaseFrame.height / target.size.height
                return CGRect(
                    x: source.minX + (targetFrame.minX * scaleX - source.minX) * fraction,
                    y: source.minY + (targetFrame.minY * scaleY - source.minY) * fraction,
                    width: source.width + (targetFrame.width * scaleX - source.width) * fraction,
                    height: source.height + (targetFrame.height * scaleY - source.height) * fraction
                )
            }

            let targetTextFrame = contentFrame(textFrame, targetFrame: target?.text)
            let textScaleX = targetTextFrame.width / textFrame.width
            let textScaleY = targetTextFrame.height / textFrame.height
            for (view, frame) in [(self.integralBalance.view, self.integralBalanceContentFrame), (self.fractionalBalance.view, self.fractionalBalanceContentFrame)] {
                if let view {
                    ComponentTransition.immediate.setTransform(view: view, transform: CATransform3DMakeScale(textScaleX * self.primaryBalanceScale, textScaleY * self.primaryBalanceScale, 1.0))
                    ComponentTransition.immediate.setPosition(view: view, position: CGPoint(
                        x: targetTextFrame.minX + (frame.midX - textFrame.minX) * textScaleX,
                        y: targetTextFrame.minY + (frame.midY - textFrame.minY) * textScaleY
                    ))
                }
            }
            if let diamondView = self.gramDiamond.view {
                let targetIconFrame = target.map { layout in
                    layout.icon.insetBy(dx: layout.icon.width * 0.0545, dy: layout.icon.height * 0.0545)
                }
                let iconFrame = contentFrame(self.gramIconContentFrame, targetFrame: targetIconFrame)
                let center = CGPoint(
                    x: self.primaryBalanceBaseFrame.minX + iconFrame.midX,
                    y: self.primaryBalanceBaseFrame.minY + iconFrame.midY
                )
                ComponentTransition.immediate.setPosition(view: diamondView, position: center)
                ComponentTransition.immediate.setTransform(view: diamondView, transform: self.diamondScrollTransform(
                    center: center,
                    scaleX: iconFrame.width / self.gramIconContentFrame.width,
                    scaleY: iconFrame.height / self.gramIconContentFrame.height
                ))
            }
        }

        private func diamondScrollTransform(center: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CATransform3D {
            let contentTransform = CATransform3DMakeScale(scaleX, scaleY, 1.0)
            guard self.balanceTransitionContainer != nil, self.balanceTransitionFraction > 0.0 else {
                return contentTransform
            }

            let origin = self.diamondClipView.convert(center, to: self.balanceTransitionView)
            let right = self.diamondClipView.convert(CGPoint(x: center.x + 1.0, y: center.y), to: self.balanceTransitionView)
            let bottom = self.diamondClipView.convert(CGPoint(x: center.x, y: center.y + 1.0), to: self.balanceTransitionView)
            let bounds = self.balanceTransitionView.bounds
            let anchor = self.balanceTransitionView.layer.anchorPoint
            var localTransform = CATransform3DIdentity
            localTransform.m11 = right.x - origin.x
            localTransform.m12 = right.y - origin.y
            localTransform.m21 = bottom.x - origin.x
            localTransform.m22 = bottom.y - origin.y
            localTransform.m41 = origin.x - bounds.minX - bounds.width * anchor.x
            localTransform.m42 = origin.y - bounds.minY - bounds.height * anchor.y

            var projection = CATransform3DConcat(localTransform, self.balanceTransitionView.layer.transform)
            projection.m13 = 0.0
            projection.m23 = 0.0
            projection.m31 = 0.0
            projection.m32 = 0.0
            projection.m33 = 1.0
            projection.m34 = 0.0
            projection.m43 = 0.0
            let w = projection.m44
            guard abs(w) > 0.0001 else {
                return contentTransform
            }

            let horizontalX = (projection.m11 * w - projection.m41 * projection.m14) / (w * w)
            let horizontalY = (projection.m12 * w - projection.m42 * projection.m14) / (w * w)
            let scale = hypot(horizontalX, horizontalY) * scaleX
            var targetTransform = CATransform3DMakeScale(scale, scale, 1.0)
            targetTransform.m41 = projection.m41 / w
            targetTransform.m42 = projection.m42 / w
            return CATransform3DConcat(targetTransform, CATransform3DInvert(projection))
        }

        private func updateCardScrollAppearance() {
            let detailsFraction = max(0.0, min(1.0, (self.balanceTransitionFraction - 0.3) / 0.3))
            let easedDetailsFraction = detailsFraction * detailsFraction * (3.0 - 2.0 * detailsFraction)
            let detailsAlpha = 1.0 - easedDetailsFraction
            self.qrAlpha = detailsAlpha
            self.qrBlurRadius = easedDetailsFraction * 8.0
            for view in [self.name.view, self.qrButton.view, self.address.view, self.addressOutline.view] {
                if let view {
                    ComponentTransition.immediate.setAlpha(view: view, alpha: detailsAlpha)
                    view.layer.removeAnimation(forKey: "filters.gaussianBlur.inputRadius")
                    if easedDetailsFraction > 0.0 {
                        ComponentTransition.immediate.setBlur(layer: view.layer, radius: easedDetailsFraction * 8.0)
                    } else {
                        view.layer.filters = nil
                    }
                }
            }
            if let currencyView = self.currency.view {
                let fadeFraction = min(1.0, self.balanceTransitionFraction / 0.25)
                let alpha = 1.0 - fadeFraction * fadeFraction * (3.0 - 2.0 * fadeFraction)
                ComponentTransition.immediate.setAlpha(view: currencyView, alpha: alpha)
            }

            let pitchFraction = self.scrollPitchFraction
            let shadingFraction = pitchFraction * pitchFraction * (3.0 - 2.0 * pitchFraction)

            let liftProgress = max(0.0, min(1.0, (self.currentScale - 1.0) / 0.02))
            let easedLiftProgress = liftProgress * liftProgress * (3.0 - 2.0 * liftProgress)
            let liftShadowOpacity = Self.maximumLiftShadowOpacity * Float(easedLiftProgress)
            let shadowWave = sin(CGFloat.pi * self.balanceTransitionFraction)
            let scrollShadowOpacity = Float(0.12 * shadowWave * shadowWave)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.scrollShadingLayer.opacity = Float(shadingFraction)
            self.shadowView.layer.shadowOpacity = max(liftShadowOpacity, scrollShadowOpacity)
            CATransaction.commit()
        }

        private func updateBalanceContainer(
            _ collapseContainerView: UIView,
            _ containerView: UIView,
            baseFrame: CGRect,
            targetFrame: CGRect?,
            collapsedFrame: CGRect?,
            collapseFraction: CGFloat
        ) {
            guard !baseFrame.isEmpty,
                  let targetFrame,
                  !targetFrame.isEmpty,
                  targetFrame.width.isFinite,
                  targetFrame.height.isFinite else {
                ComponentTransition.immediate.setPosition(view: containerView, position: baseFrame.center)
                ComponentTransition.immediate.setTransform(view: containerView, transform: CATransform3DIdentity)
                ComponentTransition.immediate.setTransform(view: collapseContainerView, transform: CATransform3DIdentity)
                return
            }

            let foregroundView: UIView
            let coordinateView: UIView
            if let balanceTransitionContainer = self.balanceTransitionContainer {
                foregroundView = self.balanceTransitionView
                coordinateView = balanceTransitionContainer
            } else {
                foregroundView = self.foregroundView
                coordinateView = self
            }
            let targetFrameInForeground: CGRect
            if self.balanceTransitionContainer != nil && collapsedFrame == nil {
                let sourceFrame = self.projectedFrame(baseFrame, transform: self.balanceSourceTransform)
                let fraction = max(0.0, min(1.0, collapseFraction))
                let referenceSize = CGSize(
                    width: sourceFrame.width + (baseFrame.width - sourceFrame.width) * fraction,
                    height: sourceFrame.height + (baseFrame.height - sourceFrame.height) * fraction
                )
                let size = CGSize(
                    width: targetFrame.width * baseFrame.width / referenceSize.width,
                    height: targetFrame.height * baseFrame.height / referenceSize.height
                )
                let center = foregroundView.convert(targetFrame.center, from: coordinateView)
                targetFrameInForeground = CGRect(
                    origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5),
                    size: size
                )
            } else {
                targetFrameInForeground = foregroundView.convert(targetFrame, from: coordinateView)
            }
            let scaleX = targetFrameInForeground.width / baseFrame.width
            let scaleY = targetFrameInForeground.height / baseFrame.height
            ComponentTransition.immediate.setPosition(
                view: containerView,
                position: targetFrameInForeground.center
            )
            ComponentTransition.immediate.setTransform(
                view: containerView,
                transform: CATransform3DMakeScale(scaleX, scaleY, 1.0)
            )

            let collapseTransform: CATransform3D
            if let collapsedFrame,
               !collapsedFrame.isEmpty,
               collapsedFrame.width.isFinite,
               collapsedFrame.height.isFinite {
                collapseTransform = self.collapseTransform(
                    in: collapseContainerView,
                    from: targetFrameInForeground,
                    to: foregroundView.convert(collapsedFrame, from: coordinateView),
                    fraction: collapseFraction
                )
            } else {
                collapseTransform = CATransform3DIdentity
            }
            ComponentTransition.immediate.setTransform(view: collapseContainerView, transform: collapseTransform)
        }

        private func collapseTransform(in containerView: UIView, from sourceFrame: CGRect, to targetFrame: CGRect, fraction: CGFloat) -> CATransform3D {
            let scaleX = targetFrame.width / sourceFrame.width
            let scaleY = targetFrame.height / sourceFrame.height
            let anchor = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
            var transform = CATransform3DMakeScale(1.0 + (scaleX - 1.0) * fraction, 1.0 + (scaleY - 1.0) * fraction, 1.0)
            transform.m41 = (targetFrame.midX - anchor.x - (sourceFrame.midX - anchor.x) * scaleX) * fraction
            transform.m42 = (targetFrame.midY - anchor.y - (sourceFrame.midY - anchor.y) * scaleY) * fraction
            return transform
        }

        private func updateProjectedBalanceFrames() {
            if self.primaryBalanceBaseFrame.isEmpty {
                self.primaryBalanceSourceFrame = .zero
            } else {
                self.primaryBalanceSourceFrame = self.projectedFrame(
                    self.primaryBalanceBaseFrame,
                    transform: self.balanceSourceTransform
                )
            }
            if self.secondaryBalanceBaseFrame.isEmpty {
                self.secondaryBalanceSourceFrame = .zero
            } else {
                self.secondaryBalanceSourceFrame = self.projectedFrame(
                    self.secondaryBalanceBaseFrame,
                    transform: self.balanceSourceTransform
                )
            }
            if self.gramIconContentFrame.isEmpty {
                self.gramIconFrame = .zero
            } else {
                self.gramIconFrame = self.primaryBalanceContainerView.convert(
                    self.gramIconContentFrame,
                    to: self
                )
            }
        }

        private func makePerspectiveTransform(pitch: Double, scale: Double) -> CATransform3D {
            var perspectiveTransform = CATransform3DIdentity
            perspectiveTransform.m34 = -1.0 / 650.0
            perspectiveTransform = CATransform3DTranslate(
                perspectiveTransform,
                CGFloat(-self.currentCardY * 3.0),
                CGFloat(self.currentCardX * 2.5),
                0.0
            )
            perspectiveTransform = CATransform3DScale(
                perspectiveTransform,
                CGFloat(scale),
                CGFloat(scale),
                1.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(pitch),
                1.0,
                0.0,
                0.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(self.currentCardY),
                0.0,
                1.0,
                0.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(self.currentCardY * 0.05),
                0.0,
                0.0,
                1.0
            )

            return perspectiveTransform
        }

        private func renderCurrentFrame(notifyBalanceGeometry: Bool = true) {
            guard self.currentSize.width > 0.0, self.currentSize.height > 0.0 else {
                return
            }

            let maxPitch = max(Self.maxPitch, Self.maxOverscrollPitch)
            let cardPitch = Self.clamp(self.currentCardX + self.overscrollPitch, maxPitch)
            let overscrollFraction = -self.overscrollPitch / Self.maxOverscrollPitch
            let overscrollScale = 1.0 + (Self.maxOverscrollScale - 1.0) * overscrollFraction
            var perspectiveTransform = self.makePerspectiveTransform(pitch: cardPitch, scale: self.currentScale * overscrollScale)
            if self.overscrollPitch != 0.0 {
                func projectedBottomY(_ transform: CATransform3D) -> CGFloat {
                    let y = self.currentSize.height * 0.5
                    let w = y * transform.m24 + transform.m44
                    let safeW = abs(w) < 0.0001 ? 0.0001 : w
                    return (y * transform.m22 + transform.m42) / safeW
                }

                let baseTransform = self.makePerspectiveTransform(pitch: self.currentCardX, scale: self.currentScale)
                let bottomOffset = projectedBottomY(baseTransform) - projectedBottomY(perspectiveTransform)
                perspectiveTransform = CATransform3DConcat(
                    perspectiveTransform,
                    CATransform3DMakeTranslation(0.0, bottomOffset, 0.0)
                )
            }

            let edgeShift = self.edgeShift(pitch: cardPitch, yaw: self.currentCardY)
            let bounds = CGRect(origin: .zero, size: self.currentSize)
            let anchorX = self.currentSize.width * 0.5
            var reachX: CGFloat = 0.0
            for corner in [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                           CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)] {
                let x = self.projectedPoint(corner, transform: perspectiveTransform).point.x - anchorX
                reachX = max(reachX, max(abs(x), abs(x + edgeShift.x)))
            }
            let fitScale = reachX > anchorX ? anchorX / reachX : 1.0
            perspectiveTransform = CATransform3DConcat(perspectiveTransform, CATransform3DMakeScale(fitScale, fitScale, 1.0))
            var backTransform = CATransform3DConcat(perspectiveTransform,
                CATransform3DMakeTranslation(edgeShift.x * fitScale, edgeShift.y * fitScale, 0.0))

            self.balanceSourceTransform = perspectiveTransform
            // Project the slab before collapsing the card; both faces then follow the same scroll transform.
            func scrolled(_ transform: CATransform3D) -> CATransform3D {
                guard !CATransform3DIsIdentity(self.scrollTransform) else { return transform }
                var result = transform
                result.m13 = 0.0
                result.m23 = 0.0
                result.m33 = 1.0
                result.m43 = 0.0
                return CATransform3DConcat(result, self.scrollTransform)
            }
            perspectiveTransform = scrolled(perspectiveTransform)
            backTransform = scrolled(backTransform)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.shadowView.layer.transform = perspectiveTransform
            self.foregroundView.layer.transform = perspectiveTransform
            CATransaction.commit()
            self.updateCardScrollAppearance()
            self.renderedCardFrame = self.foregroundView.convert(self.foregroundView.bounds, to: self)
            self.updateBalanceTransitionGeometry()
            self.backgroundView.updateFallbackTransform(perspectiveTransform)

            let projectedQuad = self.projectedQuad(for: perspectiveTransform)

            self.updateProjectedBalanceFrames()

            if let diamond = self.gramDiamond.view as? InteractiveDiamondComponent.View {
                let scale = self.currentSize.width / 370.0
                let tilt = self.panTilt * self.panTilt * (3.0 - 2.0 * self.panTilt)
                let diamondCenter = CGPoint(
                    x: self.primaryBalanceBaseFrame.minX + self.gramIconContentFrame.midX,
                    y: self.primaryBalanceBaseFrame.minY + self.gramIconContentFrame.midY
                )
                let followsCardTilt = CATransform3DIsIdentity(self.scrollTransform)
                diamond.updateWalletTilt(
                    pitch: followsCardTilt ? CGFloat(cardPitch) : 0.0,
                    roll: followsCardTilt ? CGFloat(self.currentCardY) : 0.0,
                    scale: 1.0 + 0.16 * CGFloat(tilt),
                    leftInset: diamondCenter.x - 14.0 * scale * self.primaryBalanceScale,
                    starCanvasSize: CGSize(
                        width: 2.0 * (max(diamondCenter.x, self.currentSize.width - diamondCenter.x) + 2.0),
                        height: 2.0 * (max(diamondCenter.y, self.currentSize.height - diamondCenter.y) + 2.0)
                    )
                )
            }

            let highlightFraction = min(1.0, self.scrollPitchFraction / 0.64)
            let easedHighlightFraction = highlightFraction * highlightFraction * (3.0 - 2.0 * highlightFraction)
            let scrollHighlightPitch = Double(easedHighlightFraction) * Self.maxPitch
            self.backgroundView.render(
                time: self.elapsedTime,
                reflectionRotation: self.reflectionRotation.value,
                highlightTiltX: Self.clamp(self.currentCardX + self.overscrollPitch + scrollHighlightPitch, maxPitch + 0.03),
                highlightTiltY: self.currentCardY,
                surfaceTiltX: Self.clamp(self.currentDepthX + self.overscrollPitch, maxPitch + 0.03),
                surfaceTiltY: self.currentDepthY,
                quad: projectedQuad,
                backQuad: self.projectedQuad(for: backTransform),
                qrChip: WalletCardQRChip(frame: self.qrFrame, alpha: self.qrAlpha, blurRadius: self.qrBlurRadius)
            )
            (self.qrButton.view as? PlainButtonComponent.View)?.contentView?.isHidden = self.backgroundView.displaysQRChip

            if notifyBalanceGeometry {
                self.balanceGeometryUpdated?()
            }
        }

        private func edgeShift(pitch: Double, yaw: Double) -> CGPoint {
            let depth = -Self.thickness * self.currentSize.width / 370.0 * self.currentScale
            var rotation = CATransform3DRotate(CATransform3DIdentity, CGFloat(pitch), 1.0, 0.0, 0.0)
            rotation = CATransform3DRotate(rotation, CGFloat(yaw), 0.0, 1.0, 0.0)
            return CGPoint(x: depth * rotation.m31, y: depth * rotation.m32)
        }

        private func projectedFrame(_ frame: CGRect, transform: CATransform3D) -> CGRect {
            let topLeft = self.projectedPoint(CGPoint(x: frame.minX, y: frame.minY), transform: transform).point
            let topRight = self.projectedPoint(CGPoint(x: frame.maxX, y: frame.minY), transform: transform).point
            let bottomLeft = self.projectedPoint(CGPoint(x: frame.minX, y: frame.maxY), transform: transform).point
            let bottomRight = self.projectedPoint(CGPoint(x: frame.maxX, y: frame.maxY), transform: transform).point
            let minX = min(min(topLeft.x, topRight.x), min(bottomLeft.x, bottomRight.x))
            let maxX = max(max(topLeft.x, topRight.x), max(bottomLeft.x, bottomRight.x))
            let minY = min(min(topLeft.y, topRight.y), min(bottomLeft.y, bottomRight.y))
            let maxY = max(max(topLeft.y, topRight.y), max(bottomLeft.y, bottomRight.y))
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        private func projectedPoint(_ point: CGPoint, transform: CATransform3D) -> (point: CGPoint, w: CGFloat) {
            let anchor = CGPoint(x: self.currentSize.width * 0.5, y: self.currentSize.height * 0.5)
            let x = point.x - anchor.x
            let y = point.y - anchor.y
            let transformedX = x * transform.m11 + y * transform.m21 + transform.m41
            let transformedY = x * transform.m12 + y * transform.m22 + transform.m42
            let transformedW = x * transform.m14 + y * transform.m24 + transform.m44
            let safeW = abs(transformedW) < 0.0001 ? 0.0001 : transformedW
            return (
                CGPoint(x: anchor.x + transformedX / safeW, y: anchor.y + transformedY / safeW),
                safeW
            )
        }

        private func projectedQuad(for transform: CATransform3D) -> WalletCardProjectedQuad {
            let sourceBounds = CGRect(origin: .zero, size: self.currentSize)
            let topLeft = self.projectedPoint(CGPoint(x: sourceBounds.minX, y: sourceBounds.minY), transform: transform)
            let topRight = self.projectedPoint(CGPoint(x: sourceBounds.maxX, y: sourceBounds.minY), transform: transform)
            let bottomLeft = self.projectedPoint(CGPoint(x: sourceBounds.minX, y: sourceBounds.maxY), transform: transform)
            let bottomRight = self.projectedPoint(CGPoint(x: sourceBounds.maxX, y: sourceBounds.maxY), transform: transform)

            func clipPosition(_ projected: (point: CGPoint, w: CGFloat)) -> SIMD4<Float> {
                let padding = WalletCardBackgroundView.projectionPadding
                let width = max(self.currentSize.width + padding * 2.0, 1.0)
                let height = max(self.currentSize.height + padding * 2.0, 1.0)
                let normalizedX = Float(((projected.point.x + padding) / width) * 2.0 - 1.0)
                let normalizedY = Float(1.0 - ((projected.point.y + padding) / height) * 2.0)
                let w = Float(projected.w)
                return SIMD4<Float>(normalizedX * w, normalizedY * w, 0.0, w)
            }

            return WalletCardProjectedQuad(
                bottomLeft: clipPosition(bottomLeft),
                bottomRight: clipPosition(bottomRight),
                topLeft: clipPosition(topLeft),
                topRight: clipPosition(topRight)
            )
        }

        @objc private func cardPressed() {
            self.component?.cardPressed?()
        }

        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                self.isPanning = true
                self.targetScale = 1.01
            case .changed:
                let translation = gestureRecognizer.translation(in: self)
                let designScale = max(self.currentSize.width / 361.0, 0.01)
                let travel = 240.0 * designScale
                self.panRoll = Self.clamp(Double(translation.x / travel) * Self.maxYaw, Self.maxYaw)
                self.panPitch = Self.clamp(-Double(translation.y / travel) * Self.maxPitch, Self.maxPitch)
            case .ended, .cancelled, .failed:
                self.isPanning = false
                self.targetScale = 1.0
            default:
                break
            }
        }

        @objc private func applicationDidBecomeActive() {
            self.gyroPitch = 0.0
            self.gyroRoll = 0.0
            self.currentDepthX = self.currentCardX
            self.currentDepthY = self.currentCardY
            self.updateAnimationState()
        }

        @objc private func applicationWillResignActive() {
            self.stopAnimation()
        }

        @objc private func reduceMotionChanged() {
            self.updateAnimationState()
        }

        private static func clamp(_ value: Double, _ limit: Double) -> Double {
            return max(-limit, min(limit, value))
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
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
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private func formattedWalletAddress(_ address: String) -> String {
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
