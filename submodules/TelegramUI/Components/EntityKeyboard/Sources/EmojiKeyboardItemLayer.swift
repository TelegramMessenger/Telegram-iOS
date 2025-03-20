import Foundation
import UIKit
import Display
import ComponentFlow
import MultiAnimationRenderer
import AnimationCache
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import EmojiTextAttachmentView
import EmojiStatusComponent

final class EmojiKeyboardCloneItemLayer: SimpleLayer {
}

public final class EmojiKeyboardItemLayer: MultiAnimationRenderTarget {
    public struct Key: Hashable {
        var groupId: AnyHashable
        var itemId: EmojiPagerContentComponent.ItemContent.Id
        
        public init(
            groupId: AnyHashable,
            itemId: EmojiPagerContentComponent.ItemContent.Id
        ) {
            self.groupId = groupId
            self.itemId = itemId
        }
    }
    
    enum Badge: Equatable {
        case premium
        case locked
        case featured
        case text(String)
        case customFile(TelegramMediaFile)
    }
    
    public let item: EmojiPagerContentComponent.Item
    private let context: AccountContext
    
    private var content: EmojiPagerContentComponent.ItemContent
    private var theme: PresentationTheme?
    
    private let placeholderColor: UIColor
    let pixelSize: CGSize
    let pointSize: CGSize
    private let size: CGSize
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    private var premiumBadgeView: PremiumBadgeView?
    
    private var iconLayer: SimpleLayer?
    private var tintIconLayer: SimpleLayer?
    
    private(set) var underlyingContentLayer: SimpleLayer?
    private(set) var tintContentLayer: SimpleLayer?
    
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
    
    weak var cloneLayer: EmojiKeyboardCloneItemLayer? {
        didSet {
            if let cloneLayer = self.cloneLayer {
                cloneLayer.contents = self.contents
            }
        }
    }
    
    override public var contents: Any? {
        didSet {
            self.onContentsUpdate()
            if let cloneLayer = self.cloneLayer {
                cloneLayer.contents = self.contents
            }
        }
    }
    
    override public var position: CGPoint {
        get {
            return super.position
        } set(value) {
            if let mirrorLayer = self.tintContentLayer {
                mirrorLayer.position = value
            }
            if let mirrorLayer = self.underlyingContentLayer {
                mirrorLayer.position = value
            }
            super.position = value
        }
    }
    
