import UIKit
import Display
import ComponentFlow
import TelegramCore
import ViewControllerComponent
import PeerListItemComponent

final class ShareScreenCommunityComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let model: ShareScreenState
    let revision: Int
    let bottomInset: CGFloat
    let select: (EnginePeer) -> Void

    init(model: ShareScreenState, bottomInset: CGFloat, select: @escaping (EnginePeer) -> Void) {
        self.model = model
        self.revision = model.revision
        self.bottomInset = bottomInset
        self.select = select
    }

    static func ==(lhs: ShareScreenCommunityComponent, rhs: ShareScreenCommunityComponent) -> Bool {
        return lhs.model === rhs.model && lhs.revision == rhs.revision && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private var visibleBounds: CGRect = .zero
        private var component: ShareScreenCommunityComponent?
        private var availableSize: CGSize = .zero
        private var environment: EnvironmentType?

        func updateVisibleBounds(_ bounds: CGRect) {
            guard self.visibleBounds != bounds else { return }
            self.visibleBounds = bounds
            guard let component = self.component, let environment = self.environment else { return }
            let _ = self.update(component: component, availableSize: self.availableSize, environment: environment, transition: .immediate)
        }

        private var visibleItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        var transitionViews: [UIView] {
            return self.visibleItems.values.compactMap { $0.view }
        }

        func transitionView(peerId: EnginePeer.Id) -> UIView? {
            return self.visibleItems[peerId]?.view
        }

        private let activity = UIActivityIndicatorView(style: .medium)
        private let emptyLabel = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.activity)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func update(component: ShareScreenCommunityComponent, availableSize: CGSize, environment: EnvironmentType, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.availableSize = availableSize
            self.environment = environment
            if self.visibleBounds.isEmpty { self.visibleBounds = CGRect(origin: .zero, size: availableSize) }
            let model = component.model
            let synchronousLoad = transition.userData(PeerListItemComponent.TransitionHint.self)?.synchronousLoad ?? false
            var validIds = Set<EnginePeer.Id>()
            let visibleBounds = self.visibleBounds.insetBy(dx: 0.0, dy: -120.0)
            let columns = model.communityUsesGrid ? max(3, Int(floor(availableSize.width / 72.0))) : 1
            let rowHeight: CGFloat = model.communityUsesGrid ? 100.0 : 60.0
            let cellWidth = (availableSize.width - 20.0) / CGFloat(columns)
            let visibleRange = shareScreenVisibleItems(min: visibleBounds.minY, max: visibleBounds.maxY, origin: 84.0, stride: rowHeight, count: model.communityPeers.count, columns: columns)
            for index in visibleRange {
                let peer = model.communityPeers[index]
                validIds.insert(peer.id)
                let item = self.visibleItems[peer.id] ?? ComponentView<Empty>()
                let isNew = item.view == nil
                let itemTransition = (isNew ? .immediate : transition).withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: synchronousLoad && isNew))
                self.visibleItems[peer.id] = item
                let isSelected = model.selection.contains(peer.id)
                let opensTopics = peer._asPeer().isForumOrMonoForum && !isSelected
                let title = model.displayPeer(peer).displayTitle(strings: environment.strings, displayOrder: model.context.sharedContext.currentPresentationData.with { $0.nameDisplayOrder })
                let subtitle = model.communityParticipantCounts[peer.id].map {
                    PeerListItemComponent.Subtitle(text: environment.strings.Conversation_StatusMembers(Int32(clamping: $0)), color: .neutral)
                }
                let frame: CGRect
                let itemComponent: AnyComponent<Empty>
                if model.communityUsesGrid {
                    frame = CGRect(x: 10.0 + CGFloat(index % columns) * cellWidth, y: 84.0 + CGFloat(index / columns) * rowHeight, width: cellWidth, height: rowHeight)
                    itemComponent = AnyComponent(ShareScreenPeerComponent(
                        context: model.context, theme: environment.theme, peer: peer,
                        title: model.selection.topicPeers[peer.id]?.compactDisplayTitle ?? model.displayPeer(peer).compactDisplayTitle, avatarPeer: model.displayPeer(peer), topicData: model.selection.topicData[peer.id], communityChats: model.selection.topicPeers[peer.id].map { [$0] } ?? [],
                        selected: isSelected, online: false, requirement: model.messagingRequirement(for: peer),
                        action: { component.select(peer) }
                    ))
                } else {
                    frame = CGRect(x: 0.0, y: 84.0 + CGFloat(index) * rowHeight, width: availableSize.width, height: rowHeight)
                    itemComponent = AnyComponent(ShareScreenRestrictedRowComponent(content: AnyComponent(PeerListItemComponent(
                        context: model.context, theme: environment.theme, strings: environment.strings, style: .share, sideInset: 12.0,
                        title: title, peer: peer, avatarPeer: model.displayPeer(peer), subtitle: subtitle, subtitleAccessory: .none, presence: nil,
                        rightAccessory: opensTopics ? .disclosure : .none,
                        selectionState: opensTopics ? .none : .editing(isSelected: isSelected, isTinted: false), selectionPosition: .right,
                        isEnabled: !model.messagingRequirement(for: peer).requiresPremium, hasNext: index != model.communityPeers.count - 1,
                        action: { peer, _, _ in component.select(peer) }
                    )), theme: environment.theme, requirement: model.messagingRequirement(for: peer)))
                }
                let _ = item.update(transition: itemTransition, component: itemComponent, environment: {}, containerSize: frame.size)
                if let view = item.view {
                    if view.superview == nil { self.addSubview(view) }
                    itemTransition.setFrame(view: view, frame: frame)
                    if !model.communityUsesGrid {
                        view.isAccessibilityElement = true
                        view.accessibilityLabel = [title, subtitle?.text].compactMap { $0 }.joined(separator: ", ")
                        view.accessibilityTraits = isSelected ? [.button, .selected] : .button
                    }
                }
            }
            for id in Array(self.visibleItems.keys) where !validIds.contains(id) {
                self.visibleItems.removeValue(forKey: id)?.view?.removeFromSuperview()
            }
            self.activity.center = CGPoint(x: availableSize.width / 2.0, y: shareScreenActivityCenterY(contentBottom: 84.0, visibleBounds: self.visibleBounds, bottomInset: component.bottomInset))
            self.activity.color = environment.theme.list.itemSecondaryTextColor
            if model.communityLoading { self.activity.startAnimating() } else { self.activity.stopAnimating() }
            shareScreenUpdateText(self.emptyLabel, parent: self, string: environment.strings.ChatList_Search_NoResults, font: Font.regular(17.0), color: environment.theme.list.itemSecondaryTextColor, alignment: .center, frame: CGRect(x: 16.0, y: 104.0, width: availableSize.width - 32.0, height: 44.0), isHidden: model.communityLoading || !model.communityPeers.isEmpty)
            return CGSize(width: availableSize.width, height: max(availableSize.height, 84.0 + CGFloat((model.communityPeers.count + columns - 1) / columns) * rowHeight + component.bottomInset))
        }
    }

    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment[EnvironmentType.self].value, transition: transition)
    }
}
