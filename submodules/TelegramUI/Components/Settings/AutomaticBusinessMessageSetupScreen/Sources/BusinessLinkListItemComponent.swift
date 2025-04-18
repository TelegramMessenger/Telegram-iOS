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
    let shareAction: () -> Void
    let contextAction: ((ContextExtractedContentContainingView, ContextGesture) -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        link: TelegramBusinessChatLinks.Link,
        action: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        shareAction: @escaping () -> Void,
        contextAction: ((ContextExtractedContentContainingView, ContextGesture) -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.link = link
        self.action = action
        self.deleteAction = deleteAction
        self.shareAction = shareAction
        self.contextAction = contextAction
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

    final class View: ContextControllerSourceView, ListSectionComponent.ChildView {
        private let extractedContainerView: ContextExtractedContentContainingView
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
        
        private var isExtractedToContextMenu: Bool = false
        
        override init(frame: CGRect) {
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerButton = HighlightTrackingButton()
            self.containerButton.layer.anchorPoint = CGPoint()
            self.containerButton.isExclusiveTouch = true
            
            self.swipeOptionContainer = ListItemSwipeOptionContainer(frame: CGRect())
            
            super.init(frame: frame)
            
            self.addSubview(self.extractedContainerView)
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.extractedContainerView.contentView.addSubview(self.swipeOptionContainer)
            
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
                if option.key == AnyHashable(0 as Int) {
                    component.shareAction()
                } else {
                    component.deleteAction()
                }
            }
            
            self.swipeOptionContainer.addSubview(self.containerButton)
            
            self.extractedContainerView.isExtractedToContextPreviewUpdated = { [weak self] value in
                guard let self, let component = self.component else {
                    return
                }
                self.containerButton.clipsToBounds = value
                self.containerButton.backgroundColor = value ? component.theme.list.itemBlocksBackgroundColor : nil
                self.containerButton.layer.cornerRadius = value ? 10.0 : 0.0
            }
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, transition in
                guard let self else {
                    return
                }
                self.isExtractedToContextMenu = value
                
                let mappedTransition: ComponentTransition
                if value {
                    mappedTransition = ComponentTransition(transition)
                } else {
                    mappedTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                self.componentState?.updated(transition: mappedTransition)
            }
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    gesture.cancel()
                    return
                }
                component.contextAction?(self.extractedContainerView, gesture)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        func update(component: BusinessLinkListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            let _ = previousComponent
            
            self.component = component
            self.componentState = state
            
            let leftInset: CGFloat = 0.0
            let leftContentInset: CGFloat = 62.0
            var rightInset: CGFloat = 8.0
            let topInset: CGFloat = 9.0
            let bottomInset: CGFloat = 9.0
            let titleViewCountSpacing: CGFloat = 4.0
            let titleTextSpacing: CGFloat = 4.0
            
            var innerInsets = UIEdgeInsets()
            if self.isExtractedToContextMenu {
                rightInset += 2.0
                innerInsets.left += 2.0
                innerInsets.right += 2.0
            }
            
            let viewCountText: String
            if component.link.viewCount == 0 {
                viewCountText = component.strings.Business_Links_ItemNoClicks
            } else {
                viewCountText = component.strings.Business_Links_ItemClickCount(Int32(component.link.viewCount))
            }
            let viewCountSize = self.viewCount.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: viewCountText, font: Font.regular(14.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let viewCountFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - innerInsets.left - viewCountSize.width, y: topInset + 2.0), size: viewCountSize)
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
                containerSize: CGSize(width: availableSize.width - leftInset - leftContentInset - rightInset - viewCountSize.width - titleViewCountSpacing, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: leftInset + leftContentInset, y: topInset), size: titleSize)
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
            let filteredEntities = component.link.entities.filter { entity in
                switch entity.type {
                case .CustomEmoji:
                    return true
                default:
                    return false
                }
            }
            let textString = stringWithAppliedEntities(
                component.link.message.isEmpty ? component.strings.Business_Links_ItemNoText : component.link.message,
                entities: filteredEntities,
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
            let (textLayout, textApply) = asyncLayout(TextNodeLayoutArguments(attributedString: textString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableSize.width - leftContentInset - leftInset - rightInset, height: 100.0)))
            let _ = textApply(TextNodeWithEntities.Arguments(
                context: component.context,
                cache: component.context.animationCache,
                renderer: component.context.animationRenderer,
                placeholderColor: component.theme.list.mediaPlaceholderColor,
                attemptSynchronous: true
            ))
            let textSize = textLayout.size
            let textFrame = CGRect(origin: CGPoint(x: leftInset + leftContentInset, y: titleFrame.maxY + titleTextSpacing), size: textLayout.size)
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
                let iconFrame = CGRect(origin: CGPoint(x: leftInset + floor((leftContentInset - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size)
                transition.setFrame(view: self.iconView, frame: iconFrame)
            }
            
            let swipeOptionContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
            transition.setFrame(view: self.swipeOptionContainer, frame: swipeOptionContainerFrame)
            
            let containerButtonFrame = CGRect(origin: CGPoint(x: innerInsets.left, y: innerInsets.top), size: CGSize(width: size.width - innerInsets.left - innerInsets.right, height: size.height - innerInsets.top - innerInsets.bottom))
            
            transition.setPosition(view: self.containerButton, position: containerButtonFrame.origin)
            transition.setBounds(view: self.containerButton, bounds: CGRect(origin: self.containerButton.bounds.origin, size: containerButtonFrame.size))
            
            self.swipeOptionContainer.updateLayout(size: swipeOptionContainerFrame.size, leftInset: 0.0, rightInset: 0.0)
            
            let resultBounds = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: self.extractedContainerView, frame: resultBounds)
            transition.setFrame(view: self.extractedContainerView.contentView, frame: resultBounds)
            self.extractedContainerView.contentRect = resultBounds
            
            var rightOptions: [ListItemSwipeOptionContainer.Option] = []
            rightOptions = [
                ListItemSwipeOptionContainer.Option(
                    key: 0,
                    title: component.strings.Business_Links_ItemActionShare,
                    icon: .none,
                    color: component.theme.list.itemDisclosureActions.accent.fillColor,
                    textColor: component.theme.list.itemDisclosureActions.accent.foregroundColor
                ),
                ListItemSwipeOptionContainer.Option(
                    key: 1,
                    title: component.strings.Common_Delete,
                    icon: .none,
                    color: component.theme.list.itemDisclosureActions.destructive.fillColor,
                    textColor: component.theme.list.itemDisclosureActions.destructive.foregroundColor
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
