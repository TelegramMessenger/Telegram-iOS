import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import HarnessAppContext

public final class HarnessRootViewController: UIViewController {
    public private(set) var panelHost: HarnessPanelHost?
    public private(set) var scenario: HarnessScenario = HarnessScenario.all[0]

    private let settings = HarnessSettings()
    private var harnessAccount: HarnessAccount?
    private var accountDisposable: Disposable?
    private var keyboardHeight: CGFloat = 0.0

    private let backendControl = UISegmentedControl(
        items: [HarnessBackend.engine.rawValue, HarnessBackend.legacy.rawValue])
    private let scenarioLabel = UILabel()
    public let readoutView = HarnessReadoutView()
    public let historyView = HarnessHistoryView()

    deinit {
        self.accountDisposable?.dispose()
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.view.accessibilityIdentifier = "harness.root"

        let options = HarnessLaunchOptions.parse(ProcessInfo.processInfo.arguments)
        self.settings.backend = options.backend
        self.settings.useDarkTheme = options.useDarkTheme
        self.settings.fontSize = options.fontSize
        // The panel takes its theme from the presentation data (see HarnessSharedAccountContext);
        // this makes the harness's own chrome and the system surfaces around it agree.
        self.overrideUserInterfaceStyle = options.useDarkTheme ? .dark : .light
        self.scenario = options.scenario

        self.setUpToolbar()

        NotificationCenter.default.addObserver(
            self, selector: #selector(self.keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        self.accountDisposable = (HarnessAccount.make()
        |> deliverOnMainQueue).start(next: { [weak self] harnessAccount in
            guard let self else {
                return
            }
            self.harnessAccount = harnessAccount
            self.rebuildPanelHost()
        })
    }

    // MARK: - Panel lifecycle

