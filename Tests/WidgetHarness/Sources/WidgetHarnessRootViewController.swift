import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import HarnessAppContext
import MessageWidget

/// The harness's screen: the real chat bubbles of `WidgetHarnessListHost` full screen, under a small readout whose
/// accessibility value (`harness.readout`) is the whole state, for Tier 2 tests out of process.
public final class WidgetHarnessRootViewController: UIViewController {
    public private(set) var options = WidgetHarnessLaunchOptions()
    public private(set) var listHost: WidgetHarnessListHost?
    private var harnessAccount: HarnessAccount?
    /// The settings the current list was built with (its app context reads them live).
    private var settings: HarnessSettings?
    private var accountDisposable: Disposable?
    private let readoutLabel = UILabel()
    private var readoutTimer: Foundation.Timer?
    private let backSwipe = BackSwipeStandIn()
    /// Under the readout: the held context menu's End (`harness.endMenu`) and a text selection's actions
    /// (`harness.menu.<title>`), as buttons a Tier 2 test taps.
    private let menuBar = UIStackView()
    private var endMenuButton: UIButton?
    private var openMenuButton: UIButton?
    private var selectionButtons: [UIButton] = []
    /// The selection menu whose actions the buttons are.
    private weak var buttonsMenu: WidgetHarnessContextMenuController?

    public static let readoutHeight: CGFloat = 44.0

