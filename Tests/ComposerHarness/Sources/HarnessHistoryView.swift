import UIKit
import TelegramCore
import TextFormat

public struct HarnessHistoryEntry {
    public let content: ChatInputContent
    public let dump: String
}

/// The fake history: a receipt of what the composer produced, **not** a chat.
///
/// Entries render with `attributedString(from:)` — TextFormat's display-neutral utility —
/// deliberately and not with the real bubble renderer. Message rendering is out of scope for this
/// harness, and wiring InstantPage V2 in would produce findings an agent would burn cycles on that
/// are not composer defects. Its job is to show that a send produced the right value and cleared
/// the field, and to give the composer something to sit above.
public final class HarnessHistoryView: UIView, UITableViewDataSource {
    public private(set) var entries: [HarnessHistoryEntry] = []
    private let tableView = UITableView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.tableView.accessibilityIdentifier = "harness.history"
        self.tableView.dataSource = self
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "entry")
        self.tableView.allowsSelection = false
        self.tableView.separatorStyle = .singleLine
        self.addSubview(self.tableView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.tableView.frame = self.bounds
    }

    public func append(_ content: ChatInputContent, dump: String) {
        self.entries.append(HarnessHistoryEntry(content: content, dump: dump))
        self.tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.entries.count
    }

    public func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "entry", for: indexPath)
        let entry = self.entries[indexPath.row]
        cell.accessibilityIdentifier = "harness.historyEntry.\(indexPath.row)"
        cell.textLabel?.attributedText = attributedString(from: entry.content)
        cell.textLabel?.numberOfLines = 0
        cell.accessibilityValue = entry.dump
        return cell
    }
}