    /// One path for both the first build and a backend switch.
    private func rebuildPanelHost() {
        guard let harnessAccount = self.harnessAccount else {
            return
        }
        self.panelHost?.panel.removeFromSupernode()
        self.panelHost = nil

        let context = HarnessAccountContext(account: harnessAccount, settings: self.settings)
        let host = HarnessPanelHost(
            context: context, settings: self.settings, presentController: { _ in })
        if let seed = self.scenario.seed {
            host.setInputContent(seed)
        }
        // The panel's OWN send hook (`ChatTextInputPanelNode.sendMessage`, `:336`), which
        // `sendButtonPressed()` calls. Assigning it here means a tapped Send button and a hosted
        // test take literally one path rather than two that can drift.
        host.panel.sendMessage = { [weak self] in
            self?.simulateSend()
        }
        // **The readout must not go stale while typing.** It is refreshed from the layout pass,
        // but typing a character that does not change the panel's height triggers no layout — so
        // without this the pane (and the accessibility value every Tier-2 test reads) would show
        // the state from before the keystroke. `updateActivity` is the panel's own per-keystroke
        // hook, the one the chat uses to drive the "typing…" indicator.
        host.panel.updateActivity = { [weak self] in
            self?.refreshReadout()
        }
        // ...and neither does a selection-only or formatting-only change, which reaches the harness
        // only as a new input state pushed through `updateTextInputStateAndMode`.
        host.inputStateDidChange = { [weak self] in
            self?.refreshReadout()
        }
        host.promptForLink = { [weak self] selectedText, current, completion in
            self?.presentLinkPrompt(selectedText: selectedText, current: current, completion: completion)
        }
        host.panel.updateHeight = { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        self.panelHost = host
        self.view.addSubnode(host.panel)
        self.view.setNeedsLayout()
        self.refreshReadout()
    }

    /// Appends a receipt and clears the field. Reached either by tapping the real Send button or
    /// by a hosted test calling it directly; both go through the panel's `sendMessage` hook.
    public func simulateSend() {
        guard let host = self.panelHost else {
            return
        }
        let content = host.panel.inputTextState.content
        guard !content.plainText.isEmpty else {
            return
        }
        self.historyView.append(content, dump: ComposerModelDump.text(for: host))
        host.setInputContent(ChatInputContent())
        self.view.setNeedsLayout()
        self.refreshReadout()
    }

    /// A stand-in for `chatTextLinkEditController`, with stable identifiers for XCUITest.
    /// A hosted test can answer through `linkPromptOverride` instead of presenting anything.
    public var linkPromptOverride: ((String, String?) -> String?)?

    private func presentLinkPrompt(selectedText: String, current: String?, completion: @escaping (String?) -> Void) {
        if let linkPromptOverride = self.linkPromptOverride {
            completion(linkPromptOverride(selectedText, current))
            return
        }
        let alert = UIAlertController(title: "Link", message: selectedText, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = current
            field.placeholder = "https://"
            field.accessibilityIdentifier = "harness.linkField"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in completion(nil) }))
        if current != nil {
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in completion("") }))
        }
        alert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { [weak alert] _ in
            completion(alert?.textFields?.first?.text ?? "")
        }))
        self.present(alert, animated: true)
    }

    // MARK: - Toolbar

    private func setUpToolbar() {
        self.backendControl.accessibilityIdentifier = "harness.backendControl"
        self.backendControl.selectedSegmentIndex = self.settings.backend == .engine ? 0 : 1
        self.backendControl.addTarget(
            self, action: #selector(self.backendChanged), for: .valueChanged)
        self.view.addSubview(self.backendControl)

        self.scenarioLabel.accessibilityIdentifier = "harness.scenarioLabel"
        self.scenarioLabel.font = UIFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
        self.scenarioLabel.textAlignment = .center
        self.scenarioLabel.text = "scenario: \(self.scenario.name)"
        self.view.addSubview(self.scenarioLabel)

        self.view.addSubview(self.historyView)
        self.view.addSubview(self.readoutView)
        self.refreshReadout()
    }

    /// Re-renders the inspection surface. Called after the panel's layout pass, so
    /// `lastMeasuredHeight` is current — calling it before would report the previous pass.
    public func refreshReadout() {
        guard let host = self.panelHost else {
            self.readoutView.update(text: "dump v\(ComposerModelDump.formatVersion) <no panel>")
            return
        }
        self.readoutView.update(text: ComposerModelDump.text(for: host))
    }

    /// **Rebuilds the host from scratch, and must.** `ChatTextInputPanelNode` picks its backend
    /// once, in `init` (`:863-881`), so mutating the settings without rebuilding would leave the
    /// OLD arm on screen under the NEW label — the single most misleading thing this harness
    /// could do.
    @objc private func backendChanged() {
        self.setBackend(self.backendControl.selectedSegmentIndex == 0 ? .engine : .legacy)
    }

    /// The toolbar control's path, for a hosted test that needs the other arm. Rebuilds the panel,
    /// so the scenario seed is re-applied too.
    public func setBackend(_ backend: HarnessBackend) {
        self.settings.backend = backend
        self.backendControl.selectedSegmentIndex = backend == .engine ? 0 : 1
        self.rebuildPanelHost()
        self.view.layoutIfNeeded()
    }

    // MARK: - Layout

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
            as? NSValue)?.cgRectValue else {
            return
        }
        self.keyboardHeight = max(
            0.0, self.view.bounds.height - self.view.convert(frame, from: nil).minY)
        self.view.setNeedsLayout()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = self.view.bounds.width
        let top = self.view.safeAreaInsets.top
        self.backendControl.frame = CGRect(x: 16.0, y: top + 8.0, width: width - 32.0, height: 32.0)
        self.scenarioLabel.frame = CGRect(x: 16.0, y: top + 44.0, width: width - 32.0, height: 16.0)

        guard let host = self.panelHost else {
            return
        }
        let bottomInset = max(self.keyboardHeight, self.view.safeAreaInsets.bottom)
        let height = host.updateLayout(width: width, bottomInset: bottomInset)
        let panelTop = self.view.bounds.height - bottomInset - height
        host.panel.frame = CGRect(x: 0.0, y: panelTop, width: width, height: height)

        let readoutHeight: CGFloat = 140.0
        let readoutTop = max(top + 68.0, panelTop - readoutHeight - 8.0)
        self.readoutView.frame = CGRect(
            x: 16.0, y: readoutTop, width: width - 32.0, height: readoutHeight)
        self.historyView.frame = CGRect(
            x: 0.0, y: top + 68.0,
            width: width, height: max(0.0, readoutTop - (top + 68.0) - 8.0))

        // After the panel's pass, so the dump reports THIS layout rather than the previous one.
        self.refreshReadout()
    }
}
