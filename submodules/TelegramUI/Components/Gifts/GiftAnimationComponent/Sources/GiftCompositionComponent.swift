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
    let externalState: ExternalState?
    let requestUpdate: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        subject: Subject,
        externalState: ExternalState? = nil,
        requestUpdate: @escaping () -> Void = {}
    ) {
        self.context = context
        self.theme = theme
        self.subject = subject
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
        return true
    }

    public final class View: UIView {
        private var component: GiftCompositionComponent?
        private weak var componentState: EmptyComponentState?
        
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
                let _ = self.background.update(
                    transition: backgroundTransition,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: component.context,
                        subject: .custom(backgroundColor, secondBackgroundColor, patternColor, patternFile?.fileId.id),
                        files: files,
                        isDark: false,
                        avatarCenter: CGPoint(x: availableSize.width / 2.0, y: 104.0),
                        avatarScale: 1.0,
                        defaultHeight: availableSize.height,
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
                        
                        backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
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
            if animateTransition, let disappearingAnimationNode = self.animationNode {
                self.animationNode = nil
                startFromIndex = disappearingAnimationNode.currentFrameIndex
                disappearingAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    disappearingAnimationNode.view.removeFromSuperview()
                })
            }
            
            if let file = animationFile {
                let animationNode: AnimatedStickerNode
                if self.animationNode == nil {
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
                transition.setFrame(layer: animationNode.layer, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: 20.0), size: iconSize))
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
