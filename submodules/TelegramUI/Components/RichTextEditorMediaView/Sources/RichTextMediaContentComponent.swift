import Foundation
import LottieSettings
import UIKit
import ComponentFlow
import Display
import RichTextEditorUIKit
import AccountContext
import TelegramCore
import SwiftSignalKit
import PhotoResources
import RadialStatusNode
import LottieComponent
import GlassBackgroundComponent
import InvisibleInkDustNode

/// A composable ComponentFlow renderer for ONE rich-text still image or video poster. Owns its
/// own `TransformImageNode` + media-fetch signal + aspect-fill layout, decoupled from
/// `InstantPageImageNode`. Carries a glass "more" button; interaction is **control-scoped** — the
/// `View.hitTest` returns a control ONLY when the touch lands on it (the poster passes through to the
/// editor's own tap handling), which is how the button is tappable without stealing caret/media-select
/// taps. Built as a plain `Component` so a future mosaic/slideshow wrapper can compose it without
/// structural change. Location (`.geo`) and audio are handled by `MediaItemNodeView`, not here.
@available(iOS 13.0, *)
public final class RichTextMediaContentComponent: Component {
    public let context: AccountContext
    public let media: EngineMedia
    /// Whether the glass "more" button is shown. Constant per usage (composer vs. article editor); not
    /// part of `==` for the same reason `onControlTapped` isn't — identity equality must hold across
    /// resizes so the fetch binds once.
    public let showsMoreButton: Bool

    /// When true, the poster is drawn aspect-FIT with a blurred aspect-filled backdrop (chat's
    /// `.blurBackground`) — used for a lone photo/video so a portrait/panorama shows whole with a blurred
    /// letterbox/pillarbox instead of being cropped. Mosaic cells leave it false (crop-to-fill). NOT part
    /// of `==` (identity equality must hold across resizes so the fetch binds once); the host re-sets it
    /// each layout pass, so a cell reused across a single↔mosaic transition switches mode.
    var usesAspectFit: Bool

    /// Telegram-style spoiler: the poster renders behind a heavily-blurred (`.blurBackground`) overlay +
    /// an animated "dust" cover, both owned by this cell so a mosaic of items each spoilers independently.
    /// Non-revealable authoring cover (the message-render side owns reveal). UNLIKE `usesAspectFit`, this
    /// IS part of `==`: it can toggle WITHOUT a size change (the edit-menu / ••• Spoiler action), and the
    /// host (`ComponentHostView`) skips `update` when the component compares equal at an unchanged size —
    /// so omitting it here would make a spoiler toggle a visual no-op. It does not vary across resizes, so
    /// including it does not defeat the fetch-binds-once optimization.
    var isSpoiler: Bool

    /// Set by `MediaItemNodeView`; fired when an interactive control is tapped. Not part of `==` (identity
    /// equality must hold across resizes so the fetch binds once).
    var onControlTapped: ((RichTextMediaControlKind, UIView, CGRect) -> Void)?

    public init(context: AccountContext, media: EngineMedia, showsMoreButton: Bool = true, usesAspectFit: Bool = false, isSpoiler: Bool = false) {
        self.context = context
        self.media = media
        self.showsMoreButton = showsMoreButton
        self.usesAspectFit = usesAspectFit
        self.isSpoiler = isSpoiler
    }

    public static func ==(lhs: RichTextMediaContentComponent, rhs: RichTextMediaContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.media.id != rhs.media.id {
            return false
        }
        if lhs.isSpoiler != rhs.isSpoiler {
            return false
        }
        return true
    }
    
    private final class ButtonView: UIView {
        
    }

