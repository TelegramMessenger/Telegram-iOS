import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import EmojiStatusComponent
import MultilineTextComponent

/// One category chip: emoji (or custom emoji) and title; filled accent when selected.
public final class NewsInterestChipComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let category: EngineInterestCategory
    public let isSelected: Bool
    public let action: () -> Void

    public init(context: AccountContext, theme: PresentationTheme, category: EngineInterestCategory, isSelected: Bool, action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.category = category
        self.isSelected = isSelected
        self.action = action
    }

    public static func ==(lhs: NewsInterestChipComponent, rhs: NewsInterestChipComponent) -> Bool {
        return lhs.context === rhs.context && lhs.theme === rhs.theme && lhs.category == rhs.category && lhs.isSelected == rhs.isSelected
    }

    public final class View: UIView {
        private let backgroundLayer = SimpleLayer()
        private let emoji = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private var component: NewsInterestChipComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.layer.addSublayer(self.backgroundLayer)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        @objc private func tapped() {
            self.component?.action()
        }

        func update(component: NewsInterestChipComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            let theme = component.theme
            let height: CGFloat = 28.0
            let horizontalInset: CGFloat = 12.0
            let emojiSize: CGFloat = 20.0
            let emojiSpacing: CGFloat = 6.0

            let textColor = component.isSelected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemAccentColor
            self.backgroundLayer.backgroundColor = (component.isSelected ? theme.list.itemAccentColor : theme.list.itemAccentColor.withMultipliedAlpha(0.1)).cgColor
            self.backgroundLayer.cornerRadius = height * 0.5

            var emojiComponent: AnyComponent<Empty>?
            if let fileId = component.category.emojiFileId {
                emojiComponent = AnyComponent(EmojiStatusComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    content: .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: emojiSize, height: emojiSize), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: textColor, loopMode: .count(0)),
                    isVisibleForAnimations: false,
                    action: nil
                ))
            } else if let emoji = component.category.emoji {
                emojiComponent = AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: emoji, font: Font.regular(17.0), textColor: textColor))))
            }

            var x = horizontalInset
            if let emojiComponent {
                let size = self.emoji.update(transition: .immediate, component: emojiComponent, environment: {}, containerSize: CGSize(width: emojiSize + 4.0, height: emojiSize + 4.0))
                if let emojiView = self.emoji.view {
                    if emojiView.superview == nil {
                        self.addSubview(emojiView)
                    }
                    emojiView.isHidden = false
                    transition.setFrame(view: emojiView, frame: CGRect(origin: CGPoint(x: x + floor((emojiSize - size.width) * 0.5), y: floor((height - size.height) * 0.5)), size: size))
                }
                x += emojiSize + emojiSpacing
            } else {
                self.emoji.view?.isHidden = true
            }

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.category.title, font: Font.medium(13.0), textColor: textColor)))),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - x - horizontalInset), height: height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: x, y: floor((height - titleSize.height) * 0.5)), size: titleSize))
            }

            let size = CGSize(width: x + titleSize.width + horizontalInset, height: height)
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: CGPoint(), size: size))
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

/// The "What are you interested in?" block: a header laid out like a post row's (the icon in the avatar's slot,
/// the title in the channel name's font, the same insets), then wrapping category chips where a post's text goes.
public final class NewsInterestsBlockComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let icon: String
    public let title: String
    public let categories: [EngineInterestCategory]
    public let selectedIds: Set<Int32>
    public let toggle: (Int32) -> Void

    public init(context: AccountContext, theme: PresentationTheme, icon: String, title: String, categories: [EngineInterestCategory], selectedIds: Set<Int32>, toggle: @escaping (Int32) -> Void) {
        self.context = context
        self.theme = theme
        self.icon = icon
        self.title = title
        self.categories = categories
        self.selectedIds = selectedIds
        self.toggle = toggle
    }

    public static func ==(lhs: NewsInterestsBlockComponent, rhs: NewsInterestsBlockComponent) -> Bool {
        return lhs.context === rhs.context && lhs.theme === rhs.theme && lhs.icon == rhs.icon && lhs.title == rhs.title && lhs.categories == rhs.categories && lhs.selectedIds == rhs.selectedIds
    }

    public final class View: UIView {
        private let iconView = ComponentView<Empty>()
        private let titleView = ComponentView<Empty>()
        private var chipViews: [Int32: ComponentView<Empty>] = [:]
        private let separatorLayer = SimpleLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.layer.addSublayer(self.separatorLayer)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: NewsInterestsBlockComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let theme = component.theme
            // NewsFeedPostComponent's metrics, so the block reads as one of the feed's rows.
            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 10.0
            let bottomInset: CGFloat = 10.0
            let iconSize: CGFloat = 16.0
            let iconSpacing: CGFloat = 6.0
            let contentSpacing: CGFloat = 11.0
            let chipSpacing: CGFloat = 6.0

            let titleX = sideInset + iconSize + iconSpacing
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - titleX - sideInset), height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: titleX, y: topInset), size: titleSize)
            if let view = self.titleView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: titleFrame)
            }

            let iconTextSize = self.iconView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.icon, font: Font.regular(14.0), textColor: theme.list.itemPrimaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let view = self.iconView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                // Centred in the avatar's slot, on the title, as a post's avatar is.
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: sideInset + floorToScreenPixels((iconSize - iconTextSize.width) * 0.5), y: floorToScreenPixels(titleFrame.midY - iconTextSize.height * 0.5)), size: iconTextSize))
            }

            var x = sideInset
            var y = titleFrame.maxY + contentSpacing
            var rowHeight: CGFloat = 0.0
            var validIds = Set<Int32>()
            for category in component.categories {
                validIds.insert(category.id)
                let chip: ComponentView<Empty>
                if let current = self.chipViews[category.id] {
                    chip = current
                } else {
                    chip = ComponentView<Empty>()
                    self.chipViews[category.id] = chip
                }
                let toggle = component.toggle
                let chipSize = chip.update(
                    transition: transition,
                    component: AnyComponent(NewsInterestChipComponent(context: component.context, theme: theme, category: category, isSelected: component.selectedIds.contains(category.id), action: {
                        toggle(category.id)
                    })),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 34.0)
                )
                if x > sideInset && x + chipSize.width > availableSize.width - sideInset {
                    x = sideInset
                    y += rowHeight + chipSpacing
                    rowHeight = 0.0
                }
                if let view = chip.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: x, y: y), size: chipSize))
                }
                x += chipSize.width + chipSpacing
                rowHeight = max(rowHeight, chipSize.height)
            }
            for (id, chip) in self.chipViews where !validIds.contains(id) {
                chip.view?.removeFromSuperview()
                self.chipViews.removeValue(forKey: id)
            }

            let height = y + rowHeight + bottomInset
            self.separatorLayer.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(x: sideInset, y: height - UIScreenPixel, width: availableSize.width - sideInset * 2.0, height: UIScreenPixel))
            return CGSize(width: availableSize.width, height: height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
