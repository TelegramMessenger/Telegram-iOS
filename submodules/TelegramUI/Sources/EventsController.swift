import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

// MARK: - Shared storage keys

enum TGEventStorage {
    static let eventsKey = "tg_events_v1"
    static let votesKey  = "tg_event_votes_v1"
}

// MARK: - Model

public struct TGEvent: Codable {
    public let id: UUID
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let participants: [String]
    public let location: String?
    public var chatId: Int64?
    public var chatIsGroup: Bool?   // nil = personal, true = group, false = DM
}

// MARK: - Mock data

private let cal = Calendar.current

private func makeMockEvents() -> [TGEvent] {
    let now = Date()
    func ev(_ dayOff: Int, _ h1: Int, _ h2: Int, _ title: String, _ people: [String], _ loc: String?) -> TGEvent {
        func d(_ offset: Int, _ hour: Int) -> Date {
            var c = cal.dateComponents([.year, .month, .day], from: now)
            c.day = (c.day ?? 1) + offset; c.hour = hour; c.minute = 0; c.second = 0
            return cal.date(from: c) ?? now
        }
        return TGEvent(id: UUID(), title: title, startDate: d(dayOff, h1), endDate: d(dayOff, h2),
                       participants: people, location: loc)
    }
    return [
        ev(0,  10, 11, "Встреча с командой",     ["Алексей К.", "Мария В.", "Иван Д."], "Zoom"),
        ev(0,  14, 15, "Обед с Максимом",         ["Максим Р."],                         "Кафе Пушкин"),
        ev(2,  16, 17, "Созвон по продукту",       ["Сергей П.", "Анна Л."],              nil),
        ev(4,  11, 12, "Встреча с инвестором",     ["Андрей С."],                         "Офис на Тверской"),
        ev(6,  19, 23, "День рождения Ольги",      ["Ольга М.", "Дмитрий Н.", "Катя Р."], "Ресторан Белуга"),
        ev(8,   9, 10, "Ежедневный стендап",       ["Вся команда"],                       "Telegram"),
    ]
}

// module-level seed; EventsController copies this into a mutable instance array
private let seedEvents = makeMockEvents()

// MARK: - Calendar day cell

private final class CalendarDayCell: UICollectionViewCell {
    private let circleView = UIView()
    private let dayLabel   = UILabel()
    private let dotView    = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let size: CGFloat = 34

        circleView.layer.cornerRadius = size / 2
        circleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circleView)

        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        dotView.backgroundColor = .systemOrange
        dotView.layer.cornerRadius = 3
        dotView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dotView)

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -2),
            circleView.widthAnchor.constraint(equalToConstant: size),
            circleView.heightAnchor.constraint(equalToConstant: size),

            dayLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 3),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(day: Int?, isSelected: Bool, isToday: Bool, hasEvents: Bool) {
        guard let day = day else {
            circleView.isHidden = true; dayLabel.text = nil; dotView.isHidden = true; return
        }
        circleView.isHidden = false
        dayLabel.text = "\(day)"
        dotView.isHidden = !hasEvents || isSelected

        switch (isSelected, isToday) {
        case (true, _):
            circleView.backgroundColor = .systemOrange
            dayLabel.textColor = .white
            dayLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        case (false, true):
            circleView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            dayLabel.textColor = .systemOrange
            dayLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        default:
            circleView.backgroundColor = .clear
            dayLabel.textColor = .label
            dayLabel.font = .systemFont(ofSize: 15, weight: .regular)
        }
    }
}

// MARK: - Event list cell

private final class EventCell: UITableViewCell {
    private let startLbl    = UILabel()
    private let timeline    = UIView()
    private let endLbl      = UILabel()
    private let titleLbl    = UILabel()
    private let peopleLbl   = UILabel()
    private let pinIcon     = UIImageView()
    private let locLbl      = UILabel()
    private let sourceIcon  = UIImageView()   // group vs DM badge

    private static let tf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"; return f
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        backgroundColor = .clear

        startLbl.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        startLbl.textColor = .systemOrange
        startLbl.textAlignment = .right
        startLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(startLbl)

