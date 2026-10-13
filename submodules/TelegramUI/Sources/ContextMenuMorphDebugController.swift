#if targetEnvironment(simulator)
import UIKit
import AsyncDisplayKit
import Display
import GlassBackgroundComponent
import ComponentFlow
import ContextUI
import TelegramPresentationData
import SwiftSignalKit

/// An account-free, opt-in integration gallery using the actual Telegram menu stack.
final class ContextMenuMorphDebugController: ViewController {
    private final class Source: ContextReferenceContentSource {
        let button: UIView
        let top: Bool
        let insets: UIEdgeInsets
        let path: UIBezierPath?
        init(_ button: UIView, top: Bool, insets: UIEdgeInsets = .zero, path: UIBezierPath? = nil) {
            self.button = button
            self.top = top
            self.insets = insets
            self.path = path
        }
        func transitionInfo() -> ContextControllerReferenceViewInfo? {
            guard let window = self.button.window else { return nil }
            return ContextControllerReferenceViewInfo(referenceView: self.button, contentAreaInScreenSpace: window.bounds, insets: self.insets, actionsPosition: self.top ? .top : .bottom, sourcePath: self.path)
        }
    }
    private var buttons: [UIButton] = []
    private let status = UILabel()
    private var repeatedNavigationSource: GlassContextExtractableContainer?
    private var running = false
    private var startedAutomatically = false
    private let shapes: [(String, CGSize, CGFloat)] = [
        ("Circle", CGSize(width: 48, height: 48), 24),
        ("Capsule", CGSize(width: 180, height: 48), 24),
        ("Square", CGSize(width: 72, height: 72), 0),
        ("Wide", CGSize(width: 310, height: 44), 22),
        ("Tall", CGSize(width: 64, height: 100), 18),
        ("Asymmetric", CGSize(width: 150, height: 58), 0)
    ]
    init() {
        super.init(navigationBarPresentationData: nil)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .systemGroupedBackground
        self.displayNodeDidLoad()
        self.status.text = "Telegram custom menu integration"
        self.status.font = .systemFont(ofSize: 16)
        self.status.numberOfLines = 2
        self.view.addSubview(self.status)
        for (index, shape) in self.shapes.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(shape.0, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.layer.cornerRadius = shape.2
            button.tag = index
            button.accessibilityLabel = shape.0
            button.addTarget(self, action: #selector(self.openMenu(_:)), for: .touchUpInside)
            self.view.addSubview(button)
            self.buttons.append(button)
        }
        let run = UIButton(type: .system)
        run.setTitle("Run integrated checks", for: .normal)
        run.addTarget(self, action: #selector(self.runChecks), for: .touchUpInside)
        run.tag = 100
        self.view.addSubview(run)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 26.0, *), !self.startedAutomatically, CommandLine.arguments.contains("--context-menu-morph-overlap") {
            self.startedAutomatically = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.checkProfileOverlap() }
        }
        if !self.startedAutomatically, CommandLine.arguments.contains("--context-menu-morph-checks") {
            self.startedAutomatically = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.runChecks() }
        }
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.status.frame = CGRect(x: 24, y: layout.safeInsets.top + 48, width: layout.size.width - 48, height: 48)
        var y = layout.safeInsets.top + 112
        for (index, button) in self.buttons.enumerated() {
            button.frame = CGRect(origin: CGPoint(x: 30, y: y), size: self.shapes[index].1)
            y += self.shapes[index].1.height + 18
            if index == 5 {
                let mask = CAShapeLayer()
                mask.frame = button.bounds
                mask.path = UIBezierPath(roundedRect: button.bounds, byRoundingCorners: [.topLeft, .bottomRight], cornerRadii: CGSize(width: 28, height: 28)).cgPath
                button.layer.mask = mask
            }
        }
        self.view.viewWithTag(100)?.frame = CGRect(x: 24, y: y, width: layout.size.width - 48, height: 44)
    }
    private func items(for button: UIButton, expanded: Bool = false) -> ContextController.Items {
        var items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: "Resize menu", icon: { _ in nil }, action: { [weak self, weak button] controller, _ in
                guard let self, let button else { return }
                controller?.setItems(.single(self.items(for: button, expanded: true)), minHeight: nil, animated: true)
            })),
            .action(ContextMenuActionItem(text: "Remove source and dismiss", icon: { _ in nil }, action: { [weak button] _, dismiss in
                button?.removeFromSuperview()
                dismiss(.default)
            })),
            .action(ContextMenuActionItem(text: "Dismiss", icon: { _ in nil }, action: { _, dismiss in dismiss(.default) }))
        ]
        if expanded {
            for index in 1...3 {
                items.append(.action(ContextMenuActionItem(text: "Additional row \(index)", icon: { _ in nil }, action: { _, dismiss in dismiss(.default) })))
            }
        }
        return ContextController.Items(content: .list(items), tip: .textSelection)
    }
    @objc private func openMenu(_ button: UIButton) {
        guard !self.running else { return }
        self.showMenu(button, index: nil)
    }
    private func showMenu(_ button: UIButton, index: Int?) {
        let originalTransform = button.transform
        let originalMask = button.layer.mask
        if index == 12 {
            button.transform = CGAffineTransform(rotationAngle: 0.2).scaledBy(x: 0.75, y: 0.9)
        }
        let insets = index == 13 ? UIEdgeInsets(top: 4, left: 70, bottom: 4, right: 8) : .zero
        let path: UIBezierPath? = index == 13 ? UIBezierPath(roundedRect: button.bounds.inset(by: insets), cornerRadius: 20) : nil
        if let path {
            let mask = CAShapeLayer()
            mask.frame = button.bounds
            mask.path = path.cgPath
            button.layer.mask = mask
        }
        let originalFrame = button.frame
        // Profile buttons draw their backdrop through a mask outside the reference
        // node. Plain colored buttons do not exercise that source visibility path.
        var navigationSource: GlassContextExtractableContainer?
        var separateSource: ContextReferenceContentNode?
        var separateBackground: UIVisualEffectView?
        var separateMask: UIView?
        let alreadyHiddenDecoration = UIView()
        alreadyHiddenDecoration.isHidden = true
        if let index, index >= 14, index < 17 {
            let reference = ContextReferenceContentNode()
            reference.frame = button.frame
            let foreground = ASDisplayNode()
            foreground.frame = reference.bounds
            let label = UILabel(frame: reference.bounds)
            label.text = "Shared glass source"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 12)
            foreground.view.addSubview(label)
            reference.addSubnode(foreground)
            let background: UIVisualEffectView
            if #available(iOS 26.0, *) {
                background = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            } else {
                background = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
            }
            background.frame = button.frame
            let maskContainer = UIView(frame: background.bounds)
            let mask = UIView(frame: index == 15 ? maskContainer.bounds.inset(by: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)) : maskContainer.bounds)
            mask.backgroundColor = .white
            mask.layer.cornerRadius = 16
            reference.contextMenuSourcePath = UIBezierPath(roundedRect: mask.frame, cornerRadius: mask.layer.cornerRadius)
            mask.alpha = index == 16 ? 0.65 : 1
            maskContainer.addSubview(mask)
            background.mask = maskContainer
            reference.additionalContextMenuSourceViews = [mask, alreadyHiddenDecoration]
            reference.view.accessibilityIdentifier = "live-profile-reference"
            foreground.view.accessibilityIdentifier = "live-profile-foreground"
            reference.makeContextMenuSourceContent = { [weak self, weak reference] in
                guard let self, let reference else { return nil }
                let liveBackground = UIVisualEffectView(effect: background.effect)
                liveBackground.frame = mask.frame
                liveBackground.layer.cornerRadius = mask.layer.cornerRadius
                liveBackground.clipsToBounds = true
                liveBackground.alpha = mask.alpha
                return ContextMenuSourceContent(source: reference.view, foreground: foreground.view, background: liveBackground, container: self.view)
            }
            self.view.addSubview(background)
            self.view.addSubview(reference.view)
            button.isHidden = true
            separateSource = reference
            separateBackground = background
            separateMask = mask
        }
        if let index, index >= 17 {
            let source = (index >= 20 ? self.repeatedNavigationSource : nil) ?? GlassContextExtractableContainer()
            source.frame = button.frame
            source.update(size: button.bounds.size, cornerRadius: button.bounds.height * 0.5, isDark: false, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
            if source.contentView.subviews.isEmpty {
                let label = UILabel(frame: button.bounds)
                label.text = "Sort"
                label.textAlignment = .center
                source.contentView.addSubview(label)
            }
            if index >= 20 { self.repeatedNavigationSource = source }
            self.view.addSubview(source)
            button.isHidden = true
            navigationSource = source
        }
        if separateSource != nil {
            // Render the newly created test button before opening, like a real
            // profile button that is already on screen when it is pressed.
            _ = UIGraphicsImageRenderer(bounds: self.view.bounds).image { _ in
                self.view.drawHierarchy(in: self.view.bounds, afterScreenUpdates: true)
            }
        }
        let originalSourceMaskAlpha = separateMask?.alpha
        let sourceView = navigationSource ?? separateSource?.view ?? button
        // Production opts in only single-button header capsules; the gallery
        // exercises the morph on every source shape.
        sourceView.morphsIntoContextMenu = true
        let controller = makeContextController(presentationData: defaultPresentationData(), source: .reference(Source(sourceView, top: button.tag >= 3, insets: insets, path: path)), items: .single(self.items(for: button)))
        self.present(controller, in: .window(.root))
        guard let index else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + ((index == 15 || index == 18 || (index >= 20 && index % 2 == 1)) ? 0.05 : (index < 6 || index >= 12 ? 1.2 : 0.05))) { [weak self, weak controller] in
            guard let self, let controller else { return }
            if let separateMask {
                precondition(separateMask.isHidden, "Separate source glass remained visible during the menu")
                precondition(alreadyHiddenDecoration.isHidden)
            }
            if index == 4 {
                controller.setItems(.single(self.items(for: button, expanded: true)), minHeight: nil, animated: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (index == 4 ? 0.6 : 0)) { [weak self, weak controller] in
                guard let self, let controller else { return }
                if index == 5 { button.removeFromSuperview() }
                if index == 16 { separateSource?.view.removeFromSuperview() }
                if index == 19 { navigationSource?.removeFromSuperview() }
                controller.dismiss(result: .default, completion: { [weak self] in
                    guard let self else { return }
                    if let separateSource {
                        precondition(separateSource.view.subviews.contains(where: { $0.accessibilityIdentifier == "live-profile-foreground" }), "Node-backed foreground was not restored")
                    }
                    if let navigationSource {
                        precondition(navigationSource.transitionView.alpha == 1 && !navigationSource.transitionView.isHidden)
                        if index < 20 || index == 25 {
                            navigationSource.removeFromSuperview()
                            self.repeatedNavigationSource = nil
                        }
                        button.isHidden = false
                    }
                    if let separateMask {
                        precondition(!separateMask.isHidden && separateMask.alpha == originalSourceMaskAlpha, "Separate source glass was not restored")
                        precondition(alreadyHiddenDecoration.isHidden, "Originally hidden decoration was revealed")
                        separateSource?.view.removeFromSuperview()
                        separateBackground?.removeFromSuperview()
                        button.isHidden = false
                    }
                    if index == 5 { self.view.addSubview(button) }
                    precondition(button.superview === self.view && button.frame == originalFrame && button.alpha == 1 && !button.isHidden)
                    button.transform = originalTransform
                    button.layer.mask = originalMask
                    NSLog("[MorphIntegration] PASS \(index + 1)/26 \(self.shapes[index % 6].0)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + (index >= 20 ? 0 : 0.15)) { self.check(index + 1) }
                })
                if index == 14, let separateMask {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        precondition(separateMask.isHidden, "Real backdrop must stay hidden while the composite preview morphs back")
                        NSLog("[MorphIntegration] Real source backdrop remains suppressed during composite dismissal")
                    }
                }
            }
        }
    }
    @available(iOS 26.0, *)
    private func checkProfileOverlap() {
        let source = ContextReferenceContentNode()
        source.frame = CGRect(x: 180, y: 180, width: 90, height: 54)
        let foreground = ASDisplayNode()
        foreground.frame = source.bounds
        let label = UILabel(frame: source.bounds)
        label.text = "More"
        label.textAlignment = .center
        foreground.view.addSubview(label)
        source.addSubnode(foreground)
        let background = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        background.frame = source.frame
        let mask = UIView(frame: background.bounds)
        mask.backgroundColor = .white
        mask.layer.cornerRadius = 16
        background.mask = mask
        self.view.addSubview(background)
        self.view.addSubview(source.view)
        source.view.morphsIntoContextMenu = true
        source.additionalContextMenuSourceViews = [mask]
        source.contextMenuSourcePath = UIBezierPath(roundedRect: source.bounds, cornerRadius: 16)
        source.makeContextMenuSourceContent = { [weak self, weak source] in
            guard let self, let source else { return nil }
            let liveBackground = UIVisualEffectView(effect: background.effect)
            liveBackground.frame = source.bounds
            liveBackground.layer.cornerRadius = 16
            liveBackground.clipsToBounds = true
            return ContextMenuSourceContent(source: source.view, foreground: foreground.view, background: liveBackground, container: self.view)
        }
        _ = UIGraphicsImageRenderer(bounds: self.view.bounds).image { _ in self.view.drawHierarchy(in: self.view.bounds, afterScreenUpdates: true) }
        let first = makeContextController(presentationData: defaultPresentationData(), source: .reference(Source(source.view, top: false)), items: .single(self.items(for: self.buttons[0])))
        self.present(first, in: .window(.root))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            precondition(mask.isHidden)
            var second: ContextController?
            first.dismiss(result: .default, completion: {
                NSLog("[MorphOverlap] older completed; mask hidden=%d", mask.isHidden)
                precondition(mask.isHidden, "Older menu revealed the new menu's shared background")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    second?.dismiss(result: .default, completion: {
                        precondition(!mask.isHidden, "Shared background remained hidden after last menu")
                        precondition(foreground.supernode === source && foreground.view.superview === source.view, "Overlapping menus lost the node-backed foreground")
                        NSLog("[MorphOverlap] ALL CHECKS PASSED")
                        source.view.removeFromSuperview()
                        background.removeFromSuperview()
                    })
                }
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSLog("[MorphOverlap] reopening; mask hidden=%d", mask.isHidden)
                let next = makeContextController(presentationData: defaultPresentationData(), source: .reference(Source(source.view, top: false)), items: .single(self.items(for: self.buttons[0])))
                second = next
                self.present(next, in: .window(.root))
            }
        }
    }

    @objc private func runChecks() {
        guard !self.running else { return }
        self.running = true
        self.check(0)
    }
    private func check(_ index: Int) {
        guard index < 26 else {
            self.running = false
            self.status.text = "ALL 26 INTEGRATION CHECKS PASSED"
            NSLog("[MorphIntegration] ALL CHECKS PASSED")
            return
        }
        self.status.text = "Integration check \(index + 1)/26"
        self.showMenu(self.buttons[index >= 20 ? 1 : index % 6], index: index)
    }
}
#endif
