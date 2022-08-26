import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import MultiAnimationRenderer
import AnimationCache
import AccountContext
import LottieAnimationCache
import VideoAnimationCache
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import ShimmerEffect
import PagerComponent
import StickerResources
import AppBundle
import UndoUI
import AudioToolbox
import SolidRoundedButtonComponent
import EmojiTextAttachmentView

private let premiumBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPremiumIcon"), color: .white)
private let featuredBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeAdd"), color: .white)
private let lockedBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: .white)

private let staticEmojiMapping: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = {
    guard let path = getAppBundle().path(forResource: "emoji1016", ofType: "txt") else {
        return []
    }
    guard let string = try? String(contentsOf: URL(fileURLWithPath: path)) else {
        return []
    }
    
    var result: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = []
    
    let orderedSegments = EmojiPagerContentComponent.StaticEmojiSegment.allCases
    
    let segments = string.components(separatedBy: "\n\n")
    for i in 0 ..< min(segments.count, orderedSegments.count) {
        let list = segments[i].components(separatedBy: " ")
        result.append((orderedSegments[i], list))
    }
    
    return result
}()

private final class WarpView: UIView {
    private final class WarpPartView: UIView {
        let cloneView: PortalView
        
        init?(contentView: PortalSourceView) {
            guard let cloneView = PortalView(matchPosition: false) else {
                return nil
            }
            self.cloneView = cloneView
            
            super.init(frame: CGRect())
            
            self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            
            self.clipsToBounds = true
            self.addSubview(cloneView.view)
            contentView.addPortal(view: cloneView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(containerSize: CGSize, rect: CGRect, transition: Transition) {
            transition.setFrame(view: self.cloneView.view, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: CGSize(width: containerSize.width, height: containerSize.height)))
        }
    }
    
    let contentView: PortalSourceView
    
    private let clippingView: UIView
    
    private var warpViews: [WarpPartView] = []
    private let warpMaskContainer: UIView
    private let warpMaskGradientLayer: SimpleGradientLayer
    
    override init(frame: CGRect) {
        self.contentView = PortalSourceView()
        self.clippingView = UIView()
        
        self.warpMaskContainer = UIView()
        self.warpMaskGradientLayer = SimpleGradientLayer()
        self.warpMaskContainer.layer.mask = self.warpMaskGradientLayer
        
        super.init(frame: frame)
        
        self.clippingView.addSubview(self.contentView)
        
        self.clippingView.clipsToBounds = true
        self.addSubview(self.clippingView)
        self.addSubview(self.warpMaskContainer)
        
        for _ in 0 ..< 8 {
            if let warpView = WarpPartView(contentView: self.contentView) {
                self.warpViews.append(warpView)
                self.warpMaskContainer.addSubview(warpView)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, topInset: CGFloat, warpHeight: CGFloat, theme: PresentationTheme, transition: Transition) {
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
        
        let allItemsHeight = warpHeight * 0.5
        for i in 0 ..< self.warpViews.count {
            let itemHeight = warpHeight / CGFloat(self.warpViews.count)
            let itemFraction = CGFloat(i + 1) / CGFloat(self.warpViews.count)
            let _ = itemHeight
            
            let da = CGFloat.pi * 0.5 / CGFloat(self.warpViews.count)
            let alpha = CGFloat.pi * 0.5 - itemFraction * CGFloat.pi * 0.5
            let endPoint = CGPoint(x: cos(alpha), y: sin(alpha))
            let prevAngle = alpha + da
            let prevPt = CGPoint(x: cos(prevAngle), y: sin(prevAngle))
            var angle: CGFloat
            angle = -atan2(endPoint.y - prevPt.y, endPoint.x - prevPt.x)
            
            let itemLengthVector = CGPoint(x: endPoint.x - prevPt.x, y: endPoint.y - prevPt.y)
            let itemLength = sqrt(itemLengthVector.x * itemLengthVector.x + itemLengthVector.y * itemLengthVector.y) * warpHeight * 0.5
            let _ = itemLength
            
            var transform: CATransform3D
            transform = CATransform3DIdentity
            transform.m34 = 1.0 / 240.0
            
            transform = CATransform3DTranslate(transform, 0.0, prevPt.x * allItemsHeight, (1.0 - prevPt.y) * allItemsHeight)
            transform = CATransform3DRotate(transform, angle, 1.0, 0.0, 0.0)
            
            let positionY = size.height - allItemsHeight + 4.0 + CGFloat(i) * itemLength
            let rect = CGRect(origin: CGPoint(x: 0.0, y: positionY), size: CGSize(width: size.width, height: itemLength))
            transition.setPosition(view: self.warpViews[i], position: CGPoint(x: rect.midX, y: 4.0))
            transition.setBounds(view: self.warpViews[i], bounds: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: itemLength)))
            transition.setTransform(view: self.warpViews[i], transform: transform)
            self.warpViews[i].update(containerSize: size, rect: rect, transition: transition)
        }
        
        let frame = CGRect(origin: CGPoint(x: 0.0, y: -topInset), size: CGSize(width: size.width, height: topInset + size.height - 21.0))
        transition.setPosition(view: self.clippingView, position: frame.center)
        transition.setBounds(view: self.clippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: -topInset), size: frame.size))
        
        transition.setFrame(view: self.warpMaskContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - allItemsHeight), size: CGSize(width: size.width, height: allItemsHeight)))
        
        var locations: [NSNumber] = []
        var colors: [CGColor] = []
        let numStops = 6
        for i in 0 ..< numStops {
            let step = CGFloat(i) / CGFloat(numStops - 1)
            locations.append(step as NSNumber)
            colors.append(UIColor.black.withAlphaComponent(1.0 - step * step).cgColor)
        }
        
        let gradientHeight: CGFloat = 6.0
        self.warpMaskGradientLayer.startPoint = CGPoint(x: 0.0, y: (allItemsHeight - gradientHeight) / allItemsHeight)
        self.warpMaskGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        self.warpMaskGradientLayer.locations = locations
        self.warpMaskGradientLayer.colors = colors
        self.warpMaskGradientLayer.type = .axial
        
        transition.setFrame(layer: self.warpMaskGradientLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: allItemsHeight)))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.contentView.hitTest(point, with: event)
    }
}

public final class EntityKeyboardAnimationData: Equatable {
    public enum Id: Hashable {
        case file(MediaId)
        case stickerPackThumbnail(ItemCollectionId)
    }
    
    public enum ItemType {
        case still
        case lottie
        case video
        
        var animationCacheAnimationType: AnimationCacheAnimationType {
            switch self {
            case .still:
                return .still
            case .lottie:
                return .lottie
            case .video:
                return .video
            }
        }
    }
    
    public let id: Id
    public let type: ItemType
    public let resource: MediaResourceReference
    public let dimensions: CGSize
    public let immediateThumbnailData: Data?
    public let isReaction: Bool
    
    public init(id: Id, type: ItemType, resource: MediaResourceReference, dimensions: CGSize, immediateThumbnailData: Data?, isReaction: Bool) {
        self.id = id
        self.type = type
        self.resource = resource
        self.dimensions = dimensions
        self.immediateThumbnailData = immediateThumbnailData
        self.isReaction = isReaction
    }
    
    public convenience init(file: TelegramMediaFile, isReaction: Bool = false) {
        let type: ItemType
        if file.isVideoSticker || file.isVideoEmoji {
            type = .video
        } else if file.isAnimatedSticker {
            type = .lottie
        } else {
            type = .still
        }
        self.init(id: .file(file.fileId), type: type, resource: .standalone(resource: file.resource), dimensions: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), immediateThumbnailData: file.immediateThumbnailData, isReaction: isReaction)
    }
    
    public static func ==(lhs: EntityKeyboardAnimationData, rhs: EntityKeyboardAnimationData) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.resource.resource.id != rhs.resource.resource.id {
            return false
        }
        if lhs.dimensions != rhs.dimensions {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.immediateThumbnailData != rhs.immediateThumbnailData {
            return false
        }
        if lhs.isReaction != rhs.isReaction {
            return false
        }
        
        return true
    }
}

public class PassthroughLayer: CALayer {
    public var mirrorLayer: CALayer?
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var position: CGPoint {
        get {
            return super.position
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.position = value
            }
            super.position = value
        }
    }
    
    override public var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override public var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.opacity = value
            }
            super.opacity = value
        }
    }
    
    override public var sublayerTransform: CATransform3D {
        get {
            return super.sublayerTransform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.sublayerTransform = value
            }
            super.sublayerTransform = value
        }
    }
    
    override public var transform: CATransform3D {
        get {
            return super.transform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.transform = value
            }
            super.transform = value
        }
    }
    
    override public func add(_ animation: CAAnimation, forKey key: String?) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        
        super.add(animation, forKey: key)
    }
    
    override public func removeAllAnimations() {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAllAnimations()
        }
        
        super.removeAllAnimations()
    }
    
    override public func removeAnimation(forKey: String) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        
        super.removeAnimation(forKey: forKey)
    }
}

open class PassthroughView: UIView {
    override public static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    public let passthroughView: UIView
    
    override public init(frame: CGRect) {
        self.passthroughView = UIView()
        
        super.init(frame: frame)
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.passthroughView.layer
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class PassthroughShapeLayer: CAShapeLayer {
    var mirrorLayer: CAShapeLayer?
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var position: CGPoint {
        get {
            return super.position
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.position = value
            }
            super.position = value
        }
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.opacity = value
            }
            super.opacity = value
        }
    }
    
    override var sublayerTransform: CATransform3D {
        get {
            return super.sublayerTransform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.sublayerTransform = value
            }
            super.sublayerTransform = value
        }
    }
    
    override var transform: CATransform3D {
        get {
            return super.transform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.transform = value
            }
            super.transform = value
        }
    }
    
    override var path: CGPath? {
        get {
            return super.path
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.path = value
            }
            super.path = value
        }
    }
    
    override var fillColor: CGColor? {
        get {
            return super.fillColor
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.fillColor = value
            }
            super.fillColor = value
        }
    }
    
    override var fillRule: CAShapeLayerFillRule {
        get {
            return super.fillRule
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.fillRule = value
            }
            super.fillRule = value
        }
    }
    
    override var strokeColor: CGColor? {
        get {
            return super.strokeColor
        } set(value) {
            /*if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeColor = value
            }*/
            super.strokeColor = value
        }
    }
    
    override var strokeStart: CGFloat {
        get {
            return super.strokeStart
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeStart = value
            }
            super.strokeStart = value
        }
    }
    
    override var strokeEnd: CGFloat {
        get {
            return super.strokeEnd
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeEnd = value
            }
            super.strokeEnd = value
        }
    }
    
    override var lineWidth: CGFloat {
        get {
            return super.lineWidth
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineWidth = value
            }
            super.lineWidth = value
        }
    }
    
    override var miterLimit: CGFloat {
        get {
            return super.miterLimit
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.miterLimit = value
            }
            super.miterLimit = value
        }
    }
    
    override var lineCap: CAShapeLayerLineCap {
        get {
            return super.lineCap
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineCap = value
            }
            super.lineCap = value
        }
    }
    
    override var lineJoin: CAShapeLayerLineJoin {
        get {
            return super.lineJoin
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineJoin = value
            }
            super.lineJoin = value
        }
    }
    
    override var lineDashPhase: CGFloat {
        get {
            return super.lineDashPhase
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineDashPhase = value
            }
            super.lineDashPhase = value
        }
    }
    
    override var lineDashPattern: [NSNumber]? {
        get {
            return super.lineDashPattern
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineDashPattern = value
            }
            super.lineDashPattern = value
        }
    }
    
    override func add(_ animation: CAAnimation, forKey key: String?) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        
        super.add(animation, forKey: key)
    }
    
    override func removeAllAnimations() {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAllAnimations()
        }
        
        super.removeAllAnimations()
    }
    
    override func removeAnimation(forKey: String) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        
        super.removeAnimation(forKey: forKey)
    }
}

private final class PremiumBadgeView: UIView {
    private var badge: EmojiPagerContentComponent.View.ItemLayer.Badge?
    
    let contentLayer: SimpleLayer
    private let overlayColorLayer: SimpleLayer
    private let iconLayer: SimpleLayer
    
    init() {
        self.contentLayer = SimpleLayer()
        self.contentLayer.contentsGravity = .resize
        self.contentLayer.masksToBounds = true
        
        self.overlayColorLayer = SimpleLayer()
        self.overlayColorLayer.masksToBounds = true
        
        self.iconLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.layer.addSublayer(self.overlayColorLayer)
        self.layer.addSublayer(self.iconLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(transition: Transition, badge: EmojiPagerContentComponent.View.ItemLayer.Badge, backgroundColor: UIColor, size: CGSize) {
        if self.badge != badge {
            self.badge = badge
            
            switch badge {
            case .premium:
                self.iconLayer.contents = premiumBadgeIcon?.cgImage
            case .featured:
                self.iconLayer.contents = featuredBadgeIcon?.cgImage
            case .locked:
                self.iconLayer.contents = lockedBadgeIcon?.cgImage
            }
        }
        
        let iconInset: CGFloat
        switch badge {
        case .premium:
            iconInset = 2.0
        case .featured:
            iconInset = 0.0
        case .locked:
            iconInset = 0.0
        }
        
        self.overlayColorLayer.backgroundColor = backgroundColor.cgColor
        
        transition.setFrame(layer: self.contentLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.contentLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.overlayColorLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.overlayColorLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.iconLayer, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: iconInset, dy: iconInset))
    }
}

private final class GroupHeaderActionButton: UIButton {
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    private let backgroundLayer: SimpleLayer
    private let textLayer: SimpleLayer
    private let pressed: () -> Void
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.backgroundLayer = SimpleLayer()
        self.backgroundLayer.masksToBounds = true
        
        self.textLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.backgroundLayer)
        self.layer.addSublayer(self.textLayer)
        
        self.addTarget(self, action: #selector(self.onPressed), for: .touchUpInside)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func onPressed() {
        self.pressed()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.alpha = 0.6
        
        return super.beginTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.endTracking(touch, with: event)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.cancelTracking(with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.touchesCancelled(touches, with: event)
    }
    
    func update(theme: PresentationTheme, title: String) -> CGSize {
        let textConstrainedWidth: CGFloat = 100.0
        let color = theme.list.itemCheckColors.foregroundColor
        
        self.backgroundLayer.backgroundColor = theme.list.itemCheckColors.fillColor.cgColor
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == color, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let font: UIFont = Font.semibold(15.0)
            let string = NSAttributedString(string: title.uppercased(), font: font, textColor: color)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                string.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.currentTextLayout = (title, color, textConstrainedWidth, textSize)
        }
        
        let size = CGSize(width: textSize.width + 16.0 * 2.0, height: 28.0)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((size.height - textSize.height) / 2.0)), size: textSize)
        self.textLayer.frame = textFrame
        
        self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundLayer.cornerRadius = min(size.width, size.height) / 2.0
        
        return size
    }
}

