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
    private var sourceVisibilityAssertion: AnyObject?
    private var menuVisibilityAssertion: AnyObject?
    private weak var originalSourceView: UIView?
    private var isPresenting = false
    private var pendingLayout: (CGSize, CGFloat, Bool)?
    private var cornerRadius: CGFloat = 30.0
    private var sourceLease: ContextMenuSourceLease?

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

    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, transition: ComponentTransition) {
        self.cornerRadius = cornerRadius
        // UIKit temporarily owns the presentation geometry during a morph. Keep the
        // destination model geometry stable until it has returned the view to us.
        if #available(iOS 26.0, *), let morph = self.morph as? LiquidMorphTransition, morph.isAnimating {
            self.pendingLayout = (size, cornerRadius, isDark)
            return
        }
        transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: .zero, size: size))
        transition.setPosition(view: self.backgroundView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        self.backgroundView.update(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: .init(kind: .panel), transition: transition)
        transition.setCornerRadius(layer: self.contentsView.layer, cornerRadius: cornerRadius)
    }

    public func animateIn(from sourceView: UIView, sourceRect: CGRect, sourcePath: UIBezierPath?, alongsideAnimations: @escaping () -> Void = {}) {
        self.backgroundView.alpha = 1.0
        guard #available(iOS 26.0, *), Self.isMorphSupported, sourceView.superview != nil,
              sourceView.window != nil, self.window != nil, !sourceRect.isEmpty else {
            self.fadeIn(alongsideAnimations: alongsideAnimations)
            return
        }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        // Explicit source paths are in source-view bounds coordinates. Otherwise
        // UIKit infers UIButton/glass geometry; insets describe a cropped source.
        if let sourcePath {
            parameters.visiblePath = sourcePath
            parameters.shadowPath = sourcePath
        } else if sourceRect != sourceView.bounds {
            parameters.visiblePath = UIBezierPath(rect: sourceRect)
        }
        self.originalSourceView = sourceView
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
        if !morph.animate(from: source, to: menu, attachment: sourceAttachment, in: self, sourceIdentity: sourceView, alongsideAnimations: { [weak self] in
            if let self {
                self.sourceVisibilityAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: source.view)
            }
            alongsideAnimations()
        }, completion: { [weak self] in
            // A close that took over this opening owns the menu from then on.
            guard let self, self.isPresenting else { return }
            self.isPresenting = false
            if let (size, radius, dark) = self.pendingLayout {
                self.pendingLayout = nil
                self.update(size: size, cornerRadius: radius, isDark: dark, transition: .immediate)
            }
        }) {
            self.isPresenting = false
            self.morph = nil
            self.sourceVisibilityAssertion = nil
            self.restoreSourceViews()
            self.fadeIn(alongsideAnimations: alongsideAnimations)
        }
    }

    public func animateOut(alongsideAnimations: @escaping () -> Void = {}, completion: @escaping () -> Void) {
        // A close requested while the menu is still opening starts now and takes over the
        // running morph. UIKit reports an opening complete about a second after the menu
        // looks open, so waiting for it left an open menu that ignored taps until then.
        let interruptsPresentation = self.isPresenting
        self.isPresenting = false
        self.sourceLease?.content?.updateGeometry()
        if #available(iOS 26.0, *), let morph = self.morph as? LiquidMorphTransition,
           let originalSourceView = self.originalSourceView, originalSourceView.window != nil,
           let source = self.sourcePreview, self.backgroundView.window != nil,
           let destination = LiquidMorphTransition.sourcePreview(for: source.view, parameters: source.parameters, usePresentationTransform: true) {
            // Resolve the visible shape in its current parent, including any live
            // source transform, as UIKit does for its dismissal preview.
            let attachment = destination.target.container.convert(destination.target.center, to: self)
            let menu = self.makeMenuPreview()
            if morph.animate(from: menu, to: destination, attachment: attachment, in: self, sourceIdentity: originalSourceView, interruptingCurrent: interruptsPresentation, alongsideAnimations: { [weak self] in
                // The menu is this morph's source. UIKit puts it back on screen, fully open,
                // when it tears the morph down, and our completion (which hides it) only runs
                // a main-queue turn later; a frame in between showed the open menu once. Hold
                // it hidden until then, as opening holds the button for the menu's lifetime.
                self?.menuVisibilityAssertion = LiquidMorphTransition.sourceVisibilityAssertion(for: menu.view)
                alongsideAnimations()
            }, completion: { [weak self] in
                self?.finishDismissal()
                completion()
            }) {
                return
            }
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

    private func makeMenuPreview() -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: self.backgroundView.bounds, cornerRadius: self.cornerRadius)
        return UITargetedPreview(view: self.backgroundView.transitionView, parameters: parameters)
    }

    private func finishDismissal() {
        self.sourceVisibilityAssertion = nil
        self.restoreSourceViews()
        self.backgroundView.alpha = 0.0
        self.menuVisibilityAssertion = nil
        self.morph = nil
        self.sourcePreview = nil
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
