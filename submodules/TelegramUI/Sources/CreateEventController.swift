import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

// MARK: - Delegate

protocol CreateEventControllerDelegate: AnyObject {
    func createEventController(_ controller: CreateEventController, didCreate event: TGEvent)
    func createEventController(_ controller: CreateEventController, didUpdate event: TGEvent)
}

// MARK: - Text input cell

private final class TextInputCell: UITableViewCell {
    let textField = UITextField()
    var onTextChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .next
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func textChanged() { onTextChange?(textField.text ?? "") }
}

// MARK: - Date picker cell

private final class DatePickerCell: UITableViewCell {
    let titleLabel = UILabel()
    let picker = UIDatePicker()
    var onValueChange: ((Date) -> Void)?

    init(title: String, mode: UIDatePicker.Mode, date: Date) {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        picker.datePickerMode = mode
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .compact
        }
        picker.tintColor = .systemOrange
        picker.date = date
        if mode == .time { picker.minuteInterval = 15 }
        picker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(picker)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            picker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            picker.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            picker.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
        ])

        picker.addTarget(self, action: #selector(changed), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed() { onValueChange?(picker.date) }
}

// MARK: - Controller

final class CreateEventController: UIViewController {
    weak var delegate: CreateEventControllerDelegate?
    var onSave: ((TGEvent) -> Void)?
    private let context: AccountContext
    private let editingEvent: TGEvent?
    private var pickerDisposable: Disposable?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Form state
    private var eventTitle    = ""
    private var eventDate     = Calendar.current.startOfDay(for: Date())
    private var startTime: Date = {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        c.hour = (Calendar.current.component(.hour, from: Date()) + 1) % 24
        c.minute = 0; c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    private var endTime: Date = {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        c.hour = (Calendar.current.component(.hour, from: Date()) + 2) % 24
        c.minute = 0; c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    private var participants: [String] = []
    private var eventLocation = ""

    private lazy var dateCell  = DatePickerCell(title: "Дата",    mode: .date, date: eventDate)
    private lazy var startCell = DatePickerCell(title: "Начало",  mode: .time, date: startTime)
    private lazy var endCell   = DatePickerCell(title: "Конец",   mode: .time, date: endTime)

    init(context: AccountContext, editingEvent: TGEvent? = nil, initialParticipants: [String] = []) {
        self.context = context
        self.editingEvent = editingEvent
        if let e = editingEvent {
            self.eventTitle    = e.title
            self.eventDate     = Calendar.current.startOfDay(for: e.startDate)
            self.startTime     = e.startDate
            self.endTime       = e.endDate
            self.participants  = e.participants
            self.eventLocation = e.location ?? ""
        } else {
            self.participants = initialParticipants
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { pickerDisposable?.dispose() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = editingEvent == nil ? "Новая встреча" : "Редактировать"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain,
                                                           target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Готово", style: .done,
                                                            target: self, action: #selector(saveTapped))
        navigationItem.leftBarButtonItem?.tintColor  = .systemOrange
        navigationItem.rightBarButtonItem?.tintColor = .systemOrange

        dateCell.onValueChange  = { [weak self] d in self?.eventDate  = d }
        startCell.onValueChange = { [weak self] d in self?.startTime  = d }
        endCell.onValueChange   = { [weak self] d in self?.endTime    = d }

        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(TextInputCell.self,   forCellReuseIdentifier: "text")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "basic")
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? TextInputCell {
            cell.textField.becomeFirstResponder()
        }
    }

    // MARK: Actions

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func saveTapped() {
        let title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            let a = UIAlertController(title: "Введите название", message: nil, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true); return
        }
        let start = combined(date: eventDate, time: startTime)
        var end   = combined(date: eventDate, time: endTime)
        if end <= start { end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? end }

        let event = TGEvent(id: editingEvent?.id ?? UUID(), title: title, startDate: start, endDate: end,
                            participants: participants,
                            location: eventLocation.isEmpty ? nil : eventLocation)

        // Always persist directly so events created from any context (chat, events tab) are saved
        var stored = (try? JSONDecoder().decode([TGEvent].self,
            from: UserDefaults.standard.data(forKey: TGEventStorage.eventsKey) ?? Data())) ?? []
        if editingEvent != nil {
            stored = stored.map { $0.id == event.id ? event : $0 }
        } else {
            stored.append(event)
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: TGEventStorage.eventsKey)
        }

        onSave?(event)
        if editingEvent != nil {
            delegate?.createEventController(self, didUpdate: event)
        } else {
            delegate?.createEventController(self, didCreate: event)
        }
        dismiss(animated: true)
    }

    @objc private func addParticipantTapped() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Выбрать из контактов", style: .default) { [weak self] _ in
            self?.openContactPicker()
        })
        sheet.addAction(UIAlertAction(title: "Добавить вручную", style: .default) { [weak self] _ in
            self?.addManually()
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    private func openContactPicker() {
        let params = ContactSelectionControllerParams(
            context: context,
            title: { _ in "Участники" },
            multipleSelection: .always
        )
        let picker = context.sharedContext.makeContactSelectionController(params)

        pickerDisposable?.dispose()
        pickerDisposable = (picker.result
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self else { return }
            if let (peers, _, _, _, _, _) = result {
                let pd = self.context.sharedContext.currentPresentationData.with { $0 }
                for listPeer in peers {
                    let name: String
                    switch listPeer {
                    case let .peer(enginePeer, _, _):
                        name = enginePeer.displayTitle(strings: pd.strings, displayOrder: pd.nameDisplayOrder)
                    case let .deviceContact(_, contact):
                        name = [contact.firstName, contact.lastName]
                            .filter { !$0.isEmpty }.joined(separator: " ")
                    }
                    if !name.isEmpty && !self.participants.contains(name) {
                        self.participants.append(name)
                    }
                }
                self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
            }
            self.navigationController?.popViewController(animated: true)
        })
        navigationController?.pushViewController(picker, animated: true)
    }

    private func addManually() {
        let alert = UIAlertController(title: "Добавить участника", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Имя или @username"
            tf.autocapitalizationType = .words
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Добавить", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else { return }
            if text.hasPrefix("@") {
                self.resolveAndAdd(username: String(text.dropFirst()))
            } else {
                self.appendParticipant(text)
            }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func resolveAndAdd(username: String) {
        let loading = UIAlertController(title: nil, message: "Поиск @\(username)…", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loading.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: loading.view.bottomAnchor, constant: -16)
        ])
        present(loading, animated: true)

        pickerDisposable?.dispose()
        pickerDisposable = (context.engine.peers.resolvePeerByName(name: username, referrer: nil)
            |> filter { if case .progress = $0 { return false }; return true }
            |> take(1)
            |> timeout(10, queue: Queue.mainQueue(), alternate: .single(.result(nil)))
            |> deliverOnMainQueue).startStandalone(next: { [weak self, weak loading] result in
            guard let self else { return }
            loading?.dismiss(animated: true) {
                if case let .result(peer) = result, let peer = peer {
                    let pd = self.context.sharedContext.currentPresentationData.with { $0 }
                    let name = peer.displayTitle(strings: pd.strings, displayOrder: pd.nameDisplayOrder)
                    self.appendParticipant(name)
                } else {
                    let err = UIAlertController(title: "Не найдено",
                                                message: "@\(username) не существует или недоступен",
                                                preferredStyle: .alert)
                    err.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(err, animated: true)
                }
            }
        })
    }

    private func appendParticipant(_ name: String) {
        guard !participants.contains(name) else { return }
        participants.append(name)
        tableView.insertRows(at: [IndexPath(row: participants.count - 1, section: 2)], with: .automatic)
    }

    @objc private func removeParticipant(_ sender: UIButton) {
        let idx = sender.tag
        guard idx < participants.count else { return }
        participants.remove(at: idx)
        tableView.deleteRows(at: [IndexPath(row: idx, section: 2)], with: .automatic)
        tableView.reloadSections(IndexSet(integer: 2), with: .none)
    }

    private func combined(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        var dc = cal.dateComponents([.year,.month,.day], from: date)
        let tc = cal.dateComponents([.hour,.minute], from: time)
        dc.hour = tc.hour; dc.minute = tc.minute; dc.second = 0
        return cal.date(from: dc) ?? date
    }
}