        timeline.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.35)
        timeline.layer.cornerRadius = 1
        timeline.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeline)

        endLbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        endLbl.textColor = .tertiaryLabel
        endLbl.textAlignment = .right
        endLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(endLbl)

        titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLbl.textColor = .label
        titleLbl.numberOfLines = 2
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        peopleLbl.font = .systemFont(ofSize: 13)
        peopleLbl.textColor = .secondaryLabel
        peopleLbl.numberOfLines = 1
        peopleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(peopleLbl)

        let pinCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        pinIcon.image = UIImage(systemName: "mappin", withConfiguration: pinCfg)
        pinIcon.tintColor = .systemOrange
        pinIcon.contentMode = .scaleAspectFit
        pinIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pinIcon)

        locLbl.font = .systemFont(ofSize: 13)
        locLbl.textColor = .secondaryLabel
        locLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(locLbl)

        sourceIcon.contentMode = .scaleAspectFit
        sourceIcon.tintColor = .tertiaryLabel
        sourceIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sourceIcon)

        let timeW: CGFloat = 46
        NSLayoutConstraint.activate([
            startLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            startLbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            startLbl.widthAnchor.constraint(equalToConstant: timeW),

            timeline.centerXAnchor.constraint(equalTo: startLbl.centerXAnchor),
            timeline.widthAnchor.constraint(equalToConstant: 2),
            timeline.topAnchor.constraint(equalTo: startLbl.bottomAnchor, constant: 5),
            timeline.bottomAnchor.constraint(equalTo: endLbl.topAnchor, constant: -5),

            endLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            endLbl.widthAnchor.constraint(equalToConstant: timeW),
            endLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            titleLbl.leadingAnchor.constraint(equalTo: startLbl.trailingAnchor, constant: 14),
            titleLbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            peopleLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            peopleLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 4),
            peopleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            pinIcon.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            pinIcon.topAnchor.constraint(equalTo: peopleLbl.bottomAnchor, constant: 4),
            pinIcon.widthAnchor.constraint(equalToConstant: 13),
            pinIcon.heightAnchor.constraint(equalToConstant: 16),
            pinIcon.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            locLbl.leadingAnchor.constraint(equalTo: pinIcon.trailingAnchor, constant: 4),
            locLbl.centerYAnchor.constraint(equalTo: pinIcon.centerYAnchor),
            locLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            locLbl.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            sourceIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            sourceIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            sourceIcon.widthAnchor.constraint(equalToConstant: 14),
            sourceIcon.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with event: TGEvent) {
        startLbl.text = Self.tf.string(from: event.startDate)
        endLbl.text   = Self.tf.string(from: event.endDate)
        titleLbl.text = event.title

        let people = event.participants.joined(separator: ", ")
        peopleLbl.text = people.isEmpty ? nil : people
        peopleLbl.isHidden = people.isEmpty

        if let loc = event.location {
            pinIcon.isHidden = false; locLbl.isHidden = false; locLbl.text = loc
        } else {
            pinIcon.isHidden = true; locLbl.isHidden = true
        }

        let srcCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .light)
        if let isGroup = event.chatIsGroup {
            let name = isGroup ? "person.2" : "person"
            sourceIcon.image = UIImage(systemName: name, withConfiguration: srcCfg)
            sourceIcon.isHidden = false
        } else {
            sourceIcon.isHidden = true
        }
    }
}

// MARK: - Empty state

private final class EmptyEventsView: UIView {
    init() {
        super.init(frame: .zero)
        let icon = UIImageView(image: UIImage(systemName: "calendar.badge.plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .light)))
        icon.tintColor = UIColor.systemOrange.withAlphaComponent(0.4)
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        let lbl = UILabel()
        lbl.text = "Нет встреч"
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lbl)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            lbl.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            lbl.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Controller

public final class EventsController: TelegramBaseController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    // State
    private var selectedDate: Date = Date()
    private var currentMonthStart: Date = {
        let c = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: c) ?? Date()
    }()
    private var allEvents: [TGEvent] = []
    private var displayedEvents: [TGEvent] = []

    // Calendar UI
    private let monthHeaderView  = UIView()
    private let monthLabel       = UILabel()
    private let prevButton       = UIButton(type: .system)
    private let nextButton       = UIButton(type: .system)
    private let weekdayRow       = UIStackView()
    private let collectionView: UICollectionView = {
        let fl = UICollectionViewFlowLayout()
        fl.minimumInteritemSpacing = 0
        fl.minimumLineSpacing = 0
        fl.itemSize = CGSize(width: 48, height: 48)
        return UICollectionView(frame: .zero, collectionViewLayout: fl)
    }()

    private let searchBar        = UISearchBar()
    private var searchText: String = ""

    private let divider          = UIView()
    private let dateHeaderLabel  = UILabel()
    private let tableView        = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyView        = EmptyEventsView()

    private var validLayout: ContainerViewLayout?

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"; return f
    }()

