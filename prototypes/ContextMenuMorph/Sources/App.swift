import UIKit

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ProbeController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
final class ProbeController: UIViewController {
    let engine = LiquidMorphTransition()
    let menu = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    let status = UILabel()
    var buttons: [UIButton] = []
    var source: UIButton?
    var sourcePreview: UITargetedPreview?
    var destination: UITargetedPreview?
    var isPresented = false
    var isPresenting = false
    var isDismissing = false
    var presentation = 0
    var caseIndex = 0
    var completed = 0
    var autoRun = false
    let cases: [(String, CGSize, CGFloat)] = [
        ("Circle", CGSize(width: 48, height: 48), 24),
        ("Capsule", CGSize(width: 180, height: 48), 24),
        ("Square", CGSize(width: 72, height: 72), 0),
        ("Wide", CGSize(width: 310, height: 44), 12),
        ("Tall", CGSize(width: 64, height: 100), 16),
        ("Asymmetric", CGSize(width: 150, height: 58), 0)
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let title = UILabel(frame: CGRect(x: 24, y: 70, width: 345, height: 40))
        title.text = "Custom liquid menu"
        title.font = .boldSystemFont(ofSize: 28)
        view.addSubview(title)
        status.frame = CGRect(x: 24, y: 112, width: 345, height: 44)
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        status.numberOfLines = 2
        status.text = "Ready · iOS \(UIDevice.current.systemVersion)"
        status.accessibilityIdentifier = "status"
        view.addSubview(status)
        for (index, item) in cases.enumerated() {
            let button = UIButton(type: .system)
            button.frame = CGRect(origin: CGPoint(x: index % 2 == 0 ? 24 : 140, y: 180 + CGFloat(index / 2) * 150), size: item.1)
            if index == 3 { button.frame.origin.x = 24; button.frame.origin.y += 82 }
            if index >= 4 { button.frame.origin.y += 50 }
            button.backgroundColor = .systemBlue
            button.tintColor = .white
            button.layer.cornerRadius = item.2
            button.setTitle(item.0, for: .normal)
            button.tag = index
            button.accessibilityIdentifier = "source-\(index)"
            button.addTarget(self, action: #selector(openMenu(_:)), for: .touchUpInside)
            if index == 5 {
                let mask = CAShapeLayer()
                mask.path = shape(for: button).cgPath
                button.layer.mask = mask
            }
            view.addSubview(button)
            buttons.append(button)
        }
        let run = UIButton(type: .system)
        run.frame = CGRect(x: 24, y: 710, width: 330, height: 44)
        run.setTitle("Run shape + interruption checks", for: .normal)
        run.addTarget(self, action: #selector(runChecks), for: .touchUpInside)
        view.addSubview(run)
        menu.cornerConfiguration = .corners(radius: 30)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.frame = CGRect(x: 12, y: 12, width: 256, height: 216)
        stack.distribution = .fillEqually
        for text in ["Reply", "Copy", "Share", "Dismiss"] {
            let row = UIButton(type: .system)
            row.setTitle(text, for: .normal)
            row.contentHorizontalAlignment = .leading
            row.addTarget(self, action: #selector(dismissMenu), for: .touchUpInside)
            stack.addArrangedSubview(row)
        }
        menu.contentView.addSubview(stack)
    }
    func shape(for button: UIButton) -> UIBezierPath {
        if button.tag == 5 {
            return UIBezierPath(roundedRect: button.bounds, byRoundingCorners: [.topLeft, .bottomRight], cornerRadii: CGSize(width: 28, height: 28))
        }
        return UIBezierPath(roundedRect: button.bounds, cornerRadius: cases[button.tag].2)
    }
    func preview(_ view: UIView, path: UIBezierPath) -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = .clear
        params.visiblePath = path
        params.shadowPath = path
        return UITargetedPreview(view: view, parameters: params)
    }
    @objc func openMenu(_ button: UIButton) {
        guard !engine.isAnimating, !isPresented else { return }
        source = button
        let y: CGFloat = button.frame.midY > 450 ? button.frame.minY - 250 : button.frame.maxY + 10
        menu.frame = CGRect(x: min(max(20, button.frame.minX), view.bounds.width - 300), y: y, width: 280, height: 240)
        view.addSubview(menu)
        let from = preview(button, path: shape(for: button))
        let to = preview(menu, path: UIBezierPath(roundedRect: menu.bounds, cornerRadius: 30))
        sourcePreview = from
        destination = to
        isPresented = true
        isPresenting = true
        presentation += 1
        let currentPresentation = presentation
        status.text = "Presenting \(cases[button.tag].0)"
        let started = engine.animate(from: from, to: to, attachment: button.center, in: view, sourceIdentity: button) { [self] in
            // A dismissal that took over this presentation owns the menu from then on.
            guard isPresenting, presentation == currentPresentation else { return }
            isPresenting = false
            assert(menu.superview === view, "Destination parent was not restored")
            assert(button.superview === view, "Source parent was not restored")
            status.text = "Presented \(cases[button.tag].0)"
            if autoRun { dismissMenu() }
        }
        assert(started)
    }
    @objc func dismissMenu() {
        guard isPresented, !isDismissing, let source, let from = destination, let to = sourcePreview else { return }
        // Dismissing during presentation starts now; UIKit hands the running morph over.
        let interruptsPresentation = isPresenting
        isPresenting = false
        isDismissing = true
        status.text = "Dismissing \(cases[source.tag].0)"
        let started = engine.animate(from: from, to: to, attachment: source.center, in: view, sourceIdentity: source, interruptingCurrent: interruptsPresentation) { [self] in
            menu.removeFromSuperview()
            assert(source.superview === view && source.alpha == 1 && !source.isHidden)
            isDismissing = false
            isPresented = false
            sourcePreview = nil
            destination = nil
            completed += 1
            status.text = "Passed \(completed) cycles"
            print("PASS cycle=\(completed) shape=\(cases[source.tag].0) source=\(source.frame)")
            if autoRun {
                caseIndex += 1
                if caseIndex < cases.count * 3 { runNextCase() }
                else { autoRun = false; status.text = "PASS: 18 cycles · 6 shapes · interruption"; print("ALL CHECKS PASSED") }
            }
        }
        assert(started)
    }
    @objc func runChecks() {
        guard !engine.isAnimating, !isPresented else { return }
        completed = 0
        caseIndex = 0
        autoRun = true
        runNextCase()
    }
    func runNextCase() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            openMenu(buttons[caseIndex % cases.count])
            if caseIndex >= cases.count { dismissMenu() }
        }
    }
}
