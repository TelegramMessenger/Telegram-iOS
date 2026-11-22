// A minimal native UIKit navigation app: the reference the custom navigation bar is compared against (footage, lldb).
// Bar items change on a timer, so nothing touches the bar while it animates. Build and install with build.sh.
//
// Launch arguments: -scenario <name> -interval <seconds>
//   editDone     right item Edit <-> Done (prominent, a "Done" title)
//   editCheck    right item Edit <-> the system Done item (the prominent checkmark circle)
//   backCancel   left item: back button <-> Cancel
//   oneTwo       right items [Edit] <-> [Edit, +]
//   pushPop      push a screen with a right item, then pop
//   none         (default) no timer; the content buttons trigger each change by hand
// -systemDone 1 makes a hand-made Edit -> Done change show the system Done item.
// -noopEdit 1 makes Edit do nothing (the press and release alone).
// -noRightAtRoot 1 leaves the root without a right item (a pop to it takes a capsule away).
// -twoText 1 makes One / Two add a text item ("Select") rather than the system add item (they still get two capsules).
// -longRight 1 gives pushed screens a long right item ("Select Messages") in place of Edit, so the trailing capsule's
//   width differs between a pushed screen and the root.
// -probe 1 logs the rightmost capsule's glass and press-view frames every frame (CapsuleProbe), and the transition's
//   cards and the touch (CARDS lines).
// -touchTrigger push|pop pushes (or pops) the moment a touch begins, so the swipe that touch makes is already moving
//   while the transition runs: AXe cannot place a swipe inside a 0.45 s transition otherwise. -startDepth <n> starts
//   n screens deep (for pop). Slow-motion: `xcrun simctl spawn <udid> notifyutil -s
//   com.apple.UIKit.SimulatorSlowMotionAnimationState 1` then `notifyutil -p` the same name (UIKit's drag coefficient
//   becomes 10, as the Simulator's Debug > Slow Animations does); 0 turns it off.
// Keyboard (2026-10-14, docs/superpowers/specs/2026-10-14-native-navigation-keyboard-re.md):
// -textField 1 puts a text field at the top of every screen's buttons. -focusAt <depths> (comma-separated, e.g. 0,1)
//   makes the field of each screen at those depths first responder on its FIRST appearance only (so a pop back to it
//   shows what UIKit restores by itself), in viewDidAppear, or in viewWillAppear with -focusWhen willAppear. Without
//   -focusAt nothing is focused.
//   -probe 1 then also writes KB lines (the keyboard window's UIInputSetContainerView subviews: class, presentation
//   frame in window space, clipsToBounds, alpha, and the first child's frame; each non-app window's plain-UIView
//   direct subviews, which are the transition's keyboard snapshot wrappers (WRAP) and their edge shadow (SHADOW);
//   which screens' fields are first responder; GUIDE bars), MARK lines for keyboard notifications (duration, curve,
//   begin/end frames) and, once per wrapper, ANIM lines with its CA animations' parameters.
// -customInputView 1 gives the fields a striped 300-pt input view (shown even when the simulator is in
//   hardware-keyboard mode). -guideBar 1 pins a 44-pt bar to each screen's keyboardLayoutGuide. -dumpTree 1 writes the
//   other windows' recursiveDescription 6 frames into each transition (tmp/tree.txt). -forceSoftwareKeyboard 1 tries
//   the in-process private calls that did NOT bring the software keyboard back (kept to record that).
// Films: measure/keyboard_run.sh; tables: measure/keyboard_table.py.
// -prominentRight 1 (2026-10-15): the root's right items are a prominent image item outermost (Chats' compose) beside two
//   plain image items (story, proxy), and none while editing (Chats' Edit mode, so -scenario editDone takes them away
//   and back, with the root's left item Edit <-> a prominent Done); pushed screens have one plain image item (a chat's
//   avatar; none with -pushedNoRight 1). For UIKit's grouping of a prominent item,
//   its gap, and how a bar with it morphs (-scenario pushPop).
// -adminsRight 1 (2026-10-15): the root's right items are Channel Administrators': [Edit (text), search (image)] <->
//   [the system Done item], toggled by -scenario editDone, each change with new items (as ItemListController makes).
//   For UIKit's in-place split and merge of a text pill and an image pill.
// -menuPair 1 (2026-10-18): the root's right items are Saved Messages' [search, …], two plain image items sharing one
//   pill, the outer one ("…") opening a menu on tap. For how UIKit morphs a menu out of one item of a multi-item pill.
// -searchBar 1 gives the root screen a stacked search bar (`navigationItem.searchController`, not hidden on scroll), for
//   UIKit's search bar on push and pop (bar RE §7; docs/superpowers/specs/2026-10-15-chat-list-header-transitions-design.md).
//   -searchBarAt <depth> puts it on the screen at that depth instead (1: the pushed screen).
import UIKit

final class ReferenceViewController: UIViewController {
    private let depth: Int
    private var isEditingState = false
    var usesSystemDone = false
    private var hasCancel = false
    private var hasTwo = false
    private(set) var textField: UITextField?
    private var hasAppeared = false

