import UIKit
import RichTextEditorCore
import RichTextInputDecUpstream
import RichTextEngineEditor
// `@testable`, and it is not laziness. Two things this screen exists to show are module-internal:
//   * `RichTextInputContractViolation.reporter` — the seam every UNIMPLEMENTED adapter requirement
//     reports through. With NO reporter installed its DEBUG branch is `assertionFailure`, i.e. the
//     app TRAPS on the first unimplemented requirement, which would make a hand-testing host
//     useless. Installing a reporter turns each one into a visible line instead — and a visible
//     line is the entire point: this programme's signature failure is a call site that compiled
//     cleanly and silently did nothing, ten times.
//   * `IDTextEditorBackend.isSupported()` and `canvasForTesting`, which are how the screen can say
//     WHICH canvas is actually live. `.inputDecIfSupported` falls back to legacy silently; a host
//     that reported the arm the user PICKED rather than the arm they GOT would be lying in exactly
//     the direction this programme keeps being burned by.
// Neither is worth widening the shipping module's public surface for. `Host/project.yml` sets
// `ENABLE_TESTABILITY` so this resolves.
@testable import RichTextEditorUIKit

/// **The InputDec host screen.** Phase 4's deliverable: the first surface on which a human can type
/// into the ported engine.
///
/// Telegram is closed to this engine — `IDBlockTextView.m`'s `+load` runs before `main()` and can
/// `@throw` uncaught, so no runtime flag can gate it — and five earlier rounds of hands-on defects
/// (a caret crash, a dead keyboard, a segfaulting backspace, missing autocorrect, a spelling
/// underline that turned out to be Telegram's own overlay) all reached us through Telegram. This
/// screen is the replacement channel.
///
/// ## The four arms, and why there are four rather than one
///
/// A defect is only actionable once you know whose it is. The arms are the same vocabulary the
/// parity suites use, plus one:
///
/// * **InputDec** — `RichTextEditorView` on the phase-2/3 adapter (`IDUpstreamInputBackend` →
///   `IDDocumentCanvasView`). The thing under test.
/// * **Legacy** — the same `RichTextEditorView` on the shipping backend. **The control.** A
///   divergence Legacy also shows is not something the port introduced.
/// * **Raw engine** — upstream's own `IDBlockTextView`, with no adapter and no Telegram canvas in
///   the path. Separates "the adapter is wrong" from "the engine does this".
/// * **Stock** — a plain `UITextView`. The oracle: what UIKit itself does.
/// * **Engine editor** — `RichTextEngineEditorView` (Task 3): maps Telegram's `Document` straight
///   onto the same engine, with no `IDUpstreamInputBackend`/`IDDocumentCanvasView` layer between
///   them. R2's own arm — the Tier B `EngineParityHarness`'s "hosted" side is exactly this type,
///   so this is the first surface where that automated comparison is also something a human can
///   type into by hand.
///
/// Switch arms with the segmented control and the same seed document is loaded into each, so any
/// two arms can be compared on the same input within seconds.
final class HostRootViewController: UIViewController {

    // MARK: - Arms

    // MARK: - Test seam
    //
    // `Arm`, `currentEditor`, `violations` and `select(arm:)` are `internal` rather than `private`
    // so `InputDecHostScreenSmokeTests` — a HOSTED test, running inside this very app — can drive
    // every arm and assert the engine really came up. That test is the reason this screen can be
    // handed over without someone having launched it by hand first: "it compiled" has been a false
    // signal ten times in this programme.

    enum Arm: Int, CaseIterable {
        case inputDec, legacy, rawEngine, stock, engineEditor

        var title: String {
            switch self {
            case .inputDec: return "InputDec"
            case .legacy: return "Legacy"
            case .rawEngine: return "Raw engine"
            case .stock: return "Stock"
            case .engineEditor: return "Engine editor"
            }
        }
    }

    /// The seed document. **The misspelled word is deliberate**: the user's fifth and still-open
    /// defect is "corrected words are not underlined", and phase 4's experiment proved a hosted
    /// process DOES paint the marker — so that defect is now one keystroke away on this screen.
    /// Correct "mispelled" to "misspelled" and the red underline must disappear.
    private static let seedParagraphs = [
        "The quick brown fox jumps over the lazy dog.",
        "This word is mispelled — correct it and the underline must go.",
        "",
    ]

    private(set) var arm: Arm = .inputDec
    private var editorContainer = UIView()
    private(set) var currentEditor: UIView?
    private(set) var violations: [String] = []

    private let armControl = UISegmentedControl(items: Arm.allCases.map(\.title))
    private let statusLabel = UILabel()
    private let violationsView = UITextView()
    private var editorBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "InputDec Host"