    deinit {
        self.accountDisposable?.dispose()
        self.readoutTimer?.invalidate()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.accessibilityIdentifier = "harness.root"
        self.options = WidgetHarnessLaunchOptions.parse(ProcessInfo.processInfo.arguments)

        self.readoutLabel.font = UIFont.monospacedSystemFont(ofSize: 9.0, weight: .regular)
        self.readoutLabel.numberOfLines = 4
        self.readoutLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        self.readoutLabel.isAccessibilityElement = true
        self.readoutLabel.accessibilityIdentifier = "harness.readout"
        self.view.addSubview(self.readoutLabel)

        self.menuBar.axis = .horizontal
        self.menuBar.spacing = 8.0
        self.menuBar.distribution = .fillProportionally
        self.view.addSubview(self.menuBar)
        // A text selection presents its actions through the chat's context menu controller; the harness's keeps them.
        setContextMenuControllerProvider { arguments in
            return WidgetHarnessContextMenuController(actions: arguments.actions)
        }

        self.backSwipe.onBegan = { [weak self] in
            self?.listHost?.record("back")
        }
        self.backSwipe.install(on: self.view)
        // The chat's lock while a widget control is held (ChatControllerNode installs the same on the chat's view).
        self.view.addGestureRecognizer(MessageWidgetChatLockRecognizer())

        self.accountDisposable = (HarnessAccount.make()
        |> deliverOnMainQueue).start(next: { [weak self] harnessAccount in
            guard let self else {
                return
            }
            self.harnessAccount = harnessAccount
            self.rebuild()
        })

        self.readoutTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] _ in
            self?.updateReadout()
        })
    }

    /// Tier 1's entry: the same as relaunching with these arguments, in process.
    public func reload(options: WidgetHarnessLaunchOptions) {
        self.options = options
        self.rebuild()
    }

    private func rebuild() {
        guard let harnessAccount = self.harnessAccount else {
            return
        }
        self.listHost?.node.view.removeFromSuperview()
        self.listHost = nil

        let settings = HarnessSettings()
        settings.useDarkTheme = self.options.useDarkTheme
        MessageWidgetKillSwitch.isEngaged = self.options.killSwitch
        self.settings = settings
        self.overrideUserInterfaceStyle = self.options.useDarkTheme ? .dark : .light
        let context = HarnessAccountContext(account: harnessAccount, settings: settings)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.view.backgroundColor = presentationData.theme.chat.inputPanel.panelBackgroundColor

        let host = WidgetHarnessListHost(context: context)
        host.holdsMenu = self.options.holdsMenu
        host.copyProtected = self.options.copyProtected
        host.canQuery = self.options.canQuery
        host.backgroundQuery = self.options.backgroundQuery
        host.botChat = self.options.botChat
        host.onContextMenuChange = { [weak self] open in
            self?.contextMenuChanged(open: open)
        }
        host.onSelectionMenu = { [weak self] menu in
            self?.showSelectionMenu(menu)
        }
        self.listHost = host
        self.view.insertSubview(host.node.view, belowSubview: self.readoutLabel)
        self.layoutList()
        if let raw = self.options.textSize, let textSize = PresentationFontSize(rawValue: raw) {
            host.setFontSize(textSize)
        }
        host.load(posts: WidgetHarnessPosts.load(self.options), incoming: self.options.incoming)
        self.updateOpenMenuButton(menuOpen: false)
        self.updateReadout()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.readoutLabel.frame = CGRect(x: 0.0, y: self.view.safeAreaInsets.top, width: self.view.bounds.width, height: WidgetHarnessRootViewController.readoutHeight)
        self.menuBar.frame = CGRect(x: 8.0, y: self.readoutLabel.frame.maxY + 4.0, width: self.view.bounds.width - 16.0, height: 36.0)
        self.layoutList()
    }

    private func layoutList() {
        guard let host = self.listHost else {
            return
        }
        host.node.frame = self.view.bounds
        host.updateLayout(size: self.view.bounds.size, topInset: self.view.safeAreaInsets.top + WidgetHarnessRootViewController.readoutHeight, bottomInset: self.view.safeAreaInsets.bottom)
    }

    private func makeMenuButton(title: String, identifier: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction(title: title, handler: { _ in
            action()
        }))
        button.accessibilityIdentifier = identifier
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        return button
    }

    /// With a held menu, `harness.openMenu` lifts the newest widget bubble while no menu is open.
    private func updateOpenMenuButton(menuOpen: Bool) {
        self.openMenuButton?.removeFromSuperview()
        self.openMenuButton = nil
        if self.options.holdsMenu && !menuOpen {
            let button = self.makeMenuButton(title: "Open", identifier: "harness.openMenu", action: { [weak self] in
                self?.listHost?.openContextMenuOnNewestWidget()
            })
            self.openMenuButton = button
            self.menuBar.insertArrangedSubview(button, at: 0)
        }
    }

    private func contextMenuChanged(open: Bool) {
        self.updateOpenMenuButton(menuOpen: open)
        self.endMenuButton?.removeFromSuperview()
        self.endMenuButton = nil
        if open && self.options.holdsMenu {
            let button = self.makeMenuButton(title: "End", identifier: "harness.endMenu", action: { [weak self] in
                self?.listHost?.endContextMenu()
            })
            self.endMenuButton = button
            self.menuBar.insertArrangedSubview(button, at: 0)
        }
        if !open {
            self.removeSelectionButtons()
        }
    }

    private func showSelectionMenu(_ menu: WidgetHarnessContextMenuController) {
        self.removeSelectionButtons()
        self.buttonsMenu = menu
        menu.onDismiss = { [weak self, weak menu] in
            guard let self else {
                return
            }
            // An older menu going (a selection elsewhere in the bubble was cancelled) leaves the newer menu's buttons.
            if self.buttonsMenu === menu {
                self.removeSelectionButtons()
            }
            self.listHost?.recordSelectionMenuDismissed()
        }
        for action in menu.actions {
            let title = WidgetHarnessContextMenuController.title(of: action)
            let button = self.makeMenuButton(title: title, identifier: "harness.menu.\(title)", action: {
                action.action()
            })
            self.selectionButtons.append(button)
            self.menuBar.addArrangedSubview(button)
        }
    }

    private func removeSelectionButtons() {
        for button in self.selectionButtons {
            button.removeFromSuperview()
        }
        self.selectionButtons.removeAll()
    }

    /// Settings ▸ Appearance ▸ Text Size changed while the chat is open.
    public func setTextSize(_ fontSize: PresentationFontSize) {
        self.listHost?.setFontSize(fontSize)
        self.updateReadout()
    }

    /// The widget bubbles' widget areas and content bounds now (`WidgetHarnessListHost.widgetAreas`).
    public func widgetAreas() -> [(path: String, area: CGRect, content: CGRect)] {
        return self.listHost?.widgetAreas(in: self.view) ?? []
    }

    /// The readout's lines now (Tier 1 reads them directly), in the window's coordinates, which are the screen's a Tier 2
    /// test taps in (the root view sits about 10 pt off them inside the system's presentation views).
    public func readoutLines() -> [String] {
        return self.listHost?.readoutLines(in: self.view.window ?? self.view) ?? []
    }

    private func updateReadout() {
        let lines = self.readoutLines()
        self.readoutLabel.accessibilityValue = lines.joined(separator: "\n")
        self.readoutLabel.text = lines.suffix(4).joined(separator: "\n")
    }
}

/// Stands in for the chat's navigation container: its back swipe, an `InteractiveTransitionGestureRecognizer` to the
/// right that every pan below it waits for, as `NavigationContainer` declares (`shouldBeRequiredToFailBy`), which
/// records `back` when it begins. It honours the restrictions of the view a touch lands on
/// (`disablesInteractiveTransitionGestureRecognizerNow`), as the chat's does.
private final class BackSwipeStandIn: NSObject, UIGestureRecognizerDelegate {
    var onBegan: (() -> Void)?

    func install(on view: UIView) {
        let recognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.changed(_:)), allowedDirections: { _ in
            return .right
        })
        recognizer.delegate = self
        recognizer.delaysTouchesBegan = false
        recognizer.cancelsTouchesInView = true
        view.addGestureRecognizer(recognizer)
    }

    @objc private func changed(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            self.onBegan?()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer && !(otherGestureRecognizer is InteractiveTransitionGestureRecognizer)
    }
}
