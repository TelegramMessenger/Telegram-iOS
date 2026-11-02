import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext

/// Where placeholders draw when they need not be ready at once. Concurrent, at the priority of ASDK's display queue
/// (`_ASDisplayLayer` targets the high-priority global queue), so they land no later than `AvatarNode`'s did; not the
/// default-QoS concurrent queue, where every row's photo decodes.
private let avatarComponentDisplayQueue = Queue(queue: DispatchQueue(label: "AvatarComponent.display", qos: .userInitiated, attributes: .concurrent))

/// The placeholder bitmap, as ASDK rasterizes `AvatarNode.ContentNode`: transparent, at the screen's scale.
private func renderAvatarPlaceholder(size: CGSize, parameters: AvatarNodeParameters?) -> UIImage {
    return UIGraphicsImageRenderer(size: size, format: .preferred()).image { _ in
        drawAvatarNodeContent(bounds: CGRect(origin: CGPoint(), size: size), parameters: parameters, isRasterizing: false)
    }
}

/// `ImageNode` as `AvatarNode.ContentNode` uses it: a photo delivered at once shows at once, the first one that arrives
/// later fades in, a later one crossfades over the previous, and no photo leaves the last one in place.
private final class AvatarComponentImageLayer: SimpleLayer {
    private let disposable = MetaDisposable()
    private var first = true

    deinit {
        self.disposable.dispose()
    }

    func setSignal(_ signal: Signal<UIImage?, NoError>) {
        var wasSynchronous = true
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] next in
            guard let self else {
                return
            }
            var animate = true
            if self.first && next != nil {
                self.first = false
                animate = false
                if !wasSynchronous {
                    self.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                }
            }
            if let image = next?.cgImage {
                if animate, let previousContents = self.contents, !wasSynchronous {
                    self.contents = image
                    let tempLayer = CALayer()
                    tempLayer.contents = previousContents
                    tempLayer.frame = self.bounds
                    self.addSublayer(tempLayer)
                    tempLayer.opacity = 0.0
                    tempLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: true, completion: { [weak tempLayer] _ in
                        tempLayer?.removeFromSuperlayer()
                    })
                } else {
                    self.contents = image
                }
            }
        }))
        wasSynchronous = false
    }
}

