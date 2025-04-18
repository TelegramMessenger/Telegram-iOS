import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import AvatarBackground
import AccountContext
import EmojiTextAttachmentView
import TextFormat
import ComponentFlow
import MultilineTextComponent

final class AvatarEditorPreviewView: UIView {
    private let context: AccountContext
    private var disposable: Disposable?
    private var files: [TelegramMediaFile] = []
    private var currentIndex = 0
    private var currentBackgroundIndex = 0
    private var switchingToNext = false
    
    private let backgroundView = UIImageView()
    private let label = ComponentView<Empty>()
    private var animationLayer: InlineStickerItemLayer?
    private var preloadDisposableSet =  DisposableSet()
    
    private var timer: SwiftSignalKit.Timer?
    
    private var currentSize: CGSize?
    
    var tapped: () -> Void = {}
    
    init(context: AccountContext) {
        self.context = context
        
        super.init(frame: .zero)
        
        self.addSubview(self.backgroundView)
        
        let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedProfilePhotoEmoji)
        self.disposable = (context.account.postbox.combinedView(keys: [stickersKey])
        |> runOn(Queue.concurrentDefaultQueue())
        |> deliverOnMainQueue).start(next: { [weak self] views in
            guard let self else {
                return
            }
            if let view = views.views[stickersKey] as? OrderedItemListView {
                var files: [TelegramMediaFile] = []
                for item in view.items.prefix(8) {
                    if let mediaItem = item.contents.get(RecentMediaItem.self) {
                        let file = mediaItem.media._parse()
                        files.append(file)
                        
                        self.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                    }
                }
                self.files = files
                if let size = self.currentSize {
                    self.updateLayout(size: size)
                }
            }
        })
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.addGestureRecognizer(tapRecognizer)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.disposable?.dispose()
        self.preloadDisposableSet.dispose()
        self.timer?.invalidate()
    }
    
    @objc private func handleTap() {
        self.tapped()
    }
    
    func updateLayout(size: CGSize) {
        self.currentSize = size
        self.backgroundView.frame = CGRect(origin: .zero, size: size)
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let labelSize = self.label.update(
            transition: .immediate,
            component: AnyComponent(
                MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationData.strings.MediaPicker_UseAnEmoji,
                        font: Font.semibold(12.0),
                        textColor: .white
                    )),
                    textShadowColor: UIColor(white: 0.0, alpha: 0.3),
                    textShadowBlur: 3.0
                )
            ),
            environment: {},
            containerSize: size
        )
        if let view = self.label.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: size.height - labelSize.height - 22.0), size: labelSize)
        }
        
        guard !self.files.isEmpty else {
            if self.backgroundView.image == nil {
                self.backgroundView.image = AvatarBackground.defaultBackgrounds[self.currentBackgroundIndex].generateImage(size: size)
            }
            return
        }
        
        if self.timer == nil {
            self.timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.switchingToNext = true
                if let size = self.currentSize {
                    self.updateLayout(size: size)
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        let iconSize = CGSize(width: 64.0, height: 64.0)
        let animationLayer: InlineStickerItemLayer
        var disappearingAnimationLayer: InlineStickerItemLayer?
        if let current = self.animationLayer, !self.switchingToNext {
            animationLayer = current
        } else {
            if self.switchingToNext {
                self.currentIndex = (self.currentIndex + 1) % self.files.count
                self.currentBackgroundIndex = (self.currentBackgroundIndex + 1) % AvatarBackground.defaultBackgrounds.count
                disappearingAnimationLayer = self.animationLayer
                self.switchingToNext = false
            }
            
            if let image = self.backgroundView.image {
                let snapshotView = UIImageView(image: image)
                self.insertSubview(snapshotView, aboveSubview: self.backgroundView)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
            }
            self.backgroundView.image = AvatarBackground.defaultBackgrounds[self.currentBackgroundIndex].generateImage(size: size)
            
            let file = self.files[self.currentIndex]
            let emoji = ChatTextInputTextCustomEmojiAttribute(
                interactivelySelectedFromPackId: nil,
                fileId: file.fileId.id,
                file: file
            )
            animationLayer = InlineStickerItemLayer(
                context: .account(self.context),
                userLocation: .other,
                attemptSynchronousLoad: false,
                emoji: emoji,
                file: file,
                cache: self.context.animationCache,
                renderer: self.context.animationRenderer,
                unique: true,
                placeholderColor: UIColor(white: 1.0, alpha: 0.1),
                pointSize: iconSize,
                loopCount: 1
            )
            animationLayer.isVisibleForAnimations = true
            self.layer.addSublayer(animationLayer)
            self.animationLayer = animationLayer
            
            animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            animationLayer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: .zero, duration: 0.2, additive: true)
            animationLayer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
        }
        
        
        animationLayer.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0) - 10.0), size: iconSize)
         
        if let disappearingAnimationLayer {
            disappearingAnimationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                disappearingAnimationLayer.removeFromSuperlayer()
            })
            disappearingAnimationLayer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -10.0), duration: 0.2, removeOnCompletion: false, additive: true)
            disappearingAnimationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
        }
    }
}