// MARK: - UITableViewDataSource

extension CreateEventController: UITableViewDataSource {
    func numberOfSections(in tv: UITableView) -> Int { 4 }

    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return 3
        case 2: return participants.count + 1
        case 3: return 1
        default: return 0
        }
    }

    func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Название", "Дата и время", "Участники", "Место"][section]
    }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        switch ip.section {

        case 0:
            let cell = tv.dequeueReusableCell(withIdentifier: "text", for: ip) as! TextInputCell
            cell.textField.placeholder = "Название встречи"
            cell.textField.font = .systemFont(ofSize: 16, weight: .medium)
            cell.textField.text = eventTitle
            cell.onTextChange = { [weak self] t in self?.eventTitle = t }
            return cell

        case 1:
            return [dateCell, startCell, endCell][ip.row]

        case 2:
            if ip.row < participants.count {
                let cell = tv.dequeueReusableCell(withIdentifier: "basic", for: ip)
                cell.selectionStyle = .none
                cell.textLabel?.text = participants[ip.row]
                cell.textLabel?.textColor = .label
                cell.textLabel?.font = .systemFont(ofSize: 16)
                cell.imageView?.image = nil
                let btn = UIButton(type: .system)
                btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
                btn.tintColor = UIColor.systemRed.withAlphaComponent(0.7)
                btn.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
                btn.tag = ip.row
                btn.addTarget(self, action: #selector(removeParticipant(_:)), for: .touchUpInside)
                cell.accessoryView = btn
                return cell
            } else {
                let cell = tv.dequeueReusableCell(withIdentifier: "basic", for: ip)
                cell.selectionStyle = .default
                cell.textLabel?.text = "Добавить участника"
                cell.textLabel?.textColor = .systemOrange
                cell.textLabel?.font = .systemFont(ofSize: 16)
                cell.imageView?.image = UIImage(systemName: "person.badge.plus")
                cell.imageView?.tintColor = .systemOrange
                cell.accessoryView = nil
                cell.accessoryType = .none
                return cell
            }

        case 3:
            let cell = tv.dequeueReusableCell(withIdentifier: "text", for: ip) as! TextInputCell
            cell.textField.placeholder = "Место (опционально)"
            cell.textField.font = .systemFont(ofSize: 16)
            cell.textField.text = eventLocation
            cell.onTextChange = { [weak self] t in self?.eventLocation = t }
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate

extension CreateEventController: UITableViewDelegate {
    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 52 }

    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        if ip.section == 2, ip.row == participants.count {
            addParticipantTapped()
        }
    }

    func tableView(_ tv: UITableView, canEditRowAt ip: IndexPath) -> Bool {
        ip.section == 2 && ip.row < participants.count
    }

    func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt ip: IndexPath) {
        if editingStyle == .delete {
            participants.remove(at: ip.row)
            tv.deleteRows(at: [ip], with: .automatic)
            // Reload remaining rows to reset button tags after index shift.
            tv.reloadSections(IndexSet(integer: 2), with: .none)
        }
    }
}