    // MARK: Init

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(context: context, navigationBarPresentationData:
            NavigationBarPresentationData(presentationData: self.presentationData, style: .glass))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        self.tabBarItem.title = "События"
        let tabIcon: UIImage? = UIImage(bundleImageName: "Chat List/Tabs/IconEvents").flatMap { icon in
            let size = CGSize(width: 18, height: 18)
            return UIGraphicsImageRenderer(size: size).image { _ in
                icon.draw(in: CGRect(origin: .zero, size: size))
            }.withRenderingMode(.alwaysTemplate)
        }
        self.tabBarItem.image = tabIcon
        self.tabBarItem.selectedImage = tabIcon
        if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabEvents"
        }
        self.navigationItem.title = "События"

        let addBtn = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"),
                                     style: .plain, target: self,
                                     action: #selector(addEventTapped))
        addBtn.tintColor = .systemOrange
        self.navigationItem.rightBarButtonItem = addBtn

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] pd in
            guard let self else { return }
            self.presentationData = pd
            self.statusBar.statusBarStyle = pd.theme.rootController.statusBarStyle.style
            self.tabBarItem.animationName = pd.reduceMotion ? nil : "TabEvents"
        })

        allEvents = loadEvents()
        reloadEvents()
    }

    required public init(coder aDecoder: NSCoder) { fatalError() }

    deinit { presentationDataDisposable?.dispose() }

    // MARK: View lifecycle

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always reload: events may be added from chat without touching our delegate,
        // or an existing event's chatId may be stamped after creation.
        allEvents = loadEvents()
        if isNodeLoaded {
            collectionView.reloadData()
            updateEventsList()
        }
    }

    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        let root = self.displayNode.view
        root.backgroundColor = .systemBackground

        // Month nav header
        root.addSubview(monthHeaderView)

        let chevron = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        prevButton.setImage(UIImage(systemName: "chevron.left",  withConfiguration: chevron), for: .normal)
        nextButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: chevron), for: .normal)
        prevButton.tintColor = .systemOrange; nextButton.tintColor = .systemOrange
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        monthHeaderView.addSubview(prevButton)
        monthHeaderView.addSubview(nextButton)

        monthLabel.textAlignment = .center
        monthLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        monthHeaderView.addSubview(monthLabel)

        // Weekday row
        weekdayRow.axis = .horizontal
        weekdayRow.distribution = .fillEqually
        let days = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
        for (i, d) in days.enumerated() {
            let l = UILabel(); l.text = d; l.textAlignment = .center
            l.font = .systemFont(ofSize: 12, weight: .medium)
            l.textColor = i >= 5 ? UIColor.systemRed.withAlphaComponent(0.7) : .secondaryLabel
            weekdayRow.addArrangedSubview(l)
        }
        root.addSubview(weekdayRow)

        // Calendar grid
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "day")
        collectionView.dataSource = self
        collectionView.delegate   = self
        root.addSubview(collectionView)

        // Divider
        divider.backgroundColor = .separator
        root.addSubview(divider)

        // Date header label (above events list)
        dateHeaderLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateHeaderLabel.textColor = .secondaryLabel
        root.addSubview(dateHeaderLabel)

        // Events table
        tableView.register(EventCell.self, forCellReuseIdentifier: "event")
        tableView.dataSource = self; tableView.delegate = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        root.addSubview(tableView)

        // Empty state
        emptyView.isHidden = true
        root.addSubview(emptyView)

        // Search bar — always visible
        searchBar.placeholder = "Поиск событий"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        root.addSubview(searchBar)

        refreshMonthLabel()
        updateEventsList()
    }

    // MARK: Layout

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        guard self.isNodeLoaded else { return }
        applyLayout(layout)
    }

    private func applyLayout(_ layout: ContainerViewLayout) {
        let w = layout.size.width
        let bottomInset = layout.intrinsicInsets.bottom
        let calPad: CGFloat = 8
        let calW = w - calPad * 2
        let cellW = calW / 7
        let cellH: CGFloat = 48
        let isSearching = !searchText.isEmpty

        // Nav bar bottom — safe fallback
        let navBottom: CGFloat
        if let nb = self.navigationBar, nb.frame.maxY > 0 {
            navBottom = nb.frame.maxY
        } else {
            navBottom = (layout.statusBarHeight ?? 20) + 44
        }

        // Search bar — always pinned below nav bar
        let searchBarH: CGFloat = 52
        searchBar.frame = CGRect(x: 0, y: navBottom, width: w, height: searchBarH)

        let tableTop: CGFloat
        if isSearching {
            // Hide calendar components during search
            monthHeaderView.isHidden = true
            weekdayRow.isHidden = true
            collectionView.isHidden = true
            divider.isHidden = true
            dateHeaderLabel.isHidden = true
            tableTop = searchBar.frame.maxY
        } else {
            monthHeaderView.isHidden = false
            weekdayRow.isHidden = false
            collectionView.isHidden = false
            divider.isHidden = false
            dateHeaderLabel.isHidden = false

            // Month header
            let headerH: CGFloat = 44
            monthHeaderView.frame = CGRect(x: 0, y: searchBar.frame.maxY, width: w, height: headerH)
            prevButton.frame  = CGRect(x: 4,       y: 0, width: 48, height: headerH)
            nextButton.frame  = CGRect(x: w - 52,  y: 0, width: 48, height: headerH)
            monthLabel.frame  = CGRect(x: 56,      y: 0, width: w - 112, height: headerH)

            // Weekday labels
            weekdayRow.frame = CGRect(x: calPad, y: monthHeaderView.frame.maxY,
                                      width: calW, height: 28)

            // Calendar grid
            let rows = calendarRowCount()
            let gridH = cellH * CGFloat(rows)
            let fl = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
            let newItemSize = CGSize(width: cellW, height: cellH)
            if fl.itemSize != newItemSize { fl.itemSize = newItemSize }
            collectionView.frame = CGRect(x: calPad, y: weekdayRow.frame.maxY,
                                          width: calW, height: gridH)

            // Divider
            divider.frame = CGRect(x: 0, y: collectionView.frame.maxY + 4, width: w, height: 0.5)

            // Date header label
            let dateHeaderH: CGFloat = 36
            dateHeaderLabel.frame = CGRect(x: 20, y: divider.frame.maxY,
                                           width: w - 40, height: dateHeaderH)
            tableTop = dateHeaderLabel.frame.maxY
        }

        // Table
        let tableH = layout.size.height - tableTop - bottomInset
        tableView.frame = CGRect(x: 0, y: tableTop, width: w, height: tableH)
        emptyView.frame = tableView.frame
    }

    // MARK: Calendar helpers

    private func calendarRowCount() -> Int {
        let offset = firstWeekdayOffset(for: currentMonthStart)
        let days   = daysInMonth(for: currentMonthStart)
        return (offset + days + 6) / 7
    }

    private func firstWeekdayOffset(for date: Date) -> Int {
        let wd = cal.component(.weekday, from: date) // 1=Sun … 7=Sat
        return (wd + 5) % 7                          // 0=Mon … 6=Sun
    }

    private func daysInMonth(for date: Date) -> Int {
        return cal.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func date(day: Int, in monthStart: Date) -> Date? {
        var c = cal.dateComponents([.year, .month], from: monthStart)
        c.day = day
        return cal.date(from: c)
    }

    // MARK: Data

    // MARK: Persistence

    private func loadEvents() -> [TGEvent] {
        guard let data = UserDefaults.standard.data(forKey: TGEventStorage.eventsKey),
              let events = try? JSONDecoder().decode([TGEvent].self, from: data) else {
            return seedEvents
        }
        return events
    }

    private func saveEvents() {
        if let data = try? JSONEncoder().encode(allEvents) {
            UserDefaults.standard.set(data, forKey: TGEventStorage.eventsKey)
        }
    }

    private func reloadEvents() {
        if searchText.isEmpty {
            displayedEvents = allEvents
                .filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
                .sorted { $0.startDate < $1.startDate }
        } else {
            let q = searchText.lowercased()
            displayedEvents = allEvents.filter {
                $0.title.lowercased().contains(q) ||
                $0.location?.lowercased().contains(q) == true ||
                $0.participants.joined(separator: " ").lowercased().contains(q)
            }.sorted { $0.startDate < $1.startDate }
        }
    }

    private static let dateHeaderFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"; return f
    }()

    private func updateEventsList() {
        reloadEvents()
        tableView.reloadData()
        emptyView.isHidden = !displayedEvents.isEmpty

        if searchText.isEmpty {
            var text = Self.dateHeaderFmt.string(from: selectedDate)
            if let first = text.first { text = first.uppercased() + text.dropFirst() }
            if cal.isDateInToday(selectedDate) { text = "Сегодня, " + text.components(separatedBy: ", ").dropFirst().joined(separator: ", ") }
            dateHeaderLabel.text = text
        } else {
            dateHeaderLabel.text = "Результаты поиска"
        }
    }

    private func refreshMonthLabel() {
        var text = Self.monthFmt.string(from: currentMonthStart)
        // Capitalize first letter
        if let first = text.first { text = first.uppercased() + text.dropFirst() }
        monthLabel.text = text
    }

    // MARK: Actions

    @objc private func prevMonth() {
        guard let d = cal.date(byAdding: .month, value: -1, to: currentMonthStart) else { return }
        currentMonthStart = d
        refreshMonthLabel()
        collectionView.reloadData()
    }

    @objc private func nextMonth() {
        guard let d = cal.date(byAdding: .month, value: 1, to: currentMonthStart) else { return }
        currentMonthStart = d
        refreshMonthLabel()
        collectionView.reloadData()
    }

    @objc private func addEventTapped() {
        presentCreateEvent(editingEvent: nil)
    }

    private func presentCreateEvent(editingEvent: TGEvent?) {
        let vc = CreateEventController(context: self.context, editingEvent: editingEvent)
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        self.present(nav, animated: true)
    }
}