private final class GroupHeaderLayer: UIView {
    override static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    private let actionPressed: () -> Void
    private let performItemAction: (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void
    
    private let textLayer: SimpleLayer
    private let tintTextLayer: SimpleLayer
    
    private var subtitleLayer: SimpleLayer?
    private var tintSubtitleLayer: SimpleLayer?
    private var lockIconLayer: SimpleLayer?
    private var tintLockIconLayer: SimpleLayer?
    private(set) var clearIconLayer: SimpleLayer?
    private var tintClearIconLayer: SimpleLayer?
    private var separatorLayer: SimpleLayer?
    private var tintSeparatorLayer: SimpleLayer?
    private var actionButton: GroupHeaderActionButton?
    
    private var groupEmbeddedView: GroupEmbeddedView?
    
    private var theme: PresentationTheme?
    
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    private var currentSubtitleLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    
    let tintContentLayer: SimpleLayer
    
    init(actionPressed: @escaping () -> Void, performItemAction: @escaping (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void) {
        self.actionPressed = actionPressed
        self.performItemAction = performItemAction
        
        self.textLayer = SimpleLayer()
        self.tintTextLayer = SimpleLayer()
        
        self.tintContentLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.textLayer)
        self.tintContentLayer.addSublayer(self.tintTextLayer)
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContentLayer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(
        context: AccountContext,
        theme: PresentationTheme,
        layoutType: EmojiPagerContentComponent.ItemLayoutType,
        hasTopSeparator: Bool,
        actionButtonTitle: String?,
        title: String,
        subtitle: String?,
        isPremiumLocked: Bool,
        hasClear: Bool,
        embeddedItems: [EmojiPagerContentComponent.Item]?,
        constrainedSize: CGSize,
        insets: UIEdgeInsets,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        attemptSynchronousLoad: Bool
    ) -> (size: CGSize, centralContentWidth: CGFloat) {
        var themeUpdated = false
        if self.theme !== theme {
            self.theme = theme
            themeUpdated = true
        }
        
        let needsVibrancy = !theme.overallDarkAppearance
        
        let textOffsetY: CGFloat
        if hasTopSeparator {
            textOffsetY = 9.0
        } else {
            textOffsetY = 0.0
        }
        
        let color: UIColor
        let needsTintText: Bool
        if subtitle != nil {
            color = theme.chat.inputPanel.primaryTextColor
            needsTintText = false
        } else {
            color = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
            needsTintText = true
        }
        let subtitleColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
        
        let titleHorizontalOffset: CGFloat
        if isPremiumLocked {
            titleHorizontalOffset = 10.0 + 2.0
        } else {
            titleHorizontalOffset = 0.0
        }
        
        var actionButtonSize: CGSize?
        if let actionButtonTitle = actionButtonTitle {
            let actionButton: GroupHeaderActionButton
            if let current = self.actionButton {
                actionButton = current
            } else {
                actionButton = GroupHeaderActionButton(pressed: self.actionPressed)
                self.actionButton = actionButton
                self.addSubview(actionButton)
            }
            
            actionButtonSize = actionButton.update(theme: theme, title: actionButtonTitle)
        } else {
            if let actionButton = self.actionButton {
                self.actionButton = nil
                actionButton.removeFromSuperview()
            }
        }
        
        var textConstrainedWidth = constrainedSize.width - titleHorizontalOffset - 10.0
        if let actionButtonSize = actionButtonSize {
            textConstrainedWidth -= actionButtonSize.width - 8.0
        }
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == color, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let font: UIFont
            let stringValue: String
            if subtitle == nil {
                font = Font.medium(13.0)
                stringValue = title.uppercased()
            } else {
                font = Font.semibold(16.0)
                stringValue = title
            }
            let string = NSAttributedString(string: stringValue, font: font, textColor: color)
            let whiteString = NSAttributedString(string: stringValue, font: font, textColor: .white)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                string.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.tintTextLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                whiteString.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.tintTextLayer.isHidden = !needsVibrancy
            self.currentTextLayout = (title, color, textConstrainedWidth, textSize)
        }
        
        let textFrame: CGRect
        if subtitle == nil {
            textFrame = CGRect(origin: CGPoint(x: titleHorizontalOffset + floor((constrainedSize.width - titleHorizontalOffset - textSize.width) / 2.0), y: textOffsetY), size: textSize)
        } else {
            textFrame = CGRect(origin: CGPoint(x: titleHorizontalOffset, y: textOffsetY), size: textSize)
        }
        self.textLayer.frame = textFrame
        self.tintTextLayer.frame = textFrame
        self.tintTextLayer.isHidden = !needsTintText
        
        if isPremiumLocked {
            let lockIconLayer: SimpleLayer
            if let current = self.lockIconLayer {
                lockIconLayer = current
            } else {
                lockIconLayer = SimpleLayer()
                self.lockIconLayer = lockIconLayer
                self.layer.addSublayer(lockIconLayer)
            }
            if let image = PresentationResourcesChat.chatEntityKeyboardLock(theme, color: color) {
                let imageSize = image.size
                lockIconLayer.contents = image.cgImage
                lockIconLayer.frame = CGRect(origin: CGPoint(x: textFrame.minX - imageSize.width - 3.0, y: 2.0 + UIScreenPixel), size: imageSize)
            } else {
                lockIconLayer.contents = nil
            }
            
            let tintLockIconLayer: SimpleLayer
            if let current = self.tintLockIconLayer {
                tintLockIconLayer = current
            } else {
                tintLockIconLayer = SimpleLayer()
                self.tintLockIconLayer = tintLockIconLayer
                self.tintContentLayer.addSublayer(tintLockIconLayer)
            }
            if let image = PresentationResourcesChat.chatEntityKeyboardLock(theme, color: .white) {
                tintLockIconLayer.contents = image.cgImage
                tintLockIconLayer.frame = lockIconLayer.frame
                tintLockIconLayer.isHidden = !needsVibrancy
            } else {
                tintLockIconLayer.contents = nil
            }
        } else {
            if let lockIconLayer = self.lockIconLayer {
                self.lockIconLayer = nil
                lockIconLayer.removeFromSuperlayer()
            }
            if let tintLockIconLayer = self.tintLockIconLayer {
                self.tintLockIconLayer = nil
                tintLockIconLayer.removeFromSuperlayer()
            }
        }
        
        let subtitleSize: CGSize
        if let subtitle = subtitle {
            var updateSubtitleContents: UIImage?
            var updateTintSubtitleContents: UIImage?
            if let currentSubtitleLayout = self.currentSubtitleLayout, currentSubtitleLayout.string == subtitle, currentSubtitleLayout.color == subtitleColor, currentSubtitleLayout.constrainedWidth == textConstrainedWidth {
                subtitleSize = currentSubtitleLayout.size
            } else {
                let string = NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: subtitleColor)
                let whiteString = NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: .white)
                let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                subtitleSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
                updateSubtitleContents = generateImage(subtitleSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    string.draw(in: stringBounds)
                    
                    UIGraphicsPopContext()
                })
                updateTintSubtitleContents = generateImage(subtitleSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    whiteString.draw(in: stringBounds)
                    
                    UIGraphicsPopContext()
                })
                self.currentSubtitleLayout = (subtitle, subtitleColor, textConstrainedWidth, subtitleSize)
            }
            
            let subtitleLayer: SimpleLayer
            if let current = self.subtitleLayer {
                subtitleLayer = current
            } else {
                subtitleLayer = SimpleLayer()
                self.subtitleLayer = subtitleLayer
                self.layer.addSublayer(subtitleLayer)
            }
            
            if let updateSubtitleContents = updateSubtitleContents {
                subtitleLayer.contents = updateSubtitleContents.cgImage
            }
            
            let tintSubtitleLayer: SimpleLayer
            if let current = self.tintSubtitleLayer {
                tintSubtitleLayer = current
            } else {
                tintSubtitleLayer = SimpleLayer()
                self.tintSubtitleLayer = tintSubtitleLayer
                self.tintContentLayer.addSublayer(tintSubtitleLayer)
            }
            tintSubtitleLayer.isHidden = !needsVibrancy
            
            if let updateTintSubtitleContents = updateTintSubtitleContents {
                tintSubtitleLayer.contents = updateTintSubtitleContents.cgImage
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: 0.0, y: textFrame.maxY + 1.0), size: subtitleSize)
            subtitleLayer.frame = subtitleFrame
            tintSubtitleLayer.frame = subtitleFrame
        } else {
            subtitleSize = CGSize()
            if let subtitleLayer = self.subtitleLayer {
                self.subtitleLayer = nil
                subtitleLayer.removeFromSuperlayer()
            }
        }
        
        var clearWidth: CGFloat = 0.0
        if hasClear {
            var updateImage = themeUpdated
            
            let clearIconLayer: SimpleLayer
            if let current = self.clearIconLayer {
                clearIconLayer = current
            } else {
                updateImage = true
                clearIconLayer = SimpleLayer()
                self.clearIconLayer = clearIconLayer
                self.layer.addSublayer(clearIconLayer)
            }
            let tintClearIconLayer: SimpleLayer
            if let current = self.tintClearIconLayer {
                tintClearIconLayer = current
            } else {
                updateImage = true
                tintClearIconLayer = SimpleLayer()
                self.tintClearIconLayer = tintClearIconLayer
                self.tintContentLayer.addSublayer(tintClearIconLayer)
            }
            
            tintClearIconLayer.isHidden = !needsVibrancy
            
            var clearSize = clearIconLayer.bounds.size
            if updateImage, let image = PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme, color: theme.chat.inputMediaPanel.panelContentVibrantOverlayColor) {
                clearSize = image.size
                clearIconLayer.contents = image.cgImage
            }
            if updateImage, let image = PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme, color: .white) {
                tintClearIconLayer.contents = image.cgImage
            }
            
            clearIconLayer.frame = CGRect(origin: CGPoint(x: constrainedSize.width - clearSize.width, y: floorToScreenPixels((textSize.height - clearSize.height) / 2.0)), size: clearSize)
            
            tintClearIconLayer.frame = clearIconLayer.frame
            clearWidth = 4.0 + clearSize.width
        } else {
            if let clearIconLayer = self.clearIconLayer {
                self.clearIconLayer = nil
                clearIconLayer.removeFromSuperlayer()
            }
            if let tintClearIconLayer = self.tintClearIconLayer {
                self.tintClearIconLayer = nil
                tintClearIconLayer.removeFromSuperlayer()
            }
        }
        
        var size: CGSize
        size = CGSize(width: constrainedSize.width, height: constrainedSize.height)
        
        if let embeddedItems = embeddedItems {
            let groupEmbeddedView: GroupEmbeddedView
            if let current = self.groupEmbeddedView {
                groupEmbeddedView = current
            } else {
                groupEmbeddedView = GroupEmbeddedView(performItemAction: self.performItemAction)
                self.groupEmbeddedView = groupEmbeddedView
                self.addSubview(groupEmbeddedView)
            }
            
            let groupEmbeddedViewSize = CGSize(width: constrainedSize.width + insets.left + insets.right, height: 36.0)
            groupEmbeddedView.frame = CGRect(origin: CGPoint(x: -insets.left, y: size.height -  groupEmbeddedViewSize.height), size: groupEmbeddedViewSize)
            groupEmbeddedView.update(
                context: context,
                theme: theme,
                insets: insets,
                size: groupEmbeddedViewSize,
                items: embeddedItems,
                cache: cache,
                renderer: renderer,
                attemptSynchronousLoad: attemptSynchronousLoad
            )
        } else {
            if let groupEmbeddedView = self.groupEmbeddedView {
                self.groupEmbeddedView = nil
                groupEmbeddedView.removeFromSuperview()
            }
        }
        
        if let actionButtonSize = actionButtonSize, let actionButton = self.actionButton {
            actionButton.frame = CGRect(origin: CGPoint(x: size.width - actionButtonSize.width, y: textFrame.minY + 3.0), size: actionButtonSize)
        }
        
        if hasTopSeparator {
            let separatorLayer: SimpleLayer
            if let current = self.separatorLayer {
                separatorLayer = current
            } else {
                separatorLayer = SimpleLayer()
                self.separatorLayer = separatorLayer
                self.layer.addSublayer(separatorLayer)
            }
            separatorLayer.backgroundColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.cgColor
            separatorLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel))
            
            let tintSeparatorLayer: SimpleLayer
            if let current = self.tintSeparatorLayer {
                tintSeparatorLayer = current
            } else {
                tintSeparatorLayer = SimpleLayer()
                self.tintSeparatorLayer = tintSeparatorLayer
                self.tintContentLayer.addSublayer(tintSeparatorLayer)
            }
            tintSeparatorLayer.backgroundColor = UIColor.white.cgColor
            tintSeparatorLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel))
            
            tintSeparatorLayer.isHidden = !needsVibrancy
        } else {
            if let separatorLayer = self.separatorLayer {
                self.separatorLayer = separatorLayer
                separatorLayer.removeFromSuperlayer()
            }
            if let tintSeparatorLayer = self.tintSeparatorLayer {
                self.tintSeparatorLayer = tintSeparatorLayer
                tintSeparatorLayer.removeFromSuperlayer()
            }
        }
        
        return (size, titleHorizontalOffset + textSize.width + clearWidth)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    func tapGesture(_ recognizer: UITapGestureRecognizer) -> Bool {
        if let groupEmbeddedView = self.groupEmbeddedView {
            return groupEmbeddedView.tapGesture(recognizer)
        } else {
            return false
        }
    }
}

private final class GroupEmbeddedView: UIScrollView, UIScrollViewDelegate, PagerExpandableScrollView {
    private struct ItemLayout {
        var itemSize: CGFloat
        var itemSpacing: CGFloat
        var sideInset: CGFloat
        var itemCount: Int
        var contentSize: CGSize
        
        init(height: CGFloat, sideInset: CGFloat, itemCount: Int) {
            self.itemSize = 30.0
            self.itemSpacing = 20.0
            self.sideInset = sideInset
            self.itemCount = itemCount
            
            self.contentSize = CGSize(width: self.sideInset * 2.0 + CGFloat(self.itemCount) * self.itemSize + CGFloat(self.itemCount - 1) * self.itemSpacing, height: height)
        }
        
