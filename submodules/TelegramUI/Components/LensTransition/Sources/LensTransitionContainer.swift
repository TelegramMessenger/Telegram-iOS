import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// Hosts custom menu content and morphs it using UIKit's lower-level liquid renderer.
/// The parent owns this view's frame; previews handle conversion between source windows.
public final class LensTransitionContainer: UIView {
    private let backgroundView = GlassBackgroundView()
    private var morph: AnyObject?
    private var sourcePreview: UITargetedPreview?
    private var sourceSizeAtOpen: CGSize?
    private var sourceVisibilityAssertion: AnyObject?
    private var menuVisibilityAssertion: AnyObject?
    private weak var originalSourceView: UIView?
    private var isPresenting = false
    private var pendingLayout: (CGSize, CGFloat, Bool, GlassBackgroundView.TintColor)?

    public var nativeBlurRadius: CGFloat? {
        get {
            return self.backgroundView.nativeBlurRadius
        }
        set {
            self.backgroundView.nativeBlurRadius = newValue
        }
    }
    private var cornerRadius: CGFloat = 30.0
    private var sourceLease: ContextMenuSourceLease?
    private var replacementVisibilityAssertion: AnyObject?

    public static var isMorphSupported: Bool {
        if #available(iOS 26.0, *) {
            return LiquidMorphTransition.isSupported
        }
        return false
    }

    public var contentsView: UIView {
        return self.backgroundView.contentView
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.backgroundView)
        self.backgroundView.contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.restoreSourceViews()
    }

    private func restoreSourceViews() {
        self.sourceLease = nil
    }

    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor = .init(kind: .panel), transition: ComponentTransition) {
        self.cornerRadius = cornerRadius
        // UIKit temporarily owns the presentation geometry during a morph. Keep the
        // destination model geometry stable until it has returned the view to us.
        if #available(iOS 26.0, *), let morph = self.morph as? LiquidMorphTransition, morph.isAnimating {
            self.pendingLayout = (size, cornerRadius, isDark, tintColor)
            return
        }
        transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: .zero, size: size))
        transition.setPosition(view: self.backgroundView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        self.backgroundView.update(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor, transition: transition)
        transition.setCornerRadius(layer: self.contentsView.layer, cornerRadius: cornerRadius)
    }

    public func animateIn(from sourceView: UIView, sourceRect: CGRect, sourcePath: UIBezierPath?, alongsideAnimations: @escaping () -> Void = {}) {
        self.backgroundView.alpha = 1.0
        guard #available(iOS 26.0, *), Self.isMorphSupported, sourceView.superview != nil,
              sourceView.window != nil, self.window != nil, !sourceRect.isEmpty else {
            self.fadeIn(alongsideAnimations: alongsideAnimations)
            return
        }
        let parameters = Self.previewParameters(sourceView: sourceView, sourceRect: sourceRect, sourcePath: sourcePath)
        self.originalSourceView = sourceView
        self.sourceSizeAtOpen = (sourceView as? ContextExtractableContainer)?.normalState.size
        self.sourceLease = ContextMenuSourceLease(source: sourceView, decorations: ContextReferenceContentNode.additionalSourceViews(for: sourceView), makeContent: ContextReferenceContentNode.makeSourceContent(for: sourceView))
        let previewView = self.sourceLease?.content?.view ?? (sourceView as? GlassContextExtractableContainer)?.transitionView ?? sourceView
        guard let source = LiquidMorphTransition.sourcePreview(for: previewView, parameters: parameters) else {
            self.restoreSourceViews()
            self.fadeIn(alongsideAnimations: alongsideAnimations)
            return
        }
        let menu = self.makeMenuPreview()
        self.sourcePreview = source
        let sourceAttachment = source.target.container.convert(source.target.center, to: self)
        let morph = LiquidMorphTransition()
        self.morph = morph
        self.isPresenting = true
        GlassBackgroundView.morphBlurRadius = self.nativeBlurRadius
        if !morph.animate(from: source, to: menu, attachment: sourceAttachment, in: self, sourceIdentity: sourceView, alongsideAnimations: { [weak self] in
            if let self {
                self.sourceVisibilityAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: source.view)
            }
            alongsideAnimations()
        }, completion: { [weak self] in
            if self?.nativeBlurRadius != nil {
                GlassBackgroundView.morphBlurRadius = nil
            }
            // A close that took over this opening owns the menu from then on.
            guard let self, self.isPresenting else { return }
            self.isPresenting = false
            if let (size, radius, dark, tint) = self.pendingLayout {
                self.pendingLayout = nil
                self.update(size: size, cornerRadius: radius, isDark: dark, tintColor: tint, transition: .immediate)
            }
        }) {
            GlassBackgroundView.morphBlurRadius = nil
            self.isPresenting = false
            self.morph = nil
            self.sourceVisibilityAssertion = nil
            self.restoreSourceViews()
            self.fadeIn(alongsideAnimations: alongsideAnimations)
            return
        }
    }

    /// `currentSource` is the source resolved now, as `animateIn` was given it at opening. The menu closes into it, so a
    /// source whose size changed while the menu was open (an action applied before its menu closes) takes the menu back
    /// at its new size, not the one it opened from. It can also be a different view: a source may hand its contents to
    /// a new view while the menu is open, and the menu then closes into that view.
    public func animateOut(currentSource: (view: UIView, sourceRect: CGRect, sourcePath: UIBezierPath?)? = nil, alongsideAnimations: @escaping () -> Void = {}, completion: @escaping () -> Void) {
        // A close requested while the menu is still opening starts now and takes over the
        // running morph. UIKit reports an opening complete about a second after the menu
        // looks open, so waiting for it left an open menu that ignored taps until then.
        let interruptsPresentation = self.isPresenting
        self.isPresenting = false
        self.sourceLease?.content?.updateGeometry()
        // A close that takes over a running opening keeps the morph item UIKit holds for the
        // opening's source: keyed by that view's identity, it lands where the opening recorded
        // the view, and UIKit keeps the view hidden until the morph ends. A replacement view is a
        // destination the morph has not seen, so the close lands on it as it is now.
        let replacement = currentSource.flatMap { $0.view !== self.originalSourceView && $0.view.window != nil ? $0.view : nil }
        if #available(iOS 26.0, *), let morph = self.morph as? LiquidMorphTransition,
           let originalSourceView = self.originalSourceView, (replacement ?? originalSourceView).window != nil,
           let source = self.sourcePreview, self.backgroundView.window != nil,
           let destination = LiquidMorphTransition.sourcePreview(for: replacement ?? source.view, parameters: self.closingParameters(source.parameters, sourceView: replacement ?? originalSourceView, currentSource: currentSource), usePresentationTransform: true) {
            // Resolve the visible shape in its current parent, including any live
            // source transform, as UIKit does for its dismissal preview.
            let attachment = destination.target.container.convert(destination.target.center, to: self)
            let menu = self.makeMenuPreview()
            let blurRadius = self.nativeBlurRadius
            GlassBackgroundView.morphBlurRadius = blurRadius
            if morph.animate(from: menu, to: destination, attachment: attachment, in: self, sourceIdentity: originalSourceView, interruptingCurrent: interruptsPresentation, alongsideAnimations: { [weak self] in
                // The menu is this morph's source. UIKit puts it back on screen, fully open,
                // when it tears the morph down, and our completion (which hides it) only runs
                // a main-queue turn later; a frame in between showed the open menu once. Hold
                // it hidden until then, as opening holds the button for the menu's lifetime.
                self?.menuVisibilityAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: menu.view)
                if let replacement {
                    // As the opening holds its source hidden, until the menu has closed into it.
                    self?.replacementVisibilityAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: replacement)
                }
                alongsideAnimations()
            }, completion: { [weak self] in
                if blurRadius != nil {
                    GlassBackgroundView.morphBlurRadius = nil
                }
                self?.finishDismissal()
                completion()
            }) {
                return
            }
            GlassBackgroundView.morphBlurRadius = nil
        }
        // A source can disappear because the action removed it or navigation
        // changed. In that case finish normally without constructing an invalid preview.
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.0
            alongsideAnimations()
        }, completion: { [weak self] _ in
            self?.finishDismissal()
            completion()
        })
    }

    /// Explicit source paths are in source-view bounds coordinates. Otherwise UIKit infers UIButton/glass geometry;
    /// insets describe a cropped source.
    private static func previewParameters(sourceView: UIView, sourceRect: CGRect, sourcePath: UIBezierPath?) -> UIPreviewParameters {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        if let sourcePath {
            parameters.visiblePath = sourcePath
            parameters.shadowPath = sourcePath
        } else if sourceRect != sourceView.bounds {
            parameters.visiblePath = UIBezierPath(rect: sourceRect)
        }
        return parameters
    }

    /// The opening's parameters hold the source's outline at opening, so they are re-resolved from the source as it is
    /// now. An extractable container keeps its own rule: its bounds while the menu is open are not its normal state.
    private func closingParameters(_ parameters: UIPreviewParameters, sourceView: UIView, currentSource: (view: UIView, sourceRect: CGRect, sourcePath: UIBezierPath?)?) -> UIPreviewParameters {
        if let currentSource, currentSource.view === sourceView, !(sourceView is ContextExtractableContainer), !currentSource.sourceRect.isEmpty {
            return Self.previewParameters(sourceView: sourceView, sourceRect: currentSource.sourceRect, sourcePath: currentSource.sourcePath)
        }
        return self.dismissalParameters(parameters)
    }

    private func dismissalParameters(_ parameters: UIPreviewParameters) -> UIPreviewParameters {
        guard let extractable = self.originalSourceView as? ContextExtractableContainer, let sizeAtOpen = self.sourceSizeAtOpen else {
            return parameters
        }
        let normalState = extractable.normalState
        guard normalState.size != sizeAtOpen, normalState.size.width > 0.0, normalState.size.height > 0.0 else {
            return parameters
        }
        let updated = UIPreviewParameters()
        updated.backgroundColor = parameters.backgroundColor
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: normalState.size), cornerRadius: normalState.cornerRadius)
        updated.visiblePath = path
        updated.shadowPath = path
        return updated
    }

    private func makeMenuPreview() -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: self.backgroundView.bounds, cornerRadius: self.cornerRadius)
        return UITargetedPreview(view: self.backgroundView.transitionView, parameters: parameters)
    }

    private func finishDismissal() {
        self.sourceVisibilityAssertion = nil
        self.replacementVisibilityAssertion = nil
        self.restoreSourceViews()
        self.backgroundView.alpha = 0.0
        self.menuVisibilityAssertion = nil
        self.morph = nil
        self.sourcePreview = nil
        self.sourceSizeAtOpen = nil
        self.originalSourceView = nil
    }

    private func fadeIn(alongsideAnimations: @escaping () -> Void) {
        self.backgroundView.alpha = 0.0
        UIView.animate(withDuration: 0.2) {
            self.backgroundView.alpha = 1.0
            alongsideAnimations()
        }
    }
}
