import Foundation
import UIKit
import Display
import ComponentFlow

public let mediaEditorBottomControlsButtonSide: CGFloat = 44.0
public let mediaEditorBottomControlsSelectionInset: CGFloat = 3.0
public let mediaEditorBottomControlsSideTapDelay: Double = 0.35
public let mediaEditorBottomControlsDismissFadeDuration: Double = 0.25
public let mediaEditorBottomControlsLabelHorizontalPadding: CGFloat = 25.0

public struct MediaEditorBottomControlsLayoutSpec: Equatable {
    public enum MiddleCentering: Equatable {
        case screenBand(inset: CGFloat)
        case betweenSideButtons
    }

    public var sideInset: CGFloat
    public var rightExtraInset: CGFloat
    public var middleCentering: MiddleCentering
    public var buttonSide: CGFloat

    public init(sideInset: CGFloat, rightExtraInset: CGFloat = 0.0, middleCentering: MiddleCentering, buttonSide: CGFloat = mediaEditorBottomControlsButtonSide) {
        self.sideInset = sideInset
        self.rightExtraInset = rightExtraInset
        self.middleCentering = middleCentering
        self.buttonSide = buttonSide
    }
}

public struct MediaEditorBottomControlsLayout: Equatable {
    public var leftFrame: CGRect
    public var middleFrame: CGRect?
    public var itemFrames: [CGRect]
    public var rightFrame: CGRect

    public init(leftFrame: CGRect, middleFrame: CGRect?, itemFrames: [CGRect], rightFrame: CGRect) {
        self.leftFrame = leftFrame
        self.middleFrame = middleFrame
        self.itemFrames = itemFrames
        self.rightFrame = rightFrame
    }
}

public func mediaEditorBottomControlsLocalLayout(width: CGFloat, spec: MediaEditorBottomControlsLayoutSpec, middleItemWidths: [CGFloat], middleSpacing: CGFloat, leftWidth: CGFloat, rightWidth: CGFloat) -> MediaEditorBottomControlsLayout {
    let side = spec.buttonSide
    let leftFrame = CGRect(x: spec.sideInset, y: 0.0, width: leftWidth, height: side)
    let rightFrame = CGRect(x: width - rightWidth - spec.sideInset - spec.rightExtraInset, y: 0.0, width: rightWidth, height: side)

    var itemFrames: [CGRect] = []
    var middleFrame: CGRect?
    if !middleItemWidths.isEmpty {
        let totalWidth = middleItemWidths.reduce(0.0, +) + CGFloat(middleItemWidths.count - 1) * middleSpacing
        var x: CGFloat
        switch spec.middleCentering {
        case let .screenBand(inset):
            x = floorToScreenPixels(inset + (width - inset * 2.0 - totalWidth) / 2.0)
        case .betweenSideButtons:
            x = leftFrame.maxX + floorToScreenPixels((rightFrame.minX - leftFrame.maxX - totalWidth) / 2.0)
        }
        for itemWidth in middleItemWidths {
            itemFrames.append(CGRect(x: x, y: 0.0, width: itemWidth, height: side))
            x += itemWidth + middleSpacing
        }
        middleFrame = CGRect(x: itemFrames[0].minX, y: 0.0, width: itemFrames[itemFrames.count - 1].maxX - itemFrames[0].minX, height: side)
    }
    return MediaEditorBottomControlsLayout(leftFrame: leftFrame, middleFrame: middleFrame, itemFrames: itemFrames, rightFrame: rightFrame)
}

public struct MediaEditorBottomControlsCustomLayout {
    public var key: AnyHashable
    public var layout: (_ size: CGSize, _ middleItemWidths: [CGFloat], _ leftWidth: CGFloat, _ rightWidth: CGFloat) -> MediaEditorBottomControlsLayout

    public init(key: AnyHashable, layout: @escaping (_ size: CGSize, _ middleItemWidths: [CGFloat], _ leftWidth: CGFloat, _ rightWidth: CGFloat) -> MediaEditorBottomControlsLayout) {
        self.key = key
        self.layout = layout
    }
}

public func mediaEditorBottomControlsCapsuleCornerRadius(_ size: CGSize) -> CGFloat {
    return min(size.width, size.height) * 0.5
}

