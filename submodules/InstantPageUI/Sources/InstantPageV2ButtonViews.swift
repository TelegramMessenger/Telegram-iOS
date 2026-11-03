import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TextLoadingEffect
import RichTextButtonIcons

/// Draws a pill's label and type badge. Split out of `InstantPageV2ButtonPillView` so a loading
/// shimmer can be inserted *below* the label: a view's own `draw(_:)` output lands in its layer's
/// `contents`, and sublayers always composite above that — a shimmer added to the pill directly
/// would wash over the text instead of sweeping beneath it.
///
/// Non-interactive, so the pill above keeps the tap recognizer and the touch overrides it already
/// had, hit-testing exactly as before.
private final class InstantPageV2ButtonPillContentView: UIView {
    var attachment: InstantPageInlineButtonAttachment
    /// `attachment.labelString` recoloured to the resolved button label colour. The attachment's own
    /// string is baked with the surrounding paragraph colour by `attributedStringForRichText`, which
    /// has no `InstantPageTheme` to resolve a button colour with — so the recolour happens in the
    /// pill, where the theme is available, and lands here.
    var displayLabelString: NSAttributedString
    /// The action's type icon, tinted to match the label, or nil for the actions that have none — see
    /// `richTextButtonIconName`.
    var iconImage: UIImage?
    /// Which placement `iconImage` is drawn at: trailing the label on an inline pill, a corner badge on
    /// a block one. Fixed at init, like the owning pill's own `isInline`.
    private let isInline: Bool

    init(attachment: InstantPageInlineButtonAttachment, isInline: Bool) {
        self.attachment = attachment
        self.displayLabelString = attachment.labelString
        self.isInline = isInline
        super.init(frame: CGRect())

        self.isOpaque = false
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        // Shared with `instantPageButtonEmojiPlacements`, so a pill's emoji can never drift away
        // from the label they sit in.
        context.textPosition = instantPageButtonLabelOrigin(attachment: self.attachment, pillSize: self.bounds.size)
        let line = CTLineCreateWithAttributedString(self.displayLabelString)
        CTLineDraw(line, context)

        // The type icon, as on a bot keyboard button. Drawn after the label so a pill too narrow for
        // both shows the icon rather than losing it under the text — the layout reserves room for it,
        // but a stretched row column can still be tight.
        if let iconImage = self.iconImage {
            let iconFrame: CGRect
            if self.isInline {
                // Trailing the label. An inline pill is the label's ink box plus 2pt, so a corner badge
                // has nowhere to sit; the pill was measured wider to hold this instead.
                iconFrame = instantPageInlineButtonIconFrame(attachment: self.attachment, pillSize: self.bounds.size)
            } else {
                // Top-right badge, overlaying the fill of a 40pt row pill.
                iconFrame = CGRect(
                    origin: CGPoint(
                        x: self.bounds.width - richTextBlockButtonIconInset.x - richTextButtonIconSize.width,
                        y: richTextBlockButtonIconInset.y
                    ),
                    size: richTextButtonIconSize
                )
            }
            iconImage.draw(in: iconFrame)
        }
    }
}

/// One button pill: the rounded fill is the view's own `backgroundColor` + corner radius, and a child
/// `InstantPageV2ButtonPillContentView` paints the pre-laid-out label on top. Used directly for an
/// inline `RichText.textButton` and as the child of a block-level button row.
///
/// The frame is set by the owner (the item view or the row view) — this view never writes its own.
final class InstantPageV2ButtonPillView: UIView {
    // Module-internal: `InstantPageV2View.updateInlineEmoji()` needs the laid-out label to derive
    // its emoji placements.
    private(set) var attachment: InstantPageInlineButtonAttachment
    private var theme: InstantPageTheme
    /// Inline (`RichText.textButton`) vs block-level (`pageBlockButtonRow`). Fixed at init: a pill is
    /// created by exactly one kind of owner and never changes kind.
    private let isInline: Bool
    private var isDisabled: Bool
    private var isPressed: Bool = false
    /// Owns the label + badge drawing. Kept as a subview rather than drawn by the pill so the loading
    /// shimmer can sit between the fill and the text.
    private let contentView: InstantPageV2ButtonPillContentView
    /// Hosts the `InlineStickerItemLayer`s for custom emoji in this pill's label. Owned and
    /// populated by `InstantPageV2View.updateInlineEmoji()`, which holds the render context.
    ///
    /// Inserted ABOVE `contentView`, which matters twice: the pill's label is painted into the
    /// content view's layer `contents` bitmap and a sublayer composites over it, and the loading
    /// shimmer is deliberately inserted BELOW `contentView`, so an emoji placed there would be
    /// washed by the sweep instead of sitting on top of it.
    let emojiContainerView: UIView = UIView()
    /// Live only while the tapped action is in flight. Nilled at the *start* of the fade-out, so the
    /// upkeep in `updateLoadingEffectLayout` cannot fight the removal animation.
    private var loadingEffectView: TextLoadingEffectView?
    private var progressDisposable: Disposable?

