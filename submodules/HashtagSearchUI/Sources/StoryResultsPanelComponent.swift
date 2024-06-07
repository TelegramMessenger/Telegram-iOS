import Foundation
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import MultilineTextComponent
import BundleIconComponent
import StorySetIndicatorComponent
import AccountContext

final class StoryResultsPanelComponent: CombinedComponent {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let query: String
    let state: StoryListContext.State
    let sideInset: CGFloat
    let action: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        query: String,
        state: StoryListContext.State,
        sideInset: CGFloat,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.query = query
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
        if lhs.state != rhs.state {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let avatars = Child(StorySetIndicatorComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let arrow = Child(BundleIconComponent.self)
        let separator = Child(Rectangle.self)
        let button = Child(Button.self)
        
        return { context in
            let component = context.component
            
            let spacing: CGFloat = 3.0
            
            let textLeftInset: CGFloat = 81.0 + component.sideInset
            let textTopInset: CGFloat = 9.0
            
            var existingPeerIds = Set<EnginePeer.Id>()
            var items: [StorySetIndicatorComponent.Item] = []
            for item in component.state.items {
                guard let peer = item.peer, !existingPeerIds.contains(peer.id) else {
                    continue
                }
                existingPeerIds.insert(peer.id)
                items.append(StorySetIndicatorComponent.Item(storyItem: item.storyItem, peer: peer))
            }
            
            let avatars = avatars.update(
                component: StorySetIndicatorComponent(
                    context: component.context,
                    strings: component.strings,
                    items: Array(items.prefix(3)),
                    displayAvatars: true,
                    hasUnseen: true,
                    hasUnseenPrivate: false,
                    totalCount: 0,
                    theme: component.theme,
                    action: {}
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.strings.HashtagSearch_StoriesFound(Int32(component.state.totalCount)),
                        font: Font.semibold(15.0),
                        textColor: component.theme.rootController.navigationBar.primaryTextColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - textLeftInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.strings.HashtagSearch_StoriesFoundInfo(component.query).string,
                        font: Font.regular(14.0),
                        textColor: component.theme.rootController.navigationBar.secondaryTextColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - textLeftInset, height: context.availableSize.height),
                transition: .immediate
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
                component: Rectangle(color: component.theme.rootController.navigationBar.opaqueBackgroundColor),
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
            
            context.add(avatars
                .position(CGPoint(x: component.sideInset + 10.0 + 30.0, y: background.size.height / 2.0))
            )
         
            context.add(title
                .position(CGPoint(x: textLeftInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
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
