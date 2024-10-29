import Foundation
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import MultilineTextComponent
import BundleIconComponent
import StorySetIndicatorComponent
import AccountContext
import AnimatedTextComponent
import BlurredBackgroundComponent

final class StoryResultsPanelComponent: CombinedComponent {
    enum SearchState: Equatable {
        case stories(StoryListContext.State)
        case messages(Int32)
    }
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let query: String
    let peer: EnginePeer?
    let state: SearchState
    let sideInset: CGFloat
    let action: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        query: String,
        peer: EnginePeer?,
        state: SearchState,
        sideInset: CGFloat,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.query = query
        self.peer = peer
        self.state = state
        self.sideInset = sideInset
        self.action = action
    }
    
    static func ==(lhs: StoryResultsPanelComponent, rhs: StoryResultsPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.query != rhs.query {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(BlurredBackgroundComponent.self)
        let avatars = Child(StorySetIndicatorComponent.self)
        let titlePrefix = Child(AnimatedTextComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(AnimatedTextComponent.self)
        let arrow = Child(BundleIconComponent.self)
        let separator = Child(Rectangle.self)
        let button = Child(Button.self)
        
        return { context in
            let component = context.component
            
            let spacing: CGFloat = 3.0
            
            var textLeftInset: CGFloat = 16.0 + component.sideInset
            let textTopInset: CGFloat = 9.0
            
            var existingPeerIds = Set<EnginePeer.Id>()
            var items: [StorySetIndicatorComponent.Item] = []
            switch component.state {
            case let .stories(state):
                for item in state.items {
                    guard let peer = item.peer, !existingPeerIds.contains(peer.id) || component.peer != nil else {
                        continue
                    }
                    existingPeerIds.insert(peer.id)
                    items.append(StorySetIndicatorComponent.Item(storyItem: item.storyItem, peer: peer))
                }
                textLeftInset += 65.0
            default:
                break
            }
                        
            var titlePrefixString: [AnimatedTextComponent.Item] = []
            let titleString: NSAttributedString
            var textString: [AnimatedTextComponent.Item] = []
            if let peer = component.peer, let username = peer.addressName {
                let entityType: String
                switch component.state {
                case let .messages(count):
                    titlePrefixString = [AnimatedTextComponent.Item(
                        id: "text",
                        isUnbreakable: true,
                        content: .text(component.strings.HashtagSearch_Posts(count))
                    )]
                    entityType = component.strings.HashtagSearch_FoundPosts
                case let .stories(state):
                    titlePrefixString = [AnimatedTextComponent.Item(
                        id: "text",
                        isUnbreakable: true,
                        content: .text(component.strings.HashtagSearch_Stories(Int32(state.totalCount)))
                    )]
                    entityType = component.strings.HashtagSearch_FoundStories
                }
                let fullString = component.strings.HashtagSearch_LocalStoriesFound("", "@\(username)")
                titleString = NSMutableAttributedString(
                    string: fullString.string,
                    font: Font.semibold(15.0),
                    textColor: component.theme.rootController.navigationBar.primaryTextColor,
                    paragraphAlignment: .natural
                )
                if let lastRange = fullString.ranges.last?.range {
                    (titleString as? NSMutableAttributedString)?.addAttribute(NSAttributedString.Key.foregroundColor, value: component.theme.rootController.navigationBar.accentTextColor, range: lastRange)
                }
                textString = AnimatedTextComponent.extractAnimatedTextString(string: component.strings.HashtagSearch_FoundInfoFormat(
                    ".",
                    "."
                ), id: "info", mapping: [
                    0: .text(entityType),
                    1: .text(component.query)
                ])
            } else {
                if case let .stories(state) = component.state {
                    titleString = NSAttributedString(
                        string: component.strings.HashtagSearch_StoriesFound(Int32(state.totalCount)),
                        font: Font.semibold(15.0),
                        textColor: component.theme.rootController.navigationBar.primaryTextColor,
                        paragraphAlignment: .natural
                    )
                } else {
                    titleString = NSAttributedString()
                }
                textString = AnimatedTextComponent.extractAnimatedTextString(string: component.strings.HashtagSearch_FoundInfoFormat(
                    ".",
                    "."
                ), id: "info", mapping: [
                    0: .text(component.strings.HashtagSearch_FoundStories),
                    1: .text(component.query)
                ])
            }
            
            var titlePrefixOffset: CGFloat = 0.0
            var titlePrefixChild: _UpdatedChildComponent?
            if !titlePrefixString.isEmpty {
                let titlePrefix = titlePrefix.update(
                    component: AnimatedTextComponent(
                        font: Font.semibold(15.0),
                        color: component.theme.rootController.navigationBar.primaryTextColor,
                        items: titlePrefixString,
                        noDelay: true
                    ),
                    availableSize: CGSize(width: context.availableSize.width - textLeftInset - 64.0, height: context.availableSize.height),
                    transition: context.transition
                )
                titlePrefixOffset = titlePrefix.size.width + 1.0
                titlePrefixChild = titlePrefix
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(titleString),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - textLeftInset - 64.0 - titlePrefixOffset, height: CGFloat.greatestFiniteMagnitude),
                transition: context.transition
            )

            let text = text.update(
                component: AnimatedTextComponent(
                    font: Font.regular(14.0),
                    color: component.theme.rootController.navigationBar.secondaryTextColor,
                    items: textString,
                    noDelay: true
                ),
                availableSize: CGSize(width: context.availableSize.width - textLeftInset, height: context.availableSize.height),
                transition: context.transition
            )
            
            let arrow = arrow.update(
                component: BundleIconComponent(
                    name: "Item List/DisclosureArrow",
                    tintColor: component.theme.list.disclosureArrowColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
            
            let size = CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + spacing + text.size.height + textTopInset + 2.0)
            
            let background = background.update(
                component: BlurredBackgroundComponent(color: component.theme.rootController.navigationBar.blurredBackgroundColor),
                availableSize: size,
                transition: .immediate
            )
            
            let separator = separator.update(
                component: Rectangle(color: component.theme.rootController.navigationBar.separatorColor),
                availableSize: CGSize(width: size.width, height: UIScreenPixel),
                transition: .immediate
            )
            
            let button = button.update(
                component: Button(
                    content: AnyComponent(Rectangle(color: .clear)),
                    action: component.action
                ),
                availableSize: size,
                transition: .immediate
            )
            
            context.add(background
                .position(CGPoint(x: background.size.width / 2.0, y: background.size.height / 2.0))
            )
            
            context.add(separator
                .position(CGPoint(x: background.size.width / 2.0, y: background.size.height - separator.size.height / 2.0))
            )
            
            if !items.isEmpty {
                let avatars = avatars.update(
                    component: StorySetIndicatorComponent(
                        context: component.context,
                        strings: component.strings,
                        items: Array(items.prefix(3)),
                        displayAvatars: component.peer == nil,
                        hasUnseen: true,
                        hasUnseenPrivate: false,
                        totalCount: 0,
                        theme: component.theme,
                        action: {}
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(avatars
                    .position(CGPoint(x: component.sideInset + 10.0 + 30.0, y: background.size.height / 2.0))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
            }
         
            if let titlePrefixChild {
                context.add(titlePrefixChild
                    .position(CGPoint(x: textLeftInset + titlePrefixChild.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
                )
            }
            
            context.add(title
                .position(CGPoint(x: textLeftInset + titlePrefixOffset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textLeftInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(arrow
                .position(CGPoint(x: context.availableSize.width - arrow.size.width - component.sideInset, y: size.height / 2.0))
            )
            
            context.add(button
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
        
            return size
        }
    }
}
