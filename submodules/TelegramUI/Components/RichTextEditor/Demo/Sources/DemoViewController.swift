import UIKit
import PhotosUI
import RichTextEditorCore
import RichTextEditorUIKit

final class DemoViewController: UIViewController, PHPickerViewControllerDelegate {
    private let editor = RichTextEditorView()

    private func textCell(_ id: String, _ lines: [String]) -> Cell {
        Cell(id: BlockID(id), blocks: lines.enumerated().map { i, t in
            .paragraph(ParagraphBlock(id: BlockID("\(id)p\(i)"), runs: [TextRun(text: t)]))
        })
    }

    /// An inline custom-emoji run (one U+FFFC carrying an EmojiRef) — resolved to a view by the provider.
    private func emojiRun(_ id: String, _ instance: String) -> TextRun {
        TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: EmojiRef(id: id, instanceID: instance, altText: ":\(id):")))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        overrideUserInterfaceStyle = .light

        let table = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 140), ColumnSpec(width: 110), ColumnSpec(width: 110)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [textCell("h0", ["Name"]), textCell("h1", ["Mass (suns)"]), textCell("h2", ["Distance"])]),
                Row(id: BlockID("r1"), cells: [
                    Cell(id: BlockID("c0"), blocks: [.paragraph(ParagraphBlock(id: BlockID("c0p"),
                        runs: [TextRun(text: "Sagittarius A* "), emojiRun("spinner", "cell-spin")]))]),
                    textCell("c1", ["4.3 M"]), textCell("c2", ["26,000 ly"])]),
                Row(id: BlockID("r2"), cells: [textCell("d0", ["M87*"]), textCell("d1", ["6.5 B"]), textCell("d2", ["53M ly"])]),
            ])
        let wideTable = TableBlock(id: BlockID("wt"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100),
                      ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("wr0"), isHeader: true, cells: [
                    textCell("w00", ["Col 1"]), textCell("w01", ["Col 2"]), textCell("w02", ["Col 3"]),
                    textCell("w03", ["Col 4"]), textCell("w04", ["Col 5"]), textCell("w05", ["Col 6"]),
                    textCell("w06", ["Col 7"]),
                ]),
                Row(id: BlockID("wr1"), cells: [
                    textCell("w10", ["A"]), textCell("w11", ["B"]), textCell("w12", ["C"]),
                    textCell("w13", ["D"]), textCell("w14", ["E"]), textCell("w15", ["F"]),
                    textCell("w16", ["G"]),
                ]),
            ])
        if let collapse = UIImage(systemName: "arrow.down.right.and.arrow.up.left"),
           let expand = UIImage(systemName: "arrow.up.left.and.arrow.down.right") {
            editor.quoteCollapseIcons = RichTextEditorQuoteCollapseIcons(
                collapse: collapse.withRenderingMode(.alwaysTemplate),
                expand: expand.withRenderingMode(.alwaysTemplate))
        }
        editor.document = Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("title"), style: .heading1, runs: [TextRun(text: "Into the Dark")])),
                .paragraph(ParagraphBlock(id: BlockID("intro"), runs: [
                    TextRun(text: "Black holes "), emojiRun("spinner", "intro-spin"),
                    TextRun(text: " are the strangest objects we know "), emojiRun("star", "intro-star"),
                    TextRun(text: ". Places where gravity pulls so hard that not even light escapes."),
                ])),
                .media(MediaBlock(id: BlockID("media0"), mediaID: "demo-1", kind: .image, naturalSize: Size2D(width: 1280, height: 720))),
                .paragraph(ParagraphBlock(id: BlockID("spoilerDemo"), runs: [
                    TextRun(text: "Tap to reveal: "),
                    TextRun(text: "this is a hidden spoiler", attributes: CharacterAttributes(spoiler: true)),
                ])),
                .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Three things to know")])),
                .paragraph(ParagraphBlock(id: BlockID("l0"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "Form when massive stars collapse")])),
                .paragraph(ParagraphBlock(id: BlockID("l1"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "The point of no return is the event horizon")])),
                .paragraph(ParagraphBlock(id: BlockID("l2"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "Time slows as you approach one")])),
                .paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Black holes are where the universe stops making sense. They bend time, swallow light, and remind us how little we really understand.")])),
                .paragraph(ParagraphBlock(id: BlockID("famous"), style: .heading1, runs: [TextRun(text: "Famous black holes")])),
                .table(table),
                .paragraph(ParagraphBlock(id: BlockID("wide"), style: .heading1, runs: [TextRun(text: "Wide table (horizontal scroll)")])),
                .table(wideTable),
                .paragraph(ParagraphBlock(id: BlockID("end"), runs: [TextRun(text: "")])),
            ])

        editor.registerMediaViewProvider { items, _, _, _ in DemoMediaItemView(mediaID: items.first?.mediaID ?? "") }

        editor.registerEmojiViewProvider { id, size in
            switch id {
            case "spinner":
                let v = DemoEmojiView(frame: CGRect(origin: .zero, size: size))
                v.backgroundColor = .clear
                let dot = CALayer()
                dot.frame = CGRect(x: size.width * 0.15, y: size.height * 0.15,
                                   width: size.width * 0.7, height: size.height * 0.7)
                dot.cornerRadius = dot.frame.width / 2
                dot.backgroundColor = UIColor.systemPurple.cgColor
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0; spin.toValue = 2 * Double.pi
                spin.duration = 1.0; spin.repeatCount = .infinity; spin.isRemovedOnCompletion = false
                dot.add(spin, forKey: "spin")
                v.layer.addSublayer(dot)
                return v
            default: // a static colored square ("star")
                let v = DemoEmojiView(frame: CGRect(origin: .zero, size: size))
                v.backgroundColor = .systemYellow
                v.layer.cornerRadius = 3
                return v
            }
        }

        let bar = makeToolbar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        view.addSubview(editor)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: g.topAnchor),
            bar.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 52),
            editor.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
            editor.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -16),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
        editor.selectFirstTableColumn()   // demo: showcase the Phase 6d table handles + column selection
    }

    /// A horizontally-scrollable button bar so every command stays reachable on a phone-width screen.
    /// Buttons (and menu-buttons) don't become first responder, so the editor keeps its selection.
    private func makeToolbar() -> UIView {
        func button(_ title: String, _ action: @escaping () -> Void) -> UIButton {
            var cfg = UIButton.Configuration.gray()
            cfg.title = title
            cfg.baseForegroundColor = .label
            return UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
        }
        func menuButton(_ title: String, _ menu: UIMenu) -> UIButton {
            var cfg = UIButton.Configuration.gray()
            cfg.title = title
            cfg.baseForegroundColor = .label
            let b = UIButton(configuration: cfg)
            b.menu = menu
            b.showsMenuAsPrimaryAction = true
            return b
        }

        let buttons: [UIButton] = [
            button("B") { [weak self] in self?.editor.toggleBold() },
            button("I") { [weak self] in self?.editor.toggleItalic() },
            button("S") { [weak self] in self?.editor.toggleStrikethrough() },
            button("<>") { [weak self] in self?.editor.toggleInlineCode() },
            button("Spoiler") { [weak self] in self?.editor.toggleSpoiler() },
            menuButton("Style", styleMenu()),
            menuButton("List", listMenu()),
            button("Indent") { [weak self] in self?.editor.indent() },
            button("Outdent") { [weak self] in self?.editor.outdent() },
            menuButton("Align", alignMenu()),
            menuButton("Table", tableMenu()),
            button("Image") { [weak self] in self?.presentImagePicker() },
            button("Link") { [weak self] in self?.presentLinkPrompt() },
            menuButton("Emoji", emojiMenu()),
            button("Undo") { [weak self] in self?.editor.undo() },
            button("Redo") { [weak self] in self?.editor.redo() },
        ]

        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        return scroll
    }

    private func styleMenu() -> UIMenu {
        let names: [(String, ParagraphStyleName)] = [("Heading 1", .heading1),
            ("Heading 2", .heading2), ("Heading 3", .heading3), ("Body", .body), ("Quote", .quote)]
        return UIMenu(title: "Style", children: names.map { n in
            UIAction(title: n.0) { [weak self] _ in self?.editor.setParagraphStyle(n.1) }
        })
    }
    private func listMenu() -> UIMenu {
        UIMenu(title: "List", children: [
            UIAction(title: "None") { [weak self] _ in self?.editor.setList(nil) },
            UIAction(title: "Bullet") { [weak self] _ in self?.editor.setList(.bullet) },
            UIAction(title: "Numbered") { [weak self] _ in self?.editor.setList(.ordered) },
        ])
    }
    private func alignMenu() -> UIMenu {
        let items: [(String, TextAlignment)] = [("Left", .left), ("Center", .center), ("Right", .right), ("Justify", .justified)]
        return UIMenu(title: "Align", children: items.map { i in
            UIAction(title: i.0) { [weak self] _ in self?.editor.setAlignment(i.1) }
        })
    }
    private func emojiMenu() -> UIMenu {
        UIMenu(title: "Emoji", children: [
            UIAction(title: "Insert ★ (static)") { [weak self] _ in self?.editor.insertEmoji(id: "star", altText: ":star:") },
            UIAction(title: "Insert ◐ (animated)") { [weak self] _ in self?.editor.insertEmoji(id: "spinner", altText: ":spinner:") },
        ])
    }

    private func tableMenu() -> UIMenu {
        UIMenu(title: "Table", children: [
            UIAction(title: "Insert Table 2×2") { [weak self] _ in self?.editor.insertTable(rows: 2, cols: 2) },
            UIAction(title: "Insert Wide Table 7×3") { [weak self] _ in self?.editor.insertTable(rows: 3, cols: 7) },
            UIAction(title: "Insert Row Above") { [weak self] _ in self?.editor.insertTableRowAbove() },
            UIAction(title: "Insert Row Below") { [weak self] _ in self?.editor.insertTableRowBelow() },
            UIAction(title: "Delete Row") { [weak self] _ in self?.editor.deleteTableRow() },
            UIAction(title: "Insert Column Left") { [weak self] _ in self?.editor.insertTableColumnLeft() },
            UIAction(title: "Insert Column Right") { [weak self] _ in self?.editor.insertTableColumnRight() },
            UIAction(title: "Delete Column") { [weak self] _ in self?.editor.deleteTableColumn() },
            UIAction(title: "Align Column Left") { [weak self] _ in self?.editor.setSelectionHorizontalAlignment(.left) },
            UIAction(title: "Align Column Center") { [weak self] _ in self?.editor.setSelectionHorizontalAlignment(.center) },
            UIAction(title: "Align Column Right") { [weak self] _ in self?.editor.setSelectionHorizontalAlignment(.right) },
        ])
    }

    // MARK: Phase 5b — image picker + link prompt

    private func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            let naturalSize = image.size
            DispatchQueue.main.async {
                self?.editor.becomeFirstResponder()
                let mediaID = "picked-\(UUID().uuidString)"
                self?.editor.insertMedia(mediaID: mediaID, naturalSize: naturalSize, kind: .image)
            }
        }
    }

    private func presentLinkPrompt() {
        let existing = editor.currentLink()
        let alert = UIAlertController(title: "Link", message: "Set a URL for the selected text", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "https://example.com"
            tf.text = existing
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Set", style: .default) { [weak self, weak alert] _ in
            guard let url = alert?.textFields?.first?.text, !url.isEmpty else { return }
            self?.editor.becomeFirstResponder()
            self?.editor.setLink(url)
        })
        if existing != nil {
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                self?.editor.becomeFirstResponder()
                self?.editor.removeLink()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

/// A trivial emoji host view for the Demo. Conforms to `RichTextEmojiView`; `dynamicColor` (the
/// template-emoji tint the editor pushes) is stored but unused by these opaque placeholder squares.
private final class DemoEmojiView: UIView, RichTextEmojiView {
    var dynamicColor: UIColor?
}
