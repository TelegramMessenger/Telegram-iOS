import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalizedPeerData
import CallsEmoji
import TooltipUI
import AlertUI
import PresentationDataUtils
import DeviceAccess
import ContextUI
import AudioBlob
import GradientBackground

private final class EffectImageLayer: SimpleLayer, GradientBackgroundPatternOverlayLayer {
    enum SoftlightMode {
        case whileAnimating
        case always
        case never
    }
    
    var fillWithColorUntilLoaded: UIColor? {
        didSet {
            if self.fillWithColorUntilLoaded != oldValue {
                if let fillWithColorUntilLoaded = self.fillWithColorUntilLoaded {
                    if self.currentContents == nil {
                        self.backgroundColor = fillWithColorUntilLoaded.cgColor
                    } else {
                        self.backgroundColor = nil
                    }
                } else {
                    self.backgroundColor = nil
                }
            }
        }
    }
    
    var patternContentImage: UIImage? {
        didSet {
            if self.patternContentImage !== oldValue {
                self.updateComposedImage()
                self.updateContents()
            }
        }
    }
    
    var composedContentImage: UIImage? {
        didSet {
            if self.composedContentImage !== oldValue {
                self.updateContents()
            }
        }
    }
    
    var softlightMode: SoftlightMode = .whileAnimating {
        didSet {
            if self.softlightMode != oldValue {
                self.updateFilters()
            }
        }
    }
    
    var isAnimating: Bool = false {
        didSet {
            if self.isAnimating != oldValue {
                self.updateFilters()
            }
        }
    }
    
    private var isUsingSoftlight: Bool = false
    
    var suspendCompositionUpdates: Bool = false
    private var needsCompositionUpdate: Bool = false
    
    private func updateFilters() {
        let useSoftlight: Bool
        let useFilter: Bool
        switch self.softlightMode {
        case .whileAnimating:
            useSoftlight = self.isAnimating
            useFilter = useSoftlight
        case .always:
            useSoftlight = true
            useFilter = useSoftlight
        case .never:
            useSoftlight = true
            useFilter = false
        }
        if self.isUsingSoftlight != useSoftlight {
            self.isUsingSoftlight = useSoftlight
            
            if self.isUsingSoftlight && useFilter {
                self.compositingFilter = "softLightBlendMode"
            } else {
                self.compositingFilter = nil
            }
            
            self.updateContents()
            self.updateOpacity()
        }
    }
    
    private var allowSettingContents: Bool = false
    private var currentContents: UIImage?
    
    override var contents: Any? {
        get {
            return super.contents
        } set(value) {
            if self.allowSettingContents {
                super.contents = value
            } else {
                assert(false)
            }
        }
    }
    
    private var allowSettingOpacity: Bool = false
    var compositionOpacity: Float = 1.0 {
        didSet {
            if self.compositionOpacity != oldValue {
                self.updateOpacity()
                self.updateComposedImage()
            }
        }
    }
    
    override var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if self.allowSettingOpacity {
                super.opacity = value
            } else {
                assert(false)
            }
        }
    }
    
    private var compositionData: (size: CGSize, backgroundImage: UIImage, backgroundImageHash: String)?
    
    func updateCompositionData(size: CGSize, backgroundImage: UIImage, backgroundImageHash: String) {
        if self.compositionData?.size == size && self.compositionData?.backgroundImage === backgroundImage {
            return
        }
        self.compositionData = (size, backgroundImage, backgroundImageHash)
        
        self.updateComposedImage()
    }
    
    func updateCompositionIfNeeded() {
        if self.needsCompositionUpdate {
            self.needsCompositionUpdate = false
            self.updateComposedImage()
        }
    }
    
    private static var cachedComposedImage: (size: CGSize, patternContentImage: UIImage, backgroundImageHash: String, image: UIImage)?
    
    private func updateComposedImage() {
                
        guard let (size, backgroundImage, backgroundImageHash) = self.compositionData, let patternContentImage = self.patternContentImage else {
            return
        }
        
        if let cachedComposedImage = EffectImageLayer.cachedComposedImage, cachedComposedImage.size == size, cachedComposedImage.backgroundImageHash == backgroundImageHash, cachedComposedImage.patternContentImage === patternContentImage {
            self.composedContentImage = cachedComposedImage.image
            return
        }
        
        let composedContentImage = generateImage(size, contextGenerator: { size, context in
            context.draw(backgroundImage.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.softLight)
            context.setAlpha(CGFloat(self.compositionOpacity))
            context.draw(patternContentImage.cgImage!, in: CGRect(origin: CGPoint(), size: size))
        }, opaque: true, scale: min(UIScreenScale, patternContentImage.scale))
        self.composedContentImage = composedContentImage
                
        if self.softlightMode == .whileAnimating, let composedContentImage = composedContentImage {
            EffectImageLayer.cachedComposedImage = (size, patternContentImage, backgroundImageHash, composedContentImage)
        }
    }
    
    private func updateContents() {
        var contents: UIImage?
        
        if self.isUsingSoftlight {
            contents = self.patternContentImage
        } else {
            contents = self.composedContentImage
        }
        
        if self.currentContents !== contents {
            self.currentContents = contents
            
            self.allowSettingContents = true
            self.contents = contents?.cgImage
            self.allowSettingContents = false
            
            self.backgroundColor = nil
        }
    }
    
    private func updateOpacity() {
        if self.isUsingSoftlight {
            self.allowSettingOpacity = true
            self.opacity = self.compositionOpacity
            self.allowSettingOpacity = false
            self.isOpaque = false
        } else {
            self.allowSettingOpacity = true
            self.opacity = 1.0
            self.allowSettingOpacity = false
            self.isOpaque = true
        }
    }
}