        func frame(at index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: sideInset + CGFloat(index) * (self.itemSize + self.itemSpacing), y: floor((self.contentSize.height - self.itemSize) / 2.0)), size: CGSize(width: self.itemSize, height: self.itemSize))
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.sideInset, dy: 0.0)
            var minVisibleIndex = Int(floor((offsetRect.minX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
            minVisibleIndex = max(0, minVisibleIndex)
            var maxVisibleIndex = Int(ceil((offsetRect.maxX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
            maxVisibleIndex = min(maxVisibleIndex, self.itemCount - 1)
            
            if minVisibleIndex <= maxVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
    }
    
    private let performItemAction: (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void
    
    private var visibleItemLayers: [EmojiPagerContentComponent.View.ItemLayer.Key: EmojiPagerContentComponent.View.ItemLayer] = [:]
    private var ignoreScrolling: Bool = false
    
    private var context: AccountContext?
    private var theme: PresentationTheme?
    private var cache: AnimationCache?
    private var renderer: MultiAnimationRenderer?
    private var currentInsets: UIEdgeInsets?
    private var currentSize: CGSize?
    private var items: [EmojiPagerContentComponent.Item]?
    
    private var itemLayout: ItemLayout?
    
    init(performItemAction: @escaping (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void) {
        self.performItemAction = performItemAction
        
        super.init(frame: CGRect())
        
        self.delaysContentTouches = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        if #available(iOS 13.0, *) {
            self.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.showsVerticalScrollIndicator = true
        self.showsHorizontalScrollIndicator = false
        self.delegate = self
        self.clipsToBounds = true
        self.scrollsToTop = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tapGesture(_ recognizer: UITapGestureRecognizer) -> Bool {
        guard let itemLayout = self.itemLayout else {
            return false
        }

        if case .ended = recognizer.state {
            let point = recognizer.location(in: self)
            for (_, itemLayer) in self.visibleItemLayers {
                if itemLayer.frame.inset(by: UIEdgeInsets(top: 6.0, left: itemLayout.itemSpacing, bottom: 6.0, right: itemLayout.itemSpacing)).contains(point) {
                    self.performItemAction(itemLayer.item, self, itemLayer.frame, itemLayer)
                    return true
                }
            }
        }
        
        return false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreScrolling {
            self.updateVisibleItems(transition: .immediate, attemptSynchronousLoad: false)
        }
    }
    
    private func updateVisibleItems(transition: Transition, attemptSynchronousLoad: Bool) {
        guard let context = self.context, let theme = self.theme, let itemLayout = self.itemLayout, let items = self.items, let cache = self.cache, let renderer = self.renderer else {
            return
        }
        
        var validIds = Set<EmojiPagerContentComponent.View.ItemLayer.Key>()
        if let itemRange = itemLayout.visibleItems(for: self.bounds) {
            for index in itemRange.lowerBound ..< itemRange.upperBound {
                let item = items[index]
                let itemId = EmojiPagerContentComponent.View.ItemLayer.Key(
                    groupId: AnyHashable(0),
                    itemId: item.content.id
                )
                validIds.insert(itemId)
                
                let itemLayer: EmojiPagerContentComponent.View.ItemLayer
                if let current = self.visibleItemLayers[itemId] {
                    itemLayer = current
                } else {
                    itemLayer = EmojiPagerContentComponent.View.ItemLayer(
                        item: item,
                        context: context,
                        attemptSynchronousLoad: attemptSynchronousLoad,
                        content: item.content,
                        cache: cache,
                        renderer: renderer,
                        placeholderColor: .clear,
                        blurredBadgeColor: .clear,
                        accentIconColor: theme.list.itemAccentColor,
                        pointSize: CGSize(width: 32.0, height: 32.0),
                        onUpdateDisplayPlaceholder: { _, _ in
                        }
                    )
                    self.visibleItemLayers[itemId] = itemLayer
                    self.layer.addSublayer(itemLayer)
                }
                
                let itemFrame = itemLayout.frame(at: index)
                itemLayer.frame = itemFrame
                
                itemLayer.isVisibleForAnimations = true
            }
        }
        
        var removedIds: [EmojiPagerContentComponent.View.ItemLayer.Key] = []
        for (id, itemLayer) in self.visibleItemLayers {
            if !validIds.contains(id) {
                removedIds.append(id)
                itemLayer.removeFromSuperlayer()
            }
        }
        for id in removedIds {
            self.visibleItemLayers.removeValue(forKey: id)
        }
    }
    
    func update(
        context: AccountContext,
        theme: PresentationTheme,
        insets: UIEdgeInsets,
        size: CGSize,
        items: [EmojiPagerContentComponent.Item],
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        attemptSynchronousLoad: Bool
    ) {
        if self.theme === theme && self.currentInsets == insets && self.currentSize == size && self.items == items {
            return
        }
        
        self.context = context
        self.theme = theme
        self.currentInsets = insets
        self.currentSize = size
        self.items = items
        self.cache = cache
        self.renderer = renderer
        
        let itemLayout = ItemLayout(height: size.height, sideInset: insets.left, itemCount: items.count)
        self.itemLayout = itemLayout
        
        self.ignoreScrolling = true
        if itemLayout.contentSize != self.contentSize {
            self.contentSize = itemLayout.contentSize
        }
        self.ignoreScrolling = false
        
        self.updateVisibleItems(transition: .immediate, attemptSynchronousLoad: attemptSynchronousLoad)
    }
}

private final class GroupExpandActionButton: UIButton {
    override static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    let tintContainerLayer: SimpleLayer
    
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    private let backgroundLayer: SimpleLayer
    private let tintBackgroundLayer: SimpleLayer
    private let textLayer: SimpleLayer
    private let pressed: () -> Void
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.tintContainerLayer = SimpleLayer()
        
        self.backgroundLayer = SimpleLayer()
        self.backgroundLayer.masksToBounds = true
        
        self.tintBackgroundLayer = SimpleLayer()
        self.tintBackgroundLayer.masksToBounds = true
        
        self.textLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContainerLayer
        
        self.layer.addSublayer(self.backgroundLayer)
        
        self.layer.addSublayer(self.textLayer)
        
        self.addTarget(self, action: #selector(self.onPressed), for: .touchUpInside)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func onPressed() {
        self.pressed()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.alpha = 0.6
        
        return super.beginTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.endTracking(touch, with: event)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.cancelTracking(with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.touchesCancelled(touches, with: event)
    }
    
    func update(theme: PresentationTheme, title: String) -> CGSize {
        let textConstrainedWidth: CGFloat = 100.0
        let color = theme.list.itemCheckColors.foregroundColor
        
        self.backgroundLayer.backgroundColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.cgColor
        self.tintContainerLayer.backgroundColor = UIColor.white.cgColor
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == color, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let font: UIFont = Font.semibold(13.0)
            let string = NSAttributedString(string: title.uppercased(), font: font, textColor: color)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                string.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.currentTextLayout = (title, color, textConstrainedWidth, textSize)
        }
        
        var sideInset: CGFloat = 10.0
        if textSize.width > 24.0 {
            sideInset = 6.0
        }
        let size = CGSize(width: textSize.width + sideInset * 2.0, height: 28.0)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((size.height - textSize.height) / 2.0)), size: textSize)
        self.textLayer.frame = textFrame
        
        self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.tintBackgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundLayer.cornerRadius = min(size.width, size.height) / 2.0
        self.tintContainerLayer.cornerRadius = min(size.width, size.height) / 2.0
        
        return size
    }
}

public protocol EmojiContentPeekBehavior: AnyObject {
    func setGestureRecognizerEnabled(view: UIView, isEnabled: Bool, itemAtPoint: @escaping (CGPoint) -> (EmojiPagerContentComponent.View.ItemLayer, TelegramMediaFile)?)
}

public final class EmojiPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public final class ContentAnimation {
        public enum AnimationType {
            case generic
            case groupExpanded(id: AnyHashable)
            case groupInstalled(id: AnyHashable)
        }
        
        public let type: AnimationType
        
        public init(type: AnimationType) {
            self.type = type
        }
    }
    
    public struct CustomLayout: Equatable {
        public var itemsPerRow: Int
        public var itemSize: CGFloat
        public var sideInset: CGFloat
        public var itemSpacing: CGFloat
        
        public init(
            itemsPerRow: Int,
            itemSize: CGFloat,
            sideInset: CGFloat,
            itemSpacing: CGFloat
        ) {
            self.itemsPerRow = itemsPerRow
            self.itemSize = itemSize
            self.sideInset = sideInset
            self.itemSpacing = itemSpacing
        }
    }
    
    public final class ExternalBackground {
        public let effectContainerView: UIView?
        
        public init(
            effectContainerView: UIView?
        ) {
            self.effectContainerView = effectContainerView
        }
    }
    
    public final class InputInteractionHolder {
        public var inputInteraction: InputInteraction?
        
        public init() {
        }
    }
    
    public final class InputInteraction {
        public let performItemAction: (AnyHashable, Item, UIView, CGRect, CALayer, Bool) -> Void
        public let deleteBackwards: () -> Void
        public let openStickerSettings: () -> Void
        public let openFeatured: () -> Void
        public let addGroupAction: (AnyHashable, Bool) -> Void
        public let clearGroup: (AnyHashable) -> Void
        public let pushController: (ViewController) -> Void
        public let presentController: (ViewController) -> Void
        public let presentGlobalOverlayController: (ViewController) -> Void
        public let navigationController: () -> NavigationController?
        public let sendSticker: ((FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?) -> Void)?
        public let chatPeerId: PeerId?
        public let peekBehavior: EmojiContentPeekBehavior?
        public let customLayout: CustomLayout?
        public let externalBackground: ExternalBackground?
        
        public init(
            performItemAction: @escaping (AnyHashable, Item, UIView, CGRect, CALayer, Bool) -> Void,
            deleteBackwards: @escaping () -> Void,
            openStickerSettings: @escaping () -> Void,
            openFeatured: @escaping () -> Void,
            addGroupAction: @escaping (AnyHashable, Bool) -> Void,
            clearGroup: @escaping (AnyHashable) -> Void,
            pushController: @escaping (ViewController) -> Void,
            presentController: @escaping (ViewController) -> Void,
            presentGlobalOverlayController: @escaping (ViewController) -> Void,
            navigationController: @escaping () -> NavigationController?,
            sendSticker: ((FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?) -> Void)?,
            chatPeerId: PeerId?,
            peekBehavior: EmojiContentPeekBehavior?,
            customLayout: CustomLayout?,
            externalBackground: ExternalBackground?
        ) {
            self.performItemAction = performItemAction
            self.deleteBackwards = deleteBackwards
            self.openStickerSettings = openStickerSettings
            self.openFeatured = openFeatured
            self.addGroupAction = addGroupAction
            self.clearGroup = clearGroup
            self.pushController = pushController
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.navigationController = navigationController
            self.sendSticker = sendSticker
            self.chatPeerId = chatPeerId
            self.peekBehavior = peekBehavior
            self.customLayout = customLayout
            self.externalBackground = externalBackground
        }
    }
    
    public enum StaticEmojiSegment: Int32, CaseIterable {
        case people = 0
        case animalsAndNature = 1
        case foodAndDrink = 2
        case activityAndSport = 3
        case travelAndPlaces = 4
        case objects = 5
        case symbols = 6
        case flags = 7
    }
    
    public enum ItemContent: Equatable {
        public enum Id: Hashable {
            case animation(EntityKeyboardAnimationData.Id)
            case staticEmoji(String)
            case icon(Icon)
        }
        
        public enum Icon: Equatable {
            case premiumStar
        }
        
        case animation(EntityKeyboardAnimationData)
        case staticEmoji(String)
        case icon(Icon)
        
        public var id: Id {
            switch self {
            case let .animation(animation):
                return .animation(animation.id)
            case let .staticEmoji(value):
                return .staticEmoji(value)
            case let .icon(icon):
                return .icon(icon)
            }
        }
    }
    
    public final class Item: Equatable {
        public let animationData: EntityKeyboardAnimationData?
        public let content: ItemContent
        public let itemFile: TelegramMediaFile?
        public let subgroupId: Int32?
        
        public init(
            animationData: EntityKeyboardAnimationData?,
            content: ItemContent,
            itemFile: TelegramMediaFile?,
            subgroupId: Int32?
        ) {
            self.animationData = animationData
            self.content = content
            self.itemFile = itemFile
            self.subgroupId = subgroupId
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.animationData?.resource.resource.id != rhs.animationData?.resource.resource.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if lhs.itemFile?.fileId != rhs.itemFile?.fileId {
                return false
            }
            if lhs.subgroupId != rhs.subgroupId {
                return false
            }
            
            return true
        }
    }
    
    public final class ItemGroup: Equatable {
        public let supergroupId: AnyHashable
        public let groupId: AnyHashable
        public let title: String?
        public let subtitle: String?
        public let actionButtonTitle: String?
        public let isFeatured: Bool
        public let isPremiumLocked: Bool
        public let isEmbedded: Bool
        public let hasClear: Bool
        public let isExpandable: Bool
        public let displayPremiumBadges: Bool
        public let headerItem: EntityKeyboardAnimationData?
        public let items: [Item]
        
        public init(
            supergroupId: AnyHashable,
            groupId: AnyHashable,
            title: String?,
            subtitle: String?,
            actionButtonTitle: String?,
            isFeatured: Bool,
            isPremiumLocked: Bool,
            isEmbedded: Bool,
            hasClear: Bool,
            isExpandable: Bool,
            displayPremiumBadges: Bool,
            headerItem: EntityKeyboardAnimationData?,
            items: [Item]
        ) {
            self.supergroupId = supergroupId
            self.groupId = groupId
            self.title = title
            self.subtitle = subtitle
            self.actionButtonTitle = actionButtonTitle
            self.isFeatured = isFeatured
            self.isPremiumLocked = isPremiumLocked
            self.isEmbedded = isEmbedded
            self.hasClear = hasClear
            self.isExpandable = isExpandable
            self.displayPremiumBadges = displayPremiumBadges
            self.headerItem = headerItem
            self.items = items
        }
        
        public static func ==(lhs: ItemGroup, rhs: ItemGroup) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.supergroupId != rhs.supergroupId {
                return false
            }
            if lhs.groupId != rhs.groupId {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.subtitle != rhs.subtitle {
                return false
            }
            if lhs.actionButtonTitle != rhs.actionButtonTitle {
                return false
            }
            if lhs.isFeatured != rhs.isFeatured {
                return false
            }
            if lhs.isPremiumLocked != rhs.isPremiumLocked {
                return false
            }
            if lhs.isEmbedded != rhs.isEmbedded {
                return false
            }
            if lhs.hasClear != rhs.hasClear {
                return false
            }
            if lhs.isExpandable != rhs.isExpandable {
                return false
            }
            if lhs.displayPremiumBadges != rhs.displayPremiumBadges {
                return false
            }
            if lhs.headerItem != rhs.headerItem {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            return true
        }
    }
    
    public enum ItemLayoutType {
        case compact
        case detailed
    }
    
    public let id: AnyHashable
    public let context: AccountContext
    public let avatarPeer: EnginePeer?
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let inputInteractionHolder: InputInteractionHolder
    public let itemGroups: [ItemGroup]
    public let itemLayoutType: ItemLayoutType
    public let warpContentsOnEdges: Bool
    public let enableLongPress: Bool
    public let selectedItems: Set<MediaId>
    
    public init(
        id: AnyHashable,
        context: AccountContext,
        avatarPeer: EnginePeer?,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        inputInteractionHolder: InputInteractionHolder,
        itemGroups: [ItemGroup],
        itemLayoutType: ItemLayoutType,
        warpContentsOnEdges: Bool,
        enableLongPress: Bool,
        selectedItems: Set<MediaId>
    ) {
        self.id = id
        self.context = context
        self.avatarPeer = avatarPeer
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.inputInteractionHolder = inputInteractionHolder
        self.itemGroups = itemGroups
        self.itemLayoutType = itemLayoutType
        self.warpContentsOnEdges = warpContentsOnEdges
        self.enableLongPress = enableLongPress
        self.selectedItems = selectedItems
    }
    
    public static func ==(lhs: EmojiPagerContentComponent, rhs: EmojiPagerContentComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.avatarPeer != rhs.avatarPeer {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.inputInteractionHolder !== rhs.inputInteractionHolder {
            return false
        }
        if lhs.itemGroups != rhs.itemGroups {
            return false
        }
        if lhs.itemLayoutType != rhs.itemLayoutType {
            return false
        }
        if lhs.warpContentsOnEdges != rhs.warpContentsOnEdges {
            return false
        }
        if lhs.enableLongPress != rhs.enableLongPress {
            return false
        }
        if lhs.selectedItems != rhs.selectedItems {
            return false
        }
        
        return true
    }
    
    public final class Tag {
        public let id: AnyHashable
        
        public init(id: AnyHashable) {
            self.id = id
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate, PagerContentViewWithBackground, ComponentTaggedView {
        private struct ItemGroupDescription: Equatable {
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let hasTitle: Bool
            let isPremiumLocked: Bool
            let isFeatured: Bool
            let itemCount: Int
            let isEmbedded: Bool
            let isExpandable: Bool
        }
        
        private struct ItemGroupLayout: Equatable {
            let frame: CGRect
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let headerHeight: CGFloat
            let itemTopOffset: CGFloat
            let itemCount: Int
            let collapsedItemIndex: Int?
            let collapsedItemText: String?
        }
        
        private struct ItemLayout: Equatable {
            var layoutType: ItemLayoutType
            var width: CGFloat
            var headerInsets: UIEdgeInsets
            var itemInsets: UIEdgeInsets
            var curveNearBounds: Bool
            var itemGroupLayouts: [ItemGroupLayout]
            var itemDefaultHeaderHeight: CGFloat
            var itemFeaturedHeaderHeight: CGFloat
            var nativeItemSize: CGFloat
            let visibleItemSize: CGFloat
            let playbackItemSize: CGFloat
            var horizontalSpacing: CGFloat
            var verticalSpacing: CGFloat
            var verticalGroupDefaultSpacing: CGFloat
            var verticalGroupFeaturedSpacing: CGFloat
            var itemsPerRow: Int
            var contentSize: CGSize
            
            var premiumButtonInset: CGFloat
            var premiumButtonHeight: CGFloat
            
            init(layoutType: ItemLayoutType, width: CGFloat, containerInsets: UIEdgeInsets, itemGroups: [ItemGroupDescription], expandedGroupIds: Set<AnyHashable>, curveNearBounds: Bool, customLayout: CustomLayout?) {
                self.layoutType = layoutType
                self.width = width
                
                self.premiumButtonInset = 6.0
                self.premiumButtonHeight = 50.0
                
                self.curveNearBounds = curveNearBounds
                
                let minItemsPerRow: Int
                let minSpacing: CGFloat
                let itemInsets: UIEdgeInsets
                switch layoutType {
                case .compact:
                    minItemsPerRow = 8
                    self.nativeItemSize = 40.0
                    self.playbackItemSize = 48.0
                    self.verticalSpacing = 9.0
                    
                    if width >= 420.0 {
                        itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 5.0, bottom: containerInsets.bottom, right: containerInsets.right + 5.0)
                        minSpacing = 2.0
                    } else {
                        itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 7.0, bottom: containerInsets.bottom, right: containerInsets.right + 7.0)
                        minSpacing = 9.0
                    }
                    
                    self.headerInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 16.0, bottom: containerInsets.bottom, right: containerInsets.right + 16.0)
                    
                    self.itemDefaultHeaderHeight = 24.0
                    self.itemFeaturedHeaderHeight = self.itemDefaultHeaderHeight
                case .detailed:
                    minItemsPerRow = 5
                    self.nativeItemSize = 70.0
                    self.playbackItemSize = 96.0
                    self.verticalSpacing = 2.0
                    minSpacing = 12.0
                    self.itemDefaultHeaderHeight = 24.0
                    self.itemFeaturedHeaderHeight = 60.0
                    itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 10.0, bottom: containerInsets.bottom, right: containerInsets.right + 10.0)
                    self.headerInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 16.0, bottom: containerInsets.bottom, right: containerInsets.right + 16.0)
                }
                
                self.verticalGroupDefaultSpacing = 18.0
                self.verticalGroupFeaturedSpacing = 15.0
                
                if let customLayout = customLayout {
                    self.itemsPerRow = customLayout.itemsPerRow
                    self.nativeItemSize = customLayout.itemSize
                    self.visibleItemSize = customLayout.itemSize
                    self.verticalSpacing = 9.0
                    self.itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + customLayout.sideInset, bottom: containerInsets.bottom, right: containerInsets.right + customLayout.sideInset)
                    self.horizontalSpacing = customLayout.itemSpacing
                } else {
                    self.itemInsets = itemInsets
                    let itemHorizontalSpace = width - self.itemInsets.left - self.itemInsets.right
                    self.itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + minSpacing) / (self.nativeItemSize + minSpacing)))
                    let proposedItemSize = floor((itemHorizontalSpace - minSpacing * (CGFloat(self.itemsPerRow) - 1.0)) / CGFloat(self.itemsPerRow))
                    self.visibleItemSize = proposedItemSize < self.nativeItemSize ? proposedItemSize : self.nativeItemSize
                    self.horizontalSpacing = floorToScreenPixels((itemHorizontalSpace - self.visibleItemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
                }
                
                let actualContentWidth = self.visibleItemSize * CGFloat(self.itemsPerRow) + self.horizontalSpacing * CGFloat(self.itemsPerRow - 1)
                self.itemInsets.left = floorToScreenPixels((width - actualContentWidth) / 2.0)
                self.itemInsets.right = self.itemInsets.left
                
                var verticalGroupOrigin: CGFloat = self.itemInsets.top
                self.itemGroupLayouts = []
                for itemGroup in itemGroups {
                    var itemTopOffset: CGFloat = 0.0
                    var headerHeight: CGFloat = 0.0
                    var groupSpacing = self.verticalGroupDefaultSpacing
                    if itemGroup.hasTitle {
                        if itemGroup.isFeatured {
                            headerHeight = self.itemFeaturedHeaderHeight
                            groupSpacing = self.verticalGroupFeaturedSpacing
                        } else {
                            headerHeight = self.itemDefaultHeaderHeight
                        }
                    }
                    if itemGroup.isEmbedded {
                        headerHeight += 32.0
                        groupSpacing -= 4.0
                    }
                    itemTopOffset += headerHeight
                    
                    var numRowsInGroup: Int
                    if itemGroup.isEmbedded {
                        numRowsInGroup = 0
                    } else {
                        numRowsInGroup = (itemGroup.itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                    }
                    
                    var collapsedItemIndex: Int?
                    var collapsedItemText: String?
                    let visibleItemCount: Int
                    if itemGroup.isEmbedded {
                        visibleItemCount = 0
                    } else if itemGroup.isExpandable && !expandedGroupIds.contains(itemGroup.groupId) {
                        let maxLines: Int
                        #if DEBUG
                        maxLines = 2
                        #else
                        maxLines = 3
                        #endif
                        if numRowsInGroup > maxLines {
                            visibleItemCount = self.itemsPerRow * maxLines - 1
                            collapsedItemIndex = visibleItemCount
                            collapsedItemText = "+\(itemGroup.itemCount - visibleItemCount)"
                        } else {
                            visibleItemCount = itemGroup.itemCount
                        }
                    } else {
                        visibleItemCount = itemGroup.itemCount
                    }
                    
                    if !itemGroup.isEmbedded {
                        numRowsInGroup = (visibleItemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                    }
                    
                    var groupContentSize = CGSize(width: width, height: itemTopOffset + CGFloat(numRowsInGroup) * self.visibleItemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
                    if (itemGroup.isPremiumLocked || itemGroup.isFeatured), case .compact = layoutType {
                        groupContentSize.height += self.premiumButtonInset + self.premiumButtonHeight
                    }
                    
                    self.itemGroupLayouts.append(ItemGroupLayout(
                        frame: CGRect(origin: CGPoint(x: 0.0, y: verticalGroupOrigin), size: groupContentSize),
                        supergroupId: itemGroup.supergroupId,
                        groupId: itemGroup.groupId,
                        headerHeight: headerHeight,
                        itemTopOffset: itemTopOffset,
                        itemCount: visibleItemCount,
                        collapsedItemIndex: collapsedItemIndex,
                        collapsedItemText: collapsedItemText
                    ))
                    verticalGroupOrigin += groupContentSize.height + groupSpacing
                }
                verticalGroupOrigin += self.itemInsets.bottom
                self.contentSize = CGSize(width: width, height: verticalGroupOrigin)
            }
            
            func frame(groupIndex: Int, itemIndex: Int) -> CGRect {
                let groupLayout = self.itemGroupLayouts[groupIndex]
                
                let row = itemIndex / self.itemsPerRow
                let column = itemIndex % self.itemsPerRow
                
                return CGRect(
                    origin: CGPoint(
                        x: self.itemInsets.left + CGFloat(column) * (self.visibleItemSize + self.horizontalSpacing),
                        y: groupLayout.frame.minY + groupLayout.itemTopOffset + CGFloat(row) * (self.visibleItemSize + self.verticalSpacing)
                    ),
                    size: CGSize(
                        width: self.visibleItemSize,
                        height: self.visibleItemSize
                    )
                )
            }
            
            func visibleItems(for rect: CGRect) -> [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] {
                var result: [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] = []
                
                for groupIndex in 0 ..< self.itemGroupLayouts.count {
                    let group = self.itemGroupLayouts[groupIndex]
                    
                    if !rect.intersects(group.frame) {
                        continue
                    }
                    let offsetRect = rect.offsetBy(dx: -self.itemInsets.left, dy: -group.frame.minY - group.itemTopOffset)
                    var minVisibleRow = Int(floor((offsetRect.minY - self.verticalSpacing) / (self.visibleItemSize + self.verticalSpacing)))
                    minVisibleRow = max(0, minVisibleRow)
                    let maxVisibleRow = Int(ceil((offsetRect.maxY - self.verticalSpacing) / (self.visibleItemSize + self.verticalSpacing)))

                    let minVisibleIndex = minVisibleRow * self.itemsPerRow
                    let maxVisibleIndex = min(group.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
                    
                    result.append((
                        supergroupId: group.supergroupId,
                        groupId: group.groupId,
                        groupIndex: groupIndex,
                        groupItems: maxVisibleIndex >= minVisibleIndex ? (minVisibleIndex ..< (maxVisibleIndex + 1)) : nil
                    ))
                }
                
                return result
            }
        }
        
        public final class ItemPlaceholderView: UIView {
            private let shimmerView: PortalSourceView?
            private var placeholderView: PortalView?
            private let placeholderMaskLayer: SimpleLayer
            private var placeholderImageView: UIImageView?
            
            public init(
                context: AccountContext,
                dimensions: CGSize?,
                immediateThumbnailData: Data?,
                shimmerView: PortalSourceView?,
                color: UIColor,
                size: CGSize
            ) {
                self.shimmerView = shimmerView
                self.placeholderMaskLayer = SimpleLayer()
                
                super.init(frame: CGRect())
                
                if let shimmerView = self.shimmerView, let placeholderView = PortalView() {
                    self.placeholderView = placeholderView
                    
                    placeholderView.view.clipsToBounds = true
                    placeholderView.view.layer.mask = self.placeholderMaskLayer
                    self.addSubview(placeholderView.view)
                    shimmerView.addPortal(view: placeholderView)
                }
                
                let useDirectContent = self.placeholderView == nil
                Queue.concurrentDefaultQueue().async { [weak self] in
                    if let image = generateStickerPlaceholderImage(data: immediateThumbnailData, size: size, scale: min(2.0, UIScreenScale), imageSize: dimensions ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: useDirectContent ? color : .black) {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if useDirectContent {
                                strongSelf.layer.contents = image.cgImage
                            } else {
                                strongSelf.placeholderMaskLayer.contents = image.cgImage
                            }
                        }
                    }
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            public func update(size: CGSize) {
                if let placeholderView = self.placeholderView {
                    placeholderView.view.frame = CGRect(origin: CGPoint(), size: size)
                }
                self.placeholderMaskLayer.frame = CGRect(origin: CGPoint(), size: size)
            }
        }
        
        public final class ItemLayer: MultiAnimationRenderTarget {
            public struct Key: Hashable {
                var groupId: AnyHashable
                var itemId: ItemContent.Id
                
                public init(
                    groupId: AnyHashable,
                    itemId: ItemContent.Id
                ) {
                    self.groupId = groupId
                    self.itemId = itemId
                }
            }
            
            enum Badge {
                case premium
                case locked
                case featured
            }
            
            let item: Item
            
            private let content: ItemContent
            private let placeholderColor: UIColor
            let pixelSize: CGSize
            private let size: CGSize
            private var disposable: Disposable?
            private var fetchDisposable: Disposable?
            private var premiumBadgeView: PremiumBadgeView?
            
            private var badge: Badge?
            private var validSize: CGSize?
            
            private var isInHierarchyValue: Bool = false
            public var isVisibleForAnimations: Bool = false {
                didSet {
                    if self.isVisibleForAnimations != oldValue {
                        self.updatePlayback()
                    }
                }
            }
            public private(set) var displayPlaceholder: Bool = false
            public let onUpdateDisplayPlaceholder: (Bool, Double) -> Void
        
            public init(
                item: Item,
                context: AccountContext,
                attemptSynchronousLoad: Bool,
                content: ItemContent,
                cache: AnimationCache,
                renderer: MultiAnimationRenderer,
                placeholderColor: UIColor,
                blurredBadgeColor: UIColor,
                accentIconColor: UIColor,
                pointSize: CGSize,
                onUpdateDisplayPlaceholder: @escaping (Bool, Double) -> Void
            ) {
                self.item = item
                self.content = content
                self.placeholderColor = placeholderColor
                self.onUpdateDisplayPlaceholder = onUpdateDisplayPlaceholder
                
                let scale = min(2.0, UIScreenScale)
                let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
                self.pixelSize = pixelSize
                self.size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
                
                super.init()
                
                switch content {
                case let .animation(animationData):
                    let loadAnimation: () -> Void = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.disposable = renderer.add(target: strongSelf, cache: cache, itemId: animationData.resource.resource.id.stringRepresentation, size: pixelSize, fetch: animationCacheFetchFile(context: context, resource: animationData.resource, type: animationData.type.animationCacheAnimationType, keyframeOnly: pixelSize.width >= 120.0))
                    }
                    
                    if attemptSynchronousLoad {
                        if !renderer.loadFirstFrameSynchronously(target: self, cache: cache, itemId: animationData.resource.resource.id.stringRepresentation, size: pixelSize) {
                            self.updateDisplayPlaceholder(displayPlaceholder: true)
                            
                            self.fetchDisposable = renderer.loadFirstFrame(target: self, cache: cache, itemId: animationData.resource.resource.id.stringRepresentation, size: pixelSize, fetch: animationCacheFetchFile(context: context, resource: animationData.resource, type: animationData.type.animationCacheAnimationType, keyframeOnly: true), completion: { [weak self] success, isFinal in
                                if !isFinal {
                                    if !success {
                                        Queue.mainQueue().async {
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            strongSelf.updateDisplayPlaceholder(displayPlaceholder: true)
                                        }
                                    }
                                    return
                                }
                                
                                Queue.mainQueue().async {
                                    loadAnimation()
                                    
                                    if !success {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        strongSelf.updateDisplayPlaceholder(displayPlaceholder: true)
                                    }
                                }
                            })
                        } else {
                            loadAnimation()
                        }
                    } else {
                        self.fetchDisposable = renderer.loadFirstFrame(target: self, cache: cache, itemId: animationData.resource.resource.id.stringRepresentation, size: pixelSize, fetch: animationCacheFetchFile(context: context, resource: animationData.resource, type: animationData.type.animationCacheAnimationType, keyframeOnly: true), completion: { [weak self] success, isFinal in
                            if !isFinal {
                                if !success {
                                    Queue.mainQueue().async {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        strongSelf.updateDisplayPlaceholder(displayPlaceholder: true)
                                    }
                                }
                                return
                            }
                            
                            Queue.mainQueue().async {
                                loadAnimation()
                                
                                if !success {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.updateDisplayPlaceholder(displayPlaceholder: true)
                                }
                            }
                        })
                    }
                case let .staticEmoji(staticEmoji):
                    let image = generateImage(pointSize, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        let preScaleFactor: CGFloat = 1.0
                        let scaledSize = CGSize(width: floor(size.width * preScaleFactor), height: floor(size.height * preScaleFactor))
                        let scaleFactor = scaledSize.width / size.width
                        
                        context.scaleBy(x: 1.0 / scaleFactor, y: 1.0 / scaleFactor)
                        
                        let string = NSAttributedString(string: staticEmoji, font: Font.regular(floor(32.0 * scaleFactor)), textColor: .black)
                        let boundingRect = string.boundingRect(with: scaledSize, options: .usesLineFragmentOrigin, context: nil)
                        UIGraphicsPushContext(context)
                        string.draw(at: CGPoint(x: floor((scaledSize.width - boundingRect.width) / 2.0 + boundingRect.minX), y: floor((scaledSize.height - boundingRect.height) / 2.0 + boundingRect.minY)))
                        UIGraphicsPopContext()
                    })
                    self.contents = image?.cgImage
                case let .icon(icon):
                    let image = generateImage(pointSize, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        UIGraphicsPushContext(context)
                        
                        switch icon {
                        case .premiumStar:
                            if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: accentIconColor) {
                                let imageSize = image.size.aspectFitted(CGSize(width: size.width - 6.0, height: size.height - 6.0))
                                image.draw(in: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
                            }
                        }
                        
                        UIGraphicsPopContext()
                    })
                    self.contents = image?.cgImage
                }
            }
            
            override public init(layer: Any) {
                guard let layer = layer as? ItemLayer else {
                    preconditionFailure()
                }
                
                self.item = layer.item
                
                self.content = layer.content
                self.placeholderColor = layer.placeholderColor
                self.size = layer.size
                self.pixelSize = layer.pixelSize
                
                self.onUpdateDisplayPlaceholder = { _, _ in }
                
                super.init(layer: layer)
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            deinit {
                self.disposable?.dispose()
                self.fetchDisposable?.dispose()
            }
            
            public override func action(forKey event: String) -> CAAction? {
                if event == kCAOnOrderIn {
                    self.isInHierarchyValue = true
                } else if event == kCAOnOrderOut {
                    self.isInHierarchyValue = false
                }
                self.updatePlayback()
                return nullAction
            }
            
            func update(transition: Transition, size: CGSize, badge: Badge?, blurredBadgeColor: UIColor, blurredBadgeBackgroundColor: UIColor) {
                if self.badge != badge || self.validSize != size {
                    self.badge = badge
                    self.validSize = size
                    
                    if let badge = badge {
                        var badgeTransition = transition
                        let premiumBadgeView: PremiumBadgeView
                        if let current = self.premiumBadgeView {
                            premiumBadgeView = current
                        } else {
                            badgeTransition = .immediate
                            premiumBadgeView = PremiumBadgeView()
                            self.premiumBadgeView = premiumBadgeView
                            self.addSublayer(premiumBadgeView.layer)
                        }
                        
                        let badgeDiameter = min(16.0, floor(size.height * 0.5))
                        let badgeSize = CGSize(width: badgeDiameter, height: badgeDiameter)
                        badgeTransition.setFrame(view: premiumBadgeView, frame: CGRect(origin: CGPoint(x: size.width - badgeSize.width, y: size.height - badgeSize.height), size: badgeSize))
                        premiumBadgeView.update(transition: badgeTransition, badge: badge, backgroundColor: blurredBadgeColor, size: badgeSize)
                        
                        self.blurredRepresentationBackgroundColor = blurredBadgeBackgroundColor
                        self.blurredRepresentationTarget = premiumBadgeView.contentLayer
                    } else {
                        if let premiumBadgeView = self.premiumBadgeView {
                            self.premiumBadgeView = nil
                            premiumBadgeView.removeFromSuperview()
                            
                            self.blurredRepresentationBackgroundColor = nil
                            self.blurredRepresentationTarget = nil
                        }
                    }
                }
            }
            
            private func updatePlayback() {
                let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
                
                self.shouldBeAnimating = shouldBePlaying
            }
            
            public override func updateDisplayPlaceholder(displayPlaceholder: Bool) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                
                self.displayPlaceholder = displayPlaceholder
                self.onUpdateDisplayPlaceholder(displayPlaceholder, 0.0)
            }
            
            public override func transitionToContents(_ contents: AnyObject) {
                self.contents = contents
                
                if self.displayPlaceholder {
                    self.displayPlaceholder = false
                    self.onUpdateDisplayPlaceholder(false, 0.2)
                    self.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                }
            }
        }
        
        private final class GroupBorderLayer: PassthroughShapeLayer {
            let tintContainerLayer: CAShapeLayer
            
            override init() {
                self.tintContainerLayer = CAShapeLayer()
                
                super.init()
                
                self.mirrorLayer = self.tintContainerLayer
            }
            
            override func action(forKey event: String) -> CAAction? {
                return nullAction
            }
            
            override init(layer: Any) {
                self.tintContainerLayer = CAShapeLayer()
                
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private final class ItemSelectionLayer: PassthroughLayer {
            let tintContainerLayer: SimpleLayer
            
            override init() {
                self.tintContainerLayer = SimpleLayer()
                
                super.init()
                
                self.mirrorLayer = self.tintContainerLayer
            }
            
            override func action(forKey event: String) -> CAAction? {
                return nullAction
            }
            
            override init(layer: Any) {
                self.tintContainerLayer = SimpleLayer()
                
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private final class ContentScrollLayer: CALayer {
            var mirrorLayer: CALayer?
            
            override init() {
                super.init()
            }
            
            override init(layer: Any) {
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override var position: CGPoint {
                get {
                    return super.position
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.position = value
                    }
                    super.position = value
                }
            }
            
            override var bounds: CGRect {
                get {
                    return super.bounds
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.bounds = value
                    }
                    super.bounds = value
                }
            }
            
            override func add(_ animation: CAAnimation, forKey key: String?) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.add(animation, forKey: key)
                }
                
                super.add(animation, forKey: key)
            }
            
            override func removeAllAnimations() {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAllAnimations()
                }
                
                super.removeAllAnimations()
            }
            
            override func removeAnimation(forKey: String) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAnimation(forKey: forKey)
                }
                
                super.removeAnimation(forKey: forKey)
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
            override static var layerClass: AnyClass {
                return ContentScrollLayer.self
            }
            
            private let mirrorView: UIView
            
            init(mirrorView: UIView) {
                self.mirrorView = mirrorView
                
                super.init(frame: CGRect())
                
                (self.layer as? ContentScrollLayer)?.mirrorLayer = mirrorView.layer
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private enum VisualItemKey: Hashable {
            case item(id: ItemLayer.Key)
            case header(groupId: AnyHashable)
            case groupExpandButton(groupId: AnyHashable)
            case groupActionButton(groupId: AnyHashable)
        }
        
        private let shimmerHostView: PortalSourceView?
        private let standaloneShimmerEffect: StandaloneShimmerEffect?
        
        private let backgroundView: BlurredBackgroundView
        private var vibrancyEffectView: UIVisualEffectView?
        public private(set) var mirrorContentClippingView: UIView?
        private let mirrorContentScrollView: UIView
        private var warpView: WarpView?
        private var mirrorContentWarpView: WarpView?
        private let scrollView: ContentScrollView
        private var scrollGradientLayer: SimpleGradientLayer?
        private let boundsChangeTrackerLayer = SimpleLayer()
        private var effectiveVisibleSize: CGSize = CGSize()
        
        private let placeholdersContainerView: UIView
        private var visibleItemPlaceholderViews: [ItemLayer.Key: ItemPlaceholderView] = [:]
        private var visibleItemSelectionLayers: [ItemLayer.Key: ItemSelectionLayer] = [:]
        private var visibleItemLayers: [ItemLayer.Key: ItemLayer] = [:]
        private var visibleGroupHeaders: [AnyHashable: GroupHeaderLayer] = [:]
        private var visibleGroupBorders: [AnyHashable: GroupBorderLayer] = [:]
        private var visibleGroupPremiumButtons: [AnyHashable: ComponentView<Empty>] = [:]
        private var visibleGroupExpandActionButtons: [AnyHashable: GroupExpandActionButton] = [:]
        private var expandedGroupIds: Set<AnyHashable> = Set()
        private var ignoreScrolling: Bool = false
        private var keepTopPanelVisibleUntilScrollingInput: Bool = false
        
        private var component: EmojiPagerContentComponent?
        private weak var state: EmptyComponentState?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var keyboardChildEnvironment: EntityKeyboardChildEnvironment?
        private var activeItemUpdated: ActionSlot<(AnyHashable, AnyHashable?, Transition)>?
        private var itemLayout: ItemLayout?
        
        private var longTapRecognizer: UILongPressGestureRecognizer?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            
            if ProcessInfo.processInfo.processorCount > 2 {
                self.shimmerHostView = PortalSourceView()
                self.standaloneShimmerEffect = StandaloneShimmerEffect()
            } else {
                self.shimmerHostView = nil
                self.standaloneShimmerEffect = nil
            }
            
            self.mirrorContentScrollView = UIView()
            self.mirrorContentScrollView.layer.anchorPoint = CGPoint()
            self.mirrorContentScrollView.clipsToBounds = false
            self.scrollView = ContentScrollView(mirrorView: self.mirrorContentScrollView)
            self.scrollView.layer.anchorPoint = CGPoint()
            
            self.placeholdersContainerView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            if let shimmerHostView = self.shimmerHostView {
                shimmerHostView.alpha = 0.0
                self.addSubview(shimmerHostView)
            }
            
            self.boundsChangeTrackerLayer.opacity = 0.0
            self.layer.addSublayer(self.boundsChangeTrackerLayer)
            self.boundsChangeTrackerLayer.didEnterHierarchy = { [weak self] in
                self?.standaloneShimmerEffect?.updateLayer()
            }
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = false
            self.scrollView.scrollsToTop = false
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.placeholdersContainerView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
            longTapRecognizer.minimumPressDuration = 0.2
            self.longTapRecognizer = longTapRecognizer
            self.addGestureRecognizer(longTapRecognizer)
            longTapRecognizer.isEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateIsWarpEnabled(isEnabled: Bool) {
            if isEnabled {
                if self.warpView == nil {
                    let warpView = WarpView(frame: CGRect())
                    self.warpView = warpView
                    
                    self.insertSubview(warpView, aboveSubview: self.scrollView)
                    warpView.contentView.addSubview(self.scrollView)
                }
                if self.mirrorContentWarpView == nil {
                    let mirrorContentWarpView = WarpView(frame: CGRect())
                    self.mirrorContentWarpView = mirrorContentWarpView
                    
                    mirrorContentWarpView.contentView.addSubview(self.mirrorContentScrollView)
                }
            } else {
                if let warpView = self.warpView {
                    self.warpView = nil
                    
                    self.insertSubview(self.scrollView, aboveSubview: warpView)
                    warpView.removeFromSuperview()
                }
                if let mirrorContentWarpView = self.mirrorContentWarpView {
                    self.mirrorContentWarpView = nil
                    
                    if let mirrorContentClippingView = self.mirrorContentClippingView {
                        mirrorContentClippingView.addSubview(self.mirrorContentScrollView)
                    } else if let vibrancyEffectView = self.vibrancyEffectView {
                        vibrancyEffectView.contentView.addSubview(self.mirrorContentScrollView)
                    }
                    
                    mirrorContentWarpView.removeFromSuperview()
                }
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let tag = tag as? Tag {
                if tag.id == self.component?.id {
                    return true
                }
            }
            return false
        }
        
        public func animateIn(fromLocation: CGPoint) {
            let scrollLocation = self.convert(fromLocation, to: self.scrollView)
            for (key, itemLayer) in self.visibleItemLayers {
                let distanceVector = CGPoint(x: scrollLocation.x - itemLayer.position.x, y: scrollLocation.y - itemLayer.position.y)
                let distance = sqrt(distanceVector.x * distanceVector.x + distanceVector.y * distanceVector.y)
                
                let distanceNorm = min(1.0, max(0.0, distance / self.bounds.width))
                let delay = 0.05 + (distanceNorm) * 0.3
                itemLayer.animateScale(from: 0.01, to: 1.0, duration: 0.18, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                
                if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                    itemSelectionLayer.animateScale(from: 0.01, to: 1.0, duration: 0.18, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }
        
        public func animateInReactionSelection(sourceItems: [MediaId: (position: CGPoint, frameIndex: Int, placeholder: UIImage)]) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }

            for (key, itemLayer) in self.visibleItemLayers {
                guard case let .animation(animationData) = itemLayer.item.content else {
                    continue
                }
                guard let file = itemLayer.item.itemFile else {
                    continue
                }
                if let sourceItem = sourceItems[file.fileId] {
                    itemLayer.animatePosition(from: CGPoint(x: sourceItem.position.x - itemLayer.position.x, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    
                    if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                        itemSelectionLayer.animatePosition(from: CGPoint(x: sourceItem.position.x - itemLayer.position.x, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                    
                    component.animationRenderer.setFrameIndex(itemId: animationData.resource.resource.id.stringRepresentation, size: itemLayer.pixelSize, frameIndex: sourceItem.frameIndex, placeholder: sourceItem.placeholder)
                } else {
                    let distance = itemLayer.position.y - itemLayout.frame(groupIndex: 0, itemIndex: 0).midY
                    let maxDistance = self.bounds.height
                    let clippedDistance = max(0.0, min(distance, maxDistance))
                    let distanceNorm = clippedDistance / maxDistance
                    
                    let delay = listViewAnimationCurveSystem(distanceNorm) * 0.1
                    
                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                    itemLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, delay: delay)
                    
                    if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                        itemSelectionLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        itemSelectionLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, delay: delay)
                    }
                }
            }
            
            for (_, groupHeader) in self.visibleGroupHeaders {
                let distance = groupHeader.layer.position.y - itemLayout.frame(groupIndex: 0, itemIndex: 0).midY
                let maxDistance = self.bounds.height
                let clippedDistance = max(0.0, min(distance, maxDistance))
                let distanceNorm = clippedDistance / maxDistance
                
                let delay = listViewAnimationCurveSystem(distanceNorm) * 0.16
                
                groupHeader.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                groupHeader.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: delay)
                groupHeader.tintContentLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                groupHeader.tintContentLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: delay)
            }
        }
        
        public func layerForItem(groupId: AnyHashable, item: EmojiPagerContentComponent.Item) -> CALayer? {
            let itemKey = EmojiPagerContentComponent.View.ItemLayer.Key(groupId: groupId, itemId: item.content.id)
            if let itemLayer = self.visibleItemLayers[itemKey] {
                return itemLayer
            } else {
                return nil
            }
        }
        
        public func scrollToItemGroup(id supergroupId: AnyHashable, subgroupId: Int32?) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            for groupIndex in 0 ..< itemLayout.itemGroupLayouts.count {
                let group = itemLayout.itemGroupLayouts[groupIndex]
                
                var subgroupItemIndex: Int?
                if group.supergroupId == supergroupId {
                    if let subgroupId = subgroupId {
                        inner: for itemGroup in component.itemGroups {
                            if itemGroup.supergroupId == supergroupId {
                                for i in 0 ..< itemGroup.items.count {
                                    if itemGroup.items[i].subgroupId == subgroupId {
                                        subgroupItemIndex = i
                                        break
                                    }
                                }
                                break inner
                            }
                        }
                    }
                    let wasIgnoringScrollingEvents = self.ignoreScrolling
                    self.ignoreScrolling = true
                    self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
                    
                    self.keepTopPanelVisibleUntilScrollingInput = true
                    
                    let anchorFrame: CGRect
                    if let subgroupItemIndex = subgroupItemIndex {
                        anchorFrame = itemLayout.frame(groupIndex: groupIndex, itemIndex: subgroupItemIndex)
                    } else {
                        anchorFrame = group.frame
                    }
                    
                    var scrollPosition = anchorFrame.minY + floor(-itemLayout.verticalGroupDefaultSpacing / 2.0) - pagerEnvironment.containerInsets.top
                    if scrollPosition > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        scrollPosition = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    if scrollPosition < 0.0 {
                        scrollPosition = 0.0
                    }
                    
                    let offsetDirectionSign: Double = scrollPosition < self.scrollView.bounds.minY ? -1.0 : 1.0
                    
                    var previousVisibleLayers: [ItemLayer.Key: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleItemLayers {
                        previousVisibleLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleItemSelectionLayers: [ItemLayer.Key: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleItemSelectionLayers {
                        previousVisibleItemSelectionLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisiblePlaceholderViews: [ItemLayer.Key: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleItemPlaceholderViews {
                        previousVisiblePlaceholderViews[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupHeaders: [AnyHashable: (GroupHeaderLayer, CGRect)] = [:]
                    for (id, view) in self.visibleGroupHeaders {
                        if !self.scrollView.bounds.intersects(view.frame) {
                            continue
                        }
                        previousVisibleGroupHeaders[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupBorders: [AnyHashable: (GroupBorderLayer, CGRect)] = [:]
                    for (id, layer) in self.visibleGroupBorders {
                        previousVisibleGroupBorders[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupPremiumButtons: [AnyHashable: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleGroupPremiumButtons {
                        if let view = view.view {
                            previousVisibleGroupPremiumButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                        }
                    }
                    var previousVisibleGroupExpandActionButtons: [AnyHashable: (GroupExpandActionButton, CGRect)] = [:]
                    for (id, view) in self.visibleGroupExpandActionButtons {
                        previousVisibleGroupExpandActionButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    
                    self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: scrollPosition), size: self.scrollView.bounds.size)
                    self.ignoreScrolling = wasIgnoringScrollingEvents
                    
                    self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: true, previousItemPositions: nil, updatedItemPositions: nil)
                    
                    var commonItemOffset: CGFloat?
                    var previousVisibleBoundingRect: CGRect?
                    for (id, layerAndFrame) in previousVisibleLayers {
                        if let layer = self.visibleItemLayers[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                        if let view = self.visibleItemPlaceholderViews[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    for (id, layerAndFrame) in previousVisibleGroupHeaders {
                        if let view = self.visibleGroupHeaders[id] {
                            if commonItemOffset == nil, self.scrollView.bounds.intersects(view.frame) {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    /*for (id, layerAndFrame) in previousVisibleGroupBorders {
                        if let layer = self.visibleGroupBorders[id] {
                            if commonItemOffset == nil, self.scrollView.bounds.intersects(layer.frame) {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }*/
                    
                    for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                        if let view = self.visibleGroupPremiumButtons[id]?.view, self.scrollView.bounds.intersects(view.frame) {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                        if let view = self.visibleGroupExpandActionButtons[id], self.scrollView.bounds.intersects(view.frame) {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    let duration = 0.4
                    let timingFunction = kCAMediaTimingFunctionSpring
                    
                    if let commonItemOffset = commonItemOffset {
                        for (_, layer) in self.visibleItemLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleLayers {
                            if self.visibleItemLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleItemPlaceholderViews {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                            if self.visibleItemPlaceholderViews[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.placeholdersContainerView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupHeaders {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupHeaders {
                            if self.visibleGroupHeaders[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            let tintContentLayer = view.tintContentLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                                view?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, layer) in self.visibleGroupBorders {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleGroupBorders {
                            if self.visibleGroupBorders[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            let tintContainerLayer = layer.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                layer?.removeFromSuperlayer()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                        }
                        for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                            if self.visibleGroupPremiumButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupExpandActionButtons {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                            if self.visibleGroupExpandActionButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            let tintContainerLayer = view.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                                view?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                    } else if let previousVisibleBoundingRect = previousVisibleBoundingRect {
                        var updatedVisibleBoundingRect: CGRect?
                        
                        for (_, layer) in self.visibleItemLayers {
                            let frame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleItemPlaceholderViews {
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleGroupHeaders {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                if !self.scrollView.bounds.intersects(view.frame) {
                                    continue
                                }
                                
                                let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                    updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                                } else {
                                    updatedVisibleBoundingRect = frame
                                }
                            }
                        }
                        for (_, view) in self.visibleGroupExpandActionButtons {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        
                        if let updatedVisibleBoundingRect = updatedVisibleBoundingRect {
                            var commonItemOffset = updatedVisibleBoundingRect.height * offsetDirectionSign
                            
                            if previousVisibleBoundingRect.intersects(updatedVisibleBoundingRect) {
                                if offsetDirectionSign < 0.0 {
                                    commonItemOffset = previousVisibleBoundingRect.minY - updatedVisibleBoundingRect.maxY
                                } else {
                                    commonItemOffset = previousVisibleBoundingRect.maxY - updatedVisibleBoundingRect.minY
                                }
                            }
                            
                            for (_, layer) in self.visibleItemLayers {
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (_, layer) in self.visibleItemSelectionLayers {
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleLayers {
                                if self.visibleItemLayers[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            for (id, layerAndFrame) in previousVisibleItemSelectionLayers {
                                if self.visibleItemSelectionLayers[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleItemPlaceholderViews {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                                if self.visibleItemPlaceholderViews[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.placeholdersContainerView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupHeaders {
                                if !self.scrollView.bounds.intersects(view.frame) {
                                    continue
                                }
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisibleGroupHeaders {
                                if self.visibleGroupHeaders[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                let tintContentLayer = view.tintContentLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                                    view?.removeFromSuperview()
                                    tintContentLayer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, layer) in self.visibleGroupBorders {
                                if !self.scrollView.bounds.intersects(layer.frame) {
                                    continue
                                }
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleGroupBorders {
                                if self.visibleGroupBorders[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                let tintContainerLayer = layer.tintContainerLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                    layer?.removeFromSuperlayer()
                                    tintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupPremiumButtons {
                                if let view = view.view {
                                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                                }
                            }
                            for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                                if self.visibleGroupPremiumButtons[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupExpandActionButtons {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                                if self.visibleGroupExpandActionButtons[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                let tintContainerLayer = view.tintContainerLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                                    view?.removeFromSuperview()
                                    tintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        }
                    }
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                let locationInScrollView = recognizer.location(in: self.scrollView)
                outer: for (id, groupHeader) in self.visibleGroupHeaders {
                    if groupHeader.frame.insetBy(dx: -10.0, dy: -6.0).contains(locationInScrollView) {
                        let groupHeaderPoint = self.scrollView.convert(locationInScrollView, to: groupHeader)
                        if let clearIconLayer = groupHeader.clearIconLayer, clearIconLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(groupHeaderPoint) {
                            component.inputInteractionHolder.inputInteraction?.clearGroup(id)
                            return
                        } else {
                            if groupHeader.tapGesture(recognizer) {
                                return
                            }
                        }
                    }
                }
                
                var foundItem = false
                var foundExactItem = false
                if let (item, itemKey) = self.item(atPoint: recognizer.location(in: self)), let itemLayer = self.visibleItemLayers[itemKey] {
                    foundExactItem = true
                    foundItem = true
                    if !itemLayer.displayPlaceholder {
                        component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                    }
                }
                
                if !foundExactItem {
                    if let (item, itemKey) = self.item(atPoint: recognizer.location(in: self), extendedHitRange: true), let itemLayer = self.visibleItemLayers[itemKey] {
                        foundItem = true
                        if !itemLayer.displayPlaceholder {
                            component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                        }
                    }
                }
                
                let _ = foundItem
            }
        }
        
        private let longPressDuration: Double = 0.5
        private var longPressItem: EmojiPagerContentComponent.View.ItemLayer.Key?
        private var hapticFeedback: HapticFeedback?
        private var continuousHaptic: AnyObject?
        private var longPressTimer: SwiftSignalKit.Timer?
        
        @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                let point = recognizer.location(in: self)
                
                guard let item = self.item(atPoint: point), let itemLayer = self.visibleItemLayers[item.1] else {
                    return
                }
                switch item.0.content {
                case .animation:
                    break
                default:
                    return
                }
                self.longPressItem = item.1
                
                if #available(iOS 13.0, *) {
                    self.continuousHaptic = try? ContinuousHaptic(duration: longPressDuration)
                }
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                
                let transition = Transition(animation: .curve(duration: longPressDuration, curve: .easeInOut))
                transition.setScale(layer: itemLayer, scale: 1.3)
                
                self.longPressTimer?.invalidate()
                self.longPressTimer = SwiftSignalKit.Timer(timeout: longPressDuration, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.longTapRecognizer?.state = .ended
                }, queue: .mainQueue())
                self.longPressTimer?.start()
            case .changed:
                let point = recognizer.location(in: self)
                
                if let longPressItem = self.longPressItem, let item = self.item(atPoint: point), longPressItem == item.1 {
                } else {
                    self.longTapRecognizer?.state = .cancelled
                }
            case .cancelled:
                self.longPressTimer?.invalidate()
                self.continuousHaptic = nil
                
                if let itemKey = self.longPressItem {
                    self.longPressItem = nil
                    
                    if let itemLayer = self.visibleItemLayers[itemKey] {
                        let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                        transition.setScale(layer: itemLayer, scale: 1.0)
                    }
                }
            case .ended:
                self.longPressTimer?.invalidate()
                self.continuousHaptic = nil
                
                if let itemKey = self.longPressItem {
                    self.longPressItem = nil
                    
                    if let component = self.component, let itemLayer = self.visibleItemLayers[itemKey] {
                        component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, itemLayer.item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, true)
                    } else {
                        if let itemLayer = self.visibleItemLayers[itemKey] {
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(layer: itemLayer, scale: 1.0)
                        }
                    }
                }
            default:
                break
            }
        }
        
        private func item(atPoint point: CGPoint, extendedHitRange: Bool = false) -> (Item, ItemLayer.Key)? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            var closestItem: (key: ItemLayer.Key, distance: CGFloat)?
            
            for (key, itemLayer) in self.visibleItemLayers {
                if extendedHitRange {
                    let position = CGPoint(x: itemLayer.frame.midX, y: itemLayer.frame.midY)
                    let distance = CGPoint(x: localPoint.x - position.x, y: localPoint.y - position.y)
                    let distance2 = distance.x * distance.x + distance.y * distance.y
                    if distance2 > pow(max(itemLayer.bounds.width, itemLayer.bounds.height), 2.0) {
                        continue
                    }
                    
                    if let closestItemValue = closestItem {
                        if closestItemValue.distance > distance2 {
                            closestItem = (key, distance2)
                        }
                    } else {
                        closestItem = (key, distance2)
                    }
                } else {
                    if itemLayer.frame.contains(localPoint) {
                        return (itemLayer.item, key)
                    }
                }
            }
            
            if let key = closestItem?.key {
                if let itemLayer = self.visibleItemLayers[key] {
                    return (itemLayer.item, key)
                }
            }
            
            return nil
        }
        
        private struct ScrollingOffsetState: Equatable {
            var value: CGFloat
            var isDraggingOrDecelerating: Bool
        }
        
        private var previousScrollingOffset: ScrollingOffsetState?
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if self.keepTopPanelVisibleUntilScrollingInput {
                self.keepTopPanelVisibleUntilScrollingInput = false
                
                self.updateScrollingOffset(isReset: true, transition: .immediate)
            }
            if let presentation = scrollView.layer.presentation() {
                scrollView.bounds = presentation.bounds
                scrollView.layer.removeAllAnimations()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false, previousItemPositions: nil, updatedItemPositions: nil)
            
            self.updateScrollingOffset(isReset: false, transition: .immediate)
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if velocity.y != 0.0 {
                targetContentOffset.pointee.y = self.snappedContentOffset(proposedOffset: targetContentOffset.pointee.y)
            }
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.snapScrollingOffsetToInsets()
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.snapScrollingOffsetToInsets()
        }
        
        private func updateScrollingOffset(isReset: Bool, transition: Transition) {
            guard let component = self.component else {
                return
            }

            let isInteracting = scrollView.isDragging || scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset, !self.keepTopPanelVisibleUntilScrollingInput {
                let currentBounds = scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
                if case .detailed = component.itemLayoutType {
                    self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                        relativeOffset: relativeOffset,
                        absoluteOffsetToTopEdge: offsetToTopEdge,
                        absoluteOffsetToBottomEdge: offsetToBottomEdge,
                        isReset: isReset,
                        isInteracting: isInteracting,
                        transition: transition
                    ))
                }
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: isInteracting)
        }
        
        private func snappedContentOffset(proposedOffset: CGFloat) -> CGFloat {
            guard let pagerEnvironment = self.pagerEnvironment else {
                return proposedOffset
            }
            
            var proposedOffset = proposedOffset
            let bounds = self.bounds
            if proposedOffset + bounds.height > self.scrollView.contentSize.height - pagerEnvironment.containerInsets.bottom {
                proposedOffset = self.scrollView.contentSize.height - bounds.height
            }
            if proposedOffset < pagerEnvironment.containerInsets.top {
                proposedOffset = 0.0
            }
            
            return proposedOffset
        }
        
        private func snapScrollingOffsetToInsets() {
            let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
            
            var currentBounds = self.scrollView.bounds
            currentBounds.origin.y = self.snappedContentOffset(proposedOffset: currentBounds.minY)
            transition.setBounds(view: self.scrollView, bounds: currentBounds)
            
            self.updateScrollingOffset(isReset: false, transition: transition)
        }
        
        private func updateVisibleItems(transition: Transition, attemptSynchronousLoads: Bool, previousItemPositions: [VisualItemKey: CGPoint]?, previousAbsoluteItemPositions: [VisualItemKey: CGPoint]? = nil, updatedItemPositions: [VisualItemKey: CGPoint]?, hintDisappearingGroupFrame: (groupId: AnyHashable, frame: CGRect)? = nil) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let keyboardChildEnvironment = self.keyboardChildEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            
            var topVisibleGroupId: AnyHashable?
            var topVisibleSubgroupId: AnyHashable?
            
            var validIds = Set<ItemLayer.Key>()
            var validGroupHeaderIds = Set<AnyHashable>()
            var validGroupBorderIds = Set<AnyHashable>()
            var validGroupPremiumButtonIds = Set<AnyHashable>()
            var validGroupExpandActionButtons = Set<AnyHashable>()
            
            let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
            let topVisibleDetectionBounds = effectiveVisibleBounds.offsetBy(dx: 0.0, dy: pagerEnvironment.containerInsets.top)
            
            let contentAnimation = transition.userData(ContentAnimation.self)
            var transitionHintInstalledGroupId: AnyHashable?
            var transitionHintExpandedGroupId: AnyHashable?
            if let contentAnimation = contentAnimation {
                switch contentAnimation.type {
                case let .groupInstalled(groupId):
                    transitionHintInstalledGroupId = groupId
                case let .groupExpanded(groupId):
                    transitionHintExpandedGroupId = groupId
                default:
                    break
                }
            }
            
            for groupItems in itemLayout.visibleItems(for: effectiveVisibleBounds) {
                let itemGroup = component.itemGroups[groupItems.groupIndex]
                let itemGroupLayout = itemLayout.itemGroupLayouts[groupItems.groupIndex]
                
                var assignTopVisibleSubgroupId = false
                if topVisibleGroupId == nil && itemGroupLayout.frame.intersects(topVisibleDetectionBounds) {
                    topVisibleGroupId = groupItems.supergroupId
                    assignTopVisibleSubgroupId = true
                }
                
                var headerCentralContentWidth: CGFloat?
                var headerSizeUpdated = false
                if let title = itemGroup.title {
                    validGroupHeaderIds.insert(itemGroup.groupId)
                    let groupHeaderView: GroupHeaderLayer
                    var groupHeaderTransition = transition
                    if let current = self.visibleGroupHeaders[itemGroup.groupId] {
                        groupHeaderView = current
                    } else {
                        groupHeaderTransition = .immediate
                        let groupId = itemGroup.groupId
                        groupHeaderView = GroupHeaderLayer(
                            actionPressed: { [weak self] in
                                guard let strongSelf = self, let component = strongSelf.component else {
                                    return
                                }
                                component.inputInteractionHolder.inputInteraction?.addGroupAction(groupId, false)
                            },
                            performItemAction: { [weak self] item, view, rect, layer in
                                guard let strongSelf = self, let component = strongSelf.component else {
                                    return
                                }
                                component.inputInteractionHolder.inputInteraction?.performItemAction(groupId, item, view, rect, layer, false)
                            }
                        )
                        self.visibleGroupHeaders[itemGroup.groupId] = groupHeaderView
                        self.scrollView.addSubview(groupHeaderView)
                        self.mirrorContentScrollView.layer.addSublayer(groupHeaderView.tintContentLayer)
                    }
                    
                    var actionButtonTitle: String?
                    if case .detailed = itemLayout.layoutType, itemGroup.isFeatured {
                        actionButtonTitle = itemGroup.actionButtonTitle
                    }
                    
                    let hasTopSeparator = false
                    
                    let (groupHeaderSize, centralContentWidth) = groupHeaderView.update(
                        context: component.context,
                        theme: keyboardChildEnvironment.theme,
                        layoutType: itemLayout.layoutType,
                        hasTopSeparator: hasTopSeparator,
                        actionButtonTitle: actionButtonTitle,
                        title: title,
                        subtitle: itemGroup.subtitle,
                        isPremiumLocked: itemGroup.isPremiumLocked,
                        hasClear: itemGroup.hasClear,
                        embeddedItems: itemGroup.isEmbedded ? itemGroup.items : nil,
                        constrainedSize: CGSize(width: itemLayout.contentSize.width - itemLayout.headerInsets.left - itemLayout.headerInsets.right, height: itemGroupLayout.headerHeight),
                        insets: itemLayout.headerInsets,
                        cache: component.animationCache,
                        renderer: component.animationRenderer,
                        attemptSynchronousLoad: attemptSynchronousLoads
                    )
                    
                    if groupHeaderView.bounds.size != groupHeaderSize {
                        headerSizeUpdated = true
                    }
                    headerCentralContentWidth = centralContentWidth
                    
                    let groupHeaderFrame = CGRect(origin: CGPoint(x: floor((itemLayout.contentSize.width - groupHeaderSize.width) / 2.0), y: itemGroupLayout.frame.minY + 1.0), size: groupHeaderSize)
                    groupHeaderView.bounds = CGRect(origin: CGPoint(), size: groupHeaderFrame.size)
                    groupHeaderTransition.setPosition(view: groupHeaderView, position: CGPoint(x: groupHeaderFrame.midX, y: groupHeaderFrame.midY))
                }
                
                let groupBorderRadius: CGFloat = 16.0
                
                if itemGroup.isPremiumLocked && !itemGroup.isFeatured && !itemGroup.isEmbedded && !itemLayout.curveNearBounds {
                    validGroupBorderIds.insert(itemGroup.groupId)
                    let groupBorderLayer: GroupBorderLayer
                    var groupBorderTransition = transition
                    if let current = self.visibleGroupBorders[itemGroup.groupId] {
                        groupBorderLayer = current
                    } else {
                        groupBorderTransition = .immediate
                        groupBorderLayer = GroupBorderLayer()
                        self.visibleGroupBorders[itemGroup.groupId] = groupBorderLayer
                        self.scrollView.layer.insertSublayer(groupBorderLayer, at: 0)
                        self.mirrorContentScrollView.layer.addSublayer(groupBorderLayer.tintContainerLayer)
                        
                        groupBorderLayer.strokeColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.cgColor
                        groupBorderLayer.tintContainerLayer.strokeColor = UIColor.white.cgColor
                        groupBorderLayer.lineWidth = 1.6
                        groupBorderLayer.lineCap = .round
                        groupBorderLayer.fillColor = nil
                    }
                    
                    let groupBorderHorizontalInset: CGFloat = itemLayout.itemInsets.left - 4.0
                    let groupBorderVerticalTopOffset: CGFloat = 8.0
                    let groupBorderVerticalInset: CGFloat = 6.0
                    
                    let groupBorderFrame = CGRect(origin: CGPoint(x: groupBorderHorizontalInset, y: itemGroupLayout.frame.minY + groupBorderVerticalTopOffset), size: CGSize(width: itemLayout.width - groupBorderHorizontalInset * 2.0, height: itemGroupLayout.frame.size.height - groupBorderVerticalTopOffset + groupBorderVerticalInset))
                    
                    if groupBorderLayer.bounds.size != groupBorderFrame.size || headerSizeUpdated {
                        let headerWidth: CGFloat
                        if let headerCentralContentWidth = headerCentralContentWidth {
                            headerWidth = headerCentralContentWidth + 14.0
                        } else {
                            headerWidth = 0.0
                        }
                        let path = CGMutablePath()
                        let radius = groupBorderRadius
                        path.move(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0), y: 0.0))
                        path.addLine(to: CGPoint(x: radius, y: 0.0))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
                        path.addLine(to: CGPoint(x: 0.0, y: groupBorderFrame.height - radius))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: groupBorderFrame.height), tangent2End: CGPoint(x: radius, y: groupBorderFrame.height), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width - radius, y: groupBorderFrame.height))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height), tangent2End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height - radius), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width, y: radius))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: 0.0), tangent2End: CGPoint(x: groupBorderFrame.width - radius, y: 0.0), radius: radius)
                        path.addLine(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0) + headerWidth, y: 0.0))
                        
                        let pathLength = (2.0 * groupBorderFrame.width + 2.0 * groupBorderFrame.height - 8.0 * radius + 2.0 * .pi * radius) - headerWidth
                        
                        var numberOfDashes = Int(floor(pathLength / 6.0))
                        if numberOfDashes % 2 == 0 {
                            numberOfDashes -= 1
                        }
                        let wholeLength = 6.0 * CGFloat(numberOfDashes)
                        let remainingLength = pathLength - wholeLength
                        let dashSpace = remainingLength / CGFloat(numberOfDashes)
                        
                        groupBorderTransition.setShapeLayerPath(layer: groupBorderLayer, path: path)
                        groupBorderTransition.setShapeLayerLineDashPattern(layer: groupBorderLayer, pattern: [(5.0 + dashSpace) as NSNumber, (7.0 + dashSpace) as NSNumber])
                    }
                    groupBorderTransition.setFrame(layer: groupBorderLayer, frame: groupBorderFrame)
                }
                
                if (itemGroup.isPremiumLocked || itemGroup.isFeatured), !itemGroup.isEmbedded, case .compact = itemLayout.layoutType {
                    let groupPremiumButtonMeasuringFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - 50.0 + 1.0), size: CGSize(width: 100.0, height: 50.0))
                    
                    if effectiveVisibleBounds.intersects(groupPremiumButtonMeasuringFrame) {
                        validGroupPremiumButtonIds.insert(itemGroup.groupId)
                        
                        let groupPremiumButton: ComponentView<Empty>
                        var groupPremiumButtonTransition = transition
                        var animateButtonIn = false
                        if let current = self.visibleGroupPremiumButtons[itemGroup.groupId] {
                            groupPremiumButton = current
                        } else {
                            groupPremiumButtonTransition = .immediate
                            animateButtonIn = !transition.animation.isImmediate
                            groupPremiumButton = ComponentView<Empty>()
                            self.visibleGroupPremiumButtons[itemGroup.groupId] = groupPremiumButton
                        }
                        
                        let groupId = itemGroup.groupId
                        let isPremiumLocked = itemGroup.isPremiumLocked
                        
                        let title: String
                        let backgroundColor: UIColor
                        let backgroundColors: [UIColor]
                        let foregroundColor: UIColor
                        let animationName: String?
                        let gloss: Bool
                        if itemGroup.isPremiumLocked {
                            title = keyboardChildEnvironment.strings.EmojiInput_UnlockPack(itemGroup.title ?? "Emoji").string
                            backgroundColors = [
                                UIColor(rgb: 0x0077ff),
                                UIColor(rgb: 0x6b93ff),
                                UIColor(rgb: 0x8878ff),
                                UIColor(rgb: 0xe46ace)
                            ]
                            backgroundColor = backgroundColors[0]
                            foregroundColor = .white
                            animationName = "premium_unlock"
                            gloss = true
                        } else {
                            title = keyboardChildEnvironment.strings.EmojiInput_AddPack(itemGroup.title ?? "Emoji").string
                            backgroundColors = []
                            backgroundColor = keyboardChildEnvironment.theme.list.itemCheckColors.fillColor
                            foregroundColor = keyboardChildEnvironment.theme.list.itemCheckColors.foregroundColor
                            animationName = nil
                            gloss = false
                        }
                        
                        let groupPremiumButtonSize = groupPremiumButton.update(
                            transition: groupPremiumButtonTransition,
                            component: AnyComponent(SolidRoundedButtonComponent(
                                title: title,
                                theme: SolidRoundedButtonComponent.Theme(
                                    backgroundColor: backgroundColor,
                                    backgroundColors: backgroundColors,
                                    foregroundColor: foregroundColor
                                ),
                                font: .bold,
                                fontSize: 17.0,
                                height: 50.0,
                                cornerRadius: groupBorderRadius,
                                gloss: gloss,
                                animationName: animationName,
                                iconPosition: .right,
                                iconSpacing: 4.0,
                                action: { [weak self] in
                                    guard let strongSelf = self, let component = strongSelf.component else {
                                        return
                                    }
                                    component.inputInteractionHolder.inputInteraction?.addGroupAction(groupId, isPremiumLocked)
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: itemLayout.width - itemLayout.itemInsets.left - itemLayout.itemInsets.right, height: itemLayout.premiumButtonHeight)
                        )
                        let groupPremiumButtonFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - groupPremiumButtonSize.height + 1.0), size: groupPremiumButtonSize)
                        if let view = groupPremiumButton.view {
                            if view.superview == nil {
                                self.scrollView.addSubview(view)
                            }
                            
                            if animateButtonIn, !transition.animation.isImmediate {
                                if let previousItemPosition = previousItemPositions?[.groupActionButton(groupId: itemGroup.groupId)], transitionHintInstalledGroupId != itemGroup.groupId, transitionHintExpandedGroupId != itemGroup.groupId {
                                    groupPremiumButtonTransition = transition
                                    view.center = previousItemPosition
                                }
                            }
                            
                            groupPremiumButtonTransition.setFrame(view: view, frame: groupPremiumButtonFrame)
                            if animateButtonIn, !transition.animation.isImmediate {
                                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                transition.animateScale(view: view, from: 0.01, to: 1.0)
                            }
                        }
                    }
                }
                
                if !itemGroup.isEmbedded, let collapsedItemIndex = itemGroupLayout.collapsedItemIndex, let collapsedItemText = itemGroupLayout.collapsedItemText {
                    validGroupExpandActionButtons.insert(itemGroup.groupId)
                    let groupId = itemGroup.groupId
                    
                    var animateButtonIn = false
                    var groupExpandActionButtonTransition = transition
                    let groupExpandActionButton: GroupExpandActionButton
                    if let current = self.visibleGroupExpandActionButtons[itemGroup.groupId] {
                        groupExpandActionButton = current
                    } else {
                        groupExpandActionButtonTransition = .immediate
                        animateButtonIn = !transition.animation.isImmediate
                        groupExpandActionButton = GroupExpandActionButton(pressed: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.expandGroup(groupId: groupId)
                        })
                        self.visibleGroupExpandActionButtons[itemGroup.groupId] = groupExpandActionButton
                        self.scrollView.addSubview(groupExpandActionButton)
                        self.mirrorContentScrollView.layer.addSublayer(groupExpandActionButton.tintContainerLayer)
                    }
                    
                    if animateButtonIn, !transition.animation.isImmediate {
                        if let previousItemPosition = previousItemPositions?[.groupExpandButton(groupId: itemGroup.groupId)], transitionHintInstalledGroupId != itemGroup.groupId, transitionHintExpandedGroupId != itemGroup.groupId {
                            groupExpandActionButtonTransition = transition
                            groupExpandActionButton.center = previousItemPosition
                        }
                    }
                    
                    let baseItemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: collapsedItemIndex)
                    let buttonSize = groupExpandActionButton.update(theme: keyboardChildEnvironment.theme, title: collapsedItemText)
                    let buttonFrame = CGRect(origin: CGPoint(x: baseItemFrame.minX + floor((baseItemFrame.width - buttonSize.width) / 2.0), y: baseItemFrame.minY + floor((baseItemFrame.height - buttonSize.height) / 2.0)), size: buttonSize)
                    groupExpandActionButtonTransition.setFrame(view: groupExpandActionButton, frame: buttonFrame)
                }
                
                if !itemGroup.isEmbedded, let groupItemRange = groupItems.groupItems {
                    for index in groupItemRange.lowerBound ..< groupItemRange.upperBound {
                        let item = itemGroup.items[index]
                        
                        if assignTopVisibleSubgroupId {
                            if let subgroupId = item.subgroupId {
                                topVisibleSubgroupId = AnyHashable(subgroupId)
                            }
                        }
                        
                        let itemId = ItemLayer.Key(
                            groupId: itemGroup.groupId,
                            itemId: item.content.id
                        )
                        validIds.insert(itemId)
                        
                        let itemDimensions: CGSize = item.animationData?.dimensions ?? CGSize(width: 512.0, height: 512.0)
                        
                        let itemNativeFitSize = itemDimensions.aspectFitted(CGSize(width: itemLayout.nativeItemSize, height: itemLayout.nativeItemSize))
                        let itemVisibleFitSize = itemDimensions.aspectFitted(CGSize(width: itemLayout.visibleItemSize, height: itemLayout.visibleItemSize))
                        let itemPlaybackSize = itemDimensions.aspectFitted(CGSize(width: itemLayout.playbackItemSize, height: itemLayout.playbackItemSize))
                        
                        var animateItemIn = false
                        var updateItemLayerPlaceholder = false
                        var itemTransition = transition
                        let itemLayer: ItemLayer
                        if let current = self.visibleItemLayers[itemId] {
                            itemLayer = current
                        } else {
                            updateItemLayerPlaceholder = true
                            itemTransition = .immediate
                            animateItemIn = !transition.animation.isImmediate
                            
                            let pointSize: CGSize
                            if case .staticEmoji = item.content {
                                pointSize = itemVisibleFitSize
                            } else {
                                pointSize = itemPlaybackSize
                            }
                            
                            let placeholderColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1)
                            itemLayer = ItemLayer(
                                item: item,
                                context: component.context,
                                attemptSynchronousLoad: attemptSynchronousLoads,
                                content: item.content,
                                cache: component.animationCache,
                                renderer: component.animationRenderer,
                                placeholderColor: placeholderColor,
                                blurredBadgeColor: keyboardChildEnvironment.theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(0.5),
                                accentIconColor: keyboardChildEnvironment.theme.list.itemAccentColor,
                                pointSize: pointSize,
                                onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder, duration in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if displayPlaceholder, let animationData = item.animationData {
                                        if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                            let placeholderView: ItemPlaceholderView
                                            if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
                                                placeholderView = current
                                            } else {
                                                placeholderView = ItemPlaceholderView(
                                                    context: component.context,
                                                    dimensions: animationData.dimensions,
                                                    immediateThumbnailData: animationData.immediateThumbnailData,
                                                    shimmerView: strongSelf.shimmerHostView,
                                                    color: placeholderColor,
                                                    size: itemNativeFitSize
                                                )
                                                strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
                                                strongSelf.placeholdersContainerView.addSubview(placeholderView)
                                            }
                                            placeholderView.frame = itemLayer.frame
                                            placeholderView.update(size: placeholderView.bounds.size)
                                            
                                            strongSelf.updateShimmerIfNeeded()
                                        }
                                    } else {
                                        if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
                                            strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
                                            
                                            if duration > 0.0 {
                                                placeholderView.layer.opacity = 0.0
                                                placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    placeholderView?.removeFromSuperview()
                                                    strongSelf.updateShimmerIfNeeded()
                                                })
                                            } else {
                                                placeholderView.removeFromSuperview()
                                                strongSelf.updateShimmerIfNeeded()
                                            }
                                        }
                                    }
                                }
                            )
                            
                            self.scrollView.layer.addSublayer(itemLayer)
                            self.visibleItemLayers[itemId] = itemLayer
                        }
                        
                        var itemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: index)
                        let baseItemFrame = itemFrame
                        
                        itemFrame.origin.x += floor((itemFrame.width - itemVisibleFitSize.width) / 2.0)
                        itemFrame.origin.y += floor((itemFrame.height - itemVisibleFitSize.height) / 2.0)
                        itemFrame.size = itemVisibleFitSize
                        
                        let itemBounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                        itemTransition.setBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                        
                        if animateItemIn, !transition.animation.isImmediate {
                            if let previousItemPosition = previousItemPositions?[.item(id: itemId)], transitionHintInstalledGroupId != itemId.groupId, transitionHintExpandedGroupId != itemId.groupId {
                                itemTransition = transition
                                itemLayer.position = previousItemPosition
                            } else {
                                if transitionHintInstalledGroupId == itemId.groupId || transitionHintExpandedGroupId == itemId.groupId {
                                    itemLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                                } else {
                                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                }
                            }
                        }
                        
                        let itemPosition = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                        itemTransition.setPosition(layer: itemLayer, position: itemPosition)
                        
                        var badge: ItemLayer.Badge?
                        if itemGroup.displayPremiumBadges, let file = item.itemFile, file.isPremiumSticker {
                            badge = .premium
                        }
                        itemLayer.update(transition: transition, size: itemFrame.size, badge: badge, blurredBadgeColor: UIColor(white: 0.0, alpha: 0.1), blurredBadgeBackgroundColor: keyboardChildEnvironment.theme.list.plainBackgroundColor)
                        
                        if let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                            if placeholderView.layer.position != itemPosition || placeholderView.layer.bounds != itemBounds {
                                itemTransition.setFrame(view: placeholderView, frame: itemFrame)
                                placeholderView.update(size: itemFrame.size)
                            }
                        } else if updateItemLayerPlaceholder {
                            if itemLayer.displayPlaceholder {
                                itemLayer.onUpdateDisplayPlaceholder(true, 0.0)
                            }
                        }
                        
                        if let itemFile = item.itemFile, component.selectedItems.contains(itemFile.fileId) {
                            let itemSelectionLayer: ItemSelectionLayer
                            if let current = self.visibleItemSelectionLayers[itemId] {
                                itemSelectionLayer = current
                            } else {
                                itemSelectionLayer = ItemSelectionLayer()
                                itemSelectionLayer.cornerRadius = 8.0
                                itemSelectionLayer.tintContainerLayer.cornerRadius = 8.0
                                self.scrollView.layer.insertSublayer(itemSelectionLayer, below: itemLayer)
                                self.mirrorContentScrollView.layer.addSublayer(itemSelectionLayer.tintContainerLayer)
                                self.visibleItemSelectionLayers[itemId] = itemSelectionLayer
                            }
                            
                            itemSelectionLayer.backgroundColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.cgColor
                            itemSelectionLayer.tintContainerLayer.backgroundColor = UIColor.white.cgColor
                            itemSelectionLayer.frame = baseItemFrame
                        }
                        
                        if animateItemIn, !transition.animation.isImmediate, let contentAnimation = contentAnimation, case .groupExpanded(id: itemGroup.groupId) = contentAnimation.type, let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                            placeholderView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                            placeholderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                        
                        itemLayer.isVisibleForAnimations = true
                    }
                }
            }

            var removedPlaceholerViews = false
            var removedIds: [ItemLayer.Key] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    
                    let itemSelectionLayer = self.visibleItemSelectionLayers[id]
                    
                    if !transition.animation.isImmediate {
                        if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id.groupId {
                            if let previousAbsolutePosition = previousAbsoluteItemPositions?[.item(id: id)] {
                                itemLayer.position = self.convert(previousAbsolutePosition, to: self.scrollView)
                                transition.setPosition(layer: itemLayer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            }
                            
                            itemLayer.opacity = 0.0
                            itemLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                            itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemLayer] _ in
                                itemLayer?.removeFromSuperlayer()
                            })
                            
                            if let itemSelectionLayer = itemSelectionLayer {
                                itemSelectionLayer.opacity = 0.0
                                itemSelectionLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                                itemSelectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemSelectionLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                })
                                
                                let itemSelectionTintContainerLayer = itemSelectionLayer.tintContainerLayer
                                itemSelectionTintContainerLayer.opacity = 0.0
                                itemSelectionTintContainerLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                                itemSelectionTintContainerLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemSelectionTintContainerLayer] _ in
                                    itemSelectionTintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        } else if let position = updatedItemPositions?[.item(id: id)], transitionHintInstalledGroupId != id.groupId {
                            transition.setPosition(layer: itemLayer, position: position, completion: { [weak itemLayer] _ in
                                itemLayer?.removeFromSuperlayer()
                            })
                            if let itemSelectionLayer = itemSelectionLayer {
                                transition.setPosition(layer: itemSelectionLayer, position: position, completion: { [weak itemSelectionLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                })
                            }
                        } else {
                            itemLayer.opacity = 0.0
                            itemLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                            itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemLayer] _ in
                                itemLayer?.removeFromSuperlayer()
                            })
                            
                            if let itemSelectionLayer = itemSelectionLayer {
                                itemSelectionLayer.opacity = 0.0
                                itemSelectionLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                                itemSelectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemSelectionLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                })
                                
                                let itemSelectionTintContainerLayer = itemSelectionLayer.tintContainerLayer
                                itemSelectionTintContainerLayer.opacity = 0.0
                                itemSelectionTintContainerLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                                itemSelectionTintContainerLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemSelectionTintContainerLayer] _ in
                                    itemSelectionTintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        }
                    } else {
                        itemLayer.removeFromSuperlayer()
                        if let itemSelectionLayer = itemSelectionLayer {
                            itemSelectionLayer.removeFromSuperlayer()
                        }
                    }
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
                self.visibleItemSelectionLayers.removeValue(forKey: id)
                
                if let view = self.visibleItemPlaceholderViews.removeValue(forKey: id) {
                    view.removeFromSuperview()
                    removedPlaceholerViews = true
                }
            }
            var removedItemSelectionLayerIds: [ItemLayer.Key] = []
            for (id, itemSelectionLayer) in self.visibleItemSelectionLayers {
                var fileId: MediaId?
                switch id.itemId {
                case let .animation(id):
                    switch id {
                    case let .file(fileIdValue):
                        fileId = fileIdValue
                    default:
                        break
                    }
                default:
                    break
                }
                if let fileId = fileId, component.selectedItems.contains(fileId) {
                } else {
                    itemSelectionLayer.removeFromSuperlayer()
                    removedItemSelectionLayerIds.append(id)
                    
                }
            }
            for id in removedItemSelectionLayerIds {
                self.visibleItemSelectionLayers.removeValue(forKey: id)
            }
            
            var removedGroupHeaderIds: [AnyHashable] = []
            for (id, groupHeaderLayer) in self.visibleGroupHeaders {
                if !validGroupHeaderIds.contains(id) {
                    removedGroupHeaderIds.append(id)
                    
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[VisualItemKey.header(groupId: id)] {
                            groupHeaderLayer.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            transition.setPosition(layer: groupHeaderLayer.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        let tintContentLayer = groupHeaderLayer.tintContentLayer
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.header(groupId: id)] {
                            transition.setPosition(layer: groupHeaderLayer.layer, position: position, completion: { [weak groupHeaderLayer, weak tintContentLayer] _ in
                                groupHeaderLayer?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        } else {
                            groupHeaderLayer.alpha = 0.0
                            groupHeaderLayer.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            groupHeaderLayer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak groupHeaderLayer, weak tintContentLayer] _ in
                                groupHeaderLayer?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        }
                    } else {
                        groupHeaderLayer.removeFromSuperview()
                        groupHeaderLayer.tintContentLayer.removeFromSuperlayer()
                    }
                }
            }
            for id in removedGroupHeaderIds {
                self.visibleGroupHeaders.removeValue(forKey: id)
            }
            
            var removedGroupBorderIds: [AnyHashable] = []
            for (id, groupBorderLayer) in self.visibleGroupBorders {
                if !validGroupBorderIds.contains(id) {
                    removedGroupBorderIds.append(id)
                    groupBorderLayer.removeFromSuperlayer()
                    groupBorderLayer.tintContainerLayer.removeFromSuperlayer()
                }
            }
            for id in removedGroupBorderIds {
                self.visibleGroupBorders.removeValue(forKey: id)
            }
            
            var removedGroupPremiumButtonIds: [AnyHashable] = []
            for (id, groupPremiumButton) in self.visibleGroupPremiumButtons {
                if !validGroupPremiumButtonIds.contains(id), let buttonView = groupPremiumButton.view {
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if let position = updatedItemPositions?[.groupActionButton(groupId: id)], position.y > buttonView.center.y {
                        } else if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[VisualItemKey.groupActionButton(groupId: id)] {
                            buttonView.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            transition.setPosition(layer: buttonView.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.groupActionButton(groupId: id)] {
                            buttonView.alpha = 0.0
                            buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak buttonView] _ in
                                buttonView?.removeFromSuperview()
                            })
                            transition.setPosition(layer: buttonView.layer, position: position)
                        } else {
                            buttonView.alpha = 0.0
                            if transitionHintExpandedGroupId == id || hintDisappearingGroupFrame?.groupId == id {
                                buttonView.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            }
                            buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak buttonView] _ in
                                buttonView?.removeFromSuperview()
                            })
                        }
                    } else {
                        removedGroupPremiumButtonIds.append(id)
                        buttonView.removeFromSuperview()
                    }
                }
            }
            for id in removedGroupPremiumButtonIds {
                self.visibleGroupPremiumButtons.removeValue(forKey: id)
            }
            
            var removedGroupExpandActionButtonIds: [AnyHashable] = []
            for (id, button) in self.visibleGroupExpandActionButtons {
                if !validGroupExpandActionButtons.contains(id) {
                    removedGroupExpandActionButtonIds.append(id)
                    
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if self.visibleGroupHeaders[id] == nil, let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[.groupExpandButton(groupId: id)] {
                            button.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            button.tintContainerLayer.position = button.center
                            transition.setPosition(layer: button.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        let tintContainerLayer = button.tintContainerLayer
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.groupExpandButton(groupId: id)] {
                            transition.setPosition(layer: button.layer, position: position, completion: { [weak button, weak tintContainerLayer] _ in
                                button?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        } else {
                            button.alpha = 0.0
                            if transitionHintExpandedGroupId == id || hintDisappearingGroupFrame?.groupId == id {
                                button.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            }
                            button.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak button, weak tintContainerLayer] _ in
                                button?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                    } else {
                        button.removeFromSuperview()
                        button.tintContainerLayer.removeFromSuperlayer()
                    }
                }
            }
            for id in removedGroupExpandActionButtonIds {
                self.visibleGroupExpandActionButtons.removeValue(forKey: id)
            }
            
            if removedPlaceholerViews {
                self.updateShimmerIfNeeded()
            }
            
            if itemLayout.curveNearBounds {
            } else {
                if let scrollGradientLayer = self.scrollGradientLayer {
                    self.scrollGradientLayer = nil
                    scrollGradientLayer.removeFromSuperlayer()
                }
            }
            
            if let topVisibleGroupId = topVisibleGroupId {
                self.activeItemUpdated?.invoke((topVisibleGroupId, topVisibleSubgroupId, .immediate))
            }
        }
        
        private func updateShimmerIfNeeded() {
            if let standaloneShimmerEffect = self.standaloneShimmerEffect, let shimmerHostView = self.shimmerHostView {
                if self.placeholdersContainerView.subviews.isEmpty {
                    standaloneShimmerEffect.layer = nil
                } else {
                    standaloneShimmerEffect.layer = shimmerHostView.layer
                }
            }
        }
        
        private func expandGroup(groupId: AnyHashable) {
            self.expandedGroupIds.insert(groupId)
            
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(ContentAnimation(type: .groupExpanded(id: groupId))))
        }
        
        public func pagerUpdateBackground(backgroundFrame: CGRect, transition: Transition) {
            guard let component = self.component, let keyboardChildEnvironment = self.keyboardChildEnvironment else {
                return
            }
            
            if let externalBackground = component.inputInteractionHolder.inputInteraction?.externalBackground, let effectContainerView = externalBackground.effectContainerView {
                let mirrorContentClippingView: UIView
                if let current = self.mirrorContentClippingView {
                    mirrorContentClippingView = current
                } else {
                    mirrorContentClippingView = UIView()
                    mirrorContentClippingView.clipsToBounds = true
                    self.mirrorContentClippingView = mirrorContentClippingView
                    
                    if let mirrorContentWarpView = self.mirrorContentWarpView {
                        mirrorContentClippingView.addSubview(mirrorContentWarpView)
                    } else {
                        mirrorContentClippingView.addSubview(self.mirrorContentScrollView)
                    }
                }
                
                let clippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 42.0), size: CGSize(width: backgroundFrame.width, height: backgroundFrame.height))
                transition.setPosition(view: mirrorContentClippingView, position: clippingFrame.center)
                transition.setBounds(view: mirrorContentClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: 42.0), size: clippingFrame.size))
                
                if mirrorContentClippingView.superview !== effectContainerView {
                    effectContainerView.addSubview(mirrorContentClippingView)
                }
            } else if keyboardChildEnvironment.theme.overallDarkAppearance || component.warpContentsOnEdges {
                if let vibrancyEffectView = self.vibrancyEffectView {
                    self.vibrancyEffectView = nil
                    vibrancyEffectView.removeFromSuperview()
                }
            } else {
                if self.vibrancyEffectView == nil {
                    let style: UIBlurEffect.Style
                    style = .extraLight
                    let blurEffect = UIBlurEffect(style: style)
                    let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
                    let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
                    self.vibrancyEffectView = vibrancyEffectView
                    self.backgroundView.addSubview(vibrancyEffectView)
                    vibrancyEffectView.contentView.addSubview(self.mirrorContentScrollView)
                }
            }
            
            if component.warpContentsOnEdges {
                self.backgroundView.isHidden = true
            } else {
                self.backgroundView.isHidden = false
            }
            
            self.backgroundView.updateColor(color: keyboardChildEnvironment.theme.chat.inputMediaPanel.backgroundColor, enableBlur: true, forceKeepBlur: false, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            if let vibrancyEffectView = self.vibrancyEffectView {
                transition.setFrame(view: vibrancyEffectView, frame: CGRect(origin: CGPoint(x: 0.0, y: -backgroundFrame.minY), size: CGSize(width: backgroundFrame.width, height: backgroundFrame.height + backgroundFrame.minY)))
            }
        }
        
        func update(component: EmojiPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            component.inputInteractionHolder.inputInteraction?.peekBehavior?.setGestureRecognizerEnabled(view: self, isEnabled: component.itemLayoutType == .detailed, itemAtPoint: { [weak self] point in
                guard let strongSelf = self else {
                    return nil
                }
                guard let item = strongSelf.item(atPoint: point), let itemLayer = strongSelf.visibleItemLayers[item.1], let file = item.0.itemFile else {
                    return nil
                }
                if itemLayer.displayPlaceholder {
                    return nil
                }
                return (itemLayer, file)
            })
            
            let keyboardChildEnvironment = environment[EntityKeyboardChildEnvironment.self].value
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            
            self.keyboardChildEnvironment = keyboardChildEnvironment
            self.activeItemUpdated = keyboardChildEnvironment.getContentActiveItemUpdated(component.id)
            
            self.pagerEnvironment = pagerEnvironment
            
            self.updateIsWarpEnabled(isEnabled: component.warpContentsOnEdges)
            
            if let longTapRecognizer = self.longTapRecognizer {
                longTapRecognizer.isEnabled = component.enableLongPress
            }
            
            if let shimmerHostView = self.shimmerHostView {
                transition.setFrame(view: shimmerHostView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            if let standaloneShimmerEffect = self.standaloneShimmerEffect {
                let shimmerBackgroundColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
                let shimmerForegroundColor = keyboardChildEnvironment.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
                standaloneShimmerEffect.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
            }
            
            var previousItemPositions: [VisualItemKey: CGPoint]?
            
            var calculateUpdatedItemPositions = false
            var updatedItemPositions: [VisualItemKey: CGPoint]?
            
            let contentAnimation = transition.userData(ContentAnimation.self)
            
            var transitionHintInstalledGroupId: AnyHashable?
            var transitionHintExpandedGroupId: AnyHashable?
            if let contentAnimation = contentAnimation {
                switch contentAnimation.type {
                case let .groupInstalled(groupId):
                    transitionHintInstalledGroupId = groupId
                case let .groupExpanded(groupId):
                    transitionHintExpandedGroupId = groupId
                default:
                    break
                }
            }
            let _ = transitionHintExpandedGroupId
            
            var hintDisappearingGroupFrame: (groupId: AnyHashable, frame: CGRect)?
            var previousAbsoluteItemPositions: [VisualItemKey: CGPoint] = [:]
            
            var anchorItems: [ItemLayer.Key: CGRect] = [:]
            if let previousComponent = previousComponent, let previousItemLayout = self.itemLayout, previousComponent.itemGroups != component.itemGroups {
                if !transition.animation.isImmediate {
                    var previousItemPositionsValue: [VisualItemKey: CGPoint] = [:]
                    for groupIndex in 0 ..< previousComponent.itemGroups.count {
                        let itemGroup = previousComponent.itemGroups[groupIndex]
                        for itemIndex in 0 ..< itemGroup.items.count {
                            let item = itemGroup.items[itemIndex]
                            let itemKey: ItemLayer.Key
                            itemKey = ItemLayer.Key(
                                groupId: itemGroup.groupId,
                                itemId: item.content.id
                            )
                            let itemFrame = previousItemLayout.frame(groupIndex: groupIndex, itemIndex: itemIndex)
                            previousItemPositionsValue[.item(id: itemKey)] = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                        }
                    }
                    previousItemPositions = previousItemPositionsValue
                    calculateUpdatedItemPositions = true
                }
                
                let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
                let topVisibleDetectionBounds = effectiveVisibleBounds
                for (key, itemLayer) in self.visibleItemLayers {
                    if !topVisibleDetectionBounds.intersects(itemLayer.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(itemLayer.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == key.groupId {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (key.groupId, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.item(id: key)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    } else {
                        anchorItems[key] = absoluteFrame
                    }
                }
                
                for (id, groupHeader) in self.visibleGroupHeaders {
                    if !topVisibleDetectionBounds.intersects(groupHeader.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(groupHeader.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.header(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
                
                for (id, button) in self.visibleGroupExpandActionButtons {
                    if !topVisibleDetectionBounds.intersects(button.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(button.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.groupExpandButton(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
                
                for (id, button) in self.visibleGroupPremiumButtons {
                    guard let buttonView = button.view else {
                        continue
                    }
                    if !topVisibleDetectionBounds.intersects(buttonView.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(buttonView.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.groupActionButton(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
            }
            
            var itemGroups: [ItemGroupDescription] = []
            for itemGroup in component.itemGroups {
                itemGroups.append(ItemGroupDescription(
                    supergroupId: itemGroup.supergroupId,
                    groupId: itemGroup.groupId,
                    hasTitle: itemGroup.title != nil,
                    isPremiumLocked: itemGroup.isPremiumLocked,
                    isFeatured: itemGroup.isFeatured,
                    itemCount: itemGroup.items.count,
                    isEmbedded: itemGroup.isEmbedded,
                    isExpandable: itemGroup.isExpandable
                ))
            }
            
            var itemTransition = transition
            
            let itemLayout = ItemLayout(
                layoutType: component.itemLayoutType,
                width: availableSize.width,
                containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top + 9.0, left: pagerEnvironment.containerInsets.left, bottom: 9.0 + pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right),
                itemGroups: itemGroups,
                expandedGroupIds: self.expandedGroupIds,
                curveNearBounds: component.warpContentsOnEdges,
                customLayout: component.inputInteractionHolder.inputInteraction?.customLayout
            )
            if let previousItemLayout = self.itemLayout {
                if previousItemLayout.width != itemLayout.width {
                    itemTransition = .immediate
                } else if transition.userData(ContentAnimation.self) == nil {
                    itemTransition = .immediate
                }
            } else {
                itemTransition = .immediate
            }
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            transition.setPosition(view: self.scrollView, position: CGPoint())
            let previousSize = self.scrollView.bounds.size
            self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: availableSize)
            
            let warpHeight: CGFloat = 50.0
            if let warpView = self.warpView {
                transition.setFrame(view: warpView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize))
                warpView.update(size: CGSize(width: availableSize.width, height: availableSize.height), topInset: pagerEnvironment.containerInsets.top, warpHeight: warpHeight, theme: keyboardChildEnvironment.theme, transition: transition)
            }
            if let mirrorContentWarpView = self.mirrorContentWarpView {
                transition.setFrame(view: mirrorContentWarpView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize))
                mirrorContentWarpView.update(size: CGSize(width: availableSize.width, height: availableSize.height), topInset: pagerEnvironment.containerInsets.top, warpHeight: warpHeight, theme: keyboardChildEnvironment.theme, transition: transition)
            }
            
            if availableSize.height > previousSize.height || transition.animation.isImmediate {
                self.boundsChangeTrackerLayer.removeAllAnimations()
                self.boundsChangeTrackerLayer.bounds = self.scrollView.bounds
                self.effectiveVisibleSize = self.scrollView.bounds.size
            } else {
                self.effectiveVisibleSize = CGSize(width: availableSize.width, height: max(self.effectiveVisibleSize.height, availableSize.height))
                transition.setBounds(layer: self.boundsChangeTrackerLayer, bounds: self.scrollView.bounds, completion: { [weak self] completed in
                    guard let strongSelf = self else {
                        return
                    }
                    let effectiveVisibleSize = strongSelf.scrollView.bounds.size
                    if strongSelf.effectiveVisibleSize != effectiveVisibleSize {
                        strongSelf.effectiveVisibleSize = effectiveVisibleSize
                        strongSelf.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false, previousItemPositions: nil, updatedItemPositions: nil)
                    }
                })
            }
            
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            var scrollIndicatorInsets = pagerEnvironment.containerInsets
            if self.warpView != nil {
                scrollIndicatorInsets.bottom += 20.0
            }
            if self.scrollView.scrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: scrollView.isDragging || scrollView.isDecelerating)
            
            var animatedScrollOffset: CGFloat = 0.0
            if !anchorItems.isEmpty {
                let sortedAnchorItems: [(ItemLayer.Key, CGRect)] = anchorItems.sorted(by: { lhs, rhs in
                    if lhs.value.minY != rhs.value.minY {
                        return lhs.value.minY < rhs.value.minY
                    } else {
                        return lhs.value.minX < rhs.value.minX
                    }
                })
                
                outer: for i in 0 ..< component.itemGroups.count {
                    for anchorItem in sortedAnchorItems {
                        if component.itemGroups[i].groupId != anchorItem.0.groupId {
                            continue
                        }
                        for j in 0 ..< component.itemGroups[i].items.count {
                            let itemKey: ItemLayer.Key
                            itemKey = ItemLayer.Key(
                                groupId: component.itemGroups[i].groupId,
                                itemId: component.itemGroups[i].items[j].content.id
                            )
                            
                            if itemKey == anchorItem.0 {
                                let itemFrame = itemLayout.frame(groupIndex: i, itemIndex: j)
                                
                                var contentOffsetY = itemFrame.minY - anchorItem.1.minY
                                if contentOffsetY > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                                    contentOffsetY = self.scrollView.contentSize.height - self.scrollView.bounds.height
                                }
                                if contentOffsetY < 0.0 {
                                    contentOffsetY = 0.0
                                }
                                
                                let previousBounds = self.scrollView.bounds
                                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffsetY), animated: false)
                                let scrollOffset = previousBounds.minY - contentOffsetY
                                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: scrollOffset), to: CGPoint(), additive: true)
                                animatedScrollOffset = scrollOffset
                                
                                break outer
                            }
                        }
                    }
                }
            }
            
            self.ignoreScrolling = false
            
            if calculateUpdatedItemPositions {
                var updatedItemPositionsValue: [VisualItemKey: CGPoint] = [:]
                for groupIndex in 0 ..< component.itemGroups.count {
                    let itemGroup = component.itemGroups[groupIndex]
                    let itemGroupLayout = itemLayout.itemGroupLayouts[groupIndex]
                    for itemIndex in 0 ..< itemGroup.items.count {
                        let item = itemGroup.items[itemIndex]
                        let itemKey: ItemLayer.Key
                        itemKey = ItemLayer.Key(
                            groupId: itemGroup.groupId,
                            itemId: item.content.id
                        )
                        
                        let itemFrame = itemLayout.frame(groupIndex: groupIndex, itemIndex: itemIndex)
                        updatedItemPositionsValue[.item(id: itemKey)] = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    }
                    
                    let groupPremiumButtonFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - itemLayout.premiumButtonHeight + 1.0), size: CGSize(width: itemLayout.width - itemLayout.itemInsets.left - itemLayout.itemInsets.right, height: itemLayout.premiumButtonHeight))
                    updatedItemPositionsValue[.groupActionButton(groupId: itemGroup.groupId)] = CGPoint(x: groupPremiumButtonFrame.midX, y: groupPremiumButtonFrame.midY)
                }
                updatedItemPositions = updatedItemPositionsValue
            }
            
            if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, self.scrollView.convert(hintDisappearingGroupFrameValue.frame, from: self))
            }
            
            for (id, position) in previousAbsoluteItemPositions {
                previousAbsoluteItemPositions[id] = position.offsetBy(dx: 0.0, dy: animatedScrollOffset)
            }
            
            self.updateVisibleItems(transition: itemTransition, attemptSynchronousLoads: !(scrollView.isDragging || scrollView.isDecelerating), previousItemPositions: previousItemPositions, previousAbsoluteItemPositions: previousAbsoluteItemPositions, updatedItemPositions: updatedItemPositions, hintDisappearingGroupFrame: hintDisappearingGroupFrame)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
    
    private static func hasPremium(context: AccountContext, chatPeerId: EnginePeer.Id?, premiumIfSavedMessages: Bool) -> Signal<Bool, NoError> {
        let hasPremium: Signal<Bool, NoError>
        if premiumIfSavedMessages, let chatPeerId = chatPeerId, chatPeerId == context.account.peerId {
            hasPremium = .single(true)
        } else {
            hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged
        }
        return hasPremium
    }
    
    public static func emojiInputData(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, isStandalone: Bool, isStatusSelection: Bool, isReactionSelection: Bool, isQuickReactionSelection: Bool = false, topReactionItems: [AvailableReactions.Reaction], areUnicodeEmojiEnabled: Bool, areCustomEmojiEnabled: Bool, chatPeerId: EnginePeer.Id?, selectedItems: Set<MediaId> = Set()) -> Signal<EmojiPagerContentComponent, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        
        var orderedItemListCollectionIds: [Int32] = []
        
        orderedItemListCollectionIds.append(Namespaces.OrderedItemList.LocalRecentEmoji)
        
        if isStatusSelection {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedStatusEmoji)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentStatusEmoji)
        } else if isReactionSelection {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudTopReactions)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentReactions)
        }
        
        let availableReactions: Signal<AvailableReactions?, NoError>
        if isReactionSelection {
            availableReactions = context.engine.stickers.availableReactions()
        } else {
            availableReactions = .single(nil)
        }
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
            hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: true),
            context.account.viewTracker.featuredEmojiPacks(),
            availableReactions
        )
        |> map { view, hasPremium, featuredEmojiPacks, availableReactions -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String?
                var subtitle: String?
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var isExpandable: Bool
                var isClearable: Bool
                var headerItem: EntityKeyboardAnimationData?
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var recentEmoji: OrderedItemListView?
            var featuredStatusEmoji: OrderedItemListView?
            var recentStatusEmoji: OrderedItemListView?
            var topReactions: OrderedItemListView?
            var recentReactions: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.LocalRecentEmoji {
                    recentEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedStatusEmoji {
                    featuredStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStatusEmoji {
                    recentStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentReactions {
                    recentReactions = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudTopReactions {
                    topReactions = orderedView
                }
            }
            
            if isStatusSelection {
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: nil,
                    content: .icon(.premiumStar),
                    itemFile: nil,
                    subgroupId: nil
                )
                
                let groupId = "recent"
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: true, isClearable: false, headerItem: nil, items: [resultItem]))
                }
                
                var existingIds = Set<MediaId>()
                if let recentStatusEmoji = recentStatusEmoji {
                    for item in recentStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
                if let featuredStatusEmoji = featuredStatusEmoji {
                    for item in featuredStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
            } else if isReactionSelection {
                var existingIds = Set<MessageReaction.Reaction>()
                
                var topReactionItems = topReactionItems
                if topReactionItems.isEmpty {
                    if let topReactions = topReactions {
                        for item in topReactions.items {
                            guard let topReaction = item.contents.get(RecentReactionItem.self) else {
                                continue
                            }
                            
                            switch topReaction.content {
                            case let .builtin(value):
                                if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(value) }) {
                                    topReactionItems.append(reaction)
                                } else {
                                    continue
                                }
                            case let .custom(file):
                                topReactionItems.append(AvailableReactions.Reaction(
                                    isEnabled: true,
                                    isPremium: false,
                                    value: .custom(file.fileId.id),
                                    title: "",
                                    staticIcon: file,
                                    appearAnimation: file,
                                    selectAnimation: file,
                                    activateAnimation: file,
                                    effectAnimation: file,
                                    aroundAnimation: file,
                                    centerAnimation: file
                                ))
                            }
                        }
                    }
                }
                
                for reactionItem in topReactionItems {
                    if existingIds.contains(reactionItem.value) {
                        continue
                    }
                    existingIds.insert(reactionItem.value)
                    
                    let animationFile = reactionItem.selectAnimation
                    let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: animationFile,
                        subgroupId: nil
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                        
                        if itemGroups[groupIndex].items.count >= 8 * 2 {
                            break
                        }
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: false, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
                if hasPremium {
                    var hasRecent = false
                    if let recentReactions = recentReactions, !recentReactions.items.isEmpty {
                        hasRecent = true
                    }
                    
                    let maxRecentLineCount: Int
                    #if DEBUG
                    maxRecentLineCount = 4
                    #else
                    maxRecentLineCount = 10
                    #endif
                    
                    //TODO:localize
                    let popularTitle = hasRecent ? "Recently Used" : "Popular"
                    
                    if let availableReactions = availableReactions {
                        for reactionItem in availableReactions.reactions {
                            if !reactionItem.isEnabled {
                                continue
                            }
                            if existingIds.contains(reactionItem.value) {
                                continue
                            }
                            existingIds.insert(reactionItem.value)
                            
                            let animationFile = reactionItem.selectAnimation
                            let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: animationFile,
                                subgroupId: nil
                            )
                            
                            let groupId = "popular"
                            if let groupIndex = itemGroupIndexById[groupId] {
                                itemGroups[groupIndex].items.append(resultItem)
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: popularTitle, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: false, isClearable: hasRecent && !isQuickReactionSelection, headerItem: nil, items: [resultItem]))
                            }
                        }
                    }
                    
                    if let recentReactions = recentReactions {
                        var popularInsertIndex = 0
                        for item in recentReactions.items {
                            guard let item = item.contents.get(RecentReactionItem.self) else {
                                continue
                            }
                            
                            let animationFile: TelegramMediaFile
                            switch item.content {
                            case let .builtin(value):
                                if existingIds.contains(.builtin(value)) {
                                    continue
                                }
                                existingIds.insert(.builtin(value))
                                if let availableReactions = availableReactions, let availableReaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                                    if let centerAnimation = availableReaction.centerAnimation {
                                        animationFile = centerAnimation
                                    } else {
                                        continue
                                    }
                                } else {
                                    continue
                                }
                            case let .custom(file):
                                if existingIds.contains(.custom(file.fileId.id)) {
                                    continue
                                }
                                existingIds.insert(.custom(file.fileId.id))
                                animationFile = file
                            }
                            
                            let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: animationFile,
                                subgroupId: nil
                            )
                            
                            let groupId = "popular"
                            if let groupIndex = itemGroupIndexById[groupId] {
                                if itemGroups[groupIndex].items.count + 1 >= maxRecentLineCount * 8 {
                                    break
                                }
                                
                                itemGroups[groupIndex].items.insert(resultItem, at: popularInsertIndex)
                                popularInsertIndex += 1
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: popularTitle, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: false, isClearable: hasRecent && !isQuickReactionSelection, headerItem: nil, items: [resultItem]))
                            }
                        }
                    }
                }
            }
            
            if let recentEmoji = recentEmoji, !isReactionSelection, !isStatusSelection {
                for item in recentEmoji.items {
                    guard let item = item.contents.get(RecentEmojiItem.self) else {
                        continue
                    }
                    
                    if case let .file(file) = item.content, isPremiumDisabled, file.isPremiumEmoji {
                        continue
                    }
                    
                    if !areCustomEmojiEnabled, case .file = item.content {
                        continue
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    switch item.content {
                    case let .file(file):
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil
                        )
                    case let .text(text):
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: nil,
                            content: .staticEmoji(text),
                            itemFile: nil,
                            subgroupId: nil
                        )
                    }
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: strings.Emoji_FrequentlyUsed, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: false, isClearable: true, headerItem: nil, items: [resultItem]))
                    }
                }
            }
            
            if areUnicodeEmojiEnabled {
                for (subgroupId, list) in staticEmojiMapping {
                    let groupId: AnyHashable = "static"
                    for emojiString in list {
                        let resultItem = EmojiPagerContentComponent.Item(
                            animationData: nil,
                            content: .staticEmoji(emojiString),
                            itemFile: nil,
                            subgroupId: subgroupId.rawValue
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        } else {
                            itemGroupIndexById[groupId] = itemGroups.count
                            itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: strings.EmojiInput_SectionTitleEmoji, subtitle: nil, isPremiumLocked: false, isFeatured: false, isExpandable: false, isClearable: false, headerItem: nil, items: [resultItem]))
                        }
                    }
                }
            }
            
            var installedCollectionIds = Set<ItemCollectionId>()
            for (id, _, _) in view.collectionInfos {
                installedCollectionIds.insert(id)
            }
            
            if areCustomEmojiEnabled {
                for entry in view.entries {
                    guard let item = entry.item as? StickerPackItem else {
                        continue
                    }
                    let animationData = EntityKeyboardAnimationData(file: item.file)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil
                    )
                    
                    let supergroupId = entry.index.collectionId
                    let groupId: AnyHashable = supergroupId
                    let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        
                        var title = ""
                        var headerItem: EntityKeyboardAnimationData?
                        inner: for (id, info, _) in view.collectionInfos {
                            if id == entry.index.collectionId, let info = info as? StickerPackCollectionInfo {
                                title = info.title
                                
                                if let thumbnail = info.thumbnail {
                                    let type: EntityKeyboardAnimationData.ItemType
                                    if item.file.isAnimatedSticker {
                                        type = .lottie
                                    } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                        type = .video
                                    } else {
                                        type = .still
                                    }
                                    
                                    headerItem = EntityKeyboardAnimationData(
                                        id: .stickerPackThumbnail(info.id),
                                        type: type,
                                        resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                        dimensions: thumbnail.dimensions.cgSize,
                                        immediateThumbnailData: info.immediateThumbnailData,
                                        isReaction: false
                                    )
                                }
                                
                                break inner
                            }
                        }
                        itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: title, subtitle: nil, isPremiumLocked: isPremiumLocked, isFeatured: false, isExpandable: false, isClearable: false, headerItem: headerItem, items: [resultItem]))
                    }
                }
                
                if !isStandalone {
                    for featuredEmojiPack in featuredEmojiPacks {
                        if installedCollectionIds.contains(featuredEmojiPack.info.id) {
                            continue
                        }
                        
                        for item in featuredEmojiPack.topItems {
                            let animationData = EntityKeyboardAnimationData(file: item.file)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: item.file,
                                subgroupId: nil
                            )
                            
                            let supergroupId = featuredEmojiPack.info.id
                            let groupId: AnyHashable = supergroupId
                            let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                            if isPremiumLocked && isPremiumDisabled {
                                continue
                            }
                            if let groupIndex = itemGroupIndexById[groupId] {
                                itemGroups[groupIndex].items.append(resultItem)
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                
                                var headerItem: EntityKeyboardAnimationData?
                                if let thumbnailFileId = featuredEmojiPack.info.thumbnailFileId, let file = featuredEmojiPack.topItems.first(where: { $0.file.fileId.id == thumbnailFileId }) {
                                    headerItem = EntityKeyboardAnimationData(file: file.file)
                                } else if let thumbnail = featuredEmojiPack.info.thumbnail {
                                    let info = featuredEmojiPack.info
                                    let type: EntityKeyboardAnimationData.ItemType
                                    if item.file.isAnimatedSticker {
                                        type = .lottie
                                    } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                        type = .video
                                    } else {
                                        type = .still
                                    }
                                    
                                    headerItem = EntityKeyboardAnimationData(
                                        id: .stickerPackThumbnail(info.id),
                                        type: type,
                                        resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                        dimensions: thumbnail.dimensions.cgSize,
                                        immediateThumbnailData: info.immediateThumbnailData,
                                        isReaction: false
                                    )
                                }
                                
                                itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: featuredEmojiPack.info.title, subtitle: nil, isPremiumLocked: isPremiumLocked, isFeatured: true, isExpandable: true, isClearable: false, headerItem: headerItem, items: [resultItem]))
                            }
                        }
                    }
                }
            }
            
            return EmojiPagerContentComponent(
                id: "emoji",
                context: context,
                avatarPeer: nil,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteractionHolder: EmojiPagerContentComponent.InputInteractionHolder(),
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var headerItem = group.headerItem
                    
                    if let groupId = group.id.base as? ItemCollectionId {
                        outer: for (id, info, _) in view.collectionInfos {
                            if id == groupId, let info = info as? StickerPackCollectionInfo {
                                if let thumbnailFileId = info.thumbnailFileId {
                                    for item in group.items {
                                        if let itemFile = item.itemFile, itemFile.fileId.id == thumbnailFileId {
                                            headerItem = EntityKeyboardAnimationData(file: itemFile)
                                            break outer
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(
                        supergroupId: group.supergroupId,
                        groupId: group.id,
                        title: group.title,
                        subtitle: group.subtitle,
                        actionButtonTitle: nil,
                        isFeatured: group.isFeatured,
                        isPremiumLocked: group.isPremiumLocked,
                        isEmbedded: false,
                        hasClear: group.isClearable,
                        isExpandable: group.isExpandable,
                        displayPremiumBadges: false,
                        headerItem: headerItem,
                        items: group.items
                    )
                },
                itemLayoutType: .compact,
                warpContentsOnEdges: isReactionSelection || isStatusSelection,
                enableLongPress: isReactionSelection && !isQuickReactionSelection,
                selectedItems: selectedItems
            )
        }
        return emojiItems
    }
}