    /// Fired on tap with a fresh progress promise. Mirrors `ChatMessageActionButtonNode.pressed`:
    /// the view that was tapped creates the promise and subscribes to it itself, so a loading state
    /// never has to be routed back to a particular button — there is no button identity to key on.
    var onButtonTapped: ((InstantPageButton, Promise<Bool>) -> Void)?

    init(attachment: InstantPageInlineButtonAttachment, theme: InstantPageTheme, isInline: Bool) {
        self.attachment = attachment
        self.theme = theme
        self.isInline = isInline
        self.isDisabled = attachment.button.action == .disabled
        self.contentView = InstantPageV2ButtonPillContentView(attachment: attachment, isInline: isInline)
        super.init(frame: CGRect())

        self.isOpaque = false
        self.addSubview(self.contentView)
        self.emojiContainerView.isUserInteractionEnabled = false
        self.addSubview(self.emojiContainerView)
        self.applyColors()
        self.clipsToBounds = true

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.addGestureRecognizer(recognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.progressDisposable?.dispose()
    }

    func update(attachment: InstantPageInlineButtonAttachment, theme: InstantPageTheme) {
        self.attachment = attachment
        self.theme = theme
        self.isDisabled = attachment.button.action == .disabled
        self.applyColors()
    }

    /// The colour the label is actually drawn in — `instantPageButtonColors(...)`'s resolution, not
    /// the paragraph colour baked into `attachment.labelString`. Used as an emoji layer's
    /// `dynamicColor`, so a template emoji in a `danger` or disabled pill tints with its text
    /// rather than with the surrounding body copy.
    var resolvedLabelColor: UIColor {
        return instantPageButtonColors(
            self.attachment.button.color,
            theme: self.theme,
            isInline: self.isInline,
            isDisabled: self.isDisabled,
            isLink: self.attachment.button.isLink
        ).label
    }

    private func applyColors() {
        let colors = instantPageButtonColors(self.attachment.button.color, theme: self.theme, isInline: self.isInline, isDisabled: self.isDisabled, isLink: self.attachment.button.isLink)
        self.backgroundColor = self.isPressed ? self.theme.panelHighlightedBackgroundColor : colors.fill

        let mutableLabel = self.attachment.labelString.mutableCopy() as! NSMutableAttributedString
        if mutableLabel.length != 0 {
            mutableLabel.addAttribute(.foregroundColor, value: colors.label, range: NSRange(location: 0, length: mutableLabel.length))
        }
        self.contentView.attachment = self.attachment
        self.contentView.displayLabelString = mutableLabel

        // Same colour as the label, so a disabled button's icon dims with its text.
        self.contentView.iconImage = richTextButtonIcon(for: self.attachment.button.action, color: colors.label)
        self.contentView.setNeedsDisplay()

        self.updateLoadingEffectLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.bounds.height / 2.0
        self.contentView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.emojiContainerView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.updateLoadingEffectLayout()
    }

    // MARK: - Press handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if !self.isDisabled {
            self.isPressed = true
            self.applyColors()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.isPressed = false
        self.applyColors()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.isPressed = false
        self.applyColors()
    }

    @objc private func tapped() {
        // A disabled button is inert: a forward stripped its behaviour.
        if self.isDisabled {
            return
        }
        guard let onButtonTapped = self.onButtonTapped else {
            return
        }
        let progressPromise = Promise<Bool>()
        onButtonTapped(self.attachment.button, progressPromise)

        self.progressDisposable?.dispose()
        self.progressDisposable = (progressPromise.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] isLoading in
            guard let self else {
                return
            }
            self.updateIsLoading(isLoading: isLoading)
        })
    }

    // MARK: - Loading effect

    /// Mirrors `ChatMessageActionButtonNode.updateIsLoading(isLoading:)`, including the 0.2s fade-out
    /// on the way down.
    private func updateIsLoading(isLoading: Bool) {
        if isLoading {
            if self.loadingEffectView == nil {
                let loadingEffectView = TextLoadingEffectView(frame: CGRect())
                self.loadingEffectView = loadingEffectView
                // Below the label, so the sweep passes under the text rather than washing over it.
                self.insertSubview(loadingEffectView, belowSubview: self.contentView)
                self.updateLoadingEffectLayout()
            }
        } else {
            if let loadingEffectView = self.loadingEffectView {
                self.loadingEffectView = nil
                loadingEffectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak loadingEffectView] _ in
                    loadingEffectView?.removeFromSuperview()
                })
            }
        }
    }

    /// Reapplies the effect's frame, capsule mask and tint. Called on creation, from `layoutSubviews`
    /// (a row column's width follows the row's constrained width, so a pill can be resized
    /// mid-flight) and from `applyColors` (a theme change mid-flight must not strand a stale tint).
    ///
    /// The tint is the pill's own label colour rather than the reference's flat white: a chat action
    /// button sits on a translucent dark blur, but a neutral V2 pill's fill is 0xf3f4f5 in the light
    /// theme, where white would be invisible. `instantPageButtonColors` resolves a colour that
    /// contrasts with the fill by construction.
    ///
    /// `TextLoadingEffectView.update` restarts its animation only when the size actually changes, so
    /// calling this on every layout pass is cheap and does not stutter the sweep.
    private func updateLoadingEffectLayout() {
        guard let loadingEffectView = self.loadingEffectView, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            return
        }
        let colors = instantPageButtonColors(self.attachment.button.color, theme: self.theme, isInline: self.isInline, isDisabled: self.isDisabled, isLink: self.attachment.button.isLink)
        let effectFrame = CGRect(origin: CGPoint(), size: self.bounds.size)
        loadingEffectView.frame = effectFrame
        loadingEffectView.update(
            color: colors.label,
            alpha: colors.label.brightness > 0.6 ? 0.8 : 0.5,
            rect: effectFrame,
            path: UIBezierPath(roundedRect: effectFrame, cornerRadius: effectFrame.height / 2.0).cgPath
        )
    }
}