// MARK: - CreateEventControllerDelegate

extension EventsController: CreateEventControllerDelegate {
    func createEventController(_ controller: CreateEventController, didUpdate event: TGEvent) {
        if let idx = allEvents.firstIndex(where: { $0.id == event.id }) {
            allEvents[idx] = event
        }
        // Save already performed by CreateEventController
        let comps = cal.dateComponents([.year, .month], from: event.startDate)
        if let monthStart = cal.date(from: comps) { currentMonthStart = monthStart }
        selectedDate = event.startDate
        collectionView.reloadData()
        updateEventsList()
    }

    func createEventController(_ controller: CreateEventController, didCreate event: TGEvent) {
        allEvents.append(event)
        // Save already performed by CreateEventController
        let comps = cal.dateComponents([.year, .month], from: event.startDate)
        if let monthStart = cal.date(from: comps) {
            currentMonthStart = monthStart
        }
        selectedDate = event.startDate
        collectionView.reloadData()
        updateEventsList()
    }
}

// MARK: - UICollectionView (Calendar)

extension EventsController: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
        return calendarRowCount() * 7
    }

    public func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "day", for: ip) as! CalendarDayCell
        let offset = firstWeekdayOffset(for: currentMonthStart)
        let days   = daysInMonth(for: currentMonthStart)
        let rawDay = ip.item - offset + 1

        guard rawDay >= 1, rawDay <= days, let cellDate = date(day: rawDay, in: currentMonthStart) else {
            cell.configure(day: nil, isSelected: false, isToday: false, hasEvents: false)
            return cell
        }

        let isSelected = cal.isDate(cellDate, inSameDayAs: selectedDate)
        let isToday    = cal.isDateInToday(cellDate)
        let hasEvents  = allEvents.contains { cal.isDate($0.startDate, inSameDayAs: cellDate) }
        cell.configure(day: rawDay, isSelected: isSelected, isToday: isToday, hasEvents: hasEvents)
        return cell
    }

    public func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        let offset = firstWeekdayOffset(for: currentMonthStart)
        let days   = daysInMonth(for: currentMonthStart)
        let rawDay = ip.item - offset + 1
        guard rawDay >= 1, rawDay <= days, let d = date(day: rawDay, in: currentMonthStart) else { return }
        selectedDate = d
        cv.reloadData()
        updateEventsList()
    }
}

