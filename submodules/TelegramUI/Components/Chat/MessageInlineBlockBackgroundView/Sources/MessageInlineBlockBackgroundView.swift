import Foundation
import UIKit
import Display
import HierarchyTrackingLayer
import Postbox
import TelegramCore
import AnimationCache
import MultiAnimationRenderer
import SwiftSignalKit
import AccountContext
import EmojiTextAttachmentView

private let radius: CGFloat = 4.0
private let lineWidth: CGFloat = 3.0

private func addRoundedRectPath(context: CGContext, rect: CGRect, radius: CGFloat) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: radius, y: radius)
    let fw = rect.width / radius
    let fh = rect.height / radius
    context.move(to: CGPoint(x: fw, y: fh / 2.0))
    context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw/2, y: fh), radius: 1.0)
    context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh/2), radius: 1)
    context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw/2, y: 0), radius: 1)
    context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh/2), radius: 1)
    context.closePath()
    context.restoreGState()
}

private func generateBackgroundTemplateImage(addStripe: Bool, backgroundAlpha: CGFloat) -> UIImage {
    return generateImage(CGSize(width: radius * 2.0 + 4.0, height: radius * 2.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        addRoundedRectPath(context: context, rect: CGRect(origin: CGPoint(), size: size), radius: radius)
        context.clip()
        
        if backgroundAlpha != 0.0 {
            context.setFillColor(UIColor.white.withMultipliedAlpha(backgroundAlpha).cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if addStripe {
            context.setFillColor(UIColor.white.withMultipliedAlpha(0.2).cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)))
        }
    })!.stretchableImage(withLeftCapWidth: Int(radius) + 2, topCapHeight: Int(radius) + 3).withRenderingMode(.alwaysTemplate)
}

private func generateProgressTemplateImage() -> UIImage {
    return generateImage(CGSize(width: radius * 2.0 + 4.0, height: radius * 2.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        addRoundedRectPath(context: context, rect: CGRect(origin: CGPoint(), size: size), radius: radius)
        context.clip()
        
        context.setFillColor(UIColor.white.withMultipliedAlpha(0.4).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.withMultipliedAlpha(0.7).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)))
        
        context.resetClip()
        
        let borderWidth: CGFloat = 1.5
        addRoundedRectPath(context: context, rect: CGRect(origin: CGPoint(), size: size).insetBy(dx: borderWidth * 0.5, dy: borderWidth * 0.5), radius: radius)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        context.strokePath()
        
    })!.stretchableImage(withLeftCapWidth: Int(radius) + 2, topCapHeight: Int(radius) + 3).withRenderingMode(.alwaysTemplate)
}

private let backgroundSolidTemplateImage: UIImage = {
    return generateBackgroundTemplateImage(addStripe: true, backgroundAlpha: 0.1)
}()

private let backgroundDashTemplateImage: UIImage = {
    return generateBackgroundTemplateImage(addStripe: false, backgroundAlpha: 0.1)
}()

private let transparentBackgroundSolidTemplateImage: UIImage = {
    return generateBackgroundTemplateImage(addStripe: true, backgroundAlpha: 0.0)
}()

private let transparentBackgroundDashTemplateImage: UIImage = {
    return generateBackgroundTemplateImage(addStripe: false, backgroundAlpha: 0.0)
}()

private let solidBackgroundTemplateImage: UIImage = {
    return generateBackgroundTemplateImage(addStripe: false, backgroundAlpha: 1.0)
}()

private func generateDashBackgroundTemplateImage() -> UIImage {
    return generateImage(CGSize(width: lineWidth, height: radius * 2.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: CGSize(width: radius * 2.0, height: size.height)), cornerRadius: radius).cgPath)
        context.clip()
        
        context.setFillColor(UIColor.white.withAlphaComponent(1.0).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)))
    })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(radius) + 3).withRenderingMode(.alwaysTemplate)
}

private let dashBackgroundTemplateImage: UIImage = {
    return generateDashBackgroundTemplateImage()
}()