/// Item view for an inline `RichText.textButton`.
final class InstantPageV2InlineButtonView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2InlineButtonItem
    // Module-internal: `InstantPageV2View.updateInlineEmoji()` reaches in to host emoji layers.
    let pillView: InstantPageV2ButtonPillView

    var itemFrame: CGRect { return self.item.frame }

    var onButtonTapped: ((InstantPageButton, Promise<Bool>) -> Void)? {
        didSet {
            self.pillView.onButtonTapped = self.onButtonTapped
        }
    }

    init(item: InstantPageV2InlineButtonItem, theme: InstantPageTheme) {
        self.item = item
        self.pillView = InstantPageV2ButtonPillView(attachment: item.attachment, theme: theme, isInline: true)
        super.init(frame: item.frame)
        self.addSubview(self.pillView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2InlineButtonItem, theme: InstantPageTheme) {
        self.item = item
        self.pillView.update(attachment: item.attachment, theme: theme)
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.pillView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}

/// Item view for a block-level `pageBlockButtonRow`. Positions child pills at the frames the layout
/// chose (which already encode wrapping at 8 per row and equal widths within a row).
final class InstantPageV2ButtonRowView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ButtonRowItem
    // Module-internal, see `InstantPageV2InlineButtonView.pillView`.
    var pillViews: [InstantPageV2ButtonPillView] = []
    private var theme: InstantPageTheme

    var itemFrame: CGRect { return self.item.frame }

    var onButtonTapped: ((InstantPageButton, Promise<Bool>) -> Void)? {
        didSet {
            for pill in self.pillViews {
                pill.onButtonTapped = self.onButtonTapped
            }
        }
    }

    init(item: InstantPageV2ButtonRowItem, theme: InstantPageTheme) {
        self.item = item
        self.theme = theme
        super.init(frame: item.frame)
        self.rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2ButtonRowItem, theme: InstantPageTheme) {
        self.item = item
        self.theme = theme
        self.rebuild()
        self.setNeedsLayout()
    }

    /// Reuses pills positionally when the count is unchanged, and recreates them only when it is not.
    ///
    /// The reuse is load-bearing, not an optimisation: a pill holds an in-flight loading effect, and
    /// a `.callback` tap updates the message — which relayouts the bubble and calls this. Recreating
    /// would wipe the shimmer the tap had just started. All row pills are built with the same
    /// `isInline: false`, so a positional swap is safe.
    ///
    /// This matches `ChatMessageActionButtonsNode.asyncLayout`, which likewise reuses its button
    /// nodes by position, and inherits the same consequence: an edit that replaces a row's buttons
    /// while keeping the count carries an in-flight effect onto whichever button now occupies the
    /// slot.
    private func rebuild() {
        if self.pillViews.count == self.item.buttons.count {
            for (index, pill) in self.pillViews.enumerated() {
                pill.update(attachment: self.item.buttons[index].attachment, theme: self.theme)
                pill.onButtonTapped = self.onButtonTapped
            }
            return
        }

        for pill in self.pillViews {
            pill.removeFromSuperview()
        }
        self.pillViews = self.item.buttons.map { entry in
            let pill = InstantPageV2ButtonPillView(attachment: entry.attachment, theme: self.theme, isInline: false)
            pill.onButtonTapped = self.onButtonTapped
            self.addSubview(pill)
            return pill
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, pill) in self.pillViews.enumerated() where index < self.item.buttons.count {
            pill.frame = self.item.buttons[index].frame
        }
    }
}
