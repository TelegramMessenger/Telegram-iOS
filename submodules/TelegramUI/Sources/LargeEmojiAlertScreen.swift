import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertHeaderComponent
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import MediaResources
import StickerResources
import ShimmerEffect

func largeEmojiAlertScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    fitz: String?,
    file: TelegramMediaFile,
    enable: @escaping () -> Void
) -> AlertScreen {
    let presentationDataSignal = Signal<PresentationData, NoError>.single(updatedPresentationData.initial)
    |> then(updatedPresentationData.signal)

    return AlertScreen(
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        contentSignal: presentationDataSignal |> map { presentationData in
            return [
                AnyComponentWithIdentity(
                    id: "header",
                    component: AnyComponent(
                        AlertHeaderComponent(component: AnyComponentWithIdentity(
                            id: "emoji",
                            component: AnyComponent(LargeEmojiAlertComponent(
                                context: context,
                                theme: presentationData.theme,
                                fitz: fitz,
                                file: file
                            ))
                        ))
                    )
                ),
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: presentationData.strings.Appearance_LargeEmoji))
                ),
                AnyComponentWithIdentity(
                    id: "text",
                    component: AnyComponent(AlertTextComponent(content: .plain(presentationData.strings.Conversation_LargeEmojiDisabledInfo)))
                )
            ]
        },
        actionsSignal: presentationDataSignal |> map { presentationData in
            return [
                AlertScreen.Action(title: presentationData.strings.Conversation_LargeEmojiEnable, type: .default, action: enable),
                AlertScreen.Action(title: presentationData.strings.Common_Cancel, type: .generic)
            ]
        },
        updatedPresentationData: updatedPresentationData
    )
}

private final class LargeEmojiAlertComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let fitz: String?
    let file: TelegramMediaFile

    init(context: AccountContext, theme: PresentationTheme, fitz: String?, file: TelegramMediaFile) {
        self.context = context
        self.theme = theme
        self.fitz = fitz
        self.file = file
    }

    static func ==(lhs: LargeEmojiAlertComponent, rhs: LargeEmojiAlertComponent) -> Bool {
        return lhs.context === rhs.context && lhs.theme === rhs.theme && lhs.fitz == rhs.fitz && lhs.file == rhs.file
    }

    final class View: UIView {
        private var component: LargeEmojiAlertComponent?
        private var contentNode: LargeEmojiAlertContentNode?

        func update(component: LargeEmojiAlertComponent) -> CGSize {
            if self.component?.context !== component.context || self.component?.file != component.file || self.component?.fitz != component.fitz {
                self.contentNode?.removeFromSupernode()
                let contentNode = LargeEmojiAlertContentNode(context: component.context, fitz: component.fitz, file: component.file)
                self.contentNode = contentNode
                self.addSubnode(contentNode)
            }
            self.component = component

            let size = CGSize(width: 80.0, height: 80.0)
            if let contentNode = self.contentNode {
                contentNode.frame = CGRect(origin: .zero, size: size)
                contentNode.updateLayout(size: size, theme: component.theme)
            }
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self)
    }
}

private final class LargeEmojiAlertContentNode: ASDisplayNode {
    private let context: AccountContext
    private let file: TelegramMediaFile
    private let placeholderNode: StickerShimmerEffectNode
    private let imageNode: TransformImageNode
    private let animationNode: AnimatedStickerNode
    private let disposable = MetaDisposable()
    private var animationStarted = false

    init(context: AccountContext, fitz: String?, file: TelegramMediaFile) {
        self.context = context
        self.file = file
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.imageNode = TransformImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.isUserInteractionEnabled = false
        self.animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: context.lottieRenderingSettings)

        super.init()

        self.addSubnode(self.imageNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.animationNode)

        var fitzModifier: EmojiFitzModifier?
        if let fitz {
            fitzModifier = EmojiFitzModifier(emoji: fitz)
        }

        let setupTimestamp = CACurrentMediaTime()
        self.animationNode.started = { [weak self] in
            guard let self, !self.animationStarted else {
                return
            }
            self.animationStarted = true
            self.imageNode.alpha = 0.0
            let animated = CACurrentMediaTime() - setupTimestamp > 0.3
            if animated {
                self.animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            self.removePlaceholder(animated: animated)
        }
        self.imageNode.imageUpdated = { [weak self] image in
            guard let self, image != nil, !self.animationStarted else {
                return
            }
            self.imageNode.alpha = self.placeholderNode.isEmpty ? 1.0 : 0.0
        }

        self.animationNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: fitzModifier), width: 160, height: 160, playbackMode: .once, mode: .direct(cachePathPrefix: nil))

        let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: context.account.postbox, userLocation: .other, file: file, small: false, size: dimensions.cgSize.aspectFilled(CGSize(width: 320.0, height: 320.0)), fitzModifier: fitzModifier, thumbnail: false, synchronousLoad: true), attemptSynchronously: true)
        self.disposable.set(freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file)).startStrict())
    }

    deinit {
        self.disposable.dispose()
    }

    override func didLoad() {
        super.didLoad()

        self.animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }

    override func didEnterHierarchy() {
        super.didEnterHierarchy()

        self.animationNode.visibility = true
    }

    override func didExitHierarchy() {
        super.didExitHierarchy()

        self.animationNode.visibility = false
    }

    @objc private func tap() {
        let _ = self.animationNode.playIfNeeded()
    }

    private func removePlaceholder(animated: Bool) {
        guard !self.placeholderNode.alpha.isZero else {
            return
        }
        self.placeholderNode.alpha = 0.0
        if animated {
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        } else {
            self.placeholderNode.removeFromSupernode()
        }
    }

    func updateLayout(size: CGSize, theme: PresentationTheme) {
        let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
        let frame = CGRect(origin: .zero, size: size)
        self.imageNode.frame = frame
        self.animationNode.frame = frame
        self.animationNode.updateLayout(size: size)
        self.placeholderNode.frame = frame

        if self.placeholderNode.supernode != nil, let immediateThumbnailData = self.file.immediateThumbnailData {
            self.placeholderNode.update(backgroundColor: nil, foregroundColor: theme.actionSheet.secondaryTextColor.blitOver(theme.actionSheet.itemBackgroundColor, alpha: 0.55), shimmeringColor: theme.actionSheet.itemBackgroundColor.withAlphaComponent(0.4), data: immediateThumbnailData, size: size, enableEffect: self.context.sharedContext.energyUsageSettings.fullTranslucency, imageSize: dimensions.cgSize)
            self.placeholderNode.updateAbsoluteRect(frame, within: size)
        }
        self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.cgSize.aspectFitted(size), boundingSize: size, intrinsicInsets: .zero))()
    }
}