    init(depth: Int) {
        self.depth = depth
        super.init(nibName: nil, bundle: nil)
        self.title = depth == 0 ? "Reference" : "Pushed \(depth)"
        self.navigationItem.largeTitleDisplayMode = .never
        let searchBarDepth = UserDefaults.standard.object(forKey: "searchBarAt") != nil ? UserDefaults.standard.integer(forKey: "searchBarAt") : 0
        if depth == searchBarDepth && UserDefaults.standard.bool(forKey: "searchBar") {
            self.navigationItem.searchController = UISearchController(searchResultsController: nil)
            self.navigationItem.hidesSearchBarWhenScrolling = false
            self.navigationItem.preferredSearchBarPlacement = .stacked
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGroupedBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        if UserDefaults.standard.bool(forKey: "textField") {
            let field = UITextField()
            field.borderStyle = .roundedRect
            field.placeholder = "Text \(self.depth)"
            field.autocorrectionType = .no
            field.widthAnchor.constraint(equalToConstant: 220.0).isActive = true
            if UserDefaults.standard.bool(forKey: "customInputView") {
                field.inputView = StripedInputView(frame: CGRect(x: 0.0, y: 0.0, width: 402.0, height: 300.0))
            }
            stack.addArrangedSubview(field)
            self.textField = field
        }
        for (title, action) in [("Edit / Done", #selector(self.toggleEditDone)), ("Back / Cancel", #selector(self.toggleBackCancel)), ("One / Two", #selector(self.toggleOneTwo)), ("Push", #selector(self.push))] {
            let button = UIButton(configuration: .gray())
            button.setTitle(title, for: .normal)
            button.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            // With a text field the buttons sit high enough to stay above the keyboard.
            UserDefaults.standard.bool(forKey: "textField") ? stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 40.0) : stack.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
        ])
        self.applyRightItems(animated: false)
        // -guideBar 1: a 44-pt orange bar whose bottom is pinned to the keyboard layout guide (a composer's shape).
        if UserDefaults.standard.bool(forKey: "guideBar") {
            let bar = UIView()
            bar.backgroundColor = .orange
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.accessibilityIdentifier = "guideBar"
            self.view.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                bar.heightAnchor.constraint(equalToConstant: 44.0),
                bar.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor),
            ])
        }
        if self.depth == 0 && UserDefaults.standard.bool(forKey: "glowSpike") {
            GlowSpike.install(in: self.view)
        }
    }

    /// -focusAt / -focusWhen: the field of the screen at that depth becomes first responder on its first appearance.
    private var focusesOnFirstAppearance: Bool {
        // A comma-separated list of depths ("0,1").
        let depths = (UserDefaults.standard.string(forKey: "focusAt") ?? "").split(separator: ",").compactMap { Int($0) }
        return !self.hasAppeared && depths.contains(self.depth) && self.textField != nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CapsuleProbe.shared?.mark("viewWillAppear \(self.title ?? "?")")
        if self.focusesOnFirstAppearance && UserDefaults.standard.string(forKey: "focusWhen") == "willAppear" {
            let result = self.textField?.becomeFirstResponder() ?? false
            CapsuleProbe.shared?.mark("focus \(self.title ?? "?") in viewWillAppear -> \(result)")
            ReferenceViewController.forceSoftwareKeyboard()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CapsuleProbe.shared?.mark("viewDidAppear \(self.title ?? "?")")
        if self.focusesOnFirstAppearance && UserDefaults.standard.string(forKey: "focusWhen") != "willAppear" {
            let result = self.textField?.becomeFirstResponder() ?? false
            CapsuleProbe.shared?.mark("focus \(self.title ?? "?") in viewDidAppear -> \(result)")
            ReferenceViewController.forceSoftwareKeyboard()
        }
        self.hasAppeared = true
    }

    /// -forceSoftwareKeyboard 1: the simulator flips into hardware-keyboard mode on its own now and then (the keyboard
    /// then reports zero or 270-pt frames below the screen and shows nothing). `-[UIKeyboardImpl
    /// setInHardwareKeyboardMode:NO shouldMoveKeyboard:YES]` is in-process keyboard state (`_UIKeyboardStateManager`;
    /// no preference is written) and shows the software keyboard again. Private API: the reference app only.
    static func forceSoftwareKeyboard() {
        guard UserDefaults.standard.bool(forKey: "forceSoftwareKeyboard"), let keyboardClass = NSClassFromString("UIKeyboardImpl") as? NSObject.Type else {
            return
        }
        guard let impl = keyboardClass.perform(NSSelectorFromString("activeInstance"))?.takeUnretainedValue() as? NSObject else {
            CapsuleProbe.shared?.mark("forceSoftwareKeyboard: no active keyboard")
            return
        }
        let selector = NSSelectorFromString("setInHardwareKeyboardMode:shouldMoveKeyboard:")
        guard let method = class_getInstanceMethod(type(of: impl), selector) else {
            return
        }
        typealias Function = @convention(c) (NSObject, Selector, Bool, Bool) -> Void
        unsafeBitCast(method_getImplementation(method), to: Function.self)(impl, selector, false, true)
        // `toggleSoftwareKeyboard` (what the Simulator's Cmd-K calls) would also write the persistent
        // AutomaticMinimizationEnabled keyboard preference; `showKeyboard` alone does not.
        _ = impl.perform(NSSelectorFromString("showKeyboard"))
        CapsuleProbe.shared?.mark("forceSoftwareKeyboard applied")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CapsuleProbe.shared?.mark("viewWillDisappear \(self.title ?? "?")")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        CapsuleProbe.shared?.mark("viewDidDisappear \(self.title ?? "?")")
    }

    private func applyRightItems(animated: Bool) {
        var items: [UIBarButtonItem] = []
        if UserDefaults.standard.bool(forKey: "menuPair") && self.depth == 0 {
            // Saved Messages' [search, …]: two plain image items in one pill, the outer one opening a menu on tap.
            let menu = UIMenu(children: [
                UIAction(title: "View as Chats", image: UIImage(systemName: "bubble.left.and.bubble.right"), state: .on, handler: { _ in }),
                UIAction(title: "View as Messages", image: UIImage(systemName: "bubble.left"), handler: { _ in })
            ])
            items.append(UIBarButtonItem(title: nil, image: UIImage(systemName: "ellipsis"), primaryAction: nil, menu: menu))
            items.append(UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: nil, action: nil))
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            return
        }
        if UserDefaults.standard.bool(forKey: "adminsRight") && self.depth == 0 {
            if self.isEditingState {
                items.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.toggleEditDone)))
            } else {
                items.append(UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.toggleEditDone)))
                items.append(UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: nil, action: nil))
            }
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            return
        }
        if UserDefaults.standard.bool(forKey: "prominentRight") {
            if self.depth > 0 {
                // -pushedNoRight 1: pushed screens have no right item, so the root's platters have no partner nearby.
                if !UserDefaults.standard.bool(forKey: "pushedNoRight") {
                    items.append(UIBarButtonItem(image: UIImage(systemName: "person.crop.circle"), style: .plain, target: nil, action: nil))
                }
            } else if !self.isEditingState {
                items.append(UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .prominent, target: self, action: #selector(self.noop)))
                items.append(UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: nil, action: nil))
                items.append(UIBarButtonItem(image: UIImage(systemName: "shield"), style: .plain, target: nil, action: nil))
            }
            if self.depth == 0 {
                // Chats' left button: Edit, and a prominent Done while editing.
                let left = self.isEditingState ? UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(self.toggleEditDone)) : UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.toggleEditDone))
                self.navigationItem.setLeftBarButton(left, animated: animated)
            }
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            return
        }
        // -noRightAtRoot 1: the root has no right item, so a pop to it takes the pushed screen's capsule away.
        if self.depth == 0 && UserDefaults.standard.bool(forKey: "noRightAtRoot") {
            self.navigationItem.setRightBarButtonItems([], animated: animated)
            return
        }
        if self.isEditingState {
            if self.usesSystemDone {
                items.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.toggleEditDone)))
            } else {
                items.append(UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.toggleEditDone)))
            }
        } else {
            // -noopEdit 1: Edit changes nothing, so a press shows the glass's press and release alone.
            let editAction = UserDefaults.standard.bool(forKey: "noopEdit") ? #selector(self.noop) : #selector(self.toggleEditDone)
            let editTitle = self.depth > 0 && UserDefaults.standard.bool(forKey: "longRight") ? "Select Messages" : "Edit"
            items.append(UIBarButtonItem(title: editTitle, style: .plain, target: self, action: editAction))
        }
        if self.hasTwo {
            if UserDefaults.standard.bool(forKey: "twoText") {
                items.append(UIBarButtonItem(title: "Select", style: .plain, target: nil, action: nil))
            } else {
                items.append(UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil))
            }
        }
        self.navigationItem.setRightBarButtonItems(items, animated: animated)
    }

    @objc func toggleEditDone() {
        self.isEditingState.toggle()
        self.applyRightItems(animated: true)
        NSLog("REF: editDone -> %@", self.isEditingState ? "Done" : "Edit")
        CapsuleProbe.shared?.mark("editDone -> \(self.isEditingState ? "Done" : "Edit")")
    }

    @objc func noop() {
        CapsuleProbe.shared?.mark("noop")
    }

    @objc func toggleOneTwo() {
        self.hasTwo.toggle()
        self.applyRightItems(animated: true)
        NSLog("REF: oneTwo -> %@", self.hasTwo ? "two" : "one")
    }

    @objc func toggleBackCancel() {
        self.hasCancel.toggle()
        let item = self.hasCancel ? UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.toggleBackCancel)) : nil
        self.navigationItem.setLeftBarButton(item, animated: true)
        NSLog("REF: backCancel -> %@", self.hasCancel ? "Cancel" : "back")
    }

    @objc func push() {
        self.navigationController?.pushViewController(ReferenceViewController(depth: self.depth + 1), animated: true)
        NSLog("REF: push")
    }
}

