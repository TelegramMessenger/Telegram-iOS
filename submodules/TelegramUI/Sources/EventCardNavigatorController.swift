import Foundation
import UIKit
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore

// MARK: - Vote models and storage

struct TGVoteEntry: Codable {
    let userId: Int64
    let displayName: String
    let vote: String    // "yes" or "no"
    let date: Date
}

private let votesV2Key = "tg_event_votes_v2"

private func loadVotes() -> [String: String] {
    guard let data = UserDefaults.standard.data(forKey: TGEventStorage.votesKey),
          let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
    return dict
}

private func saveVotes(_ dict: [String: String]) {
    if let data = try? JSONEncoder().encode(dict) {
        UserDefaults.standard.set(data, forKey: TGEventStorage.votesKey)
    }
}

private func loadVotesV2() -> [String: [TGVoteEntry]] {
    guard let data = UserDefaults.standard.data(forKey: votesV2Key),
          let dict = try? JSONDecoder().decode([String: [TGVoteEntry]].self, from: data) else { return [:] }
    return dict
}

private func saveVotesV2(_ dict: [String: [TGVoteEntry]]) {
    if let data = try? JSONEncoder().encode(dict) {
        UserDefaults.standard.set(data, forKey: votesV2Key)
    }
}

private func loadStoredEvents() -> [TGEvent] {
    guard let data = UserDefaults.standard.data(forKey: TGEventStorage.eventsKey),
          let events = try? JSONDecoder().decode([TGEvent].self, from: data) else { return [] }
    return events
}

private func saveStoredEvents(_ events: [TGEvent]) {
    if let data = try? JSONEncoder().encode(events) {
        UserDefaults.standard.set(data, forKey: TGEventStorage.eventsKey)
    }
}

// MARK: - Card view

private final class EventCardView: UIView {
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()
    private let divider = UIView()
    private let yesButton = UIButton(type: .system)
    private let noButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    var onYes: (() -> Void)?
    var onNo: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 20
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .label

        dateLabel.font = .systemFont(ofSize: 15, weight: .medium)
        dateLabel.textColor = .secondaryLabel

        timeLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        timeLabel.textColor = .label

        locationLabel.font = .systemFont(ofSize: 15)
        locationLabel.textColor = .secondaryLabel
        locationLabel.numberOfLines = 1

        divider.backgroundColor = .separator

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        for btn in [yesButton, noButton] {
            btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            btn.layer.cornerRadius = 14
        }
        yesButton.setTitle("✅  Иду", for: .normal)
        yesButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        yesButton.setTitleColor(.systemGreen, for: .normal)
        yesButton.addTarget(self, action: #selector(yesTapped), for: .touchUpInside)

        noButton.setTitle("❌  Не иду", for: .normal)
        noButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        noButton.setTitleColor(.systemRed, for: .normal)
        noButton.addTarget(self, action: #selector(noTapped), for: .touchUpInside)

        for v in [titleLabel, dateLabel, timeLabel, locationLabel, divider, yesButton, noButton, statusLabel] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            timeLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            locationLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 8),
            locationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            locationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            divider.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 24),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            yesButton.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 24),
            yesButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            yesButton.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -6),
            yesButton.heightAnchor.constraint(equalToConstant: 52),

            noButton.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 24),
            noButton.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 6),
            noButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            noButton.heightAnchor.constraint(equalToConstant: 52),

            statusLabel.topAnchor.constraint(equalTo: yesButton.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
        ])
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"; return f
    }()

    func configure(event: TGEvent, vote: String?) {
        var dateStr = Self.dateFmt.string(from: event.startDate)
        if let first = dateStr.first { dateStr = first.uppercased() + dateStr.dropFirst() }

        titleLabel.text = event.title
        dateLabel.text = "📅  \(dateStr)"
        timeLabel.text = "⏰  \(Self.timeFmt.string(from: event.startDate)) – \(Self.timeFmt.string(from: event.endDate))"

        if let loc = event.location, !loc.isEmpty {
            locationLabel.text = "📍  \(loc)"
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }

        applyVoteState(vote)
    }

    private func applyVoteState(_ vote: String?) {
        switch vote {
        case "yes":
            yesButton.backgroundColor = .systemGreen
            yesButton.setTitleColor(.white, for: .normal)
            noButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            noButton.setTitleColor(.systemRed, for: .normal)
            statusLabel.text = "Вы идёте на встречу ✓"
            statusLabel.textColor = .systemGreen
        case "no":
            noButton.backgroundColor = .systemRed
            noButton.setTitleColor(.white, for: .normal)
            yesButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            yesButton.setTitleColor(.systemGreen, for: .normal)
            statusLabel.text = "Вы отказались от встречи"
            statusLabel.textColor = .systemRed
        default:
            yesButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            yesButton.setTitleColor(.systemGreen, for: .normal)
            noButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            noButton.setTitleColor(.systemRed, for: .normal)
            statusLabel.text = "Вы ещё не ответили"
            statusLabel.textColor = .secondaryLabel
        }
    }

    @objc private func yesTapped() { onYes?() }
    @objc private func noTapped() { onNo?() }
}