public func mediaEditorBottomControlsScreenStableFrame(_ frame: CGRect, fromCapsuleOrigin: CGPoint, toCapsuleOrigin: CGPoint) -> CGRect {
    return frame.offsetBy(dx: fromCapsuleOrigin.x - toCapsuleOrigin.x, dy: fromCapsuleOrigin.y - toCapsuleOrigin.y)
}

public func mediaEditorBottomControlsCentreAnchoredFrame(_ frame: CGRect, fromCapsuleSize: CGSize, toCapsuleSize: CGSize) -> CGRect {
    return frame.offsetBy(dx: (toCapsuleSize.width - fromCapsuleSize.width) * 0.5, dy: (toCapsuleSize.height - fromCapsuleSize.height) * 0.5)
}

public func mediaEditorBottomControlsSelectionFrame(itemFrame: CGRect) -> CGRect {
    return itemFrame.insetBy(dx: mediaEditorBottomControlsSelectionInset, dy: mediaEditorBottomControlsSelectionInset)
}

public func mediaEditorBottomControlsSideTapAllowed(now: Double, lastSideItemsChange: Double?) -> Bool {
    guard let lastSideItemsChange else {
        return true
    }
    return now - lastSideItemsChange >= mediaEditorBottomControlsSideTapDelay
}

public struct MediaEditorBottomControlsSideItem: Equatable {
    public enum Content: Equatable {
        case icon(String, flipped: Bool)
        case label(String, icon: String?)
    }

    public enum Tint: Equatable {
        case panel
        case accent(UIColor)
    }

    public var id: String
    public var content: Content
    public var width: CGFloat?
    public var tint: Tint
    public var accessibilityLabel: String?

