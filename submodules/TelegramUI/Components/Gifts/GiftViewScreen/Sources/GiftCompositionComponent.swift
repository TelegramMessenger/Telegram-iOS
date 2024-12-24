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

final class GiftCompositionComponent: Component {
    enum Subject: Equatable {
        case generic(TelegramMediaFile)
        case unique(TelegramMediaFile, UIColor, TelegramMediaFile?)
        case preview([TelegramMediaFile], [TelegramMediaFile])
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let subject: Subject
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        subject: Subject
    ) {
        self.context = context
        self.theme = theme
        self.subject = subject
    }

    static func ==(lhs: GiftCompositionComponent, rhs: GiftCompositionComponent) -> Bool {
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

    final class View: UIView {
        private var component: GiftCompositionComponent?
        private weak var componentState: EmptyComponentState?
        
        private let background = ComponentView<Empty>()
        private var animationNode: AnimatedStickerNode?
        
        private var previewTimer: SwiftSignalKit.Timer?
        private var previewAnimationIndex: Int32 = 0
        private var previewBackgroundIndex: Int32 = 0
        private var previewBackgroundFileIndex: Int32 = 1
        private var animatePreviewTransition = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GiftCompositionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.componentState = state
            
            var animationFile: TelegramMediaFile?
            var backgroundColor: UIColor?
            var secondBackgroundColor: UIColor?
            var backgroundFile: TelegramMediaFile?
            var files: [Int64: TelegramMediaFile] = [:]
            
            switch component.subject {
            case let .generic(file):
                animationFile = file
                                
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }
            case let .unique(file, color, icon):
                animationFile = file
                backgroundColor = color
                backgroundFile = icon
                if let backgroundFile {
                    files[backgroundFile.fileId.id] = backgroundFile
                }
                
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }
            case let .preview(iconFiles, backgroundFiles):
                animationFile = iconFiles[Int(self.previewAnimationIndex)]
                
                let colors = component.context.peerNameColors.profileColors[self.previewBackgroundIndex]
                backgroundColor = colors?.main
                secondBackgroundColor = colors?.secondary
                
                backgroundFile = backgroundFiles[Int(self.previewBackgroundFileIndex)]
                if let backgroundFile {
                    files[backgroundFile.fileId.id] = backgroundFile
                }
                
                for file in iconFiles {
                    let _ = freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start()
                }
                
                if self.previewTimer == nil {
                    self.previewTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.previewAnimationIndex = (self.previewAnimationIndex + 1) % Int32(iconFiles.count)
                        self.previewBackgroundIndex = (self.previewBackgroundIndex + 1) % Int32(component.context.peerNameColors.profileColors.count)
                        self.previewBackgroundFileIndex = (self.previewBackgroundFileIndex + 1) % Int32(backgroundFiles.count)
                        self.animatePreviewTransition = true
                        self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    }, queue: Queue.mainQueue())
                    self.previewTimer?.start()
                }
            }
            
            var animateTransition = false
            if self.animatePreviewTransition {
                animateTransition = true
                self.animatePreviewTransition = false
            } else if let previousComponent, case .preview = previousComponent.subject, case .unique = component.subject {
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
                        subject: .custom(backgroundColor, secondBackgroundColor, backgroundFile?.fileId.id),
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
                        self.insertSubview(backgroundView, at: 0)
                        
                        backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                    backgroundTransition.setFrame(view: backgroundView, frame: CGRect(origin: .zero, size: availableSize))
                }
            } else if let backgroundView = self.background.view, backgroundView.superview != nil {
                backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, completion: { _ in
                    backgroundView.removeFromSuperview()
                })
            }
              
            let iconSize = CGSize(width: 128.0, height: 128.0)
            
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
                    self.animationNode = animationNode

                    self.addSubview(animationNode.view)
                    
                    let pathPrefix = component.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                    animationNode.setup(source: AnimatedStickerResourceSource(account: component.context.account, resource: file.resource, isVideo: file.isVideoSticker), width: Int(iconSize.width * 1.6), height: Int(iconSize.height * 1.6), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
                                        
                    if let startFromIndex {
                        animationNode.play(firstFrame: false, fromIndex: startFromIndex)
                        //animationNode.seekTo(.frameIndex(startFromIndex))
                    } else {
                        animationNode.playLoop()
                    }
                    animationNode.visibility = true
                    animationNode.updateLayout(size: iconSize)
                    
                    if animateTransition {
                        animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
            }
                
//            if self.animationLayer == nil, let animationFile {
//                let emoji = ChatTextInputTextCustomEmojiAttribute(
//                    interactivelySelectedFromPackId: nil,
//                    fileId: animationFile.fileId.id,
//                    file: animationFile
//                )
//                
//                let animationLayer = InlineStickerItemLayer(
//                    context: .account(component.context),
//                    userLocation: .other,
//                    attemptSynchronousLoad: false,
//                    emoji: emoji,
//                    file: animationFile,
//                    cache: component.context.animationCache,
//                    renderer: component.context.animationRenderer,
//                    unique: true,
//                    placeholderColor: component.theme.list.mediaPlaceholderColor,
//                    pointSize: CGSize(width: iconSize.width * 1.2, height: iconSize.height * 1.2),
//                    loopCount: 1
//                )
//                animationLayer.isVisibleForAnimations = true
//                self.animationLayer = animationLayer
//                self.layer.addSublayer(animationLayer)
//            }
            if let animationNode = self.animationNode {
                transition.setFrame(layer: animationNode.layer, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: 25.0), size: iconSize))
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
