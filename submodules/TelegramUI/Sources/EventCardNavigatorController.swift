import Foundation
import UIKit
import AccountContext

// MARK: - Vote storage helpers

private let votesKey = "tg_event_votes_v1"

private func loadVotes() -> [String: String] {
    guard let data = UserDefaults.standard.data(forKey: votesKey),
          let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
    return dict
}

private func saveVotes(_ dict: [String: String]) {
    if let data = try? JSONEncoder().encode(dict) {
        UserDefaults.standard.set(data, forKey: votesKey)
    }
}

private func loadStoredEvents() -> [TGEvent] {
    guard let data = UserDefaults.standard.data(forKey: "tg_events_v1"),
          let events = try? JSONDecoder().decode([TGEvent].self, from: data) else { return [] }
    return events
}

private func saveStoredEvents(_ events: [TGEvent]) {
    if let data = try? JSONEncoder().encode(events) {
        UserDefaults.standard.set(data, forKey: "tg_events_v1")
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

    func configure(event: TGEvent, vote: String?) {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "ru_RU")
        dateFmt.dateFormat = "EEEE, d MMMM"
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "ru_RU")
        timeFmt.dateFormat = "HH:mm"

        var dateStr = dateFmt.string(from: event.startDate)
        if let first = dateStr.first { dateStr = first.uppercased() + dateStr.dropFirst() }

        titleLabel.text = event.title
        dateLabel.text = "📅  \(dateStr)"
        timeLabel.text = "⏰  \(timeFmt.string(from: event.startDate)) – \(timeFmt.string(from: event.endDate))"

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
    private var events: [TGEvent] = []
    private var currentIndex: Int = 0

    private let cardView = EventCardView()
    private let counterLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let emptyLabel = UILabel()

    public init(chatId: Int64) {
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "События"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        setupLayout()
        reload()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func setupLayout() {
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

        for v in [counterLabel, cardView, prevButton, nextButton, emptyLabel] as [UIView] {
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            counterLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            counterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            cardView.topAnchor.constraint(equalTo: counterLabel.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            prevButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            prevButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            nextButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func reload() {
        let all = loadStoredEvents()
        // Show events for this group, newest first.
        events = all.filter { $0.chatId == chatId }
            .sorted { $0.startDate > $1.startDate }
        currentIndex = 0
        updateUI()
    }

    private func updateUI() {
        let hasEvents = !events.isEmpty
        cardView.isHidden = !hasEvents
        counterLabel.isHidden = !hasEvents
        prevButton.isHidden = !hasEvents
        nextButton.isHidden = !hasEvents
        emptyLabel.isHidden = hasEvents

        guard hasEvents else { return }

        let event = events[currentIndex]
        let votes = loadVotes()
        cardView.configure(event: event, vote: votes[event.id.uuidString])
        counterLabel.text = "\(currentIndex + 1) / \(events.count)"
        prevButton.isEnabled = currentIndex < events.count - 1
        nextButton.isEnabled = currentIndex > 0

        cardView.onYes = { [weak self] in self?.vote("yes", for: event) }
        cardView.onNo = { [weak self] in self?.vote("no", for: event) }
    }

    private func vote(_ answer: String, for event: TGEvent) {
        var votes = loadVotes()
        let key = event.id.uuidString
        let prev = votes[key]
        votes[key] = (prev == answer) ? nil : answer  // toggle off if tapping same
        saveVotes(votes)

        // "Yes" → add event to personal calendar (if not already present).
        if answer == "yes", prev != "yes" {
            addEventToPersonalCalendar(event)
        }

        updateUI()
    }

    private func addEventToPersonalCalendar(_ event: TGEvent) {
        var stored = loadStoredEvents()
        // Only add if not already there as a personal (chatId-less) copy.
        let alreadyExists = stored.contains { $0.id == event.id && $0.chatId == nil }
        guard !alreadyExists else { return }
        let personal = TGEvent(
            id: event.id, title: event.title,
            startDate: event.startDate, endDate: event.endDate,
            participants: event.participants, location: event.location,
            chatId: nil
        )
        stored.append(personal)
        saveStoredEvents(stored)
    }

    @objc private func prevTapped() {
        guard currentIndex < events.count - 1 else { return }
        currentIndex += 1
        animateTransition(direction: -1)
        updateUI()
    }

    @objc private func nextTapped() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        animateTransition(direction: 1)
        updateUI()
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
