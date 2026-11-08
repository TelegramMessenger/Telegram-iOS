import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

struct JokerQuickReply: Codable, Equatable {
    let id: String
    let text: String

    static func ==(lhs: JokerQuickReply, rhs: JokerQuickReply) -> Bool {
        return lhs.id == rhs.id && lhs.text == rhs.text
    }
}

private enum JokerLocalKeys {
    static let quickReplies = "joker_quick_replies_json"
    static let greetingEnabled = "joker_greeting_enabled"
    static let greetingText = "joker_greeting_text"
}

public func getJokerLocalQuickReplies() -> [JokerQuickReply] {
    guard let data = UserDefaults.standard.data(forKey: JokerLocalKeys.quickReplies) else {
        return []
    }
    return (try? JSONDecoder().decode([JokerQuickReply].self, from: data)) ?? []
}

public func getJokerLocalGreeting() -> (enabled: Bool, text: String) {
    let enabled = UserDefaults.standard.bool(forKey: JokerLocalKeys.greetingEnabled)
    let text = UserDefaults.standard.string(forKey: JokerLocalKeys.greetingText) ?? ""
    return (enabled, text)
}

private func saveJokerLocalQuickReplies(_ replies: [JokerQuickReply]) {
    let data = try? JSONEncoder().encode(replies)
    UserDefaults.standard.set(data, forKey: JokerLocalKeys.quickReplies)
    UserDefaults.standard.synchronize()
}

