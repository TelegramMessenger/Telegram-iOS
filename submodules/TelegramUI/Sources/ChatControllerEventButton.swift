import Foundation
import UIKit
import TelegramCore
import AccountContext

// MARK: - Floating button view

final class EventFloatingButton: UIView {
    private let iconLabel = UILabel()
    private let badge = UIView()
    private var onTap: (() -> Void)?
    private var lastTouchWasDrag = false

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: CGRect(x: 0, y: 0, width: 52, height: 52))
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        layer.cornerRadius = 26
        backgroundColor = UIColor.systemOrange.withAlphaComponent(0.88)
        alpha = 0.65
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 6

        iconLabel.text = "📅"
        iconLabel.font = .systemFont(ofSize: 22)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    func updateEventCount(_ count: Int) {
        badge.subviews.forEach { $0.removeFromSuperview() }
        badge.removeFromSuperview()
        guard count > 0 else { return }

        let label = UILabel()
        label.text = "\(count)"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.sizeToFit()

        let size: CGFloat = max(16, label.frame.width + 8)
        badge.frame = CGRect(x: frame.width - size / 2 - 2, y: -4, width: size, height: 16)
        badge.backgroundColor = .systemRed
        badge.layer.cornerRadius = 8
        label.center = CGPoint(x: size / 2, y: 8)
        badge.addSubview(label)
        addSubview(badge)
    }

    @objc private func handleTap() {
        guard !lastTouchWasDrag else { return }
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.15) { self.transform = .identity }
        }
        onTap?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        switch gesture.state {
        case .began:
            lastTouchWasDrag = false
            UIView.animate(withDuration: 0.15) { self.alpha = 0.85 }
        case .changed:
            let t = gesture.translation(in: superview)
            if abs(t.x) > 4 || abs(t.y) > 4 { lastTouchWasDrag = true }
            center = CGPoint(x: center.x + t.x, y: center.y + t.y)
            gesture.setTranslation(.zero, in: superview)
            clampToSuperview(superview)
        case .ended, .cancelled:
            snapToEdge(superview)
            UIView.animate(withDuration: 0.2) { self.alpha = 0.65 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.lastTouchWasDrag = false }
        default:
            break
        }
    }

    private func clampToSuperview(_ sv: UIView) {
        let pad: CGFloat = 8
        let halfW = bounds.width / 2
        let halfH = bounds.height / 2
        let safeTop = (sv as? UIWindow)?.safeAreaInsets.top ?? 44
        let safeBottom = (sv as? UIWindow)?.safeAreaInsets.bottom ?? 34
        center = CGPoint(
            x: max(halfW + pad, min(sv.bounds.width - halfW - pad, center.x)),
            y: max(halfH + safeTop + 8, min(sv.bounds.height - halfH - safeBottom - 80, center.y))
        )
    }

    private func snapToEdge(_ sv: UIView) {
        let pad: CGFloat = 16
        let targetX: CGFloat = center.x < sv.bounds.midX
            ? bounds.width / 2 + pad
            : sv.bounds.width - bounds.width / 2 - pad
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: []) {
            self.center.x = targetX
        }
    }
}

// MARK: - ChatControllerImpl extension

extension ChatControllerImpl {

    private static let floatingEventButtonTag = 77421

    func setupEventFloatingButtonIfNeeded() {
        let peer = presentationInterfaceState.renderedPeer?.peer
        let isGroup: Bool
        if peer is TelegramGroup {
            isGroup = true
        } else if let ch = peer as? TelegramChannel, case .group = ch.info {
            isGroup = true
        } else {
            isGroup = false
        }

        if !isGroup {
            view.viewWithTag(Self.floatingEventButtonTag)?.removeFromSuperview()
            return
        }

        // Already installed.
        if view.viewWithTag(Self.floatingEventButtonTag) != nil { return }

        guard let peerId = chatLocation.peerId else { return }
        let chatId = peerId.id._internalGetInt64Value()

        let button = EventFloatingButton { [weak self] in
            guard let self else { return }
            let nav = UINavigationController(rootViewController: EventCardNavigatorController(chatId: chatId))
            nav.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *) {
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.prefersGrabberVisible = true
                }
            }
            self.present(nav, animated: true)
        }
        button.tag = Self.floatingEventButtonTag

        // Initial position: right edge, vertically centered.
        let bw: CGFloat = 52
        button.frame = CGRect(
            x: view.bounds.width - bw - 16,
            y: view.bounds.height / 2,
            width: bw, height: bw
        )
        view.addSubview(button)

        refreshEventFloatingButtonBadge(chatId: chatId)
    }

    func refreshEventFloatingButtonBadge(chatId: Int64) {
        guard let button = view.viewWithTag(Self.floatingEventButtonTag) as? EventFloatingButton else { return }
        let key = "tg_events_v1"
        let stored = (try? JSONDecoder().decode([TGEvent].self,
            from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? []
        let votes = (try? JSONDecoder().decode([String: String].self,
            from: UserDefaults.standard.data(forKey: "tg_event_votes_v1") ?? Data())) ?? [:]
        let unvotedCount = stored
            .filter { $0.chatId == chatId }
            .filter { votes[$0.id.uuidString] == nil }
            .count
        button.updateEventCount(unvotedCount)
    }
}