    public final class View: UIView {
        private let imageNode = TransformImageNode()
        private var statusNode: RadialStatusNode?
        private let fetchDisposable = MetaDisposable()
        // Spoiler visuals, owned per-cell: a heavily-blurred (`.blurBackground`) overlay occluding the
        // sharp poster, plus a `MediaDustNode` particle cover on top. A SEPARATE blur node is required —
        // `TransformImageArguments.==` ignores `resizeMode`, so flipping the main node's resizeMode alone
        // would early-out and never re-render. Both are non-revealable authoring covers (taps fall through
        // to the editor). `currentMediaSignal` is the poster signal, reused for the blur (no extra fetch).
        private var blurNode: TransformImageNode?
        private var dustNode: MediaDustNode?
        private var blurBoundMediaId: EngineMedia.Id?
        // The BLURRED signal for the spoiler cover (`chatSecretPhoto`/`chatSecretMessageVideo`, which render
        // `blurred: true` — the sharp foreground is suppressed, unlike `.blurBackground` on a sharp signal,
        // which only fills the letterbox gaps and is covered by the sharp image). Same source as the poster.
        private var currentBlurredSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?

        private let moreButtonBackgroundContainer: GlassBackgroundContainerView
        private let moreButton: HighlightTrackingButton
        private let moreButtonBackground: GlassBackgroundView
        private let moreButtonIcon = ComponentView<Empty>()

        private var boundMediaId: EngineMedia.Id?
        private var didBind = false

        // Pre-upload progress is owned HERE, not passed in by the host. The editor re-provides a media
        // view only when its item signature changes (DocumentCanvasView+Media.syncMediaItemViews), and
        // upload progress is not — and cannot be — part of that signature, so a host-pushed value never
        // arrives during an upload. Subscribing here mirrors how this view already owns its own fetch.
        private let preuploadDisposable = MetaDisposable()
        private var boundPreuploadMediaId: EngineMedia.Id?
        private var preuploadProgress: Float?
        private var dimensions: PixelDimensions?
        private var isVideo = false
        private var currentSize: CGSize?
        
        private var component: RichTextMediaContentComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            self.moreButton = HighlightTrackingButton()
            self.moreButtonBackgroundContainer = GlassBackgroundContainerView()
            self.moreButtonBackground = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.imageNode.view)
            
            self.moreButtonBackground.isUserInteractionEnabled = false
            self.moreButton.addSubview(self.moreButtonBackground)
            self.moreButtonBackgroundContainer.contentView.addSubview(self.moreButton)
            self.addSubview(self.moreButtonBackgroundContainer)
            
