import Foundation
import UIKit
import CoreText
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import LottieSettings

public let anonymousNumbersCountryId = "FT"
private let anonymousNumbersFlagAnimationName = "GramDiamond"

public struct CountryFlagAnimationEmbeddedItem: Hashable {
    public let name: String
    public let fontSize: CGFloat
}

private final class CountryFlagRunDelegateData {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat

    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

private func countryFlagAnimationSide(fontSize: CGFloat) -> CGFloat {
    return floorToScreenPixels(fontSize * 24.0 / 17.0)
}

public func countryFlagAttributedString(countryId: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
    guard countryId == anonymousNumbersCountryId else {
        return NSAttributedString(string: emojiFlagForISOCountryCode(countryId), font: font, textColor: textColor)
    }

    let string = NSMutableAttributedString(string: "\u{FFFC}", font: font, textColor: textColor)
    let range = NSRange(location: 0, length: string.length)
    string.addAttribute(NSAttributedString.Key("Attribute__EmbeddedItem"), value: AnyHashable(CountryFlagAnimationEmbeddedItem(name: anonymousNumbersFlagAnimationName, fontSize: font.pointSize)), range: range)

    let runDelegateData = CountryFlagRunDelegateData(ascent: font.ascender, descent: font.descender, width: countryFlagAnimationSide(fontSize: font.pointSize))
    var callbacks = CTRunDelegateCallbacks(
        version: kCTRunDelegateCurrentVersion,
        dealloc: { dataRef in
            Unmanaged<CountryFlagRunDelegateData>.fromOpaque(dataRef).release()
        },
        getAscent: { dataRef in
            return Unmanaged<CountryFlagRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().ascent
        },
        getDescent: { dataRef in
            return Unmanaged<CountryFlagRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().descent
        },
        getWidth: { dataRef in
            return Unmanaged<CountryFlagRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
        }
    )
    if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
        string.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: range)
    }
    return string
}

public func countryFlagAndNameAttributedString(countryId: String, name: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
    let string = NSMutableAttributedString(attributedString: countryFlagAttributedString(countryId: countryId, font: font, textColor: textColor))
    string.append(NSAttributedString(string: " \(name)", font: font, textColor: textColor))
    return string
}

public final class CountryFlagTextAnimations {
    private var animationNodes: [DefaultAnimatedStickerNodeImpl] = []

    public init() {
    }

    public func update(layout: TextNodeLayout?, in containerView: UIView) {
        var frames: [(String, CGRect)] = []
        if let layout {
            for item in layout.embeddedItems {
                guard let flagItem = item.value.base as? CountryFlagAnimationEmbeddedItem else {
                    continue
                }
                let side = countryFlagAnimationSide(fontSize: flagItem.fontSize)
                let center = item.rect.offsetBy(dx: layout.insets.left, dy: layout.insets.top - flagItem.fontSize * 0.04).center
                let frame = CGRect(x: floorToScreenPixels(center.x - side / 2.0), y: floorToScreenPixels(center.y - side / 2.0), width: side, height: side)
                frames.append((flagItem.name, frame))
            }
        }

        while self.animationNodes.count > frames.count {
            self.animationNodes.removeLast().view.removeFromSuperview()
        }
        for i in 0 ..< frames.count {
            let (name, frame) = frames[i]
            let animationNode: DefaultAnimatedStickerNodeImpl
            if i < self.animationNodes.count {
                animationNode = self.animationNodes[i]
            } else {
                animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)
                animationNode.isUserInteractionEnabled = false
                let pixelSide = Int(frame.width * UIScreenScale)
                animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: name), width: pixelSide, height: pixelSide, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                self.animationNodes.append(animationNode)
            }
            if animationNode.view.superview !== containerView {
                containerView.addSubview(animationNode.view)
            }
            animationNode.frame = frame
            animationNode.updateLayout(size: frame.size)
            animationNode.visibility = true
        }
    }
}

open class CountryButtonNode: ASButtonNode {
    private let flagAnimations = CountryFlagTextAnimations()
    private let flagContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    public func setCountryTitle(countryId: String, name: String, font: UIFont, color: UIColor) {
        self.setAttributedTitle(countryFlagAndNameAttributedString(countryId: countryId, name: name, font: font, textColor: color), for: [])
    }

    override open func layout() {
        super.layout()

        if self.flagContainerView.superview == nil {
            self.view.addSubview(self.flagContainerView)
        } else {
            self.view.bringSubviewToFront(self.flagContainerView)
        }
        self.flagContainerView.frame = self.titleNode.frame
        self.flagAnimations.update(layout: self.titleNode.cachedLayout, in: self.flagContainerView)
    }
}