/// -customInputView 1: the text fields' input view, 300 pt of 40-pt vertical stripes in pure magenta (255,0,255) and
/// pure cyan (0,255,255), so a film can find it (and its horizontal shift) by colour whatever the simulator's
/// hardware-keyboard state. It goes through the same input-view machinery as the system keyboard
/// (UIKeyboardSceneDelegate placements, the navigation transition's keyboard snapshot wrappers).
final class StripedInputView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.autoresizingMask = [.flexibleWidth]
        self.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        for index in 0 ..< 12 where index % 2 == 1 {
            let stripe = UIView(frame: CGRect(x: CGFloat(index) * 40.0, y: 0.0, width: 40.0, height: frame.height))
            stripe.backgroundColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
            stripe.autoresizingMask = [.flexibleHeight]
            self.addSubview(stripe)
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

/// -glowSpike 1: glass capsules with UIKit's press glow drawn by hand (a white layer under the `vibrantColorMatrix`
/// filters read from `_UIFlexInteraction`'s BigGlow and LittleGlow), at glow 1 and 0.5, beside a plain one, to compare
/// with a real pressed capsule.
enum GlowSpike {
    static func filter(_ matrix: [Float32]) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol else {
            return nil
        }
        let filter = filterClass.perform(NSSelectorFromString("filterWithName:"), with: "vibrantColorMatrix").takeUnretainedValue() as? NSObject
        var values = matrix
        filter?.setValue(NSValue(bytes: &values, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
        return filter
    }

    static let big: [Float32] = [1.1575, -0.1431, -0.0144, 0.0, 0.05, -0.0425, 1.0570, -0.0145, 0.0, 0.05, -0.0426, -0.1430, 1.1856, 0.0, 0.05, 0.0, 0.0, 0.0, 1.0, 0.0]
    static let littleLight: [Float32] = [2.3229, -0.5962, -0.0600, 0.0, 0.0, -0.1772, 1.9040, -0.0602, 0.0, 0.0, -0.1773, -0.5958, 2.4399, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]

    static func install(in view: UIView) {
        // Row 1 at rest; row 2 scaled 1.36 as a press is (a transform on the glass), to see that the glow overlay
        // leaves the scaled glass drawn at its scale.
        for (index, (glow, scale)) in [(0.0, 1.0), (1.0, 1.0), (0.5, 1.0), (0.0, 1.36), (1.0, 1.36), (0.5, 1.36)].enumerated() {
            let size = CGSize(width: 62.33, height: 44.0)
            let glass = UIVisualEffectView(effect: UIGlassEffect())
            glass.frame = CGRect(origin: CGPoint(x: 60.0 + CGFloat(index % 3) * 100.0, y: 200.0 + CGFloat(index / 3) * 100.0), size: size)
            glass.transform = CGAffineTransform(scaleX: scale, y: scale)
            glass.layer.cornerRadius = 22.0
            glass.clipsToBounds = true
            view.addSubview(glass)
            let label = UILabel()
            label.text = "Edit"
            label.font = UIFont.systemFont(ofSize: 17.0)
            label.sizeToFit()
            label.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            glass.contentView.addSubview(label)
            let container = UIView(frame: CGRect(origin: CGPoint(), size: size))
            container.clipsToBounds = true
            container.layer.cornerRadius = 22.0
            container.isUserInteractionEnabled = false
            let bigGlow = UIView(frame: container.bounds)
            bigGlow.backgroundColor = .white
            bigGlow.layer.filters = [GlowSpike.filter(GlowSpike.big)].compactMap { $0 }
            bigGlow.alpha = CGFloat(glow)
            container.addSubview(bigGlow)
            let littleSize = 66.0 + 198.0 * (1.0 - glow)
            let littleGlow = UIView(frame: CGRect(x: (size.width - littleSize) / 2.0, y: (size.height - littleSize) / 2.0, width: littleSize, height: littleSize))
            littleGlow.layer.shadowColor = UIColor.white.cgColor
            littleGlow.layer.shadowRadius = littleSize / 2.0
            littleGlow.layer.shadowOpacity = 1.0
            littleGlow.layer.shadowOffset = .zero
            littleGlow.layer.shadowPath = UIBezierPath(rect: littleGlow.bounds).cgPath
            littleGlow.layer.filters = [GlowSpike.filter(GlowSpike.littleLight)].compactMap { $0 }
            littleGlow.alpha = CGFloat(glow)
            container.addSubview(littleGlow)
            glass.contentView.addSubview(container)
        }
        // Row 3, as the app's transition capsule is built: the glass inside a glass container effect, the container
        // scaled 1.36, and the glow a sibling above the container with the same transform (no glow, glow, glow
        // inside the glass instead).
        for (index, mode) in ["none", "sibling", "inside"].enumerated() {
            let size = CGSize(width: 62.33, height: 44.0)
            let center = CGPoint(x: 60.0 + CGFloat(index) * 100.0 + size.width / 2.0, y: 422.0)
            let container = UIVisualEffectView(effect: UIGlassContainerEffect())
            container.bounds = CGRect(origin: CGPoint(), size: size)
            container.center = center
            container.transform = CGAffineTransform(scaleX: 1.36, y: 1.36)
            let glass = UIVisualEffectView(effect: UIGlassEffect())
            glass.frame = CGRect(origin: CGPoint(), size: size)
            glass.layer.cornerRadius = 22.0
            glass.clipsToBounds = true
            container.contentView.addSubview(glass)
            view.addSubview(container)
            let items = UILabel()
            items.text = "Edit"
            items.sizeToFit()
            let itemsHost = UIView()
            itemsHost.bounds = CGRect(origin: CGPoint(), size: size)
            itemsHost.center = center
            itemsHost.transform = container.transform
            items.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            itemsHost.addSubview(items)
            view.addSubview(itemsHost)
            guard mode != "none" else {
                continue
            }
            let glowView = UIView()
            glowView.clipsToBounds = true
            glowView.layer.cornerRadius = 22.0
            glowView.isUserInteractionEnabled = false
            let bigGlow = UIView(frame: CGRect(origin: CGPoint(), size: size))
            bigGlow.backgroundColor = .white
            bigGlow.layer.filters = [GlowSpike.filter(GlowSpike.big)].compactMap { $0 }
            glowView.addSubview(bigGlow)
            if mode == "sibling" {
                glowView.bounds = CGRect(origin: CGPoint(), size: size)
                glowView.center = center
                glowView.transform = container.transform
                view.addSubview(glowView)
            } else {
                glowView.frame = CGRect(origin: CGPoint(), size: size)
                glass.contentView.addSubview(glowView)
            }
        }
    }
}

/// -probe 1: logs, every frame, where the bar's rightmost glass capsule is drawn: the glass shape (its
/// CABackdropLayer) and UIKit's press view (UIPlatformGlassInteractionView), as window-space presentation frames,
/// with the time of each item change. Written to <tmp>/probe.txt in the app's data container.
/// The window: records the touch for the probe, and runs -touchTrigger.
final class ReferenceWindow: UIWindow {
    static var lastTouch: (location: CGPoint, phase: UITouch.Phase)?
    var touchTrigger: ((UITouch) -> Void)?

    override func sendEvent(_ event: UIEvent) {
        if let touch = event.allTouches?.first {
            ReferenceWindow.lastTouch = (touch.location(in: self), touch.phase)
            if touch.phase == .began {
                CapsuleProbe.shared?.mark(String(format: "touch began %.1f,%.1f", touch.location(in: self).x, touch.location(in: self).y))
                self.touchTrigger?(touch)
            } else if touch.phase == .ended || touch.phase == .cancelled {
                CapsuleProbe.shared?.mark(String(format: "touch %@ %.1f,%.1f", touch.phase == .ended ? "ended" : "cancelled", touch.location(in: self).x, touch.location(in: self).y))
            }
        }
        super.sendEvent(event)
    }
}

final class CapsuleProbe {
    static var shared: CapsuleProbe?
    private let window: UIWindow
    private var link: CADisplayLink?
    private var lines: [String] = []
    private var lastFlush = 0.0
    private var transitionTicks = 0
    private let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("probe.txt")

    init(window: UIWindow) {
        self.window = window
        try? FileManager.default.removeItem(atPath: self.path)
        try? FileManager.default.removeItem(atPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("tree.txt"))
        let link = CADisplayLink(target: self, selector: #selector(self.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        link.add(to: .main, forMode: .common)
        self.link = link
        for (name, label) in [(UIResponder.keyboardWillShowNotification, "willShow"), (UIResponder.keyboardWillHideNotification, "willHide"), (UIResponder.keyboardWillChangeFrameNotification, "willChangeFrame"), (UIResponder.keyboardDidShowNotification, "didShow"), (UIResponder.keyboardDidHideNotification, "didHide")] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let info = notification.userInfo ?? [:]
                let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? -1.0
                let curve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue ?? -1
                let begin = (info[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .null
                let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .null
                self?.mark(String(format: "keyboard %@ duration %.3f curve %d begin %.1f,%.1f,%.1f,%.1f end %.1f,%.1f,%.1f,%.1f", label, duration, curve, begin.minX, begin.minY, begin.width, begin.height, end.minX, end.minY, end.width, end.height))
            }
        }
    }

    /// Every window, the keyboard's included: `+[UIWindow allWindowsIncludingInternalWindows:onlyVisibleWindows:]`
    /// (private; the reference app only).
    private static let allWindows: () -> [UIWindow] = {
        let selector = NSSelectorFromString("allWindowsIncludingInternalWindows:onlyVisibleWindows:")
        guard let method = class_getClassMethod(UIWindow.self, selector) else {
            return { [] }
        }
        typealias Function = @convention(c) (AnyClass, Selector, Bool, Bool) -> NSArray
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return { (function(UIWindow.self, selector, true, false) as? [UIWindow]) ?? [] }
    }()

    /// Once per wrapper view: every CA animation on it and its subviews (keyPath, class, spring parameters, duration,
    /// beginTime, speed, timing function, additive, from/to), as ANIM marks.
    private var dumpedWrappers = Set<ObjectIdentifier>()
    private func dumpAnimations(of wrapper: UIView) {
        guard !self.dumpedWrappers.contains(ObjectIdentifier(wrapper)) else {
            return
        }
        var found = false
        func visit(_ layer: CALayer, path: String) {
            for key in layer.animationKeys() ?? [] {
                guard let animation = layer.animation(forKey: key) else {
                    continue
                }
                found = true
                var text = String(format: "ANIM %@ key %@ %@ duration %.4f begin %.4f (now %.4f) speed %.3f additive %d", path, key, NSStringFromClass(type(of: animation)), animation.duration, animation.beginTime, CACurrentMediaTime(), animation.speed, (animation as? CAPropertyAnimation)?.isAdditive == true ? 1 : 0)
                if let spring = animation as? CASpringAnimation {
                    text += String(format: " mass %.4f stiffness %.4f damping %.4f velocity %.4f settling %.4f", spring.mass, spring.stiffness, spring.damping, spring.initialVelocity, spring.settlingDuration)
                }
                if let basic = animation as? CABasicAnimation {
                    text += " from \(String(describing: basic.fromValue ?? "nil")) to \(String(describing: basic.toValue ?? "nil"))"
                }
                if let timing = animation.timingFunction {
                    var c1: [Float] = [0, 0], c2: [Float] = [0, 0]
                    timing.getControlPoint(at: 1, values: &c1)
                    timing.getControlPoint(at: 2, values: &c2)
                    text += String(format: " timing (%.3f,%.3f,%.3f,%.3f)", c1[0], c1[1], c2[0], c2[1])
                }
                self.mark(text)
            }
            for (index, sublayer) in (layer.sublayers ?? []).enumerated() {
                visit(sublayer, path: path + "/\(index)")
            }
        }
        visit(wrapper.layer, path: "wrapper")
        if found {
            self.dumpedWrappers.insert(ObjectIdentifier(wrapper))
        }
    }

    /// The KB line: in every window other than the app's, each subview of a `UIInputSetContainerView` (the input view
    /// host and, during a navigation transition, the clipping wrappers `-[_UINavigationParallaxTransition
    /// prepareToAnimateKeyboard:]` adds next to it) with its presentation frame in its window, clipsToBounds, alpha and
    /// its first child's frame; and the window's sublayerTransform x.
    private func keyboardLine() -> String {
        var parts: [String] = []
        for window in CapsuleProbe.allWindows() where window !== self.window {
            let windowName = NSStringFromClass(type(of: window))
            let windowLayer = window.layer.presentation() ?? window.layer
            var containers: [String] = []
            func frameInWindow(_ layer: CALayer) -> CGRect {
                let presentation = layer.presentation() ?? layer
                return presentation.convert(presentation.bounds, to: windowLayer)
            }
            func visit(_ view: UIView, depth: Int) {
                if NSStringFromClass(type(of: view)) == "UIInputSetContainerView" {
                    for subview in view.subviews {
                        let frame = frameInWindow(subview.layer)
                        let presentation = subview.layer.presentation() ?? subview.layer
                        var item = String(format: "%@:%.1f,%.1f,%.1f,%.1f:c%d:a%.2f:h%d", NSStringFromClass(type(of: subview)), frame.minX, frame.minY, frame.width, frame.height, subview.clipsToBounds ? 1 : 0, presentation.opacity, subview.isHidden ? 1 : 0)
                        if let child = subview.subviews.first {
                            let childPresentation = child.layer.presentation() ?? child.layer
                            item += String(format: ":[%@ %.1f,%.1f,%.1f,%.1f n%d]", NSStringFromClass(type(of: child)), childPresentation.frame.minX, childPresentation.frame.minY, childPresentation.frame.width, childPresentation.frame.height, subview.subviews.count)
                        }
                        containers.append(item)
                    }
                    return
                }
                if depth < 8 {
                    for subview in view.subviews {
                        visit(subview, depth: depth + 1)
                    }
                }
            }
            visit(window, depth: 0)
            // The transition's keyboard wrappers are direct subviews of the window (siblings of the input set
            // container, or of the text effects window's tracking view): log each plain UIView there.
            for subview in window.subviews where type(of: subview) == UIView.self {
                let frame = frameInWindow(subview.layer)
                let presentation = subview.layer.presentation() ?? subview.layer
                containers.append(String(format: "WRAP:%.2f,%.2f,%.2f,%.2f:c%d:a%.2f:n%d", frame.minX, frame.minY, frame.width, frame.height, subview.clipsToBounds ? 1 : 0, presentation.opacity, subview.subviews.count))
                for child in subview.subviews where NSStringFromClass(type(of: child)).contains("EdgeShadow") {
                    let childFrame = frameInWindow(child.layer)
                    containers.append(String(format: "SHADOW:%.2f,%.2f:a%.3f", childFrame.minX, childFrame.width, (child.layer.presentation() ?? child.layer).opacity))
                }
                self.dumpAnimations(of: subview)
            }
            if !containers.isEmpty || windowName.contains("Keyboard") {
                parts.append(String(format: "%@ tx %.1f hidden %d { %@ }", windowName, (window.layer.presentation() ?? window.layer).sublayerTransform.m41, window.isHidden ? 1 : 0, containers.joined(separator: " ; ")))
            }
        }
        var focused: [String] = []
        var guides: [String] = []
        func visitControllers(_ view: UIView) {
            if let controller = view.next as? ReferenceViewController, controller.textField?.isFirstResponder == true {
                focused.append(controller.title ?? "?")
            }
            if view.accessibilityIdentifier == "guideBar", let controller = view.superview?.next as? ReferenceViewController {
                let windowLayer = self.window.layer.presentation() ?? self.window.layer
                let presentation = view.layer.presentation() ?? view.layer
                let frame = presentation.convert(presentation.bounds, to: windowLayer)
                guides.append(String(format: "%@:%.1f,%.1f", controller.title ?? "?", frame.minX, frame.minY))
            }
            for subview in view.subviews {
                visitControllers(subview)
            }
        }
        visitControllers(self.window)
        return parts.joined(separator: " | ") + " FR " + (focused.isEmpty ? "-" : focused.joined(separator: ",")) + (guides.isEmpty ? "" : " GUIDE " + guides.joined(separator: ";"))
    }

    func mark(_ text: String) {
        self.lines.append(String(format: "%.4f MARK %@", CACurrentMediaTime(), text))
    }

    private func windowFrame(_ layer: CALayer) -> CGRect {
        let presentation = layer.presentation() ?? layer
        let windowLayer = self.window.layer.presentation() ?? self.window.layer
        return presentation.convert(presentation.bounds, to: windowLayer)
    }

    @objc private func tick() {
        var backdrops: [CALayer] = []
        var interactions: [CALayer] = []
        func visit(_ layer: CALayer) {
            if NSStringFromClass(type(of: layer)) == "CABackdropLayer" {
                backdrops.append(layer)
            }
            if let delegate = layer.delegate, NSStringFromClass(type(of: delegate)).contains("PlatformGlassInteractionView") {
                interactions.append(layer)
            }
            for sublayer in layer.sublayers ?? [] {
                visit(sublayer)
            }
        }
        visit(self.window.layer)
        func describe(_ layers: [CALayer]) -> String {
            // The rightmost capsule in the bar.
            let frames = layers.map { self.windowFrame($0) }.filter { $0.midY < 140.0 && $0.midX > 280.0 && $0.width < 200.0 }
            guard let frame = frames.max(by: { $0.midX < $1.midX }) else {
                return "-"
            }
            return String(format: "%.2f,%.2f,%.2f,%.2f", frame.midX, frame.midY, frame.width, frame.height)
        }
        // Every glass in the capsule area, with its effective opacity: during a change the old and new entries can both
        // be there.
        func effectiveOpacity(_ layer: CALayer) -> Float {
            var opacity: Float = 1.0
            var current: CALayer? = layer
            while let item = current {
                let presentation = item.presentation() ?? item
                opacity *= presentation.isHidden ? 0.0 : presentation.opacity
                current = item.superlayer
            }
            return opacity
        }
        let all = backdrops.compactMap { layer -> String? in
            let frame = self.windowFrame(layer)
            guard frame.midY < 140.0 && frame.midX > 280.0 && frame.width < 200.0 else {
                return nil
            }
            // The press grows the glass's own bounds; a pulse scales an ancestor. So bounds / rest size is the press
            // alone, and frame / bounds is everything above it.
            let bounds = (layer.presentation() ?? layer).bounds
            return String(format: "%p:%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f", layer, frame.midX, frame.midY, frame.width, frame.height, effectiveOpacity(layer), bounds.width, bounds.height)
        }
        // UIKit's press view carries the press as its own transform.
        let press = interactions.compactMap { layer -> String? in
            let frame = self.windowFrame(layer)
            guard frame.midY < 140.0 && frame.midX > 280.0 && frame.width < 200.0 else {
                return nil
            }
            let transform = (layer.presentation() ?? layer).transform
            return String(format: "%p:%.4f,%.4f", layer, transform.m11, transform.m22)
        }
        self.lines.append(String(format: "%.4f G %@ I %@ ALL %@ PRESS %@", CACurrentMediaTime(), describe(backdrops), describe(interactions), all.joined(separator: ";"), press.joined(separator: ";")))
        // The transition's cards (`_UIParallaxTransitionCardView`, window minX), each screen's view (window minX, with
        // its title) and the touch, on their own line so probe_series.py's parsing is unchanged.
        var cards: [String] = []
        var screens: [String] = []
        func visitViews(_ view: UIView) {
            let name = NSStringFromClass(type(of: view))
            if name.contains("ParallaxTransitionCardView") {
                cards.append(String(format: "%p:%.2f", view, self.windowFrame(view.layer).minX))
            }
            if let controller = view.next as? ReferenceViewController {
                screens.append(String(format: "%@:%.2f:%d", controller.title ?? "?", self.windowFrame(view.layer).minX, view.window == nil ? 0 : 1))
            }
            for subview in view.subviews {
                visitViews(subview)
            }
        }
        visitViews(self.window)
        // UIKit's press look (`_UIFlexInteraction`): the full-capsule BigGlow, the LittleGlow at the touch, and each
        // button label's alpha, for every capsule in the bar.
        var glows: [String] = []
        func visitGlow(_ layer: CALayer) {
            if let name = layer.name, name.hasPrefix("_UIFlexInteraction.") {
                let presentation = layer.presentation() ?? layer
                let frame = self.windowFrame(layer)
                glows.append(String(format: "%@:%.1f,%.1f:%.3f", name.replacingOccurrences(of: "_UIFlexInteraction.", with: ""), frame.midX, frame.width, presentation.opacity))
            }
            if let delegate = layer.delegate, NSStringFromClass(type(of: delegate)) == "UIButtonLabel" || NSStringFromClass(type(of: delegate)).contains("FlexInteractionGlowContainer") {
                let presentation = layer.presentation() ?? layer
                let frame = self.windowFrame(layer)
                if frame.midY < 140.0 {
                    // Then, for a label, its effective opacity (with every ancestor's) and its on-screen width over
                    // its own: how SwiftUI's item appearance (opacity, scale) is applied above it.
                    var effective: Float = 1.0
                    var current: CALayer? = layer
                    while let item = current {
                        let itemPresentation = item.presentation() ?? item
                        effective *= itemPresentation.isHidden ? 0.0 : itemPresentation.opacity
                        current = item.superlayer
                    }
                    let ownWidth = presentation.bounds.width
                    let scale = ownWidth > 0.0 ? frame.width / ownWidth : 0.0
                    glows.append(String(format: "%@:%.1f:%.3f:%.3f:%.4f", NSStringFromClass(type(of: delegate)) == "UIButtonLabel" ? "Label" : "Container", frame.midX, presentation.opacity, effective, scale))
                }
            }
            for sublayer in layer.sublayers ?? [] {
                visitGlow(sublayer)
            }
        }
        visitGlow(self.window.layer)
        self.lines.append(String(format: "%.4f GLOW %@", CACurrentMediaTime(), glows.joined(separator: ";")))
        let touch = ReferenceWindow.lastTouch.map { String(format: "%.1f,%.1f,%d", $0.location.x, $0.location.y, $0.phase.rawValue) } ?? "-"
        let navigation = self.window.rootViewController as? UINavigationController
        let transitioning = navigation?.transitionCoordinator != nil ? 1 : 0
        self.lines.append(String(format: "%.4f CARDS %@ SCREENS %@ TOUCH %@ TRANSITIONING %d TOP %@", CACurrentMediaTime(), cards.joined(separator: ";"), screens.joined(separator: ";"), touch, transitioning, navigation?.topViewController?.title ?? "-"))
        if UserDefaults.standard.bool(forKey: "textField") {
            self.lines.append(String(format: "%.4f KB %@", CACurrentMediaTime(), self.keyboardLine()))
            // -dumpTree 1: the other windows' recursiveDescription, 6 frames into each transition (tree.txt).
            if UserDefaults.standard.bool(forKey: "dumpTree") {
                if transitioning == 1 {
                    self.transitionTicks += 1
                    if self.transitionTicks == 6 {
                        var text = String(format: "%.4f\n", CACurrentMediaTime())
                        for window in CapsuleProbe.allWindows() where window !== self.window {
                            text += (window.value(forKey: "recursiveDescription") as? String) ?? "?"
                            text += "\n"
                        }
                        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("tree.txt")
                        let previous = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
                        try? (previous + text).write(toFile: path, atomically: true, encoding: .utf8)
                    }
                } else {
                    self.transitionTicks = 0
                }
            }
        }
        let now = CACurrentMediaTime()
        if now - self.lastFlush > 1.0 {
            self.lastFlush = now
            try? self.lines.joined(separator: "\n").write(toFile: self.path, atomically: true, encoding: .utf8)
        }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var timer: Timer?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let root = ReferenceViewController(depth: 0)
        // -systemDone 1: tapping Edit by hand shows the system Done item (the checkmark circle).
        root.usesSystemDone = UserDefaults.standard.bool(forKey: "systemDone")
        let navigationController = UINavigationController(rootViewController: root)
        let window = ReferenceWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
        if UserDefaults.standard.bool(forKey: "probe") {
            CapsuleProbe.shared = CapsuleProbe(window: window)
        }
        for depth in 0 ..< max(0, UserDefaults.standard.integer(forKey: "startDepth")) {
            navigationController.pushViewController(ReferenceViewController(depth: depth + 1), animated: false)
        }
        switch UserDefaults.standard.string(forKey: "touchTrigger") {
        case "push":
            window.touchTrigger = { [weak navigationController] _ in
                guard let navigationController, let top = navigationController.topViewController as? ReferenceViewController else {
                    return
                }
                top.push()
                CapsuleProbe.shared?.mark("push")
            }
        case "pop":
            window.touchTrigger = { [weak navigationController] _ in
                guard let navigationController, navigationController.viewControllers.count > 1 else {
                    return
                }
                navigationController.popViewController(animated: true)
                CapsuleProbe.shared?.mark("pop")
            }
        default:
            break
        }

        let defaults = UserDefaults.standard
        let scenario = defaults.string(forKey: "scenario") ?? "none"
        let interval = defaults.double(forKey: "interval") > 0.0 ? defaults.double(forKey: "interval") : 2.0
        // Back/Cancel needs a back button: start one level deep.
        if scenario == "backCancel" {
            navigationController.pushViewController(ReferenceViewController(depth: 1), animated: false)
        }
        var pushed = false
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard let top = navigationController.topViewController as? ReferenceViewController else {
                return
            }
            switch scenario {
            case "editDone":
                top.toggleEditDone()
            case "editCheck":
                top.usesSystemDone = true
                top.toggleEditDone()
            case "backCancel":
                top.toggleBackCancel()
            case "oneTwo":
                top.toggleOneTwo()
            case "pushPop":
                if pushed {
                    navigationController.popViewController(animated: true)
                    NSLog("REF: pop")
                } else {
                    top.push()
                }
                pushed.toggle()
            default:
                break
            }
        }
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