private func generateDashTemplateImage(isMonochrome: Bool, isTriple: Bool) -> UIImage {
    return generateImage(CGSize(width: radius * 2.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        
        let dashOffset: CGFloat
        if isTriple {
            dashOffset = isMonochrome ? -7.0 : 5.0
        } else {
            dashOffset = isMonochrome ? -4.0 : 5.0
        }
        
        let dashHeight: CGFloat = isTriple ? 6.0 : 9.0
        
        context.translateBy(x: 0.0, y: dashOffset)
        
        for _ in 0 ..< 2 {
            context.move(to: CGPoint(x: 0.0, y: 3.0))
            context.addLine(to: CGPoint(x: lineWidth, y: 0.0))
            context.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
            context.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
            context.closePath()
            context.fillPath()
            
            context.translateBy(x: 0.0, y: size.height)
        }
        
        context.clear(CGRect(origin: CGPoint(x: lineWidth, y: 0.0), size: CGSize(width: size.width - lineWidth, height: size.height)))
    })!.resizableImage(withCapInsets: .zero, resizingMode: .tile).withRenderingMode(.alwaysTemplate)
}

private let dashOpaqueTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: false, isTriple: false)
}()

private let dashOpaqueTripleTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: false, isTriple: true)
}()

private let dashMonochromeTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: true, isTriple: false)
}()

private let dashMonochromeTripleTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: true, isTriple: true)
}()

private func generateGradient(gradientWidth: CGFloat, baseAlpha: CGFloat) -> UIImage {
    return generateImage(CGSize(width: gradientWidth, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let foregroundColor = UIColor(white: 1.0, alpha: min(1.0, baseAlpha * 4.0))
        
        if let shadowImage = UIImage(named: "Stories/PanelGradient") {
            UIGraphicsPushContext(context)
            
            for i in 0 ..< 2 {
                let shadowFrame = CGRect(origin: CGPoint(x: CGFloat(i) * (size.width * 0.5), y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height))
                
                context.saveGState()
                context.translateBy(x: shadowFrame.midX, y: shadowFrame.midY)
                context.rotate(by: CGFloat(i == 0 ? 1.0 : -1.0) * CGFloat.pi * 0.5)
                let adjustedRect = CGRect(origin: CGPoint(x: -shadowFrame.height * 0.5, y: -shadowFrame.width * 0.5), size: CGSize(width: shadowFrame.height, height: shadowFrame.width))
                
                context.clip(to: adjustedRect, mask: shadowImage.cgImage!)
                context.setFillColor(foregroundColor.cgColor)
                context.fill(adjustedRect)
                
                context.restoreGState()
            }
            
            UIGraphicsPopContext()
        }
    })!.withRenderingMode(.alwaysTemplate)
}

private final class PatternContentsTarget: MultiAnimationRenderTarget {
    private let imageUpdated: () -> Void
    
    init(imageUpdated: @escaping () -> Void) {
        self.imageUpdated = imageUpdated
        
        super.init()
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        self.contents = contents
        self.imageUpdated()
    }
}

private final class LineView: UIView {
    private let backgroundView: UIImageView
    private var dashBackgroundView: UIImageView?
    private var dashThirdBackgroundView: UIImageView?
    
    private var params: Params?
    private var isAnimating: Bool = false
    
    private struct Params: Equatable {
        var size: CGSize
        var primaryColor: UIColor
        var secondaryColor: UIColor?
        var thirdColor: UIColor?
        var displayProgress: Bool
        
        init(size: CGSize, primaryColor: UIColor, secondaryColor: UIColor?, thirdColor: UIColor?, displayProgress: Bool) {
            self.size = size
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.thirdColor = thirdColor
            self.displayProgress = displayProgress
        }
    }
    
    override init(frame: CGRect) {
        self.backgroundView = UIImageView()
        self.backgroundView.image = dashBackgroundTemplateImage
        
        super.init(frame: frame)
        
        self.layer.cornerRadius = radius
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .circular
        }
        
