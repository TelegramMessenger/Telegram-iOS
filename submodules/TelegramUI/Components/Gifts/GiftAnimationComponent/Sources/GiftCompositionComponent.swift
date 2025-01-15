import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AppBundle
import AccountContext
import EmojiTextAttachmentView
import TextFormat
import PeerInfoCoverComponent
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import EmojiStatusComponent

public final class GiftCompositionComponent: Component {
    public class ExternalState {
        public fileprivate(set) var previewPatternColor: UIColor?
        public init() {
            self.previewPatternColor = nil
        }
    }
    
    public enum Subject: Equatable {
        case generic(TelegramMediaFile)
        case unique(StarGift.UniqueGift)
        case preview([StarGift.UniqueGift.Attribute])
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let subject: Subject
    let animationOffset: CGPoint?
    let animationScale: CGFloat?
    let displayAnimationStars: Bool
    let externalState: ExternalState?
    let requestUpdate: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        subject: Subject,
        animationOffset: CGPoint? = nil,
        animationScale: CGFloat? = nil,
        displayAnimationStars: Bool = false,
        externalState: ExternalState? = nil,
        requestUpdate: @escaping () -> Void = {}
    ) {
        self.context = context
        self.theme = theme
        self.subject = subject
        self.animationOffset = animationOffset
        self.animationScale = animationScale
        self.displayAnimationStars = displayAnimationStars
        self.externalState = externalState
        self.requestUpdate = requestUpdate
    }

