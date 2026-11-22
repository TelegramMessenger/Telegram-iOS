import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import ViewControllerComponent
import EmojiStatusComponent
import PeerListItemComponent
import MultilineTextComponent

// The topic picker stays inside the share sheet, like ShareController's topics grid.
final class ShareScreenTopicsComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let model: ShareScreenState
    let revision: Int
    let bottomInset: CGFloat

    init(model: ShareScreenState, bottomInset: CGFloat) {
        self.model = model
        self.revision = model.revision
        self.bottomInset = bottomInset
    }

    static func ==(lhs: ShareScreenTopicsComponent, rhs: ShareScreenTopicsComponent) -> Bool {
        return lhs.model === rhs.model && lhs.revision == rhs.revision && lhs.bottomInset == rhs.bottomInset
    }

    final class TopicButton: UIControl {
        let icon = ComponentView<Empty>()
        let title = ComponentView<Empty>()
        var action: (() -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func pressed() { self.action?() }
    }

    final class View: UIView {
        private var visibleBounds: CGRect = .zero
        private var component: ShareScreenTopicsComponent?
        private var availableSize: CGSize = .zero
        private var environment: Environment<EnvironmentType>?

        func updateVisibleBounds(_ bounds: CGRect) {
            guard self.visibleBounds != bounds else { return }
            self.visibleBounds = bounds
            guard let component = self.component, let environment = self.environment else { return }
            let _ = self.update(component: component, availableSize: self.availableSize, environment: environment, synchronousLoad: false)
        }

        var transitionViews: [UIView] {
            return Array(self.visibleItems.values)
        }

        private let activity = UIActivityIndicatorView(style: .medium)
        private let emptyLabel = ComponentView<Empty>()
        private var visibleItems: [Int64: TopicButton] = [:]

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.activity)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func update(component: ShareScreenTopicsComponent, availableSize: CGSize, environment: Environment<EnvironmentType>, synchronousLoad: Bool) -> CGSize {
            self.component = component
            self.availableSize = availableSize
            self.environment = environment
            if self.visibleBounds.isEmpty { self.visibleBounds = CGRect(origin: .zero, size: availableSize) }
            let environment = environment[EnvironmentType.self].value
            let model = component.model
            let columns = max(3, Int(floor(availableSize.width / 72.0)))
            let width = (availableSize.width - 20.0) / CGFloat(columns)
            var validIds = Set<Int64>()
            let visibleBounds = self.visibleBounds.insetBy(dx: 0.0, dy: -120.0)
            let visibleRange = shareScreenVisibleItems(min: visibleBounds.minY, max: visibleBounds.maxY, origin: 84.0, stride: 100.0, count: model.forumTopics.count, columns: columns)
            for index in visibleRange {
                let topic = model.forumTopics[index]
                validIds.insert(topic.id)
                let button: TopicButton
                var isNew = false
                if let current = self.visibleItems[topic.id] { button = current }
                else {
                    isNew = true
                    button = TopicButton(frame: .zero)
                    self.visibleItems[topic.id] = button
                    self.addSubview(button)
                }
                button.frame = CGRect(x: 10.0 + CGFloat(index % columns) * width, y: 84.0 + CGFloat(index / columns) * 100.0, width: width, height: 100.0)
                button.action = { [weak model] in model?.selectTopic(topic) }
                button.accessibilityLabel = topic.title
                if let data = topic.data {
                    let content: EmojiStatusComponent.Content
                    if let fileId = data.info.icon {
                        content = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 96.0, height: 96.0), placeholderColor: environment.theme.actionSheet.disabledActionTextColor, themeColor: environment.theme.actionSheet.primaryTextColor, loopMode: .count(0))
                    } else {
                        content = .topic(title: String(data.info.title.prefix(1)), color: data.info.iconColor, size: CGSize(width: 64.0, height: 64.0))
                    }
                    let size = button.icon.update(transition: .immediate, component: AnyComponent(EmojiStatusComponent(context: model.context, animationCache: model.context.animationCache, animationRenderer: model.context.animationRenderer, content: content, isVisibleForAnimations: environment.isVisible, action: nil)), environment: {}, containerSize: CGSize(width: 54.0, height: 54.0))
                    if let view = button.icon.view {
                        if view.superview == nil { button.addSubview(view) }
                        view.isUserInteractionEnabled = false
                        view.frame = CGRect(x: floorToScreenPixels((width - size.width) / 2.0), y: 7.0, width: size.width, height: size.height)
                    }
                    let titleSize = button.title.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: topic.title, font: Font.regular(11.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                            horizontalAlignment: .center,
                            truncationType: .end,
                            maximumNumberOfLines: 2
                        )),
                        environment: {},
                        containerSize: CGSize(width: width - 4.0, height: 28.0)
                    )
                    if let titleView = button.title.view {
                        if titleView.superview == nil {
                            titleView.isUserInteractionEnabled = false
                            button.addSubview(titleView)
                        }
                        titleView.isHidden = false
                        titleView.frame = CGRect(x: floorToScreenPixels((width - titleSize.width) * 0.5), y: 68.0, width: titleSize.width, height: titleSize.height)
                    }
                } else {
                    button.title.view?.isHidden = true
                    let _ = button.icon.update(transition: ComponentTransition.immediate.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: synchronousLoad && isNew)), component: AnyComponent(ShareScreenPeerComponent(context: model.context, theme: environment.theme, peer: topic.peer, title: topic.title, isStory: false, selected: false, online: false, action: {})), environment: {}, containerSize: button.bounds.size)
                    if let view = button.icon.view {
                        if view.superview == nil { button.addSubview(view) }
                        view.frame = button.bounds
                        view.isUserInteractionEnabled = false
                    }
                }
            }
            for id in Array(self.visibleItems.keys) where !validIds.contains(id) {
                self.visibleItems.removeValue(forKey: id)?.removeFromSuperview()
            }
            let height = 84.0 + CGFloat((model.forumTopics.count + columns - 1) / columns) * 100.0
            self.activity.center = CGPoint(x: availableSize.width / 2.0, y: shareScreenActivityCenterY(contentBottom: height, visibleBounds: self.visibleBounds, bottomInset: component.bottomInset))
            if model.topicsLoading { self.activity.startAnimating() } else { self.activity.stopAnimating() }
            shareScreenUpdateText(self.emptyLabel, parent: self, string: environment.strings.ChatList_Search_NoResults, font: Font.regular(17.0), color: environment.theme.list.itemSecondaryTextColor, alignment: .center, frame: CGRect(x: 16.0, y: 114.0, width: availableSize.width - 32.0, height: 44.0), isHidden: model.topicsLoading || !model.forumTopics.isEmpty)
            return CGSize(width: availableSize.width, height: max(540.0, height + (model.forumTopics.isEmpty ? 100.0 : 0.0) + component.bottomInset))
        }
    }
    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, synchronousLoad: transition.userData(PeerListItemComponent.TransitionHint.self)?.synchronousLoad ?? false)
    }
}