        self.addSubview(self.backgroundView)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func updateAnimations() {
        guard let params = self.params else {
            return
        }
        
        if params.displayProgress {
            if let dashBackgroundView = self.dashBackgroundView {
                if dashBackgroundView.layer.animation(forKey: "progress") == nil {
                    let animation = dashBackgroundView.layer.makeAnimation(from: 18.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
                    animation.repeatCount = 1.0
                    self.isAnimating = true
                    animation.completion = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isAnimating = false
                        self.updateAnimations()
                    }
                    dashBackgroundView.layer.add(animation, forKey: "progress")
                }
                if let dashThirdBackgroundView = self.dashThirdBackgroundView {
                    if dashThirdBackgroundView.layer.animation(forKey: "progress") == nil {
                        let animation = dashThirdBackgroundView.layer.makeAnimation(from: 18.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
                        animation.repeatCount = 1.0
                        self.isAnimating = true
                        animation.completion = { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.isAnimating = false
                            self.updateAnimations()
                        }
                        dashThirdBackgroundView.layer.add(animation, forKey: "progress")
                    }
                }
            } else {
                let phaseDuration: Double = 1.0
                if self.backgroundView.layer.animation(forKey: "progress") == nil {
                    let animation = self.backgroundView.layer.makeAnimation(from: 0.0 as NSNumber, to: -params.size.height as NSNumber, keyPath: "position.y", timingFunction: kCAMediaTimingFunctionSpring, duration: phaseDuration * 0.5, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: false, additive: true)
                    animation.repeatCount = 1.0
                    self.isAnimating = true
                    animation.completion = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        let animation = self.backgroundView.layer.makeAnimation(from: params.size.height as NSNumber, to: 0.0 as NSNumber, keyPath: "position.y", timingFunction: kCAMediaTimingFunctionSpring, duration: phaseDuration * 0.5, delay: self.params?.displayProgress == true ? 0.1 : 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
                        animation.repeatCount = 1.0
                        self.isAnimating = true
                        animation.completion = { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.isAnimating = false
                            self.updateAnimations()
                        }
                        self.backgroundView.layer.add(animation, forKey: "progress")
                    }
                    self.backgroundView.layer.add(animation, forKey: "progress")
                }
            }
        }
        
        if self.isAnimating && self.dashBackgroundView == nil {
            self.backgroundView.backgroundColor = params.primaryColor
            self.backgroundView.layer.masksToBounds = true
            self.backgroundView.layer.cornerRadius = radius * 0.5
        } else {
            self.backgroundView.backgroundColor = nil
            self.backgroundView.layer.masksToBounds = false
        }
        
        self.layer.masksToBounds = params.secondaryColor != nil || self.isAnimating
    }
    
    func update(size: CGSize, primaryColor: UIColor, secondaryColor: UIColor?, thirdColor: UIColor?, displayProgress: Bool, animation: ListViewItemUpdateAnimation) {
        let params = Params(
            size: size,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            thirdColor: thirdColor,
            displayProgress: displayProgress
        )
        if self.params == params {
            return
        }
        let previousParams = self.params
        self.params = params
        
        let _ = previousParams
        
        self.backgroundView.tintColor = primaryColor
        
        if let secondaryColor {
            let dashBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: thirdColor != nil ? -12.0 : -18.0), size: CGSize(width: radius * 2.0, height: size.height + 18.0))
            
            let dashBackgroundView: UIImageView
            if let current = self.dashBackgroundView {
                dashBackgroundView = current
                
                animation.animator.updateFrame(layer: dashBackgroundView.layer, frame: dashBackgroundFrame, completion: nil)
            } else {
                dashBackgroundView = UIImageView()
                self.dashBackgroundView = dashBackgroundView
                self.addSubview(dashBackgroundView)
                
                dashBackgroundView.frame = dashBackgroundFrame
            }
            
            let templateImage: UIImage
            let monochromeTemplateImage: UIImage
            
            if let thirdColor {
                let thirdDashBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -18.0), size: CGSize(width: radius * 2.0, height: size.height + 18.0))
                templateImage = dashOpaqueTripleTemplateImage
                monochromeTemplateImage = dashMonochromeTripleTemplateImage
                
                let dashThirdBackgroundView: UIImageView
                if let current = self.dashThirdBackgroundView {
                    dashThirdBackgroundView = current
                    
                    animation.animator.updateFrame(layer: dashThirdBackgroundView.layer, frame: thirdDashBackgroundFrame, completion: nil)
                } else {
                    dashThirdBackgroundView = UIImageView()
                    self.dashThirdBackgroundView = dashThirdBackgroundView
                    self.addSubview(dashThirdBackgroundView)
                    
                    dashThirdBackgroundView.frame = thirdDashBackgroundFrame
                }
                