// MARK: - Navigator controller

public final class EventCardNavigatorController: UIViewController {
    private let chatId: Int64
    private let context: AccountContext
    private var events: [TGEvent] = []
    private var currentIndex: Int = 0
    private var scanDisposable: Disposable?
    private var currentUserId: Int64 = 0
    private var currentUserName: String = "Вы"

    // Layout
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let counterLabel = UILabel()
    private let cardView = EventCardView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let emptyLabel = UILabel()
    private let participantsStack = UIStackView()

    public init(chatId: Int64, context: AccountContext) {
        self.chatId = chatId
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        scanDisposable?.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "События"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        setupLayout()
        loadCurrentUser()
        reload()
        scanMessageHistory()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        counterLabel.font = .systemFont(ofSize: 14, weight: .medium)
        counterLabel.textColor = .secondaryLabel
        counterLabel.textAlignment = .center
        counterLabel.translatesAutoresizingMaskIntoConstraints = false

        cardView.translatesAutoresizingMaskIntoConstraints = false

        prevButton.setTitle("◀  Предыдущее", for: .normal)
        prevButton.titleLabel?.font = .systemFont(ofSize: 15)
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        prevButton.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle("Следующее  ▶", for: .normal)
        nextButton.titleLabel?.font = .systemFont(ofSize: 15)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.text = "Нет событий в этом чате"
        emptyLabel.font = .systemFont(ofSize: 17)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        participantsStack.axis = .vertical
        participantsStack.spacing = 0
        participantsStack.translatesAutoresizingMaskIntoConstraints = false

        for v in [counterLabel, cardView, prevButton, nextButton, emptyLabel, participantsStack] as [UIView] {
            contentView.addSubview(v)
        }

        NSLayoutConstraint.activate([
            counterLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            counterLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            cardView.topAnchor.constraint(equalTo: counterLabel.bottomAnchor, constant: 12),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            prevButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 20),
            prevButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            nextButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 20),
            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            participantsStack.topAnchor.constraint(equalTo: prevButton.bottomAnchor, constant: 24),
            participantsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            participantsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            participantsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 120),
        ])
    }

    // MARK: - Current user

    private func loadCurrentUser() {
        let accountPeerId = context.account.peerId
        let _ = (context.account.postbox.transaction { transaction -> (Int64, String) in
            let userId = accountPeerId.toInt64()
            if let user = transaction.getPeer(accountPeerId) as? TelegramUser {
                let name = [user.firstName, user.lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                return (userId, name.isEmpty ? "Пользователь" : name)
            }
            return (userId, "Пользователь")
        } |> deliverOnMainQueue).startStandalone { [weak self] (userId, name) in
            self?.currentUserId = userId
            self?.currentUserName = name
        }
    }

    // MARK: - Data

    private func reload() {
        let all = loadStoredEvents()
        let newEvents = all.filter { $0.chatId == chatId }
            .sorted { $0.startDate > $1.startDate }
        if newEvents.map(\.id) != events.map(\.id) {
            currentIndex = 0
        }
        events = newEvents
        updateUI()
    }

    private func updateUI() {
        let hasEvents = !events.isEmpty
        cardView.isHidden = !hasEvents
        counterLabel.isHidden = !hasEvents
        prevButton.isHidden = !hasEvents
        nextButton.isHidden = !hasEvents
        emptyLabel.isHidden = hasEvents
        participantsStack.isHidden = !hasEvents

        guard hasEvents else { return }

        let event = events[currentIndex]
        let votes = loadVotes()
        cardView.configure(event: event, vote: votes[event.id.uuidString])
        counterLabel.text = "\(currentIndex + 1) / \(events.count)"
        prevButton.isEnabled = currentIndex < events.count - 1
        nextButton.isEnabled = currentIndex > 0

        cardView.onYes = { [weak self] in self?.vote("yes", for: event) }
        cardView.onNo = { [weak self] in self?.vote("no", for: event) }

        rebuildParticipants(for: event)
    }

    // MARK: - Participant list

    private static let voteDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private func rebuildParticipants(for event: TGEvent) {
        participantsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let allVotesV2 = loadVotesV2()
        let entries = (allVotesV2[event.id.uuidString] ?? [])
            .sorted { $0.date < $1.date }

        let accepted = entries.filter { $0.vote == "yes" }
        let declined = entries.filter { $0.vote == "no" }

        let topDivider = makeDivider()
        participantsStack.addArrangedSubview(topDivider)

        let headerLabel = UILabel()
        headerLabel.text = "Участники"
        headerLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headerLabel.textColor = .label
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        let headerWrap = wrapWithPadding(headerLabel, top: 20, bottom: 8, leading: 20, trailing: 20)
        participantsStack.addArrangedSubview(headerWrap)

        addParticipantSection(title: "✅ Идут (\(accepted.count))",
                              entries: accepted,
                              highlightColor: .systemGreen)
        addParticipantSection(title: "❌ Не идут (\(declined.count))",
                              entries: declined,
                              highlightColor: .systemRed)

        if accepted.isEmpty && declined.isEmpty {
            let noVotesLabel = UILabel()
            noVotesLabel.text = "Пока никто не ответил"
            noVotesLabel.font = .systemFont(ofSize: 14)
            noVotesLabel.textColor = .tertiaryLabel
            let wrap = wrapWithPadding(noVotesLabel, top: 8, bottom: 8, leading: 20, trailing: 20)
            participantsStack.addArrangedSubview(wrap)
        }
    }

    private func addParticipantSection(title: String, entries: [TGVoteEntry], highlightColor: UIColor) {
        let sectionHeader = UILabel()
        sectionHeader.text = title
        sectionHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        sectionHeader.textColor = highlightColor
        let sectionWrap = wrapWithPadding(sectionHeader, top: 12, bottom: 4, leading: 20, trailing: 20)
        participantsStack.addArrangedSubview(sectionWrap)

        if entries.isEmpty {
            let emptyRowLabel = UILabel()
            emptyRowLabel.text = "  —"
            emptyRowLabel.font = .systemFont(ofSize: 14)
            emptyRowLabel.textColor = .tertiaryLabel
            let wrap = wrapWithPadding(emptyRowLabel, top: 2, bottom: 2, leading: 20, trailing: 20)
            participantsStack.addArrangedSubview(wrap)
        } else {
            for entry in entries {
                let row = makeParticipantRow(entry: entry)
                participantsStack.addArrangedSubview(row)
            }
        }
    }

    private func makeParticipantRow(entry: TGVoteEntry) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = entry.displayName
        nameLabel.font = .systemFont(ofSize: 15)
        nameLabel.textColor = .label
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let dateLabel = UILabel()
        dateLabel.text = Self.voteDateFmt.string(from: entry.date)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [nameLabel, dateLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.layoutMargins = UIEdgeInsets(top: 6, left: 20, bottom: 6, right: 20)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    private func wrapWithPadding(_ child: UIView, top: CGFloat, bottom: CGFloat, leading: CGFloat, trailing: CGFloat) -> UIView {
        let wrap = UIView()
        child.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: wrap.topAnchor, constant: top),
            child.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -bottom),
            child.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: leading),
            child.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -trailing),
        ])
        return wrap
    }

    // MARK: - Voting

    private func vote(_ answer: String, for event: TGEvent) {
        let key = event.id.uuidString

        // v1 (for badge counting)
        var votes = loadVotes()
        let prev = votes[key]
        votes[key] = (prev == answer) ? nil : answer
        saveVotes(votes)

        // v2 (for participant list with names/dates)
        var votesV2 = loadVotesV2()
        var entries = votesV2[key] ?? []
        entries.removeAll { $0.userId == currentUserId }
        if prev != answer {
            entries.append(TGVoteEntry(
                userId: currentUserId,
                displayName: currentUserName,
                vote: answer,
                date: Date()
            ))
        }
        votesV2[key] = entries
        saveVotesV2(votesV2)

        if answer == "yes", prev != "yes" {
            addEventToPersonalCalendar(event)
        }

        updateUI()
    }

    private func addEventToPersonalCalendar(_ event: TGEvent) {
        var stored = loadStoredEvents()
        let alreadyExists = stored.contains {
            $0.chatId == nil && $0.title == event.title && $0.startDate == event.startDate
        }
        guard !alreadyExists else { return }
        stored.append(TGEvent(
            id: UUID(), title: event.title,
            startDate: event.startDate, endDate: event.endDate,
            participants: event.participants, location: event.location,
            chatId: nil
        ))
        saveStoredEvents(stored)
    }

    // MARK: - Cross-device event discovery via TGEventAttribute

    private func scanMessageHistory() {
        let chatId = self.chatId
        let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup,    id: PeerId.Id._internalFromInt64Value(chatId))
        let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(chatId))

        scanDisposable = (context.account.postbox.transaction { transaction -> [TGEvent] in
            var resolvedPeerId: PeerId?
            for candidate in [groupPeerId, channelPeerId] {
                if transaction.getPeer(candidate) != nil { resolvedPeerId = candidate; break }
            }
            guard let peerId = resolvedPeerId else { return [] }

            let view = transaction.getMessagesHistoryViewState(
                input: .single(peerId: peerId, threadId: nil),
                ignoreMessagesInTimestampRange: nil,
                ignoreMessageIds: Set(),
                count: 200, clipHoles: true,
                anchor: .upperBound,
                namespaces: .just(Set([Namespaces.Message.Cloud]))
            )

            var found: [TGEvent] = []
            for entry in view.entries {
                // Primary path: TGEventAttribute (invisible, stored on fork clients)
                if let attr = entry.message.attributes.first(where: { $0 is TGEventAttribute }) as? TGEventAttribute,
                   let uuid = UUID(uuidString: attr.eventId) {
                    found.append(TGEvent(
                        id: uuid, title: attr.title,
                        startDate: Date(timeIntervalSince1970: attr.startTimestamp),
                        endDate: Date(timeIntervalSince1970: attr.endTimestamp),
                        participants: [], location: attr.location, chatId: chatId
                    ))
                    continue
                }
                // Fallback: legacy [TGE:{...}] text marker (messages sent before attribute migration)
                let text = entry.message.text
                guard let start = text.range(of: "[TGE:"),
                      let end = text.range(of: "]", range: start.upperBound..<text.endIndex) else { continue }
                struct LegacyMarker: Decodable { let i: String; let t: String; let s: Double; let e: Double; let l: String? }
                let jsonStr = String(text[start.upperBound..<end.lowerBound])
                guard let data = jsonStr.data(using: .utf8),
                      let m = try? JSONDecoder().decode(LegacyMarker.self, from: data),
                      let uuid = UUID(uuidString: m.i) else { continue }
                found.append(TGEvent(
                    id: uuid, title: m.t,
                    startDate: Date(timeIntervalSince1970: m.s),
                    endDate: Date(timeIntervalSince1970: m.e),
                    participants: [], location: m.l, chatId: chatId
                ))
            }
            return found
        } |> deliverOnMainQueue).startStandalone { [weak self] discovered in
            guard let self, !discovered.isEmpty else { return }
            var stored = loadStoredEvents()
            let existingIds = Set(stored.map { $0.id })
            let newEvents = discovered.filter { !existingIds.contains($0.id) }
            guard !newEvents.isEmpty else { return }
            stored.append(contentsOf: newEvents)
            saveStoredEvents(stored)
            self.reload()
        }
    }

    // MARK: - Navigation

    @objc private func prevTapped() {
        guard currentIndex < events.count - 1 else { return }
        currentIndex += 1
        updateUI()
        animateTransition(direction: -1)
    }

    @objc private func nextTapped() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        updateUI()
        animateTransition(direction: 1)
    }

    private func animateTransition(direction: CGFloat) {
        let offset = direction * view.bounds.width * 0.4
        cardView.transform = CGAffineTransform(translationX: offset, y: 0)
        cardView.alpha = 0.4
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