public final class JokerLocalQuickRepliesController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let context: AccountContext
    private let tableView: UITableView
    private let emptyLabel: UILabel
    private var replies: [JokerQuickReply]

    public init(context: AccountContext) {
        self.context = context
        self.tableView = UITableView(frame: .zero, style: .insetGrouped)
        self.emptyLabel = UILabel()
        self.replies = getJokerLocalQuickReplies()
        super.init(nibName: nil, bundle: nil)

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "ردود سريعة محلية", enValue: "Local Quick Replies")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addReply))
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = .clear
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.view.addSubview(self.tableView)

        self.emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "لا توجد ردود سريعة بعد.\nاضغط + لإضافة رد.", enValue: "No quick replies yet.\nTap + to add one.")
        self.emptyLabel.font = Font.regular(15.0)
        self.emptyLabel.textColor = presentationData.theme.list.itemPrimaryTextColor
        self.view.addSubview(self.emptyLabel)

        NSLayoutConstraint.activate([
            self.emptyLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.emptyLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            self.emptyLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 28.0),
            self.emptyLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -28.0)
        ])

        self.reloadData()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.tableView.frame = self.view.bounds
    }

    private func reloadData() {
        self.replies = getJokerLocalQuickReplies()
        self.tableView.reloadData()
        self.tableView.isHidden = !self.replies.isEmpty
        self.emptyLabel.isHidden = !self.replies.isEmpty
    }

    @objc private func addReply() {
        self.presentReplyEditor(nil)
    }

    private func presentReplyEditor(_ reply: JokerQuickReply?) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let title = reply == nil
            ? jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إضافة رد سريع", enValue: "Add Quick Reply")
            : jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعديل رد سريع", enValue: "Edit Quick Reply")

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اكتب الرد هنا", enValue: "Type your reply here")
            textField.text = reply?.text ?? ""
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
        }

        let cancel = UIAlertAction(title: presentationData.strings.Common_Cancel, style: .cancel)
        let save = UIAlertAction(title: presentationData.strings.Common_Save, style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return
            }
            var replies = getJokerLocalQuickReplies()
            if let reply {
                replies = replies.map { $0.id == reply.id ? JokerQuickReply(id: reply.id, text: text) : $0 }
            } else {
                replies.append(JokerQuickReply(id: UUID().uuidString, text: text))
            }
            saveJokerLocalQuickReplies(replies)
            self.reloadData()
        }

        alert.addAction(cancel)
        alert.addAction(save)
        self.present(alert, animated: true)
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.replies.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let reply = self.replies[indexPath.row]
        cell.textLabel?.numberOfLines = 3
        cell.textLabel?.text = reply.text
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.presentReplyEditor(self.replies[indexPath.row])
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let delete = UIContextualAction(style: .destructive, title: presentationData.strings.Common_Delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            let reply = self.replies[indexPath.row]
            let replies = getJokerLocalQuickReplies().filter { $0.id != reply.id }
            saveJokerLocalQuickReplies(replies)
            self.reloadData()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

public final class JokerLocalGreetingController: ViewController {
    private let context: AccountContext

    private let descriptionLabel: UILabel
    private let enableRow: UIView
    private let enableLabel: UILabel
    private let enableSwitch: UISwitch
    private let messageLabel: UILabel
    private let textView: UITextView
    private let saveButton: UIButton

    public init(context: AccountContext) {
        self.context = context

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        self.descriptionLabel = UILabel()
        self.enableRow = UIView()
        self.enableLabel = UILabel()
        self.enableSwitch = UISwitch()
        self.messageLabel = UILabel()
        self.textView = UITextView()
        self.saveButton = UIButton(type: .system)

        super.init(nibName: nil, bundle: nil)

        self.title = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "رسائل ترحيبية محلية", enValue: "Local Greeting Messages")
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let renderData = getJokerLocalGreeting()
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        self.view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        self.descriptionLabel.numberOfLines = 0
        self.descriptionLabel.font = Font.regular(14.0)
        self.descriptionLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        self.descriptionLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "هذه الرسالة ليست من Telegram Business. تُحفظ على هاتفك وتستخدم لإرسال رد تلقائي للعملاء الجدد.", enValue: "This is not Telegram Business. It is stored on your device and can be used to reply to new customers.")
        self.view.addSubview(self.descriptionLabel)

        self.enableLabel.translatesAutoresizingMaskIntoConstraints = false
        self.enableLabel.font = Font.regular(16.0)
        self.enableLabel.textColor = presentationData.theme.list.itemPrimaryTextColor
        self.enableLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تفعيل الرسالة الترحيبية", enValue: "Enable greeting message")
        self.enableRow.addSubview(self.enableLabel)

        self.enableSwitch.translatesAutoresizingMaskIntoConstraints = false
        self.enableSwitch.isOn = renderData.enabled
        self.enableSwitch.addTarget(self, action: #selector(self.toggleEnabled), for: .valueChanged)
        self.enableRow.addSubview(self.enableSwitch)

        self.enableRow.translatesAutoresizingMaskIntoConstraints = false
        self.enableRow.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.view.addSubview(self.enableRow)

        self.messageLabel.translatesAutoresizingMaskIntoConstraints = false
        self.messageLabel.font = Font.semibold(14.0)
        self.messageLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        self.messageLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "نص الرسالة", enValue: "Message text")
        self.view.addSubview(self.messageLabel)

        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.font = Font.regular(17.0)
        self.textView.text = renderData.text
        self.textView.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.textView.textColor = presentationData.theme.list.itemPrimaryTextColor
        self.textView.layer.cornerRadius = 12.0
        self.view.addSubview(self.textView)

        self.saveButton.translatesAutoresizingMaskIntoConstraints = false
        self.saveButton.setTitle(jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حفظ", enValue: "Save"), for: .normal)
        self.saveButton.setTitleColor(.white, for: .normal)
        self.saveButton.titleLabel?.font = Font.semibold(17.0)
        self.saveButton.backgroundColor = presentationData.theme.list.itemAccentColor
        self.saveButton.layer.cornerRadius = 12.0
        self.saveButton.addTarget(self, action: #selector(self.save), for: .touchUpInside)
        self.view.addSubview(self.saveButton)

        NSLayoutConstraint.activate([
            self.descriptionLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16.0),
            self.descriptionLabel.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            self.descriptionLabel.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),

            self.enableRow.topAnchor.constraint(equalTo: self.descriptionLabel.bottomAnchor, constant: 16.0),
            self.enableRow.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.enableRow.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.enableRow.heightAnchor.constraint(equalToConstant: 60.0),

            self.enableLabel.leadingAnchor.constraint(equalTo: self.enableRow.leadingAnchor, constant: 16.0),
            self.enableLabel.centerYAnchor.constraint(equalTo: self.enableRow.centerYAnchor),

            self.enableSwitch.trailingAnchor.constraint(equalTo: self.enableRow.trailingAnchor, constant: -16.0),
            self.enableSwitch.centerYAnchor.constraint(equalTo: self.enableRow.centerYAnchor),

            self.messageLabel.topAnchor.constraint(equalTo: self.enableRow.bottomAnchor, constant: 24.0),
            self.messageLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16.0),
            self.messageLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16.0),

            self.textView.topAnchor.constraint(equalTo: self.messageLabel.bottomAnchor, constant: 8.0),
            self.textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16.0),
            self.textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16.0),
            self.textView.heightAnchor.constraint(equalToConstant: 180.0),

            self.saveButton.topAnchor.constraint(equalTo: self.textView.bottomAnchor, constant: 24.0),
            self.saveButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16.0),
            self.saveButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16.0),
            self.saveButton.heightAnchor.constraint(equalToConstant: 48.0)
        ])
    }

    @objc private func toggleEnabled() {
        UserDefaults.standard.set(self.enableSwitch.isOn, forKey: JokerLocalKeys.greetingEnabled)
        UserDefaults.standard.synchronize()
    }

    @objc private func save() {
        UserDefaults.standard.set(self.enableSwitch.isOn, forKey: JokerLocalKeys.greetingEnabled)
        UserDefaults.standard.set(self.textView.text, forKey: JokerLocalKeys.greetingText)
        UserDefaults.standard.synchronize()
        self.navigationController?.popViewController(animated: true)
    }
}