final class NewCallBackgroundNode: ASDisplayNode {
    
    private let contentNode: ASDisplayNode
    
    private var gradientBackgroundNode: GradientBackgroundNode?
    private var dummedGradientBackgroundNode: GradientBackgroundNode?
    private var state: CallBackgroundState?
    private let patternImageLayer: EffectImageLayer
   
    init(context: AccountContext, forChatDisplay: Bool, useSharedAnimationPhase: Bool = false, useExperimentalImplementation: Bool = false) {
   
        self.contentNode = ASDisplayNode()
        self.patternImageLayer = EffectImageLayer()
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.frame

        self.contentNode.contentMode = .scaleAspectFill
        self.addSubnode(contentNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        self.validLayout = size
        
        transition.updatePosition(node: self.contentNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(), size: size))
        
        if let gradientBackgroundNode = self.gradientBackgroundNode {
            transition.updateFrame(node: gradientBackgroundNode, frame: contentNode.frame)
            gradientBackgroundNode.updateLayout(size: size, transition: transition, extendAnimation: false, backwards: false, completion: {})
        }
        
        loadPatternForSizeIfNeeded(size: size, transition: transition)
    }
    
    func update(state: CallBackgroundState) {
        guard state != self.state else {
            return
        }
//        let oldColors = state.wallpaper.map { UIColor(rgb: $0) }
        self.state = state

        let mappedColors = state.wallpaper.map { color -> UIColor in
            return UIColor(rgb: color)
        }

        var scheduleLoopingEvent = false
        if self.gradientBackgroundNode == nil {
            let gradientBackgroundNode = createGradientBackgroundNode(colors: mappedColors, useSharedAnimationPhase: false)
            self.dummedGradientBackgroundNode = createGradientBackgroundNode(colors: mappedColors, useSharedAnimationPhase: false)
            self.gradientBackgroundNode = gradientBackgroundNode
            self.insertSubnode(gradientBackgroundNode, aboveSubnode: self.contentNode)
            gradientBackgroundNode.setPatternOverlay(layer: self.patternImageLayer)
            
            if self.isLooping {
                scheduleLoopingEvent = true
            }
        }
        updateIsLooping(false)
        dummedGradientBackgroundNode?.updateColors(colors: mappedColors)
        
        let fadeAnim = CABasicAnimation(keyPath: "contents")
        fadeAnim.fromValue = gradientBackgroundNode?.contentView.image
        fadeAnim.toValue = dummedGradientBackgroundNode?.contentView.image
        fadeAnim.duration = 0.25
        fadeAnim.completion = { [weak self] comp in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateIsLooping(true)
            }
            
        }
        gradientBackgroundNode?.contentView.layer.add(fadeAnim, forKey: "contents")
        
        gradientBackgroundNode?.updateColors(colors: mappedColors)
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)

            if scheduleLoopingEvent {
                self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
            }
        }
    }
    
    private func loadPatternForSizeIfNeeded(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(), size: size))
    }
    
    private var isAnimating = false
    private var isLooping = false
    
    private var validLayout: CGSize?
    
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
        guard !(self.isLooping && self.isAnimating) else {
            return
        }
        self.isAnimating = true
        self.gradientBackgroundNode?.animateEvent(transition: transition, extendAnimation: extendAnimation, backwards: false, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.isAnimating = false
                if strongSelf.isLooping && strongSelf.validLayout != nil {
                    strongSelf.animateEvent(transition: transition, extendAnimation: extendAnimation)
                }
            }
        })
    }

    func updateIsLooping(_ isLooping: Bool) {
        let wasLooping = self.isLooping
        self.isLooping = isLooping

        if isLooping && !wasLooping {
            self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
        }
    }
}

enum CallBackgroundState {
    case initiating
    case established
    case weakSignal
    
    
    var wallpaper: [UInt32] {
        switch self {
        case .established:
            return [
                UIColor(hexString: "398D6F")!.rgb,
                UIColor(hexString: "3C9C8F")!.rgb,
                UIColor(hexString: "53A6DE")!.rgb,
                UIColor(hexString: "BAC05D")!.rgb
            ]
        case .initiating:
            return [
                UIColor(hexString: "5295D6")!.rgb,
                UIColor(hexString: "616AD5")!.rgb,
                UIColor(hexString: "7261DA")!.rgb,
                UIColor(hexString: "AC65D4")!.rgb
            ]
        case .weakSignal:
            return [
                UIColor(hexString: "FF7E46")!.rgb,
                UIColor(hexString: "B84498")!.rgb,
                UIColor(hexString: "C94986")!.rgb,
                UIColor(hexString: "F4992E")!.rgb
            ]
        }
    }
}