                if thirdColor.alpha == 0.0 {
                    dashThirdBackgroundView.alpha = 0.4
                    dashThirdBackgroundView.image = monochromeTemplateImage
                    dashThirdBackgroundView.tintColor = primaryColor
                } else {
                    dashThirdBackgroundView.alpha = 1.0
                    dashThirdBackgroundView.image = templateImage
                    dashThirdBackgroundView.tintColor = thirdColor
                }
            } else {
                templateImage = dashOpaqueTemplateImage
                monochromeTemplateImage = dashMonochromeTemplateImage
                if let dashThirdBackgroundView = self.dashThirdBackgroundView {
                    self.dashThirdBackgroundView = nil
                    dashThirdBackgroundView.removeFromSuperview()
                }
            }
            
            if secondaryColor.alpha == 0.0 {
                self.backgroundView.alpha = 0.2
                dashBackgroundView.image = monochromeTemplateImage
                dashBackgroundView.tintColor = primaryColor
            } else {
                self.backgroundView.alpha = 1.0
                dashBackgroundView.image = templateImage
                dashBackgroundView.tintColor = secondaryColor
            }
        } else {
            if let dashBackgroundView = self.dashBackgroundView {
                self.dashBackgroundView = nil
                dashBackgroundView.removeFromSuperview()
            }
            if let dashThirdBackgroundView = self.dashThirdBackgroundView {
                self.dashThirdBackgroundView = nil
                dashThirdBackgroundView.removeFromSuperview()
            }
            
            self.backgroundView.alpha = 1.0
        }
        
        self.layer.masksToBounds = params.secondaryColor != nil || self.isAnimating
        
        animation.animator.updateFrame(layer: self.backgroundView.layer, frame: CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)), completion: nil)
        
        self.updateAnimations()
    }
}

public final class MessageInlineBlockBackgroundView: UIView {
    public final class Pattern: Equatable {
        public let context: AccountContext
        public let fileId: Int64
        public let file: TelegramMediaFile?
        
        public init(context: AccountContext, fileId: Int64, file: TelegramMediaFile?) {
            self.context = context
            self.fileId = fileId
            self.file = file
        }
        
        public static func ==(lhs: Pattern, rhs: Pattern) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.context !== rhs.context {
                return false
            }
            if lhs.fileId != rhs.fileId {
                return false
            }
            if lhs.file?.fileId != rhs.file?.fileId {
                return false
            }
            
            return true
        }
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var isTransparent: Bool
        var primaryColor: UIColor
        var secondaryColor: UIColor?
        var thirdColor: UIColor?
        var backgroundColor: UIColor?
        var pattern: Pattern?
        var patternTopRightPosition: CGPoint?
        var patternAlpha: CGFloat
        var displayProgress: Bool
        
