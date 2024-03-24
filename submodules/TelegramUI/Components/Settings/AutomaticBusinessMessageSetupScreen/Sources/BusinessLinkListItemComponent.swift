import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import TelegramPresentationData
import AppBundle
import AccountContext
import Postbox
import TelegramCore
import TextNodeWithEntities
import MultilineTextComponent
import TextFormat
import ListItemSwipeOptionContainer

final class BusinessLinkListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let link: TelegramBusinessChatLinks.Link
    let action: () -> Void
    let deleteAction: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        link: TelegramBusinessChatLinks.Link,
        action: @escaping () -> Void,
        deleteAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.link = link
        self.action = action
        self.deleteAction = deleteAction
    }

    static func ==(lhs: BusinessLinkListItemComponent, rhs: BusinessLinkListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private let containerButton: HighlightTrackingButton
        private let swipeOptionContainer: ListItemSwipeOptionContainer
        
        private let iconView = UIImageView()
        private let viewCount = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = TextNodeWithEntities()
        
        private var component: BusinessLinkListItemComponent?
        private weak var componentState: EmptyComponentState?
        
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            self.containerButton = HighlightTrackingButton()
            self.containerButton.layer.anchorPoint = CGPoint()
            self.containerButton.isExclusiveTouch = true
            
            self.swipeOptionContainer = ListItemSwipeOptionContainer(frame: CGRect())
            
            super.init(frame: frame)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.internalHighligthedChanged = { [weak self] isHighlighted in
                guard let self else {
                    return
                }
                if let customUpdateIsHighlighted = self.customUpdateIsHighlighted {
                    customUpdateIsHighlighted(isHighlighted)
                }
            }
            
            self.swipeOptionContainer.updateRevealOffset = { [weak self] offset, transition in
                guard let self else {
                    return
                }
                transition.setBounds(view: self.containerButton, bounds: CGRect(origin: CGPoint(x: -offset, y: 0.0), size: self.containerButton.bounds.size))
            }
            self.swipeOptionContainer.revealOptionSelected = { [weak self] option, _ in
                guard let self, let component = self.component else {
                    return
                }
                self.swipeOptionContainer.setRevealOptionsOpened(false, animated: true)
                component.deleteAction()
            }
            
            self.addSubview(self.swipeOptionContainer)
            
            self.swipeOptionContainer.addSubview(self.containerButton)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        func update(component: BusinessLinkListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            let _ = previousComponent
            
            self.component = component
            self.componentState = state
            
            let leftContentInset: CGFloat = 62.0
            let rightInset: CGFloat = 8.0
            let topInset: CGFloat = 9.0
            let bottomInset: CGFloat = 9.0
            let titleViewCountSpacing: CGFloat = 4.0
            let titleTextSpacing: CGFloat = 4.0
            
            //TODO:localize
            
            let viewCountText: String
            if component.link.viewCount == 0 {
                viewCountText = "no clicks"
            } else {
                viewCountText = "\(component.link.viewCount) clicks"
            }
            let viewCountSize = self.viewCount.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: viewCountText, font: Font.regular(14.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let viewCountFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - viewCountSize.width, y: topInset + 2.0), size: viewCountSize)
            if let viewCountView = self.viewCount.view {
                if viewCountView.superview == nil {
                    viewCountView.isUserInteractionEnabled = false
                    viewCountView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.containerButton.addSubview(viewCountView)
                }
                transition.setPosition(view: viewCountView, position: CGPoint(x: viewCountFrame.maxX, y: viewCountFrame.minY))
                viewCountView.bounds = CGRect(origin: CGPoint(), size: viewCountFrame.size)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.link.title ?? component.link.url, font: Font.regular(16.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftContentInset - rightInset - viewCountSize.width - titleViewCountSpacing, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: leftContentInset, y: topInset), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    titleView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let asyncLayout = TextNodeWithEntities.asyncLayout(self.text)
            let textString = stringWithAppliedEntities(
                component.link.message.isEmpty ? "No text" : component.link.message,
                entities: component.link.entities,
                baseColor: component.theme.list.itemSecondaryTextColor,
                linkColor: component.theme.list.itemSecondaryTextColor,
                baseQuoteTintColor: nil,
                baseQuoteSecondaryTintColor: nil,
                baseQuoteTertiaryTintColor: nil,
                codeBlockTitleColor: nil,
                codeBlockAccentColor: nil,
                codeBlockBackgroundColor: nil,
                baseFont: Font.regular(15.0),
                linkFont: Font.regular(15.0),
                boldFont: Font.semibold(15.0),
                italicFont: Font.italic(15.0),
                boldItalicFont: Font.semiboldItalic(15.0),
                fixedFont: Font.monospace(15.0),
                blockQuoteFont: Font.regular(15.0),
                underlineLinks: false,
                external: false,
                message: nil,
                entityFiles: [:],
                adjustQuoteFontSize: false,
                cachedMessageSyntaxHighlight: nil
            )
            let (textLayout, textApply) = asyncLayout(TextNodeLayoutArguments(attributedString: textString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableSize.width - leftContentInset - rightInset, height: 100.0)))
            let _ = textApply(TextNodeWithEntities.Arguments(
                context: component.context,
                cache: component.context.animationCache,
                renderer: component.context.animationRenderer,
                placeholderColor: component.theme.list.mediaPlaceholderColor,
                attemptSynchronous: true
            ))
            let textSize = textLayout.size
            let textFrame = CGRect(origin: CGPoint(x: leftContentInset, y: titleFrame.maxY + titleTextSpacing), size: textLayout.size)
            if self.text.textNode.view.superview == nil {
                self.text.textNode.view.isUserInteractionEnabled = false
                self.containerButton.addSubview(self.text.textNode.view)
            }
            transition.setFrame(view: self.text.textNode.view, frame: textFrame)
            
            let size = CGSize(width: availableSize.width, height: topInset + titleSize.height + titleTextSpacing + textSize.height + bottomInset)
            
            self.iconView.image = PresentationResourcesItemList.sharedLinkIcon(component.theme)
            if let image = self.iconView.image {
                if self.iconView.superview == nil {
                    self.iconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(self.iconView)
                }
                let iconFrame = CGRect(origin: CGPoint(x: floor((leftContentInset - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size)
                transition.setFrame(view: self.iconView, frame: iconFrame)
            }
            
            let swipeOptionContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
            transition.setFrame(view: self.swipeOptionContainer, frame: swipeOptionContainerFrame)
            
            transition.setPosition(view: self.containerButton, position: CGPoint())
            transition.setBounds(view: self.containerButton, bounds: CGRect(origin: self.containerButton.bounds.origin, size: size))
            
            self.swipeOptionContainer.updateLayout(size: swipeOptionContainerFrame.size, leftInset: 0.0, rightInset: 0.0)
            
            var rightOptions: [ListItemSwipeOptionContainer.Option] = []
            let color: UIColor = component.theme.list.itemDisclosureActions.destructive.fillColor
            let textColor: UIColor = component.theme.list.itemDisclosureActions.destructive.foregroundColor
            rightOptions = [
                ListItemSwipeOptionContainer.Option(
                    key: 0,
                    title: component.strings.Common_Delete,
                    icon: .none,
                    color: color,
                    textColor: textColor
                )
            ]
            self.swipeOptionContainer.setRevealOptions(([], rightOptions))
            
            self.separatorInset = leftContentInset
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