public final class AvatarComponent: Component {
    public enum ClipStyle {
        case round
        case roundedRect
    }

    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer?
    let clipStyle: ClipStyle
    let overrideImage: AvatarNodeImageOverride?
    let icon: AnyComponent<Empty>?
    let size: CGSize?
    /// Whether the photo is decoded on the main thread as the view is updated. A view built ahead of being
    /// shown (a list row entering during a scroll) can pass false and stay blank until it loads.
    let synchronousLoad: Bool

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer?,
        clipStyle: ClipStyle = .round,
        overrideImage: AvatarNodeImageOverride? = nil,
        icon: AnyComponent<Empty>? = nil,
        size: CGSize? = nil,
        synchronousLoad: Bool = true
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.clipStyle = clipStyle
        self.overrideImage = overrideImage
        self.icon = icon
        self.size = size
        self.synchronousLoad = synchronousLoad
    }

    public static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.clipStyle != rhs.clipStyle {
            return false
        }
        if lhs.overrideImage != rhs.overrideImage {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.synchronousLoad != rhs.synchronousLoad {
            return false
        }
        return true
    }

    /// `AvatarNode` rebuilt on a view and two layers: `contentView` is its `ContentNode` (the placeholder as contents,
    /// drawn by the same routine) and `imageLayer` its `ImageNode` (the photo). The update follows `AvatarNode.frame`
    /// and `ContentNode.setPeer(context:…)` step by step.
    public final class View: UIView {
        private let contentView: UIView
        private let imageLayer: AvatarComponentImageLayer
        private var icon: ComponentView<Empty>?

        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?

        private var font: UIFont
        private var avatarState: AvatarNodeState = .empty
        private var overrideImage: AvatarNodeImageOverride?
        private var theme: PresentationTheme?
        private var parameters: AvatarNodeParameters?
        /// ASDK's `displaySuspended` on the content node: set while a photo shows, so no placeholder draws under it.
        private var placeholderSuspended = false
        /// ASDK's `setNeedsDisplay`: the placeholder draws once, at the end of the update that asked for it.
        private var placeholderNeedsDisplay = false
        /// Bumped by every draw and by suspending, so that only the latest draw lands.
        private var placeholderGeneration = 0

        override init(frame: CGRect) {
            self.contentView = UIView()
            self.imageLayer = AvatarComponentImageLayer()
            self.font = avatarPlaceholderFont(size: 42.0)

            super.init(frame: frame)

            self.contentView.isOpaque = false
            self.contentView.accessibilityIgnoresInvertColors = true
            self.contentView.layer.addSublayer(self.imageLayer)
            self.addSubview(self.contentView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let size = component.size ?? availableSize

            if self.component == nil {
                let font = avatarPlaceholderFont(size: ceil(42.0 * size.width / 100.0))
                if self.font.pointSize != font.pointSize {
                    self.setPlaceholderNeedsDisplay()
                }
                self.font = font
            }

            self.component = component
            self.state = state

            var cutoutRect: CGRect?
            if let icon = component.icon {
                let iconView: ComponentView<Empty>
                if let current = self.icon {
                    iconView = current
                } else {
                    iconView = ComponentView()
                    self.icon = iconView
                }
                let iconSize = iconView.update(
                    transition: .immediate,
                    component: icon,
                    environment: {},
                    containerSize: CGSize(width: 24.0, height: 24.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: size.width - iconSize.width + 2.0, y: size.height - iconSize.height + 2.0), size: iconSize)
                if let iconView = iconView.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
                cutoutRect = CGRect(origin: CGPoint(x: iconFrame.minX, y: size.height - iconFrame.maxY), size: iconFrame.size).insetBy(dx: -2.0 + UIScreenPixel, dy: -2.0 + UIScreenPixel)
            }

            var clipStyle: AvatarNodeClipStyle = .round
            if case .roundedRect = component.clipStyle {
                clipStyle = .roundedRect
            }

            // `AvatarNode.frame`: only a new size lays the content out again, and it redraws the placeholder.
            if !self.contentView.frame.size.equalTo(size) {
                self.contentView.frame = CGRect(origin: CGPoint(), size: size)
                self.imageLayer.frame = CGRect(origin: CGPoint(), size: size)
                self.setPlaceholderNeedsDisplay()
            }

            // `ContentNode.setPeer(context:…)`. The display size is not part of the state: a new size alone keeps the
            // photo it has, stretched.
            let resolved = avatarNodeResolvedImage(context: component.context, peer: component.peer, overrideImage: component.overrideImage, synchronousLoad: component.synchronousLoad)
            var displaySynchronously = false
            let updatedState = avatarNodePeerState(peer: component.peer, representation: resolved.representation, clipStyle: clipStyle, cutoutRect: cutoutRect)
            if updatedState != self.avatarState || component.overrideImage != self.overrideImage || component.theme !== self.theme {
                self.avatarState = updatedState
                self.overrideImage = component.overrideImage
                self.theme = component.theme

                let account = component.context.account
                let parameters: AvatarNodeParameters
                if let peer = component.peer, let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer), authorOfMessage: nil, representation: resolved.representation, displayDimensions: size, clipStyle: clipStyle, emptyColor: nil, synchronousLoad: resolved.synchronousLoad, provideUnrounded: false, cutoutRect: cutoutRect) {
                    self.contentView.layer.contents = nil
                    self.setPlaceholderSuspended(true)
                    self.imageLayer.setSignal(signal |> map { next -> UIImage? in
                        return next?.0
                    })
                    parameters = avatarNodePeerParameters(context: component.context, accountPeerId: account.peerId, theme: component.theme, peer: peer, icon: resolved.icon, font: self.font, hasImage: true, clipStyle: clipStyle, cutoutRect: cutoutRect)
                } else {
                    self.setPlaceholderSuspended(false)
                    // As `ContentNode`: the photo's contents go, its signal stays.
                    self.imageLayer.contents = nil
                    parameters = avatarNodePeerParameters(context: component.context, accountPeerId: account.peerId, theme: component.theme, peer: component.peer, icon: resolved.icon, font: self.font, hasImage: false, clipStyle: clipStyle, cutoutRect: cutoutRect)
                }
                self.parameters = parameters
                self.setPlaceholderNeedsDisplay()
                // `recursivelyEnsureDisplaySynchronously`
                displaySynchronously = resolved.synchronousLoad
            }

            self.displayPlaceholderIfNeeded(synchronously: displaySynchronously)

            return size
        }

        private func setPlaceholderNeedsDisplay() {
            if !self.placeholderSuspended {
                self.placeholderNeedsDisplay = true
            }
        }

        private func setPlaceholderSuspended(_ suspended: Bool) {
            guard self.placeholderSuspended != suspended else {
                return
            }
            self.placeholderSuspended = suspended
            if suspended {
                // A draw in flight must not land under the photo.
                self.placeholderGeneration += 1
                self.placeholderNeedsDisplay = false
            } else {
                self.placeholderNeedsDisplay = true
            }
        }

        /// The previous placeholder stays until the new one lands. Off the main thread unless `synchronously`, as
        /// ASDK draws `ContentNode` (`displaysAsynchronously`).
        private func displayPlaceholderIfNeeded(synchronously: Bool) {
            guard self.placeholderNeedsDisplay, !self.placeholderSuspended else {
                return
            }
            let size = self.contentView.bounds.size
            if size.width <= 0.0 || size.height <= 0.0 {
                // ASDK draws nothing at zero size and draws again once the size is set (which asks again here).
                return
            }
            self.placeholderNeedsDisplay = false
            self.placeholderGeneration += 1
            let generation = self.placeholderGeneration
            let parameters = self.parameters
            if synchronously {
                self.contentView.layer.contents = renderAvatarPlaceholder(size: size, parameters: parameters).cgImage
            } else {
                avatarComponentDisplayQueue.async { [weak self] in
                    let image = renderAvatarPlaceholder(size: size, parameters: parameters)
                    Queue.mainQueue().async {
                        guard let self, self.placeholderGeneration == generation, !self.placeholderSuspended else {
                            return
                        }
                        self.contentView.layer.contents = image.cgImage
                    }
                }
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
