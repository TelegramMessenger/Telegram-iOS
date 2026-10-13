import UIKit
import ObjectiveC

private var sourceStateKey: UInt8 = 0
private var decorationStateKey: UInt8 = 0

private final class ContextMenuSourceState {
    var owners = 0
    var content: ContextMenuSourceContent?
}

private final class ContextMenuDecorationState {
    var owners = 0
    let wasHidden: Bool

    init(view: UIView) {
        self.wasHidden = view.isHidden
    }
}

/// Keeps separately rendered source decorations hidden until the last menu returns.
/// Overlapping menus share the same live content until the last claim ends.
public final class ContextMenuSourceLease {
    private let source: UIView
    private let state: ContextMenuSourceState
    private let decorations: [(UIView, ContextMenuDecorationState)]

    public var content: ContextMenuSourceContent? { self.state.content }

    public init(source: UIView, decorations: [UIView], makeContent: (() -> ContextMenuSourceContent?)? = nil) {
        assert(Thread.isMainThread)
        self.source = source
        let state: ContextMenuSourceState
        if let current = objc_getAssociatedObject(source, &sourceStateKey) as? ContextMenuSourceState {
            state = current
        } else {
            state = ContextMenuSourceState()
            state.content = makeContent?()
            objc_setAssociatedObject(source, &sourceStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        self.state = state
        state.owners += 1
        var claims: [(UIView, ContextMenuDecorationState)] = []
        var seen = Set<ObjectIdentifier>()
        for view in decorations where seen.insert(ObjectIdentifier(view)).inserted {
            let claim: ContextMenuDecorationState
            if let current = objc_getAssociatedObject(view, &decorationStateKey) as? ContextMenuDecorationState {
                claim = current
            } else {
                claim = ContextMenuDecorationState(view: view)
                objc_setAssociatedObject(view, &decorationStateKey, claim, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            claim.owners += 1
            view.isHidden = true
            claims.append((view, claim))
        }
        self.decorations = claims
    }

    deinit {
        assert(Thread.isMainThread)
        for (view, claim) in self.decorations {
            claim.owners -= 1
            if claim.owners == 0 {
                view.isHidden = claim.wasHidden
                objc_setAssociatedObject(view, &decorationStateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        self.state.owners -= 1
        if self.state.owners == 0 {
            self.state.content?.restore()
            objc_setAssociatedObject(self.source, &sourceStateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

/// Temporarily hosts the actual foreground outside its pressed button ancestor.
/// A matching live backdrop travels with it; no pixels are captured or frozen.
public final class ContextMenuSourceContent {
    public let view = UIView()
    private weak var source: UIView?
    private weak var originalParent: UIView?
    private let originalIndex: Int
    private let foreground: UIView
    private var restored = false
    private var onRestore: (() -> Void)?

    public init(source: UIView, foreground: UIView, background: UIView, container: UIView, onRestore: (() -> Void)? = nil) {
        self.onRestore = onRestore
        self.source = source
        self.foreground = foreground
        self.originalParent = foreground.superview
        self.originalIndex = foreground.superview?.subviews.firstIndex(of: foreground) ?? 0
        self.view.isUserInteractionEnabled = false
        self.view.addSubview(background)
        // Detach first so node-backed views reconcile their old node hierarchy
        // before entering a plain UIView. Direct reparenting makes ASDisplayKit
        // remove the view again from didMoveToSuperview.
        foreground.removeFromSuperview()
        self.view.addSubview(foreground)
        container.addSubview(self.view)
        self.updateGeometry()
    }

    public func updateGeometry() {
        guard !self.restored, let source = self.source, let parent = self.view.superview else { return }
        let origin = source.convert(CGPoint.zero, to: parent)
        let x = source.convert(CGPoint(x: 1, y: 0), to: parent)
        let y = source.convert(CGPoint(x: 0, y: 1), to: parent)
        self.view.bounds = source.bounds
        self.view.center = source.convert(CGPoint(x: source.bounds.midX, y: source.bounds.midY), to: parent)
        self.view.transform = CGAffineTransform(a: x.x - origin.x, b: x.y - origin.y, c: y.x - origin.x, d: y.y - origin.y, tx: 0, ty: 0)
    }

    fileprivate func restore() {
        guard !self.restored else { return }
        self.restored = true
        if let parent = self.originalParent, self.foreground.superview === self.view {
            self.foreground.removeFromSuperview()
            parent.insertSubview(self.foreground, at: min(self.originalIndex, parent.subviews.count))
        }
        self.view.removeFromSuperview()
        self.onRestore?()
        self.onRestore = nil
    }

    deinit { self.restore() }
}