    public init(id: String, content: Content, width: CGFloat? = nil, tint: Tint, accessibilityLabel: String? = nil) {
        self.id = id
        self.content = content
        self.width = width
        self.tint = tint
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct MediaEditorBottomControlsMiddleItem {
    public enum Content {
        case icon(String)
        case image(UIImage?, CGSize)
        case coloredImage(key: String, size: CGSize, generate: (UIColor) -> UIImage?)
        case text(String, font: UIFont, horizontalInset: CGFloat)
        case custom(AnyComponent<Empty>)
    }

    public var id: String
    public var content: Content
    public var isHighlighted: Bool
    public var isDisabled: Bool
    public var tag: AnyObject?
    public var accessibilityLabel: String?
    public var action: () -> Void
    public var longPress: ((UIView, ContextGesture?) -> Void)?

    public init(id: String, content: Content, isHighlighted: Bool = false, isDisabled: Bool = false, tag: AnyObject? = nil, accessibilityLabel: String? = nil, action: @escaping () -> Void, longPress: ((UIView, ContextGesture?) -> Void)? = nil) {
        self.id = id
        self.content = content
        self.isHighlighted = isHighlighted
        self.isDisabled = isDisabled
        self.tag = tag
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.longPress = longPress
    }
}

func mediaEditorBottomControlsSameContent(_ lhs: MediaEditorBottomControlsMiddleItem.Content, _ rhs: MediaEditorBottomControlsMiddleItem.Content) -> Bool {
    switch lhs {
    case let .icon(name):
        if case .icon(name) = rhs {
            return true
        }
        return false
    case let .image(image, size):
        if case let .image(rhsImage, rhsSize) = rhs {
            return image === rhsImage && size == rhsSize
        }
        return false
    case let .coloredImage(key, size, _):
        if case let .coloredImage(rhsKey, rhsSize, _) = rhs {
            return key == rhsKey && size == rhsSize
        }
        return false
    case let .text(text, font, inset):
        if case let .text(rhsText, rhsFont, rhsInset) = rhs {
            return text == rhsText && font == rhsFont && inset == rhsInset
        }
        return false
    case .custom:
        return false
    }
}

public let mediaEditorBottomControlsHandoffBlurRadius: CGFloat = 8.0
public let mediaEditorBottomControlsHandoffFadeDuration: Double = 0.2
public let mediaEditorBottomControlsHandoffMoveDuration: Double = 0.4
public let mediaEditorBottomControlsHandBackGlassFadeDuration: Double = 0.2

public struct MediaEditorBottomControlsHandoff {
    public struct Slot {
        public var frame: CGRect
        public var hasGlass: Bool
        public var contentViews: [UIView]

        public init(frame: CGRect, hasGlass: Bool, contentViews: [UIView]) {
            self.frame = frame
            self.hasGlass = hasGlass
            self.contentViews = contentViews
        }
    }

    public var left: Slot?
    public var middle: Slot?
    public var right: Slot?
    public var didAdopt: () -> Void

    public init(left: Slot?, middle: Slot?, right: Slot?, didAdopt: @escaping () -> Void) {
        self.left = left
        self.middle = middle
        self.right = right
        self.didAdopt = didAdopt
    }
}

public struct MediaEditorBottomControlsHandBack {
    public struct Target: Equatable {
        public var frame: CGRect
        public var hasGlass: Bool

        public init(frame: CGRect, hasGlass: Bool) {
            self.frame = frame
            self.hasGlass = hasGlass
        }
    }

    public var left: Target?
    public var middle: Target?
    public var right: Target?

    public init(left: Target?, middle: Target?, right: Target?) {
        self.left = left
        self.middle = middle
        self.right = right
    }
}

public enum MediaEditorBottomControlsHandoffSlotPlan: Equatable {
    case morph(from: CGRect)
    case inPlace
}

public func mediaEditorBottomControlsHandoffSlotPlan(source: CGRect?, target: CGRect, reduceMotion: Bool) -> MediaEditorBottomControlsHandoffSlotPlan {
    guard let source, !reduceMotion, source.width > 0.0, source.height > 0.0, target.width > 0.0, target.height > 0.0 else {
        return .inPlace
    }
    return .morph(from: source)
}

public func mediaEditorFadeWithBlur(view: UIView, isIn: Bool, alpha: CGFloat? = nil, duration: Double = mediaEditorBottomControlsHandoffFadeDuration, delay: Double = 0.0) {
    if isIn {
        let targetAlpha = alpha ?? view.alpha
        view.alpha = targetAlpha
        view.layer.animateAlpha(from: 0.0, to: targetAlpha, duration: duration, delay: delay, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        ComponentTransition.animateTransientBlur(layer: view.layer, fromRadius: mediaEditorBottomControlsHandoffBlurRadius, toRadius: 0.0, duration: duration, delay: delay)
    } else {
        let currentAlpha = CGFloat(view.layer.presentation()?.opacity ?? Float(view.alpha))
        view.alpha = 0.0
        view.layer.animateAlpha(from: currentAlpha, to: 0.0, duration: duration, delay: delay, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        ComponentTransition.animateTransientBlur(layer: view.layer, fromRadius: 0.0, toRadius: mediaEditorBottomControlsHandoffBlurRadius, duration: duration, delay: delay)
    }
}

public struct MediaEditorPreviewMorph: Equatable {
    public var position: CGPoint
    public var scale: CGFloat

    public init(position: CGPoint, scale: CGFloat) {
        self.position = position
        self.scale = scale
    }
}

public func mediaEditorPreviewMorph(viewCenter: CGPoint, contentFrame: CGRect, targetFrame: CGRect) -> MediaEditorPreviewMorph {
    guard contentFrame.width > 0.0, targetFrame.width > 0.0 else {
        return MediaEditorPreviewMorph(position: viewCenter, scale: 1.0)
    }
    let scale = targetFrame.width / contentFrame.width
    let position = CGPoint(
        x: targetFrame.midX - (contentFrame.midX - viewCenter.x) * scale,
        y: targetFrame.midY - (contentFrame.midY - viewCenter.y) * scale
    )
    return MediaEditorPreviewMorph(position: position, scale: scale)
}

public func mediaEditorAnimatePreviewMorph(view: UIView, contentFrame: CGRect? = nil, cameraFrame: CGRect, toCamera: Bool, completion: (() -> Void)? = nil) {
    guard let superview = view.superview else {
        completion?()
        return
    }
    let viewCenter = superview.convert(view.center, to: nil)
    let content = contentFrame ?? view.convert(view.bounds, to: nil)
    let morph = mediaEditorPreviewMorph(viewCenter: viewCenter, contentFrame: content, targetFrame: cameraFrame)
    let morphPosition = superview.convert(morph.position, from: nil)
    let duration = mediaEditorBottomControlsHandoffMoveDuration
    if toCamera {
        view.layer.animatePosition(from: view.layer.position, to: morphPosition, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion?()
        })
        view.layer.animateScale(from: 1.0, to: morph.scale, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    } else {
        view.layer.animatePosition(from: morphPosition, to: view.layer.position, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion?()
        })
        view.layer.animateScale(from: morph.scale, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
    }
}
