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

private func generateTemplateImage(isMonochrome: Bool) -> UIImage {
    return generateImage(CGSize(width: radius * 2.0 + 4.0, height: radius * 2.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        //context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: radius).cgPath)
        addRoundedRectPath(context: context, rect: CGRect(origin: CGPoint(), size: size), radius: radius)
        context.clip()
        
        context.setFillColor(UIColor.white.withMultipliedAlpha(0.1).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.withAlphaComponent(isMonochrome ? 0.2 : 1.0).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)))
    })!.stretchableImage(withLeftCapWidth: Int(radius) + 2, topCapHeight: Int(radius) + 3).withRenderingMode(.alwaysTemplate)
}

private let plainTemplateImage: UIImage = {
    return generateTemplateImage(isMonochrome: false)
}()

private let monochromePatternTemplateImage: UIImage = {
    return generateTemplateImage(isMonochrome: true)
}()

private func generateDashBackgroundTemplateImage() -> UIImage {
    return generateImage(CGSize(width: radius * 2.0 + 4.0, height: radius * 2.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: radius).cgPath)
        context.clip()
        
        context.setFillColor(UIColor.white.withMultipliedAlpha(0.1).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: size.height)))
    })!.stretchableImage(withLeftCapWidth: Int(radius) + 2, topCapHeight: Int(radius) + 3).withRenderingMode(.alwaysTemplate)
}

private let dashBackgroundTemplateImage: UIImage = {
    return generateDashBackgroundTemplateImage()
}()

private func generateDashTemplateImage(isMonochrome: Bool) -> UIImage {
    return generateImage(CGSize(width: radius * 2.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        
        let dashOffset: CGFloat = isMonochrome ? -4.0 : 5.0
        
        context.translateBy(x: 0.0, y: dashOffset)
        
        for _ in 0 ..< 2 {
            context.move(to: CGPoint(x: 0.0, y: 3.0))
            context.addLine(to: CGPoint(x: lineWidth, y: 0.0))
            context.addLine(to: CGPoint(x: lineWidth, y: 9.0))
            context.addLine(to: CGPoint(x: 0.0, y: 9.0 + 3.0))
            context.closePath()
            context.fillPath()
            
            context.translateBy(x: 0.0, y: 18.0)
        }
        
        context.clear(CGRect(origin: CGPoint(x: lineWidth, y: 0.0), size: CGSize(width: size.width - lineWidth, height: size.height)))
    })!.resizableImage(withCapInsets: .zero, resizingMode: .tile).withRenderingMode(.alwaysTemplate)
}

private let dashOpaqueTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: false)
}()

private let dashMonochromeTemplateImage: UIImage = {
    return generateDashTemplateImage(isMonochrome: true)
}()

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
        var primaryColor: UIColor
        var secondaryColor: UIColor?
        var pattern: Pattern?
        var displayProgress: Bool
    }

    private var params: Params?

    public var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if let params = self.params {
                    self.update(
                        size: params.size,
                        primaryColor: params.primaryColor,
                        secondaryColor: params.secondaryColor,
                        pattern: params.pattern,
                        animation: .System(duration: 0.2, transition: ControlledTransition(
                            duration: 0.2,
                            curve: .easeInOut,
                            interactive: false
                        ))
                    )
                }
            }
        }
    }
    
    private let backgroundView: UIImageView
    private var dashView: UIImageView?
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    
    private var patternContentsTarget: PatternContentsTarget?
    private var patternContentLayers: [SimpleLayer] = []
    private var patternFile: TelegramMediaFile?
    private var patternFileDisposable: Disposable?
    private var patternImage: UIImage?
    private var patternImageDisposable: Disposable?

    override public init(frame: CGRect) {
        self.backgroundView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.patternFileDisposable?.dispose()
        self.patternImageDisposable?.dispose()
    }
    
    private func updateAnimations() {
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
        primaryColor: UIColor,
        secondaryColor: UIColor?,
        pattern: Pattern?,
        animation: ListViewItemUpdateAnimation
    ) {
        let params = Params(
            size: size,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            pattern: pattern,
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
            
            if let secondaryColor = params.secondaryColor {
                self.backgroundView.tintColor = params.primaryColor
                
                if self.dashView == nil {
                    let dashView = UIImageView()
                    dashView.layer.cornerRadius = radius
                    if #available(iOS 13.0, *) {
                        dashView.layer.cornerCurve = .circular
                    }
                    self.dashView = dashView
                    self.addSubview(dashView)
                }
                
                if secondaryColor.alpha == 0.0 {
                    self.backgroundView.image = monochromePatternTemplateImage
                    self.dashView?.image = dashMonochromeTemplateImage
                    self.dashView?.tintColor = primaryColor
                } else {
                    self.backgroundView.image = plainTemplateImage
                    self.dashView?.image = dashOpaqueTemplateImage
                    self.dashView?.tintColor = secondaryColor
                }
            } else {
                self.backgroundView.image = plainTemplateImage
                self.backgroundView.tintColor = params.primaryColor
                
                if let dashView = self.dashView {
                    self.dashView = dashView
                    dashView.removeFromSuperview()
                }
            }
        }
        
        if previousParams?.pattern != params.pattern {
            if let pattern = params.pattern {
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
        
        self.dashView?.layer.masksToBounds = params.pattern == nil && params.secondaryColor != nil
        
        animation.animator.updateFrame(layer: self.backgroundView.layer, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
        if let dashView = self.dashView {
            animation.animator.updateFrame(layer: dashView.layer, frame: CGRect(origin: CGPoint(), size: CGSize(width: radius * 2.0, height: size.height)), completion: nil)
        }
        
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
                Placement(CGPoint(x: 176.0, y: 13.0), 38.0),
                Placement(CGPoint(x: 51.0, y: 45.0), 58.0),
                Placement(CGPoint(x: 349.0, y: 36.0), 58.0),
                Placement(CGPoint(x: 132.0, y: 64.0), 46.0),
                Placement(CGPoint(x: 241.0, y: 64.0), 54.0),
                Placement(CGPoint(x: 68.0, y: 121.0), 44.0),
                Placement(CGPoint(x: 178.0, y: 122.0), 47.0),
                Placement(CGPoint(x: 315.0, y: 122.0), 47.0),
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
                
                let itemSize = CGSize(width: placement.size / 3.0, height: placement.size / 3.0)
                patternContentLayer.frame = CGRect(origin: CGPoint(x: size.width - placement.position.x / 3.0 - itemSize.width * 0.5, y: placement.position.y / 3.0 - itemSize.height * 0.5), size: itemSize)
                var alphaFraction = abs(placement.position.x) / 400.0
                alphaFraction = min(1.0, max(0.0, alphaFraction))
                patternContentLayer.opacity = 0.5 * Float(1.0 - alphaFraction)
                
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
        
        self.updateAnimations()
    }
}