        installContractViolationReporter()
        buildChrome()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        select(arm: .inputDec)
    }

    // MARK: - The violation channel

    /// Every adapter requirement that is NOT implemented reports a NAMED violation rather than
    /// returning a plausible value. Route them to the on-screen log.
    private func installContractViolationReporter() {
        RichTextInputContractViolation.reporter = { [weak self] message in
            // The engine calls back on the main thread, but a reporter that assumes so and is
            // wrong would corrupt the array silently — which is the failure shape this whole screen
            // is built to make loud.
            let record = "\(Self.timestamp())  \(message)"
            if Thread.isMainThread {
                self?.append(violation: record)
            } else {
                DispatchQueue.main.async { self?.append(violation: record) }
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func append(violation: String) {
        violations.append(violation)
        NSLog("INPUTDEC-HOST violation: %@", violation)
        refreshViolations()
    }

    private func refreshViolations() {
        violationsView.text = violations.isEmpty
            ? "No contract violations yet."
            : violations.suffix(200).joined(separator: "\n")
        violationsView.textColor = violations.isEmpty ? .secondaryLabel : .systemRed
        if !violations.isEmpty {
            let end = NSRange(location: (violationsView.text as NSString).length, length: 0)
            violationsView.scrollRangeToVisible(end)
        }
        updateStatus()
    }

    // MARK: - Chrome

    private func buildChrome() {
        armControl.selectedSegmentIndex = Arm.inputDec.rawValue
        armControl.addTarget(self, action: #selector(armChanged), for: .valueChanged)
        // Accessibility identifiers exist for the UI tier (tranche T6), not for VoiceOver: an
        // XCUITest runs out of process and can only address what the accessibility tree exposes.
        armControl.accessibilityIdentifier = "host.arm"
        statusLabel.accessibilityIdentifier = "host.status"
        violationsView.accessibilityIdentifier = "host.violations"
        editorContainer.accessibilityIdentifier = "host.editor" 

        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .secondaryLabel

        violationsView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        violationsView.isEditable = false
        violationsView.backgroundColor = .secondarySystemBackground
        violationsView.layer.cornerRadius = 6

        editorContainer.backgroundColor = .secondarySystemBackground
        editorContainer.layer.cornerRadius = 6
        editorContainer.clipsToBounds = true

        let dump = UIButton(type: .system)
        dump.setTitle("Dump", for: .normal)
        dump.addTarget(self, action: #selector(dumpTapped), for: .touchUpInside)
        let clear = UIButton(type: .system)
        clear.setTitle("Clear log", for: .normal)
        clear.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        let reset = UIButton(type: .system)
        reset.setTitle("Reset", for: .normal)
        reset.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [dump, clear, reset, UIView()])
        buttons.axis = .horizontal
        buttons.spacing = 16

        for subview in [armControl, statusLabel, editorContainer, buttons, violationsView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let guide = view.safeAreaLayoutGuide
        let bottom = violationsView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8)
        editorBottomConstraint = bottom
        NSLayoutConstraint.activate([
            armControl.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            armControl.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            armControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),

            statusLabel.topAnchor.constraint(equalTo: armControl.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: armControl.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: armControl.trailingAnchor),

            editorContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            editorContainer.leadingAnchor.constraint(equalTo: armControl.leadingAnchor),
            editorContainer.trailingAnchor.constraint(equalTo: armControl.trailingAnchor),

            buttons.topAnchor.constraint(equalTo: editorContainer.bottomAnchor, constant: 6),
            buttons.leadingAnchor.constraint(equalTo: armControl.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: armControl.trailingAnchor),

            violationsView.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 6),
            violationsView.leadingAnchor.constraint(equalTo: armControl.leadingAnchor),
            violationsView.trailingAnchor.constraint(equalTo: armControl.trailingAnchor),
            violationsView.heightAnchor.constraint(equalToConstant: 110),
            bottom,
        ])
        refreshViolations()
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? NSValue else { return }
        let keyboardTop = view.convert(frame.cgRectValue, from: nil).minY
        let overlap = max(0, view.bounds.maxY - keyboardTop - view.safeAreaInsets.bottom)
        editorBottomConstraint?.constant = -8 - overlap
        view.layoutIfNeeded()
    }

    // MARK: - Actions

    @objc private func armChanged() {
        guard let next = Arm(rawValue: armControl.selectedSegmentIndex) else { return }
        select(arm: next)
    }

    @objc private func clearTapped() {
        violations.removeAll()
        refreshViolations()
    }

    @objc private func resetTapped() {
        select(arm: arm)
    }

    /// Prints the arm's whole observable state to the console AND to the log view. `Dump` is what
    /// turns "it looks wrong" into a bug report: it records the text, the selection, and the live
    /// canvas class, so a screenshot is not the only evidence.
    @objc private func dumpTapped() {
        var lines = ["--- dump (\(arm.title)) ---"]
        if let input = currentEditor as? UITextInput {
            let text = input.text(in: input.textRange(from: input.beginningOfDocument,
                                                     to: input.endOfDocument)!) ?? ""
            lines.append("text: \(text.debugDescription)")
            if let selection = input.selectedTextRange {
                let start = input.offset(from: input.beginningOfDocument, to: selection.start)
                let end = input.offset(from: input.beginningOfDocument, to: selection.end)
                lines.append("selection: [\(start), \(end))")
            } else {
                lines.append("selection: nil")
            }
        }
        if let editor = currentEditor as? RichTextEditorView {
            let input = editor.canvasForTesting
            let text = input.text(in: input.textRange(from: input.beginningOfDocument,
                                                     to: input.endOfDocument)!) ?? ""
            lines.append("canvas text: \(text.debugDescription)")
            lines.append("blocks: \(editor.document.blocks.count)")
        }
        if let engine = currentEditor as? IDBlockTextView {
            lines.append("blocks: \(engine.attributedBlocks.map(\.string))")
        }
        lines.append(liveCanvasDescription())
        for line in lines { NSLog("INPUTDEC-HOST %@", line) }
        violations.append(contentsOf: lines)
        refreshViolations()
    }

    // MARK: - Building an arm

    func select(arm: Arm) {
        self.arm = arm
        armControl.selectedSegmentIndex = arm.rawValue
        currentEditor?.resignFirstResponder()
        currentEditor?.removeFromSuperview()

        let editor = makeEditor(for: arm)
        editor.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.addSubview(editor)
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: editorContainer.topAnchor),
            editor.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: editorContainer.bottomAnchor),
        ])
        currentEditor = editor
        view.layoutIfNeeded()
        updateStatus()
    }

    private func makeEditor(for arm: Arm) -> UIView {
        switch arm {
        case .inputDec:
            return makeRichTextEditor(backend: .inputDecIfSupported)
        case .legacy:
            return makeRichTextEditor(backend: .legacy)
        case .rawEngine:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17.0),
                .foregroundColor: UIColor.label,
            ]
            let blocks = Self.seedParagraphs.map { NSAttributedString(string: $0, attributes: attributes) }
            let engine = IDBlockTextView(frame: .zero, attributedBlocks: blocks)
            engine.isEditable = true
            engine.isSelectable = true
            return engine
        case .stock:
            let stock = UITextView(frame: .zero)
            stock.font = .systemFont(ofSize: 17.0)
            stock.backgroundColor = .clear
            stock.spellCheckingType = .yes
            stock.autocorrectionType = .yes
            stock.text = Self.seedParagraphs.joined(separator: "\n")
            return stock
        case .engineEditor:
            let editor = RichTextEngineEditorView(frame: .zero)
            editor.document = Document(blocks: Self.seedParagraphs.enumerated().map { index, text in
                .paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                          runs: text.isEmpty ? [] : [TextRun(text: text)]))
            })
            return editor
        }
    }

    private func makeRichTextEditor(backend: RichTextEditorInputBackendPreference) -> RichTextEditorView {
        // `.inputDecIfSupported`, never `.inputDecRequired`: the required form is a
        // `preconditionFailure` on a runtime where `isSupported()` is false, and a host app that
        // traps on launch teaches nothing. The status line below reports the canvas that was
        // ACTUALLY built, so a silent fallback is visible rather than mistaken for a passing arm.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                        inputBackend: backend)
        editor.backgroundColor = .clear
        editor.isSpellCheckingEnabled = true
        editor.document = Document(blocks: Self.seedParagraphs.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                      runs: text.isEmpty ? [] : [TextRun(text: text)]))
        })
        return editor
    }

    // MARK: - Status

    /// Reports what is ACTUALLY on screen, never what was requested.
    func liveCanvasDescription() -> String {
        guard let editor = currentEditor else { return "canvas: <none>" }
        if let rich = editor as? RichTextEditorView {
            return "canvas: \(String(describing: type(of: rich.canvasForTesting)))"
        }
        return "canvas: \(String(describing: type(of: editor)))"
    }

    private func updateStatus() {
        let supported = IDTextEditorBackend.isSupported()
        var lines = ["arm: \(arm.title)   \(liveCanvasDescription())",
                     "IDTextEditorBackend.isSupported() = \(supported)   "
                     + "violations: \(violations.count)"]
        if arm == .inputDec, let rich = currentEditor as? RichTextEditorView,
           !(rich.canvasForTesting is IDDocumentCanvasView) {
            lines.append("⚠️ FELL BACK TO LEGACY — this is NOT the InputDec arm.")
        }
        statusLabel.text = lines.joined(separator: "\n")
        statusLabel.textColor = violations.isEmpty ? .secondaryLabel : .systemRed
    }
}