            self.moreButton.addTarget(self, action: #selector(self.moreButtonPressed), for: .touchUpInside)
            self.moreButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.25)
                transition.setAlpha(view: self.moreButton, alpha: highlighted ? 0.6 : 1.0)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable.dispose()
            self.preuploadDisposable.dispose()
        }

        /// Subscribe once per media id. Holds NO pre-upload need — observing must never keep an
        /// orphaned upload alive; the need belongs to whatever owns the content.
        private func bindPreuploadIfNeeded(context: AccountContext, media: EngineMedia) {
            guard let mediaId = media.id else {
                return
            }
            if self.boundPreuploadMediaId == mediaId {
                return
            }
            self.boundPreuploadMediaId = mediaId
            self.preuploadProgress = nil
            self.preuploadDisposable.set((context.engine.messages.mediaPreuploadState(id: mediaId)
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                let progress: Float?
                switch state {
                case let .progress(value):
                    progress = value
                case .done, .failed, .none:
                    progress = nil
                }
                guard self.preuploadProgress != progress else {
                    return
                }
                self.preuploadProgress = progress
                // Refresh the status node DIRECTLY rather than via `state.updated()`. A component
                // re-render re-runs `update`, which re-issues the image fetch unconditionally
                // (`fetchDisposable.set(...)`), so driving per-tick progress through the component
                // would refetch the poster on every tick.
                if let size = self.currentSize {
                    self.updateStatusNode(availableSize: size, isSpoiler: self.component?.isSpoiler ?? false)
                }
            }))
        }

        /// The centre overlay: upload progress while pre-uploading, else a play button for video.
        private func updateStatusNode(availableSize: CGSize, isSpoiler: Bool) {
            guard self.isVideo || self.preuploadProgress != nil else {
                self.statusNode?.view.isHidden = true
                return
            }
            let statusNode: RadialStatusNode
            if let existing = self.statusNode {
                statusNode = existing
            } else {
                statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
                self.addSubview(statusNode.view)   // RadialStatusNode is an ASControlNode; host its .view
                self.statusNode = statusNode
            }
            // Chosen every pass rather than once at construction: a medium transitions from uploading
            // to idle in place, and a photo has no resting state at all.
            let state: RadialStatusNodeState
            if let progress = self.preuploadProgress {
                state = .progress(color: .white, lineWidth: nil, value: CGFloat(progress), cancelEnabled: false, animateRotation: true)
            } else {
                state = .play(.white)
            }
            statusNode.transitionToState(state, animated: true, completion: {})
            let statusSize: CGFloat = max(18.0, min(50.0, floor(min(availableSize.width, availableSize.height) * 0.7)))
            statusNode.frame = CGRect(x: floorToScreenPixels((availableSize.width - statusSize) / 2.0), y: floorToScreenPixels((availableSize.height - statusSize) / 2.0), width: statusSize, height: statusSize)
            // A spoilered video hides its play button under the blur (mirrors the message side);
            // upload progress stays visible, since a spoiler is about the recipient, not the sender.
            statusNode.view.isHidden = isSpoiler && self.preuploadProgress == nil
        }

        /// Only the interactive chrome (the more button) claims a touch; the image/video poster area
        /// returns nil so the touch passes through to the editor, which runs its own tap handling
        /// (caret placement / media-select highlight). Routes through the button's
        /// `GlassBackgroundContainerView`, whose own `hitTest` already returns the button when hit and
        /// nil otherwise. Add any future interactive controls to this override.
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let inButton = self.moreButtonBackgroundContainer.convert(point, from: self)
            return self.moreButtonBackgroundContainer.hitTest(inButton, with: event)
        }

        @objc private func moreButtonPressed() {
            self.component?.onControlTapped?(.more, self.moreButtonBackgroundContainer,
                                             self.moreButtonBackgroundContainer.bounds)
        }
        
        func update(component: RichTextMediaContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let context = component.context
            self.fetchDisposable.set(nil)
            self.statusNode?.view.removeFromSuperview()
            self.statusNode = nil
            self.isVideo = false
            self.dimensions = nil

            if case let .image(image) = component.media, let largest = largestImageRepresentation(image.representations) {
                self.dimensions = largest.dimensions
                let imageReference = ImageMediaReference.standalone(media: image)
                self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, userLocation: .other, photoReference: imageReference))
                self.currentBlurredSignal = chatSecretPhoto(account: context.account, userLocation: .other, photoReference: imageReference, ignoreFullSize: true)
                self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: .other, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
            } else if case let .file(file) = component.media {
                self.dimensions = file.dimensions
                let fileReference = FileMediaReference.standalone(media: file)
                if file.mimeType.hasPrefix("image/") {
                    _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: fileReference).start()
                    self.imageNode.setSignal(instantPageImageFile(account: context.account, userLocation: .other, fileReference: fileReference, fetched: true))
                } else {
                    self.imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox, userLocation: .other, videoReference: fileReference))
                    self.isVideo = true
                }
                self.currentBlurredSignal = chatSecretMessageVideo(account: context.account, userLocation: .other, videoReference: fileReference)
            }
            // else: unexpected media kind (.geo / audio reach here only by misuse) — leave the
            // node blank rather than crash.
            
            self.imageNode.frame = CGRect(origin: .zero, size: availableSize)

            let emptyColor = component.context.sharedContext.currentPresentationData.with { $0 }.theme.list.mediaPlaceholderColor
            if let dimensions = self.dimensions {
                let imageSize: CGSize
                let resizeMode: TransformImageResizeMode
                if component.usesAspectFit {
                    imageSize = dimensions.cgSize.aspectFitted(availableSize)
                    resizeMode = .blurBackground
                } else {
                    imageSize = dimensions.cgSize.aspectFilled(availableSize)
                    resizeMode = .fill(.black)
                }
                let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets(), resizeMode: resizeMode, emptyColor: emptyColor))
                apply()
            }

            // Spoiler: a heavily-blurred `.blurBackground` overlay occluding the sharp poster, plus a
            // `MediaDustNode` particle cover on top — both owned by this cell. Non-revealable authoring
            // cover: the dust does not reveal on tap and is non-interactive, so taps fall through to the
            // editor (caret / media-select). Ordered above the poster but BELOW the more/add controls
            // (which were added to `self` in init, so they stay on top and remain tappable).
            if component.isSpoiler, let dimensions = self.dimensions, let signal = self.currentBlurredSignal {
                let blurNode: TransformImageNode
                if let existing = self.blurNode {
                    blurNode = existing
                } else {
                    blurNode = TransformImageNode()
                    blurNode.contentAnimations = []
                    self.blurNode = blurNode
                    self.insertSubview(blurNode.view, aboveSubview: self.imageNode.view)
                }
                if self.blurBoundMediaId != component.media.id {
                    self.blurBoundMediaId = component.media.id
                    blurNode.setSignal(signal)
                }
                blurNode.view.isHidden = false
                blurNode.frame = CGRect(origin: .zero, size: availableSize)
                let blurImageSize = dimensions.cgSize.aspectFilled(availableSize)
                let blurApply = blurNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: blurImageSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .blurBackground, emptyColor: emptyColor))
                blurApply()

                let dustNode: MediaDustNode
                if let existing = self.dustNode {
                    dustNode = existing
                } else {
                    dustNode = MediaDustNode(enableAnimations: context.sharedContext.energyUsageSettings.fullTranslucency)
                    dustNode.revealOnTap = false
                    dustNode.isUserInteractionEnabled = false
                    self.dustNode = dustNode
                    self.insertSubview(dustNode.view, aboveSubview: blurNode.view)
                }
                dustNode.view.isHidden = false
                dustNode.view.frame = CGRect(origin: .zero, size: availableSize)
                dustNode.update(size: availableSize, color: .white, transition: .immediate)
            } else {
                self.blurNode?.view.isHidden = true
                self.dustNode?.view.isHidden = true
            }

            self.currentSize = availableSize
            self.bindPreuploadIfNeeded(context: context, media: component.media)
            self.updateStatusNode(availableSize: availableSize, isSpoiler: component.isSpoiler)
            
            let buttonSize = CGSize(width: 36.0, height: 36.0)
            let buttonHorizontalInset: CGFloat = 8.0
            let buttonVerticalInset: CGFloat = 8.0
            
            let moreButtonFrame = CGRect(origin: CGPoint(x: buttonHorizontalInset, y: buttonVerticalInset), size: buttonSize)
            
            transition.setFrame(view: self.moreButtonBackgroundContainer, frame: moreButtonFrame)
            self.moreButtonBackgroundContainer.update(size: buttonSize, isDark: true, transition: transition)
            
            transition.setFrame(view: self.moreButtonBackground, frame: CGRect(origin: CGPoint(), size: moreButtonFrame.size))
            self.moreButtonBackground.update(size: moreButtonFrame.size, cornerRadius: moreButtonFrame.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: transition)
            
            transition.setFrame(view: self.moreButton, frame: CGRect(origin: CGPoint(), size: moreButtonFrame.size))
            
            let buttonIconSize = self.moreButtonIcon.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_baremoredots"),
                    color: .white,
                    startingPosition: .begin,
                    lottieSettings: component.context.lottieRenderingSettings
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let moreButtonIconView = self.moreButtonIcon.view {
                if moreButtonIconView.superview == nil {
                    self.moreButtonBackground.contentView.addSubview(moreButtonIconView)
                }
                transition.setFrame(view: moreButtonIconView, frame: buttonIconSize.centered(in: CGRect(origin: CGPoint(), size: buttonSize)))
            }

            self.moreButtonBackgroundContainer.isHidden = !component.showsMoreButton

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