// MARK: - UITableView (Events)

extension EventsController: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tv: UITableView) -> Int {
        displayedEvents.count
    }

    public func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { 1 }

    public func tableView(_ tv: UITableView, heightForHeaderInSection s: Int) -> CGFloat { 8 }
    public func tableView(_ tv: UITableView, heightForFooterInSection s: Int) -> CGFloat { 0 }
    public func tableView(_ tv: UITableView, viewForHeaderInSection s: Int) -> UIView? { UIView() }
    public func tableView(_ tv: UITableView, viewForFooterInSection s: Int) -> UIView? { nil }

    public func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "event", for: ip) as! EventCell
        cell.configure(with: displayedEvents[ip.section])
        return cell
    }

    public func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        presentCreateEvent(editingEvent: displayedEvents[ip.section])
    }


    public func tableView(_ tv: UITableView, canEditRowAt ip: IndexPath) -> Bool { true }

    public func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            guard let self else { done(false); return }
            let event = self.displayedEvents[ip.section]
            self.allEvents.removeAll { $0.id == event.id }
            self.saveEvents()
            self.displayedEvents.remove(at: ip.section)
            tv.deleteSections(IndexSet(integer: ip.section), with: .automatic)
            self.collectionView.reloadData()
            self.emptyView.isHidden = !self.displayedEvents.isEmpty
            done(true)
        }
        action.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - UISearchBarDelegate

extension EventsController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        searchText = text
        updateEventsList()
        if let layout = validLayout { applyLayout(layout) }
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchText = ""
        updateEventsList()
        if let layout = validLayout { applyLayout(layout) }
    }

    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchText.isEmpty {
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
}
