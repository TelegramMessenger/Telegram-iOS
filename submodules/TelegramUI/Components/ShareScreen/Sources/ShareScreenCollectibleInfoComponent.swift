import Foundation
import UIKit
import CoreText
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MultilineTextComponent
import LottieComponent
import LottieSettings

final class ShareScreenCollectibleInfoComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let info: TelegramCollectibleItemInfo
    let openUrl: (String) -> Void

    init(theme: PresentationTheme, strings: PresentationStrings, info: TelegramCollectibleItemInfo, openUrl: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.info = info
        self.openUrl = openUrl
    }

    static func ==(lhs: ShareScreenCollectibleInfoComponent, rhs: ShareScreenCollectibleInfoComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.strings === rhs.strings && lhs.info == rhs.info
    }

    private final class RunDelegateData {
        let ascent: CGFloat
        let descent: CGFloat
        let width: CGFloat

        init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
            self.ascent = ascent
            self.descent = descent
            self.width = width
        }
    }

    final class View: UIView {
        private let background = UIView()
        private let icon = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private var currencySymbolIcon: UIImage?
        private var arrowIcon: UIImage?
        private var component: ShareScreenCollectibleInfoComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.background.layer.cornerRadius = 16.0
            self.background.layer.cornerCurve = .continuous
            self.addSubview(self.background)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func makeText(component: ShareScreenCollectibleInfoComponent) -> NSAttributedString {
            let info = component.info
            let strings = component.strings
            var username = ""
            if case let .username(value) = info.subject {
                username = value
            }
            let dateText = stringForDate(timestamp: info.purchaseDate, strings: strings)
            let (rawCryptoCurrencyText, cryptoCurrencySign, _) = formatCurrencyAmountCustom(info.cryptoCurrencyAmount, currency: info.cryptoCurrency, customFormat: CurrencyFormatterEntry(
                symbol: "~",
                thousandsSeparator: ",",
                decimalSeparator: ".",
                symbolOnLeft: true,
                spaceBetweenAmountAndSymbol: false,
                decimalDigits: 9
            ))
            var cryptoCurrencyText = rawCryptoCurrencyText
            while cryptoCurrencyText.hasSuffix("0") {
                cryptoCurrencyText.removeLast()
            }
            if cryptoCurrencyText.hasSuffix(".") {
                cryptoCurrencyText.removeLast()
            }
            let (currencyText, currencySign, _) = formatCurrencyAmountCustom(info.currencyAmount, currency: info.currency)
            let rawText = strings.CollectibleItemInfo_UsernameText("@\(username)", strings.CollectibleItemInfo_StoreName, dateText, "\(cryptoCurrencySign)\(cryptoCurrencyText)", "\(currencySign)\(currencyText)")
            let result = NSMutableAttributedString(string: rawText.string, font: Font.regular(14.0), textColor: component.theme.list.itemPrimaryTextColor)
            for range in rawText.ranges where [0, 1, 3].contains(range.index) {
                result.addAttribute(.font, value: Font.semibold(14.0), range: range.range)
            }

            if self.currencySymbolIcon == nil, let image = UIImage(bundleImageName: "Wallet/TransactionGram") {
                let iconSize = CGSize(width: 15.0, height: 15.0)
                self.currencySymbolIcon = generateImage(CGSize(width: iconSize.width, height: iconSize.height + 4.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if let cgImage = image.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: iconSize))
                    }
                })?.withRenderingMode(.alwaysOriginal)
            }
            let currencySymbolRange = (result.string as NSString).range(of: "~")
            if currencySymbolRange.location != NSNotFound, let currencySymbolIcon = self.currencySymbolIcon {
                result.replaceCharacters(in: currencySymbolRange, with: "$")
                result.addAttribute(.attachment, value: currencySymbolIcon, range: currencySymbolRange)
                let font = Font.semibold(14.0)
                let data = RunDelegateData(ascent: font.ascender, descent: font.descender, width: currencySymbolIcon.size.width + 1.0)
                var callbacks = CTRunDelegateCallbacks(
                    version: kCTRunDelegateCurrentVersion,
                    dealloc: { dataRef in
                        Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                    },
                    getAscent: { dataRef in
                        return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().ascent
                    },
                    getDescent: { dataRef in
                        return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().descent
                    },
                    getWidth: { dataRef in
                        return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
                    }
                )
                if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(data).toOpaque()) {
                    result.addAttribute(NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String), value: runDelegate, range: currencySymbolRange)
                }
            }

            if self.arrowIcon == nil, let templateImage = UIImage(bundleImageName: "Settings/TextArrowRight") {
                let imageSize = CGSize(width: floor(templateImage.size.width * 0.8), height: floor(templateImage.size.height * 0.8))
                self.arrowIcon = generateImage(imageSize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if let cgImage = templateImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                    }
                })?.withRenderingMode(.alwaysTemplate)
            }
            result.append(NSAttributedString(string: " \(strings.CollectibleItemInfo_ShareInlineText_LearnMore)", attributes: [
                .font: Font.medium(14.0),
                .foregroundColor: component.theme.list.itemAccentColor,
                NSAttributedString.Key(rawValue: "URL"): ""
            ]))
            if let range = result.string.range(of: ">"), let arrowIcon = self.arrowIcon {
                result.addAttribute(.attachment, value: arrowIcon, range: NSRange(range, in: result.string))
            }
            return result
        }

        func update(component: ShareScreenCollectibleInfoComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            let insets = UIEdgeInsets(top: 10.0, left: 50.0, bottom: 10.0, right: 12.0)
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(self.makeText(component: component)),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.185,
                    highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightAction: { attributes in
                        return attributes[NSAttributedString.Key(rawValue: "URL")] != nil ? NSAttributedString.Key(rawValue: "URL") : nil
                    },
                    tapAction: { [weak self] _, _ in
                        guard let component = self?.component else { return }
                        component.openUrl(component.info.url)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - insets.left - insets.right, height: 1000.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: textSize)
            }
            let size = CGSize(width: availableSize.width, height: insets.top + textSize.height + insets.bottom)
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_collectible_username"),
                    color: component.theme.list.itemAccentColor,
                    loop: false,
                    lottieSettings: .noAccountFallback
                )),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                    iconView.playOnce(delay: 0.1)
                }
                iconView.frame = CGRect(origin: CGPoint(x: floor((insets.left - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            }
            self.background.backgroundColor = component.theme.list.blocksBackgroundColor
            self.background.frame = CGRect(origin: .zero, size: size)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