    public static func ==(lhs: GiftCompositionComponent, rhs: GiftCompositionComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.animationOffset != rhs.animationOffset {
            return false
        }
        if lhs.animationScale != rhs.animationScale {
            return false
        }
        if lhs.displayAnimationStars != rhs.displayAnimationStars {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: GiftCompositionComponent?
        private weak var componentState: EmptyComponentState?
        
        private var starsLayer: StarsEffectLayer?
        
        private let background = ComponentView<Empty>()
        private var animationNode: AnimatedStickerNode?
        
        private var disposables = DisposableSet()
        private var fetchedFiles = Set<Int64>()
        
        private var previewTimer: SwiftSignalKit.Timer?
        
        private var currentFile: TelegramMediaFile?
        private var previewModels: [StarGift.UniqueGift.Attribute] = []
        private var previewBackdrops: [StarGift.UniqueGift.Attribute] = []
        private var previewPatterns: [StarGift.UniqueGift.Attribute] = []
        
        private var previewModelIndex: Int32 = 0
        private var previewBackdropIndex: Int32 = 0
        private var previewPatternIndex: Int32 = 0
        private var animatePreviewTransition = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposables.dispose()
        }
        
        @objc private func handleTap() {
            guard let animationNode = animationNode as? DefaultAnimatedStickerNodeImpl else {
                return
            }
            if case .once = animationNode.playbackMode, !animationNode.isPlaying {
                animationNode.playOnce()
            }
        }
        
        public func update(component: GiftCompositionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.componentState = state
            
            var animationFile: TelegramMediaFile?
            var backgroundColor: UIColor?
            var secondBackgroundColor: UIColor?
            var patternColor: UIColor?
            var patternFile: TelegramMediaFile?
            var files: [Int64: TelegramMediaFile] = [:]
                        
            var loop = false
            switch component.subject {
            case let .generic(file):
                animationFile = file
                self.currentFile = file
                
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }
            case let .unique(gift):
                for attribute in gift.attributes {
                    switch attribute {
                    case let .model(_, file, _):
                        animationFile = file
                        if !self.fetchedFiles.contains(file.fileId.id) {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                            self.fetchedFiles.insert(file.fileId.id)
                        }
                    case let .pattern(_, file, _):
                        patternFile = file
                        files[file.fileId.id] = file
                    case let .backdrop(_, innerColorValue, outerColorValue, patternColorValue, _, _):
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                    default:
                        break
                    }
                }
                
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }
            case let .preview(sampleAttributes):
                loop = true
                
                if self.previewModels.isEmpty {
                    var models: [StarGift.UniqueGift.Attribute] = []
                    var patterns: [StarGift.UniqueGift.Attribute] = []
                    var backdrops: [StarGift.UniqueGift.Attribute] = []
                    for attribute in sampleAttributes {
                        switch attribute {
                        case .model:
                            models.append(attribute)
                        case .pattern:
                            patterns.append(attribute)
                        case .backdrop:
                            backdrops.append(attribute)
                        default:
                            break
                        }
                    }
                    self.previewModels = models
                    self.previewPatterns = patterns
                    self.previewBackdrops = backdrops
                }
                
                for case let .model(_, file, _) in self.previewModels {
                    if !self.fetchedFiles.contains(file.fileId.id) {
                        self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                        self.fetchedFiles.insert(file.fileId.id)
                    }
                }
                
                for case let .pattern(_, file, _) in self.previewModels {
                    if !self.fetchedFiles.contains(file.fileId.id) {
                        self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                        self.fetchedFiles.insert(file.fileId.id)
                    }
                }
                
                if !self.previewModels.isEmpty {
                    if case let .model(_, file, _) = self.previewModels[Int(self.previewModelIndex)] {
                        animationFile = file
                    }
                    
                    if case let .pattern(_, file, _) = self.previewPatterns[Int(self.previewPatternIndex)] {
                        patternFile = file
                        files[file.fileId.id] = file
                    }
                    
                    if case let .backdrop(_, innerColorValue, outerColorValue, patternColorValue, _, _) = self.previewBackdrops[Int(self.previewBackdropIndex)] {
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                    }
                }
                    
                if self.previewTimer == nil {
                    self.previewTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                        guard let self, !self.previewModels.isEmpty else {
                            return
                        }
                        self.previewModelIndex = (self.previewModelIndex + 1) % Int32(self.previewModels.count)
                        
                        let previousPatternIndex = self.previewPatternIndex
                        var randomPatternIndex = previousPatternIndex
                        while randomPatternIndex == previousPatternIndex {
                            randomPatternIndex = Int32.random(in: 0 ..< Int32(self.previewPatterns.count))
                        }
                        self.previewPatternIndex = randomPatternIndex
                        
                        let previousBackdropIndex = self.previewBackdropIndex
                        var randomBackdropIndex = previousBackdropIndex
                        while randomBackdropIndex == previousBackdropIndex {
                            randomBackdropIndex = Int32.random(in: 0 ..< Int32(self.previewBackdrops.count))
                        }
                        self.previewBackdropIndex = randomBackdropIndex
                        
                        self.animatePreviewTransition = true
                        self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    }, queue: Queue.mainQueue())
                    self.previewTimer?.start()
                }
            }
            
            component.externalState?.previewPatternColor = secondBackgroundColor
                                    
            var animateTransition = false
            if self.animatePreviewTransition {
                animateTransition = true
                self.animatePreviewTransition = false
            } else if let previousComponent, case .preview = previousComponent.subject, case .unique = component.subject {
                animateTransition = true
            } else if let previousComponent, case .generic = previousComponent.subject, case .preview = component.subject {
                animateTransition = true
            } else if let previousComponent, case .preview = previousComponent.subject, case .generic = component.subject {
                animateTransition = true
            }
            
            if let backgroundColor {
                var backgroundTransition = transition
                
                if animateTransition, let backgroundView = self.background.view as? PeerInfoCoverComponent.View {
                    backgroundView.animateTransition()
                }
                
                var avatarCenter = CGPoint(x: availableSize.width / 2.0, y: 104.0)
                if let _ = component.animationScale {
                    avatarCenter = CGPoint(x: avatarCenter.x, y: 67.0)
                }
                
                let _ = self.background.update(
                    transition: backgroundTransition,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: component.context,
                        subject: .custom(backgroundColor, secondBackgroundColor, patternColor, patternFile?.fileId.id),
                        files: files,
                        isDark: false,
                        avatarCenter: avatarCenter,
                        avatarScale: 1.0,
                        defaultHeight: 300.0,
                        gradientOnTop: true,
                        avatarTransitionFraction: 0.0,
                        patternTransitionFraction: 0.0
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let backgroundView = self.background.view {
                    if backgroundView.superview == nil {
                        backgroundTransition = .immediate
                        backgroundView.clipsToBounds = true
                        backgroundView.isUserInteractionEnabled = false
                        self.insertSubview(backgroundView, at: 0)
                        
                        if previousComponent != nil {
                            backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    backgroundTransition.setFrame(view: backgroundView, frame: CGRect(origin: .zero, size: availableSize))
                }
            } else if let backgroundView = self.background.view, backgroundView.superview != nil {
                backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    backgroundView.removeFromSuperview()
                })
            }
              
            let iconSize = CGSize(width: 136.0, height: 136.0)
            
            var startFromIndex: Int?
            var animationTransition = transition
            if animateTransition, let disappearingAnimationNode = self.animationNode {
                self.animationNode = nil
                startFromIndex = disappearingAnimationNode.currentFrameIndex
                disappearingAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    disappearingAnimationNode.view.removeFromSuperview()
                })
                animationTransition = .immediate
            }
            
            if let file = animationFile {
                let animationNode: AnimatedStickerNode
                if self.animationNode == nil {
                    animationTransition = .immediate
                    animationNode = DefaultAnimatedStickerNodeImpl()
                    animationNode.isUserInteractionEnabled = false
                    self.animationNode = animationNode

                    self.addSubview(animationNode.view)
                    
                    let pathPrefix = component.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                    animationNode.setup(source: AnimatedStickerResourceSource(account: component.context.account, resource: file.resource, isVideo: file.isVideoSticker), width: Int(iconSize.width * 1.6), height: Int(iconSize.height * 1.6), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
                                     
                    if let startFromIndex {
                        if let animationNode = animationNode as? DefaultAnimatedStickerNodeImpl {
                            animationNode.playbackMode = loop ? .loop : .once
                        }
                        animationNode.play(firstFrame: false, fromIndex: startFromIndex)
                    } else {
                        if loop {
                            animationNode.playLoop()
                        } else {
                            animationNode.playOnce()
                        }
                    }
                    animationNode.visibility = true
                    animationNode.updateLayout(size: iconSize)
                    
                    if animateTransition {
                        animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
            }
            if let animationNode = self.animationNode {
                let offset = component.animationOffset ?? .zero
                var size = CGSize(width: iconSize.width, height: iconSize.height)
                if let scale = component.animationScale {
                    size = CGSize(width: size.width * scale, height: size.height * scale)
                }
                let animationFrame = CGRect(origin: CGPoint(x: availableSize.width / 2.0 + offset.x - size.width / 2.0, y: 88.0 + offset.y - size.height / 2.0), size: size)
                animationNode.layer.bounds = CGRect(origin: .zero, size: iconSize)
                animationTransition.setPosition(layer: animationNode.layer, position: animationFrame.center)
                animationTransition.setScale(layer: animationNode.layer, scale: size.width / iconSize.width)
                
                if component.displayAnimationStars {
                    var starsTransition = transition
                    let starsLayer: StarsEffectLayer
                    if let current = self.starsLayer {
                        starsLayer = current
                    } else {
                        starsTransition = .immediate
                        starsLayer = StarsEffectLayer()
                        self.layer.insertSublayer(starsLayer, below: animationNode.layer)
                        self.starsLayer = starsLayer
                        starsLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                    let starsSize = CGSize(width: 36.0, height: 36.0)
                    starsLayer.update(color: .white, size: starsSize)
                    starsLayer.bounds = CGRect(origin: .zero, size: starsSize)
                    starsTransition.setPosition(layer: starsLayer, position: animationFrame.center)
                } else if let starsLayer = self.starsLayer {
                    self.starsLayer = nil
                    transition.setPosition(layer: starsLayer, position: animationFrame.center)
                    starsLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        starsLayer.removeFromSuperlayer()
                    })
                }
            }
                        
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class StarsEffectLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(color: UIColor) {
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 8.0
        emitter.lifetime = 2.0
        emitter.velocity = 0.1
        emitter.scale = 0.12
        emitter.scaleRange = 0.02
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.withAlphaComponent(0.55).cgColor,
            color.withAlphaComponent(0.55).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        self.emitterLayer.emitterCells = [emitter]
    }
    
    func update(color: UIColor, size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup(color: color)
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = size
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
