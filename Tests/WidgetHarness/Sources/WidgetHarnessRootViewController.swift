import Foundation
import UIKit
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
        self.listHost?.listView.view.removeFromSuperview()
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
        self.listHost = host
        self.view.insertSubview(host.listView.view, belowSubview: self.readoutLabel)
        self.layoutList()
        host.load(posts: WidgetHarnessPosts.load(self.options), incoming: self.options.incoming)
        self.updateReadout()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.readoutLabel.frame = CGRect(x: 0.0, y: self.view.safeAreaInsets.top, width: self.view.bounds.width, height: WidgetHarnessRootViewController.readoutHeight)
        self.layoutList()
    }

    private func layoutList() {
        guard let host = self.listHost else {
            return
        }
        host.listView.view.frame = self.view.bounds
        host.updateLayout(size: self.view.bounds.size, topInset: self.view.safeAreaInsets.top + WidgetHarnessRootViewController.readoutHeight, bottomInset: self.view.safeAreaInsets.bottom)
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

    /// The readout's lines now (Tier 1 reads them directly).
    public func readoutLines() -> [String] {
        return self.listHost?.readoutLines(in: self.view) ?? []
    }

    private func updateReadout() {
        let lines = self.readoutLines()
        self.readoutLabel.accessibilityValue = lines.joined(separator: "\n")
        self.readoutLabel.text = lines.suffix(4).joined(separator: "\n")
    }
}