    override public var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let mirrorLayer = self.tintContentLayer {
                mirrorLayer.bounds = value
            }
            if let mirrorLayer = self.underlyingContentLayer {
                mirrorLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override public func add(_ animation: CAAnimation, forKey key: String?) {
        if let mirrorLayer = self.tintContentLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        if let mirrorLayer = self.underlyingContentLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        super.add(animation, forKey: key)
    }
    
    override public func removeAllAnimations() {
        if let mirrorLayer = self.tintContentLayer {
            mirrorLayer.removeAllAnimations()
        }
        if let mirrorLayer = self.underlyingContentLayer {
            mirrorLayer.removeAllAnimations()
        }
        super.removeAllAnimations()
    }
    
    override public func removeAnimation(forKey: String) {
        if let mirrorLayer = self.tintContentLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        if let mirrorLayer = self.underlyingContentLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        super.removeAnimation(forKey: forKey)
    }
    
    public var onContentsUpdate: () -> Void = {}
    public var onLoop: () -> Void = {}

    public init(
        item: EmojiPagerContentComponent.Item,
        context: AccountContext,
        attemptSynchronousLoad: Bool,
        content: EmojiPagerContentComponent.ItemContent,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        placeholderColor: UIColor,
        blurredBadgeColor: UIColor,
        accentIconColor: UIColor,
        pointSize: CGSize,
        onUpdateDisplayPlaceholder: @escaping (Bool, Double) -> Void
    ) {
        self.item = item
        self.context = context
        self.content = content
        self.placeholderColor = placeholderColor
        self.onUpdateDisplayPlaceholder = onUpdateDisplayPlaceholder
        
        let scale = min(2.0, UIScreenScale)
        let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        self.pixelSize = pixelSize
        self.pointSize = pointSize
        self.size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        
        super.init()
        
        switch content {
        case let .animation(animationData):
            let animationDataResource = animationData.resource._parse()
            
            let loadAnimation: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.disposable = renderer.add(target: strongSelf, cache: cache, itemId: animationDataResource.resource.id.stringRepresentation, unique: false, size: pixelSize, fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: animationDataResource, type: animationData.type.animationCacheAnimationType, keyframeOnly: pixelSize.width >= 120.0, customColor: animationData.isTemplate ? .white : nil))
            }
            
            if attemptSynchronousLoad {
                if !renderer.loadFirstFrameSynchronously(target: self, cache: cache, itemId: animationDataResource.resource.id.stringRepresentation, size: pixelSize) {
                    self.updateDisplayPlaceholder(displayPlaceholder: true)
                    
                    self.fetchDisposable = renderer.loadFirstFrame(target: self, cache: cache, itemId: animationDataResource.resource.id.stringRepresentation, size: pixelSize, fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: animationDataResource, type: animationData.type.animationCacheAnimationType, keyframeOnly: true, customColor: animationData.isTemplate ? .white : nil), completion: { [weak self] success, isFinal in
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
                self.fetchDisposable = renderer.loadFirstFrame(target: self, cache: cache, itemId: animationDataResource.resource.id.stringRepresentation, size: pixelSize, fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: animationDataResource, type: animationData.type.animationCacheAnimationType, keyframeOnly: true, customColor: animationData.isTemplate ? .white : nil), completion: { [weak self] success, isFinal in
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
            
            if let particleColor = animationData.particleColor {
                let underlyingContentLayer = SimpleLayer()
                self.underlyingContentLayer = underlyingContentLayer
                
                let starsLayer = StarsEffectLayer()
                starsLayer.frame = CGRect(origin: CGPoint(x: -3.0, y: -3.0), size: CGSize(width: 42.0, height: 42.0))
                starsLayer.update(color: particleColor, size: CGSize(width: 42.0, height: 42.0))
                underlyingContentLayer.addSublayer(starsLayer)
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
                string.draw(at: CGPoint(x: floorToScreenPixels((scaledSize.width - boundingRect.width) / 2.0 + boundingRect.minX), y: floorToScreenPixels((scaledSize.height - boundingRect.height) / 2.0 + boundingRect.minY)))
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
                case let .topic(title, color):
                    let colors = topicIconColors(for: color)
                    if let image = generateTopicIcon(backgroundColors: colors.0.map { UIColor(rgb: $0) }, strokeColors: colors.1.map { UIColor(rgb: $0) }, title: title) {
                        let imageSize = image.size//.aspectFitted(CGSize(width: size.width - 6.0, height: size.height - 6.0))
                        image.draw(in: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
                    }
                case .stop:
                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Premium/NoIcon"), color: .white) {
                        let imageSize = image.size.aspectFitted(CGSize(width: size.width - 6.0, height: size.height - 6.0))
                        image.draw(in: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
                    }
                case .add:
                    break
                }
                
                UIGraphicsPopContext()
            })?.withRenderingMode(icon == .stop ? .alwaysTemplate : .alwaysOriginal)
            self.contents = image?.cgImage
        }
        
        if case .icon(.add) = content {
            let tintContentLayer = SimpleLayer()
            self.tintContentLayer = tintContentLayer
            
            let iconLayer = SimpleLayer()
            self.iconLayer = iconLayer
            self.addSublayer(iconLayer)
            
            let tintIconLayer = SimpleLayer()
            self.tintIconLayer = tintIconLayer
            tintContentLayer.addSublayer(tintIconLayer)
        }
    }
    
    override public init(layer: Any) {
        guard let layer = layer as? EmojiKeyboardItemLayer else {
            preconditionFailure()
        }
        
        self.context = layer.context
        self.item = layer.item
        
        self.content = layer.content
        self.placeholderColor = layer.placeholderColor
        self.size = layer.size
        self.pixelSize = layer.pixelSize
        self.pointSize = layer.pointSize
        
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
    
    func update(
        content: EmojiPagerContentComponent.ItemContent,
        theme: PresentationTheme,
        strings: PresentationStrings
    ) {
        var themeUpdated = false
        if self.theme !== theme {
            self.theme = theme
            themeUpdated = true
        }
        var contentUpdated = false
        if self.content != content {
            self.content = content
            contentUpdated = true
        }
        
        if themeUpdated || contentUpdated {
            if case let .icon(icon) = content, case let .topic(title, color) = icon {
                let image = generateImage(self.size, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    UIGraphicsPushContext(context)
                    
                    let colors = topicIconColors(for: color)
                    if let image = generateTopicIcon(backgroundColors: colors.0.map { UIColor(rgb: $0) }, strokeColors: colors.1.map { UIColor(rgb: $0) }, title: title) {
                        let imageSize = image.size
                        image.draw(in: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
                    }
                
                    UIGraphicsPopContext()
                })
                self.contents = image?.cgImage
            } else if case .icon(.add) = content {
                guard let iconLayer = self.iconLayer, let tintIconLayer = self.tintIconLayer else {
                    return
                }
                func generateIcon(color: UIColor) -> UIImage? {
                    return generateImage(self.pointSize, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        UIGraphicsPushContext(context)
                        
                        context.setFillColor(color.withMultipliedAlpha(0.2).cgColor)
                        
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 21.0).cgPath)
                        context.fillPath()
                        context.setFillColor(color.cgColor)
                        
                        let plusSize = CGSize(width: 3.5, height: 28.0)
                        context.addPath(UIBezierPath(roundedRect: CGRect(x: floorToScreenPixels((size.width - plusSize.width) / 2.0), y: floorToScreenPixels((size.height - plusSize.height) / 2.0), width: plusSize.width, height: plusSize.height).offsetBy(dx: 0.0, dy: -17.0), cornerRadius: plusSize.width / 2.0).cgPath)
                        context.addPath(UIBezierPath(roundedRect: CGRect(x: floorToScreenPixels((size.width - plusSize.height) / 2.0), y: floorToScreenPixels((size.height - plusSize.width) / 2.0), width: plusSize.height, height: plusSize.width).offsetBy(dx: 0.0, dy: -17.0), cornerRadius: plusSize.width / 2.0).cgPath)
                        context.fillPath()
                        
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        
                        let string = strings.Stickers_CreateSticker
                        var lineOriginY = size.height / 2.0 - 18.0
                        let components = string.components(separatedBy: "\n")
                        for component in components {
                            context.saveGState()
                            let attributedString = NSAttributedString(string: component, attributes: [NSAttributedString.Key.font: Font.medium(17.0), NSAttributedString.Key.foregroundColor: color])
                            
                            let line = CTLineCreateWithAttributedString(attributedString)
                            let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                            
                            let lineOrigin = CGPoint(x: floorToScreenPixels((size.width - lineBounds.size.width) / 2.0), y: lineOriginY)
                            context.textPosition = lineOrigin
                            CTLineDraw(line, context)
                                                        
                            lineOriginY -= lineBounds.height + 6.0
                            context.restoreGState()
                        }
                        
                        UIGraphicsPopContext()
                    })
                }
                
                let needsVibrancy = !theme.overallDarkAppearance
                let color = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor

                iconLayer.contents = generateIcon(color: color)?.cgImage
                tintIconLayer.contents = generateIcon(color: .black)?.cgImage
                
                tintIconLayer.isHidden = !needsVibrancy
            }
        }
    }
    
    func update(
        transition: ComponentTransition,
        size: CGSize,
        badge: Badge?,
        blurredBadgeColor: UIColor,
        blurredBadgeBackgroundColor: UIColor
    ) {
        if self.badge != badge || self.validSize != size {
            self.badge = badge
            self.validSize = size
            
            if let iconLayer = self.iconLayer, let tintIconLayer = self.tintIconLayer {
                transition.setFrame(layer: iconLayer, frame: CGRect(origin: .zero, size: size))
                transition.setFrame(layer: tintIconLayer, frame: CGRect(origin: .zero, size: size))
            }
            
            if let badge = badge {
                var badgeTransition = transition
                let premiumBadgeView: PremiumBadgeView
                if let current = self.premiumBadgeView {
                    premiumBadgeView = current
                } else {
                    badgeTransition = .immediate
                    premiumBadgeView = PremiumBadgeView(context: self.context)
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
    
    public override func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        self.contents = contents
        
        if self.displayPlaceholder {
            self.displayPlaceholder = false
            self.onUpdateDisplayPlaceholder(false, 0.2)
            self.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
        }
        
        if didLoop {
            self.onLoop()
        }
    }
}