        init(
            size: CGSize,
            isTransparent: Bool,
            primaryColor: UIColor,
            secondaryColor: UIColor?,
            thirdColor: UIColor?,
            backgroundColor: UIColor?,
            pattern: Pattern?,
            patternTopRightPosition: CGPoint?,
            patternAlpha: CGFloat,
            displayProgress: Bool
        ) {
            self.size = size
            self.isTransparent = isTransparent
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.thirdColor = thirdColor
            self.backgroundColor = backgroundColor
            self.pattern = pattern
            self.patternTopRightPosition = patternTopRightPosition
            self.patternAlpha = patternAlpha
            self.displayProgress = displayProgress
        }
    }

    private var params: Params?

    public var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if let params = self.params {
                    self.update(
                        size: params.size,
                        isTransparent: params.isTransparent,
                        primaryColor: params.primaryColor,
                        secondaryColor: params.secondaryColor,
                        thirdColor: params.thirdColor,
                        backgroundColor: params.backgroundColor,
                        pattern: params.pattern,
                        animation: .None
                    )
                }
            }
        }
    }
    
    private let backgroundView: UIImageView
    private var lineView: LineView
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    
    private var patternContentsTarget: PatternContentsTarget?
    private var patternContentLayers: [SimpleLayer] = []
    private var patternFile: TelegramMediaFile?
    private var patternFileDisposable: Disposable?
    private var patternImage: UIImage?
    private var patternImageDisposable: Disposable?
    
    private var progressBackgroundContentsView: UIImageView?
    private var progressBackgroundMaskContainer: UIView?
    private var progressBackgroundGradientView: UIImageView?

    override public init(frame: CGRect) {
        self.backgroundView = UIImageView()
        self.lineView = LineView()
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.lineView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.patternFileDisposable?.dispose()
        self.patternImageDisposable?.dispose()
    }
    
    private func updateAnimations() {
        guard let hierarchyTrackingLayer = self.hierarchyTrackingLayer, hierarchyTrackingLayer.isInHierarchy else {
            return
        }
        guard let params = self.params else {
            return
        }
        guard let progressBackgroundGradientView = self.progressBackgroundGradientView else {
            return
        }
        let gradientWidth = progressBackgroundGradientView.bounds.width
        
        if progressBackgroundGradientView.layer.animation(forKey: "shimmer") != nil {
            return
        }

        let duration: Double = 1.0
        let animation = progressBackgroundGradientView.layer.makeAnimation(from: 0.0 as NSNumber, to: (params.size.width + gradientWidth + params.size.width * 0.1) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        progressBackgroundGradientView.layer.add(animation, forKey: "shimmer")
        
        self.lineView.updateAnimations()
    }
    
    private func loadPatternFromFile() {
        guard let pattern = self.params?.pattern else {
            return
        }
        guard let patternContentsTarget = self.patternContentsTarget else {
            return
        }
        guard let patternFile = self.patternFile else {
            return
        }
        self.patternImageDisposable = pattern.context.animationRenderer.loadFirstFrame(
            target: patternContentsTarget,
            cache: pattern.context.animationCache, itemId: "reply-pattern-\(patternFile.fileId)",
            size: CGSize(width: 64, height: 64),
            fetch: animationCacheFetchFile(
                postbox: pattern.context.account.postbox,
                userLocation: .other,
                userContentType: .sticker,
                resource: .media(media: .standalone(media: patternFile), resource: patternFile.resource),
                type: AnimationCacheAnimationType(file: patternFile),
                keyframeOnly: false,
                customColor: .white
            ),
            completion: { [weak self] _, _ in
                guard let self else {
                    return
                }
                self.updatePatternLayerImages()
            }
        )
    }
    
    private func updatePatternLayerImages() {
        let image = self.patternContentsTarget?.contents
        for patternContentLayer in self.patternContentLayers {
            patternContentLayer.contents = image
        }
    }
    
    public func update(
        size: CGSize,
        isTransparent: Bool,
        primaryColor: UIColor,
        secondaryColor: UIColor?,
        thirdColor: UIColor?,
        backgroundColor: UIColor?,
        pattern: Pattern?,
        patternTopRightPosition: CGPoint? = nil,
        patternAlpha: CGFloat = 1.0,
        animation: ListViewItemUpdateAnimation
    ) {
        let params = Params(
            size: size,
            isTransparent: isTransparent,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            thirdColor: thirdColor,
            backgroundColor: backgroundColor,
            pattern: pattern,
            patternTopRightPosition: patternTopRightPosition,
            patternAlpha: patternAlpha,
            displayProgress: self.displayProgress
        )
        if self.params == params {
            return
        }
        let previousParams = self.params
        self.params = params

        if previousParams?.primaryColor != params.primaryColor || previousParams?.secondaryColor != params.secondaryColor {
            for patternContentLayer in self.patternContentLayers {
                patternContentLayer.layerTintColor = primaryColor.cgColor
            }
            
            if let backgroundColor = params.backgroundColor {
                self.backgroundView.image = solidBackgroundTemplateImage
                self.backgroundView.tintColor = backgroundColor
            } else {
                if params.isTransparent {
                    if params.secondaryColor != nil {
                        self.backgroundView.image = transparentBackgroundDashTemplateImage
                    } else {
                        self.backgroundView.image = transparentBackgroundSolidTemplateImage
                    }
                } else {
                    if params.secondaryColor != nil {
                        self.backgroundView.image = backgroundDashTemplateImage
                    } else {
                        self.backgroundView.image = backgroundSolidTemplateImage
                    }
                }
                self.backgroundView.tintColor = params.primaryColor
            }
        }
        
        if previousParams?.pattern != params.pattern {
            if let pattern = params.pattern, pattern.fileId != 0 {
                self.layer.masksToBounds = true
                self.layer.cornerRadius = radius
                if #available(iOS 13.0, *) {
                    self.layer.cornerCurve = .circular
                }
                
                if self.patternContentsTarget == nil {
                    self.patternContentsTarget = PatternContentsTarget(imageUpdated: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.updatePatternLayerImages()
                    })
                }
                
                if previousParams?.pattern?.fileId != pattern.fileId {
                    self.patternFile = nil
                    self.patternFileDisposable?.dispose()
                    self.patternFileDisposable = nil
                    self.patternImageDisposable?.dispose()
                    
                    if let file = pattern.file {
                        self.patternFile = file
                        self.loadPatternFromFile()
                    } else {
                        let fileId = pattern.fileId
                        self.patternFileDisposable = (pattern.context.engine.stickers.resolveInlineStickers(fileIds: [pattern.fileId])
                        |> deliverOnMainQueue).startStrict(next: { [weak self] files in
                            guard let self else {
                                return
                            }
                            if let file = files[fileId] {
                                self.patternFile = file
                                self.loadPatternFromFile()
                            }
                        })
                    }
                }
            } else {
                self.layer.masksToBounds = false
                
                self.patternContentsTarget = nil
                self.patternFileDisposable?.dispose()
                self.patternFileDisposable = nil
                self.patternFile = nil
            }
        }
        
        animation.animator.updateFrame(layer: self.backgroundView.layer, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
        
        let lineFrame = CGRect(origin: CGPoint(), size: CGSize(width: radius * 2.0, height: size.height))
        self.lineView.update(
            size: lineFrame.size,
            primaryColor: params.primaryColor,
            secondaryColor: params.secondaryColor,
            thirdColor: params.thirdColor,
            displayProgress: params.displayProgress,
            animation: animation
        )
        animation.animator.updateFrame(layer: self.lineView.layer, frame: lineFrame, completion: nil)
        
        if params.pattern != nil {
            var maxIndex = 0
            
            struct Placement {
                var position: CGPoint
                var size: CGFloat
                
                init(_ position: CGPoint, _ size: CGFloat) {
                    self.position = position
                    self.size = size
                }
            }
            
            let placements: [Placement] = [
                Placement(CGPoint(x: 180.0, y: 13.0), 38.0),
                Placement(CGPoint(x: 55.0, y: 47.0), 58.0),
                Placement(CGPoint(x: 364.0, y: 26.0), 58.0),
                Placement(CGPoint(x: 133.0, y: 74.0), 46.0),
                Placement(CGPoint(x: 262.0, y: 67.0), 54.0),
                Placement(CGPoint(x: 62.0, y: 125.0), 44.0),
                Placement(CGPoint(x: 171.0, y: 135.0), 47.0),
                Placement(CGPoint(x: 320.0, y: 124.0), 47.0),
            ]
            
            for placement in placements {
                let patternContentLayer: SimpleLayer
                if maxIndex < self.patternContentLayers.count {
                    patternContentLayer = self.patternContentLayers[maxIndex]
                } else {
                    patternContentLayer = SimpleLayer()
                    patternContentLayer.layerTintColor = primaryColor.cgColor
                    self.layer.addSublayer(patternContentLayer)
                    self.patternContentLayers.append(patternContentLayer)
                }
                patternContentLayer.contents = self.patternContentsTarget?.contents
                
                var patternOrigin = CGPoint(x: size.width, y: 0.0)
                if let patternTopRightPosition {
                    patternOrigin.x -= patternTopRightPosition.x
                    patternOrigin.y += patternTopRightPosition.y
                }
                
                let itemSize = CGSize(width: placement.size / 3.0, height: placement.size / 3.0)
                patternContentLayer.frame = CGRect(origin: CGPoint(x: patternOrigin.x - placement.position.x / 3.0 - itemSize.width * 0.5, y: patternOrigin.y + placement.position.y / 3.0 - itemSize.height * 0.5), size: itemSize)
                var alphaFraction = abs(placement.position.x / 3.0) / min(500.0, size.width)
                alphaFraction = min(1.0, max(0.0, alphaFraction))
                patternContentLayer.opacity = 0.3 * Float(1.0 - alphaFraction) * Float(patternAlpha)
                
                maxIndex += 1
            }
            
            if maxIndex < self.patternContentLayers.count {
                for i in maxIndex ..< self.patternContentLayers.count {
                    self.patternContentLayers[i].removeFromSuperlayer()
                }
                self.patternContentLayers.removeSubrange(maxIndex ..< self.patternContentLayers.count)
            }
        } else {
            for patternContentLayer in self.patternContentLayers {
                patternContentLayer.removeFromSuperlayer()
            }
            self.patternContentLayers.removeAll()
        }
        
        let gradientWidth: CGFloat = min(300.0, max(200.0, size.width * 0.9))
        
        if previousParams?.displayProgress != params.displayProgress {
            if params.displayProgress {
                let progressBackgroundContentsView: UIImageView
                if let current = self.progressBackgroundContentsView {
                    progressBackgroundContentsView = current
                } else {
                    progressBackgroundContentsView = UIImageView()
                    progressBackgroundContentsView.image = generateProgressTemplateImage()
                    self.progressBackgroundContentsView = progressBackgroundContentsView
                    self.insertSubview(progressBackgroundContentsView, aboveSubview: self.backgroundView)
                    progressBackgroundContentsView.tintColor = primaryColor
                }
                
                let progressBackgroundMaskContainer: UIView
                if let current = self.progressBackgroundMaskContainer {
                    progressBackgroundMaskContainer = current
                } else {
                    progressBackgroundMaskContainer = UIView()
                    self.progressBackgroundMaskContainer = progressBackgroundMaskContainer
                    progressBackgroundContentsView.mask = progressBackgroundMaskContainer
                }
                
                let progressBackgroundGradientView: UIImageView
                if let current = self.progressBackgroundGradientView {
                    progressBackgroundGradientView = current
                } else {
                    progressBackgroundGradientView = UIImageView()
                    self.progressBackgroundGradientView = progressBackgroundGradientView
                    progressBackgroundMaskContainer.addSubview(progressBackgroundGradientView)
                    progressBackgroundGradientView.image = generateGradient(gradientWidth: 100.0, baseAlpha: 0.5)
                }
                
                progressBackgroundContentsView.frame = CGRect(origin: CGPoint(), size: size)
                progressBackgroundMaskContainer.frame = CGRect(origin: CGPoint(), size: size)
                progressBackgroundGradientView.frame = CGRect(origin: CGPoint(x: -gradientWidth, y: 0.0), size: CGSize(width: gradientWidth, height: size.height))
                
                if self.hierarchyTrackingLayer == nil {
                    let hierarchyTrackingLayer = HierarchyTrackingLayer()
                    self.hierarchyTrackingLayer = hierarchyTrackingLayer
                    self.layer.addSublayer(hierarchyTrackingLayer)
                    hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] _ in
                        self?.updateAnimations()
                    }
                }
            } else {
                if let progressBackgroundContentsView = self.progressBackgroundContentsView {
                    self.progressBackgroundContentsView = nil
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
                    transition.updateAlpha(layer: progressBackgroundContentsView.layer, alpha: 0.0, completion: { [weak progressBackgroundContentsView] _ in
                        progressBackgroundContentsView?.removeFromSuperview()
                    })
                }
                self.progressBackgroundMaskContainer = nil
                self.progressBackgroundGradientView = nil
                
                if let hierarchyTrackingLayer = self.hierarchyTrackingLayer {
                    self.hierarchyTrackingLayer = nil
                    hierarchyTrackingLayer.isInHierarchyUpdated = nil
                    hierarchyTrackingLayer.removeFromSuperlayer()
                }
            }
        } else {
            if let progressBackgroundContentsView = self.progressBackgroundContentsView {
                animation.animator.updateFrame(layer: progressBackgroundContentsView.layer, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
                progressBackgroundContentsView.tintColor = primaryColor
            }
            if let progressBackgroundMaskContainer = self.progressBackgroundMaskContainer {
                animation.animator.updateFrame(layer: progressBackgroundMaskContainer.layer, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
            }
            if let progressBackgroundGradientView = self.progressBackgroundGradientView {
                animation.animator.updateFrame(layer: progressBackgroundGradientView.layer, frame: CGRect(origin: CGPoint(x: -gradientWidth, y: 0.0), size: CGSize(width: gradientWidth, height: size.height)), completion: nil)
            }
        }
        
        self.updateAnimations()
    }
}
