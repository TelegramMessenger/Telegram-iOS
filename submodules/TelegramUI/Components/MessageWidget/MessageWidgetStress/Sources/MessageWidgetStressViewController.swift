import Foundation
import UIKit

/// A screen that runs the stress kit (MessageWidgetStressRunner) in a stand-in bubble at its top and shows each widget's
/// result under it; at the end it writes the run file into the app's Documents (`stress-<pass>-<date>.json`) and hands
/// its URL to `onFinish` (the Debug Settings entry shares it, the widget harness logs it). For a device's run, as
/// packages/stress CLIENTS.md asks: no debugger attached, low power mode off, the device cool at the start.
public final class MessageWidgetStressViewController: UIViewController {
    private let kit: MessageWidgetStressKit
    private let options: MessageWidgetStressRunner.Options
    private var runner: MessageWidgetStressRunner?
    private let stage = UIView()
    private let log = UITextView()
    private var lines: [String] = []
    /// The run file, once written.
    public var onFinish: ((URL) -> Void)?

    public init(kit: MessageWidgetStressKit, options: MessageWidgetStressRunner.Options) {
        self.kit = kit
        self.options = options
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.stage.clipsToBounds = true
        self.stage.backgroundColor = UIColor(white: 0.94, alpha: 1.0)
        self.view.addSubview(self.stage)
        self.log.isEditable = false
        self.log.font = UIFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
        self.log.textColor = .black
        self.log.backgroundColor = .white
        self.view.addSubview(self.log)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = self.view.safeAreaInsets.top
        let width = CGFloat(self.kit.width)
        // The widgets are 325 px tall at the kit's width; the stage is the bubble's room for one.
        self.stage.frame = CGRect(x: max(0.0, (self.view.bounds.width - width) / 2.0), y: top, width: width, height: 360.0)
        self.log.frame = CGRect(x: 8.0, y: self.stage.frame.maxY + 8.0, width: self.view.bounds.width - 16.0, height: max(0.0, self.view.bounds.height - self.stage.frame.maxY - 8.0 - self.view.safeAreaInsets.bottom))
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard self.runner == nil else {
            return
        }
        UIApplication.shared.isIdleTimerDisabled = true
        let runner = MessageWidgetStressRunner(kit: self.kit, host: self.stage, options: self.options)
        runner.onProgress = { [weak self] line in
            self?.append(line)
        }
        self.runner = runner
        self.append("\(self.options.pass.rawValue) pass: \(self.kit.entries.count) widgets in the kit")
        runner.start { [weak self] data in
            self?.finish(data)
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent || self.isBeingDismissed {
            self.runner?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func append(_ line: String) {
        self.lines.append(line)
        if self.lines.count > 400 {
            self.lines.removeFirst(self.lines.count - 400)
        }
        self.log.text = self.lines.joined(separator: "\n")
        self.log.scrollRangeToVisible(NSRange(location: max(0, (self.log.text as NSString).length - 1), length: 1))
    }

    private func finish(_ data: Data) {
        UIApplication.shared.isIdleTimerDisabled = false
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "stress-\(self.options.pass.rawValue)-\(formatter.string(from: Date())).json"
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            self.append("written: \(url.path)")
            self.onFinish?(url)
        } catch {
            self.append("could not write \(name): \(error)")
        }
    }
}
