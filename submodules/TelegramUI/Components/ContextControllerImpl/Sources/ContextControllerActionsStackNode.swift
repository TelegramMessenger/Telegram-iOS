import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import AccountContext
import ReactionSelectionNode
import Markdown
import EntityKeyboard
import AnimationCache
import MultiAnimationRenderer
import AnimationUI
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import LottieComponent
import TextNodeWithEntities
import ContextUI

public protocol ContextControllerActionsListItemNode: ASDisplayNode {
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void)
    
    func canBeHighlighted() -> Bool
    func updateIsHighlighted(isHighlighted: Bool)
    func performAction()
    
    var needsPadding: Bool { get }
}

public final class ContextControllerActionsListActionItemNode: HighlightTrackingButtonNode, ContextControllerActionsListItemNode {
    private let context: AccountContext?
    private let getController: () -> ContextControllerProtocol?
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestUpdateAction: (AnyHashable, ContextMenuActionItem) -> Void
    private var item: ContextMenuActionItem
    
    private let titleLabelNode: ImmediateTextNodeWithEntities
    private let subtitleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private let additionalIconNode: ASImageNode
    private var badgeIconNode: ASImageNode?
    private var animationNode: AnimationNode?
    
    private var currentAnimatedIconContent: ContextMenuActionItem.IconAnimation?
    private var animatedIcon: ComponentView<Empty>?
    
    private var currentBadge: (badge: ContextMenuActionBadge, image: UIImage)?
    
    private var iconDisposable: Disposable?
    
    public let needsPadding: Bool = true
    
    public init(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void,
        item: ContextMenuActionItem
    ) {
        self.context = context
        self.getController = getController
        self.requestDismiss = requestDismiss
        self.requestUpdateAction = requestUpdateAction
        self.item = item
        
        self.titleLabelNode = ImmediateTextNodeWithEntities()
        self.titleLabelNode.isAccessibilityElement = false
        self.titleLabelNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.isAccessibilityElement = false
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.isUserInteractionEnabled = false
        
        self.additionalIconNode = ASImageNode()
        self.additionalIconNode.isAccessibilityElement = false
        self.additionalIconNode.isUserInteractionEnabled = false
                
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityLabel = item.text
        self.accessibilityTraits = [.button]
        
        self.addSubnode(self.titleLabelNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.additionalIconNode)
        
        self.isEnabled = self.canBeHighlighted()
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.startTimer()
            } else {
                strongSelf.invalidateTimer()
            }
        }
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.iconDisposable?.dispose()
    }
        
    private var timer: SwiftSignalKit.Timer?
    private func startTimer() {
        self.invalidateTimer()
        
        self.timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.invalidateTimer()
            self.longPressed()
        }, queue: Queue.mainQueue())
        self.timer?.start()
    }
    
    private func invalidateTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.view.isExclusiveTouch = true
    }
    
    @objc private func pressed() {
        self.invalidateTimer()
        
        self.item.action?(ContextMenuActionItem.Action(
            controller: self.getController(),
            dismissWithResult: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestDismiss(result)
            },
            updateAction: { [weak self] id, updatedAction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdateAction(id, updatedAction)
            }
        ))
    }
    
    private func longPressed() {
        self.touchesCancelled(nil, with: nil)
        
        self.item.longPressAction?(ContextMenuActionItem.Action(
            controller: self.getController(),
            dismissWithResult: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestDismiss(result)
            },
            updateAction: { [weak self] id, updatedAction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdateAction(id, updatedAction)
            }
        ))
    }
    
    public func canBeHighlighted() -> Bool {
        return self.item.action != nil
    }
    
    public func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    public func performAction() {
        self.pressed()
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.titleLabelNode.tapAttributeAction != nil {
            if let result = self.titleLabelNode.hitTest(self.view.convert(point, to: self.titleLabelNode.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    public func setItem(item: ContextMenuActionItem) {
        self.item = item
        self.accessibilityLabel = item.text
    }
    
    public func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 18.0
        let verticalInset: CGFloat = 11.0
        let titleSubtitleSpacing: CGFloat = 1.0
        let iconSideInset: CGFloat = 20.0
        let standardIconWidth: CGFloat = 32.0
        let iconSpacing: CGFloat = 8.0
        
        var forcedHeight: CGFloat?
        var titleVerticalOffset: CGFloat?
        let titleFont: UIFont
        let titleBoldFont: UIFont
        switch self.item.textFont {
        case let .custom(font, height, verticalOffset):
            titleFont = font
            titleBoldFont = font
            forcedHeight = height
            titleVerticalOffset = verticalOffset
        case .small:
            let smallTextFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
            titleFont = smallTextFont
            titleBoldFont = Font.semibold(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
        case .regular:
            titleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
            titleBoldFont = Font.semibold(presentationData.listsFontSize.baseDisplaySize)
        }
        
        let subtitleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
        let subtitleColor = presentationData.theme.contextMenu.secondaryColor
        
        if let context = self.context {
            self.titleLabelNode.arguments = TextNodeWithEntities.Arguments(
                context: context,
                cache: context.animationCache,
                renderer: context.animationRenderer,
                placeholderColor: presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.1),
                attemptSynchronous: true
            )
        }
        self.titleLabelNode.visibility = self.item.enableEntityAnimations
        
        var subtitle: NSAttributedString?
        switch self.item.textLayout {
        case .singleLine:
            self.titleLabelNode.maximumNumberOfLines = 1
        case .twoLinesMax:
            self.titleLabelNode.maximumNumberOfLines = 2
        case let .secondLineWithValue(subtitleValue):
            self.titleLabelNode.maximumNumberOfLines = 1
            subtitle = NSAttributedString(
                string: subtitleValue,
                font: subtitleFont,
                textColor: subtitleColor
            )
        case let .secondLineWithAttributedValue(subtitleValue):
            self.titleLabelNode.maximumNumberOfLines = 1
            let mutableString = subtitleValue.mutableCopy() as! NSMutableAttributedString
            mutableString.addAttribute(.foregroundColor, value: subtitleColor, range: NSRange(location: 0, length: mutableString.length))
            mutableString.addAttribute(.font, value: subtitleFont, range: NSRange(location: 0, length: mutableString.length))
            subtitle = mutableString
        case .multiline:
            self.titleLabelNode.maximumNumberOfLines = 0
            self.titleLabelNode.lineSpacing = 0.1
        }
        
        let titleColor: UIColor
        let linkColor = presentationData.theme.list.itemAccentColor
        switch self.item.textColor {
        case .primary:
            titleColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            titleColor = presentationData.theme.contextMenu.destructiveColor
        case .disabled:
            titleColor = presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4)
        }
        
        if self.item.parseMarkdown || !self.item.entities.isEmpty {
            let attributedText: NSAttributedString
            if !self.item.entities.isEmpty {
                let inputStateText = ChatTextInputStateText(text: self.item.text, attributes: self.item.entities.compactMap { entity -> ChatTextInputStateTextAttribute? in
                    if case let .CustomEmoji(_, fileId) = entity.type {
                        return ChatTextInputStateTextAttribute(type: .customEmoji(stickerPack: nil, fileId: fileId, enableAnimation: true), range: entity.range)
                    } else if case .Bold = entity.type {
                        return ChatTextInputStateTextAttribute(type: .bold, range: entity.range)
                    } else if case .Italic = entity.type {
                        return ChatTextInputStateTextAttribute(type: .italic, range: entity.range)
                    } else if case .Url = entity.type {
                        return ChatTextInputStateTextAttribute(type: .textUrl(""), range: entity.range)
                    }
                    return nil
                })
                let result = NSMutableAttributedString(attributedString: inputStateText.attributedText(files: self.item.entityFiles))
                result.addAttributes([
                    .font: titleFont,
                    .foregroundColor: titleColor
                ], range: NSRange(location: 0, length: result.length))
                for attribute in inputStateText.attributes {
                    if case .bold = attribute.type {
                        result.addAttribute(NSAttributedString.Key.font, value: titleBoldFont, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
                    } else if case .italic = attribute.type {
                        result.addAttribute(NSAttributedString.Key.font, value: Font.semibold(15.0), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
                    } else if case .textUrl = attribute.type {
                        result.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
                        result.addAttribute(NSAttributedString.Key.font, value: titleBoldFont, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
                    }
                }
                attributedText = result
            } else {
                attributedText = parseMarkdownIntoAttributedString(
                    self.item.text,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: titleFont, textColor: titleColor),
                        bold: MarkdownAttributeSet(font: titleBoldFont, textColor: titleColor),
                        link: MarkdownAttributeSet(font: titleBoldFont, textColor: presentationData.theme.list.itemAccentColor),
                        linkAttribute: { value in return ("URL", value) }
                    )
                )
            }
            self.titleLabelNode.attributedText = attributedText
            self.titleLabelNode.linkHighlightColor = presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.5)
            self.titleLabelNode.highlightAttributeAction = { attributes in
                if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                    return NSAttributedString.Key(rawValue: "URL")
                } else {
                    return nil
                }
            }
            self.titleLabelNode.tapAttributeAction = { [weak item] attributes, _ in
                if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                    item?.textLinkAction()
                }
            }
        } else {
            self.titleLabelNode.attributedText = NSAttributedString(
                string: self.item.text,
                font: titleFont,
                textColor: titleColor)
        }
        
        self.titleLabelNode.isUserInteractionEnabled = self.titleLabelNode.tapAttributeAction != nil && self.item.action == nil
        
        self.subtitleNode.attributedText = subtitle
        
        var iconSize: CGSize?
        if let iconSource = self.item.iconSource {
            iconSize = iconSource.size
            self.iconNode.cornerRadius = iconSource.cornerRadius
            self.iconNode.contentMode = iconSource.contentMode
            self.iconNode.clipsToBounds = true
            if self.iconDisposable == nil {
                self.iconDisposable = (iconSource.signal |> deliverOnMainQueue).start(next: { [weak self] image in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.iconNode.image = image
                }).strict()
            }
        } else if let image = self.iconNode.image {
            iconSize = image.size
        } else if let animationName = self.item.animationName {
            if self.animationNode == nil {
                let animationNode = AnimationNode(animation: animationName, colors: ["__allcolors__": titleColor], scale: 1.0)
                animationNode.loop(count: 3)
                self.addSubnode(animationNode)
                self.animationNode = animationNode
            }
            iconSize = CGSize(width: 24.0, height: 24.0)
        } else {
            let iconImage = self.item.icon(presentationData.theme)
            self.iconNode.image = iconImage
            iconSize = iconImage?.size
        }
        
        if let iconAnimation = self.item.iconAnimation {
            let animatedIcon: ComponentView<Empty>
            if let current = self.animatedIcon {
                animatedIcon = current
            } else {
                animatedIcon = ComponentView()
                self.animatedIcon = animatedIcon
            }
            
            let animatedIconSize = CGSize(width: 24.0, height: 24.0)
            let _ = animatedIcon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: iconAnimation.name),
                    color: titleColor,
                    startingPosition: iconAnimation.loop ? .begin : .end,
                    loop: iconAnimation.loop
                )),
                environment: {},
                containerSize: animatedIconSize
            )
            
            iconSize = animatedIconSize
        } else if let animatedIcon = self.animatedIcon {
            self.animatedIcon = nil
            animatedIcon.view?.removeFromSuperview()
        }
        
        let additionalIcon = self.item.additionalLeftIcon?(presentationData.theme)
        var additionalIconSize: CGSize?
        self.additionalIconNode.image = additionalIcon
        
        if let additionalIcon {
            additionalIconSize = additionalIcon.size
        }
        
        let badgeSize: CGSize?
        if let badge = self.item.badge {
            var badgeImage: UIImage?
            if let currentBadge = self.currentBadge, currentBadge.badge == badge {
                badgeImage = currentBadge.image
            } else {
                switch badge.style {
                case .badge:
                    let badgeTextColor: UIColor = presentationData.theme.list.itemCheckColors.foregroundColor
                    let badgeString = NSAttributedString(string: badge.value, font: Font.regular(13.0), textColor: badgeTextColor)
                    let badgeTextBounds = badgeString.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                    
                    let badgeSideInset: CGFloat = 5.0
                    let badgeVerticalInset: CGFloat = 1.0
                    var badgeBackgroundSize = CGSize(width: badgeSideInset * 2.0 + ceil(badgeTextBounds.width), height: badgeVerticalInset * 2.0 + ceil(badgeTextBounds.height))
                    badgeBackgroundSize.width = max(badgeBackgroundSize.width, badgeBackgroundSize.height)
                    badgeImage = generateImage(badgeBackgroundSize, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: size.height * 0.5).cgPath)
                        context.fillPath()
                        
                        UIGraphicsPushContext(context)
                        
                        badgeString.draw(at: CGPoint(x: badgeTextBounds.minX + floor((badgeBackgroundSize.width - badgeTextBounds.width) * 0.5), y: badgeTextBounds.minY + badgeVerticalInset))
                        
                        UIGraphicsPopContext()
                    })
                case .label:
                    let badgeTextColor: UIColor = presentationData.theme.list.itemCheckColors.foregroundColor
                    let badgeString = NSAttributedString(string: badge.value, font: Font.semibold(11.0), textColor: badgeTextColor)
                    let badgeTextBounds = badgeString.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                    
                    let badgeSideInset: CGFloat = 3.0
                    let badgeVerticalInset: CGFloat = 1.0
                    let badgeBackgroundSize = CGSize(width: badgeSideInset * 2.0 + ceil(badgeTextBounds.width), height: badgeVerticalInset * 2.0 + ceil(badgeTextBounds.height))
                    badgeImage = generateImage(badgeBackgroundSize, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 5.0).cgPath)
                        context.fillPath()
                        
                        UIGraphicsPushContext(context)
                        
                        badgeString.draw(at: CGPoint(x: badgeTextBounds.minX + badgeSideInset + UIScreenPixel, y: badgeTextBounds.minY + badgeVerticalInset + UIScreenPixel))
                        
                        UIGraphicsPopContext()
                    })
                }
            }
            
            let badgeIconNode: ASImageNode
            if let current = self.badgeIconNode {
                badgeIconNode = current
            } else {
                badgeIconNode = ASImageNode()
                self.badgeIconNode = badgeIconNode
                self.addSubnode(badgeIconNode)
            }
            badgeIconNode.image = badgeImage
            
            badgeSize = badgeImage?.size
        } else {
            if let badgeIconNode = self.badgeIconNode {
                self.badgeIconNode = nil
                badgeIconNode.removeFromSupernode()
            }
            badgeSize = nil
        }
        
        var maxTextWidth: CGFloat = constrainedSize.width
        maxTextWidth -= sideInset
        
        if let iconSize = iconSize {
            maxTextWidth -= max(standardIconWidth, iconSize.width)
            maxTextWidth -= iconSpacing
        } else {
            maxTextWidth -= sideInset
        }
        
        if let additionalIconSize {
            maxTextWidth -= additionalIconSize.width
        }
        
        if let badgeSize = badgeSize {
            maxTextWidth -= badgeSize.width
            maxTextWidth -= 8.0
        }
        
        maxTextWidth = max(1.0, maxTextWidth)
        
        let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 1000.0))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: maxTextWidth, height: 1000.0))
        
        var minSize = CGSize()
        minSize.width += sideInset
        minSize.width += max(titleSize.width, subtitleSize.width)
        if let iconSize = iconSize {
            minSize.width += max(standardIconWidth, iconSize.width)
            minSize.width += iconSideInset
            minSize.width += iconSpacing
        } else {
            minSize.width += sideInset
        }
        if let additionalIconSize {
            minSize.width += additionalIconSize.width
            minSize.width += iconSideInset
            minSize.width += iconSpacing
        }
        if let forcedHeight {
            minSize.height = forcedHeight
        } else {
            minSize.height += verticalInset * 2.0
            minSize.height += titleSize.height
            if subtitle != nil {
                minSize.height += titleSubtitleSpacing
                minSize.height += subtitleSize.height
            }
        }
        
        return (minSize: minSize, apply: { size, transition in
            var titleFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: titleSize)
            if let customTextInsets = self.item.customTextInsets {
                titleFrame.origin.x = customTextInsets.left
            }
            if let titleVerticalOffset {
                titleFrame = titleFrame.offsetBy(dx: 0.0, dy: titleVerticalOffset)
            }
            var subtitleFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
            if iconSize != nil {
                titleFrame.origin.x = iconSideInset + 40.0
                subtitleFrame.origin.x = titleFrame.minX
            }
            
            transition.updateFrameAdditive(node: self.titleLabelNode, frame: titleFrame)
            transition.updateFrameAdditive(node: self.subtitleNode, frame: subtitleFrame)
            
            if let badgeIconNode = self.badgeIconNode, let iconSize = badgeIconNode.image?.size {
                transition.updateFrame(node: badgeIconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 8.0, y: titleFrame.minY + floor((titleFrame.height - iconSize.height) * 0.5)), size: iconSize))
            }
            
            if let iconSize {
                let iconFrame = CGRect(
                    origin: CGPoint(
                        x: iconSideInset + floor((standardIconWidth - iconSize.width) * 0.5),
                        y: floor((size.height - iconSize.height) / 2.0)
                    ),
                    size: iconSize
                )
                transition.updateFrame(node: self.iconNode, frame: iconFrame, beginWithCurrentState: true)
                if let animationNode = self.animationNode {
                    transition.updateFrame(node: animationNode, frame: iconFrame, beginWithCurrentState: true)
                }
                if let animatedIconView = self.animatedIcon?.view {
                    if animatedIconView.superview == nil {
                        self.view.addSubview(animatedIconView)
                        animatedIconView.frame = iconFrame
                    } else {
                        transition.updateFrame(view: animatedIconView, frame: iconFrame, beginWithCurrentState: true)
                        if let currentAnimatedIconContent = self.currentAnimatedIconContent, currentAnimatedIconContent != self.item.iconAnimation {
                            if let animatedIconView = animatedIconView as? LottieComponent.View {
                                animatedIconView.playOnce()
                            }
                        }
                    }
                    
                    self.currentAnimatedIconContent = self.item.iconAnimation
                }
            }
            
            if let additionalIconSize {
                let iconFrame = CGRect(
                    origin: CGPoint(
                        x: size.width - iconSideInset - additionalIconSize.width,
                        y: floor((size.height - additionalIconSize.height) / 2.0)
                    ),
                    size: additionalIconSize
                )
                transition.updateFrame(node: self.additionalIconNode, frame: iconFrame, beginWithCurrentState: true)
            }
        })
    }
}

private final class ContextControllerActionsListSeparatorItemNode: ASDisplayNode, ContextControllerActionsListItemNode {
    private let separatorView: UIImageView
    
    let needsPadding: Bool = false
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
    
    override init() {
        self.separatorView = UIImageView()
        self.separatorView.image = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - 1.0) * 0.5)), size: CGSize(width: size.width, height: 1.0)))
        })?.withRenderingMode(.alwaysTemplate)
        
        super.init()
        
        self.view.addSubview(self.separatorView)
    }
    
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        return (minSize: CGSize(width: 0.0, height: 20.0), apply: { size, transition in
            let sideInset: CGFloat = 18.0
            self.separatorView.tintColor = presentationData.theme.contextMenu.itemSeparatorColor
            transition.updateFrame(view: self.separatorView, frame: CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((size.height - 1.0) * 0.5)), size: CGSize(width: max(0.0, size.width - sideInset * 2.0), height: 1.0)))
        })
    }
}

private final class ContextControllerActionsListCustomItemNode: ASDisplayNode, ContextControllerActionsListItemNode {
    func canBeHighlighted() -> Bool {
        if let itemNode = self.itemNode {
            return itemNode.canBeHighlighted()
        } else {
            return false
        }
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        if let itemNode = self.itemNode {
            itemNode.updateIsHighlighted(isHighlighted: isHighlighted)
        }
    }
    
    func performAction() {
        if let itemNode = self.itemNode {
            itemNode.performAction()
        }
    }
    
    var needsPadding: Bool {
        if let itemNode = self.itemNode {
            return itemNode.needsPadding
        } else {
            return true
        }
    }
    
    private let getController: () -> ContextControllerProtocol?
    private let item: ContextMenuCustomItem
    private let requestDismiss: (ContextMenuActionResult) -> Void
    
    private var presentationData: PresentationData?
    private(set) var itemNode: ContextMenuCustomNode?
    
    init(
        getController: @escaping () -> ContextControllerProtocol?,
        item: ContextMenuCustomItem,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void
    ) {
        self.getController = getController
        self.item = item
        self.requestDismiss = requestDismiss
        
        super.init()
    }
    
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        if self.presentationData?.theme !== presentationData.theme {
            if let itemNode = self.itemNode {
                itemNode.updateTheme(presentationData: presentationData)
            }
        }
        self.presentationData = presentationData
        
        let itemNode: ContextMenuCustomNode
        if let current = self.itemNode {
            itemNode = current
        } else {
            itemNode = self.item.node(
                presentationData: presentationData,
                getController: self.getController,
                actionSelected: { result in
                    switch result {
                    case .default, .dismissWithoutContent:
                        self.requestDismiss(result)
                    default:
                        break
                    }
                }
            )
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
        
        let itemLayoutAndApply = itemNode.updateLayout(constrainedWidth: constrainedSize.width, constrainedHeight: constrainedSize.height)
        
        return (minSize: itemLayoutAndApply.0, apply: { size, transition in
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            itemLayoutAndApply.1(size, transition)
        })
    }
}

public final class ContextControllerActionsListStackItem: ContextControllerActionsStackItem {
    final class Node: ASDisplayNode, ContextControllerActionsStackItemNode {
        private final class Params {
            let presentationData: PresentationData
            let constrainedSize: CGSize
            let standardMinWidth: CGFloat
            let standardMaxWidth: CGFloat
            let additionalBottomInset: CGFloat
            
            init(presentationData: PresentationData, constrainedSize: CGSize, standardMinWidth: CGFloat, standardMaxWidth: CGFloat, additionalBottomInset: CGFloat) {
                self.presentationData = presentationData
                self.constrainedSize = constrainedSize
                self.standardMinWidth = standardMinWidth
                self.standardMaxWidth = standardMaxWidth
                self.additionalBottomInset = additionalBottomInset
            }
        }
        
        private final class Item {
            let node: ContextControllerActionsListItemNode
            
            init(node: ContextControllerActionsListItemNode) {
                self.node = node
            }
        }
        
        private let context: AccountContext?
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let getController: () -> ContextControllerProtocol?
        private let requestDismiss: (ContextMenuActionResult) -> Void
        private var items: [ContextMenuItem]
        private var itemNodes: [Item]
        
        private var tip: ContextController.Tip?
        private var tipDisposable: Disposable?
        private var tipNode: InnerTextSelectionTipContainerNode?
        private var tipSeparatorNode: ContextControllerActionsListSeparatorItemNode?
        
        private var hapticFeedback: HapticFeedback?
        
        private let highlightedItemBackgroundView: UIView
        private var highlightedItemNode: Item?
        
        private var params: Params?
        private var invalidatedItemNodes: Bool = false
        
        var wantsFullWidth: Bool {
            return false
        }
        
        init(
            context: AccountContext?,
            getController: @escaping () -> ContextControllerProtocol?,
            requestDismiss: @escaping (ContextMenuActionResult) -> Void,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            items: [ContextMenuItem],
            tip: ContextController.Tip?,
            tipSignal: Signal<ContextController.Tip?, NoError>?
        ) {
            self.context = context
            self.requestUpdate = requestUpdate
            self.getController = getController
            self.requestDismiss = requestDismiss
            self.items = items
            self.tip = tip
            
            var requestUpdateAction: ((AnyHashable, ContextMenuActionItem) -> Void)?
            self.itemNodes = items.map { item -> Item in
                switch item {
                case let .action(actionItem):
                    return Item(
                        node: ContextControllerActionsListActionItemNode(
                            context: context,
                            getController: getController,
                            requestDismiss: requestDismiss,
                            requestUpdateAction: { id, action in
                                requestUpdateAction?(id, action)
                            },
                            item: actionItem
                        )
                    )
                case .separator:
                    return Item(
                        node: ContextControllerActionsListSeparatorItemNode()
                    )
                case let .custom(customItem, _):
                    return Item(
                        node: ContextControllerActionsListCustomItemNode(
                            getController: getController,
                            item: customItem,
                            requestDismiss: requestDismiss
                        )
                    )
                }
            }
            
            self.highlightedItemBackgroundView = UIView()
            self.highlightedItemBackgroundView.alpha = 0.0
            
            super.init()
            
            self.view.addSubview(self.highlightedItemBackgroundView)
            
            for item in self.itemNodes {
                self.addSubnode(item.node)
            }
            
            requestUpdateAction = { [weak self] id, action in
                guard let self else {
                    return
                }
                self.requestUpdateAction(id: id, action: action)
            }
        }
        
        deinit {
            self.tipDisposable?.dispose()
        }
        
        func updateItems(items: [ContextMenuItem]) {
            self.items = items
            for i in 0 ..< items.count {
                if self.itemNodes.count < i {
                    break
                }
                if case let .action(action) = items[i] {
                    if let itemNode = self.itemNodes[i].node as? ContextControllerActionsListActionItemNode {
                        itemNode.setItem(item: action)
                    }
                }
            }
        }
        
        private func requestUpdateAction(id: AnyHashable, action: ContextMenuActionItem) {
            loop: for i in 0 ..< self.items.count {
                switch self.items[i] {
                case let .action(currentAction):
                    if currentAction.id == id {
                        let previousNode = self.itemNodes[i]
                        previousNode.node.removeFromSupernode()
                        
                        let addedNode = Item(
                            node: ContextControllerActionsListActionItemNode(
                                context: self.context,
                                getController: self.getController,
                                requestDismiss: self.requestDismiss,
                                requestUpdateAction: { [weak self] id, action in
                                    guard let self else {
                                        return
                                    }
                                    self.requestUpdateAction(id: id, action: action)
                                },
                                item: action
                            )
                        )
                        self.itemNodes[i] = addedNode
                        self.addSubnode(addedNode.node)
                        
                        self.requestUpdate(.immediate)
                        
                        break loop
                    }
                default:
                    break
                }
            }
        }
        
        private func update(transition: ContainedViewLayoutTransition) {
            if let params = self.params {
                let _ = self.update(
                    presentationData: params.presentationData,
                    constrainedSize: params.constrainedSize,
                    standardMinWidth: params.standardMinWidth,
                    standardMaxWidth: params.standardMaxWidth,
                    additionalBottomInset: params.additionalBottomInset,
                    transition: transition
                )
            }
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            additionalBottomInset: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            self.params = Params(
                presentationData: presentationData,
                constrainedSize: constrainedSize,
                standardMinWidth: standardMinWidth,
                standardMaxWidth: standardMaxWidth,
                additionalBottomInset: additionalBottomInset
            )
            
            var highlightedItemFrame: CGRect?
            
            let verticalInset: CGFloat = 10.0
            
            var itemNodeLayouts: [(minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void)] = []
            var combinedSize = CGSize(width: 0.0, height: 0.0)
            for i in 0 ..< self.itemNodes.count {
                let item = self.itemNodes[i]
                
                let itemNodeLayout = item.node.update(
                    presentationData: presentationData,
                    constrainedSize: CGSize(width: standardMaxWidth, height: constrainedSize.height)
                )
                
                if item.node.needsPadding {
                    if i == 0 {
                        combinedSize.height += verticalInset
                    }
                }
                
                itemNodeLayouts.append(itemNodeLayout)
                combinedSize.width = max(combinedSize.width, itemNodeLayout.minSize.width)
                combinedSize.height += itemNodeLayout.minSize.height
                
                if item.node.needsPadding {
                    if i == self.itemNodes.count - 1 {
                        combinedSize.height += verticalInset
                    }
                }
            }
            self.invalidatedItemNodes = false
            combinedSize.width = max(combinedSize.width, standardMinWidth)
            
            var nextItemOrigin = CGPoint(x: 0.0, y: 0.0)
            for i in 0 ..< self.itemNodes.count {
                let item = self.itemNodes[i]
                let itemNodeLayout = itemNodeLayouts[i]
                
                var itemTransition = transition
                if item.node.frame.isEmpty {
                    itemTransition = .immediate
                }
                
                if item.node.needsPadding {
                    if i == 0 {
                        nextItemOrigin.y += verticalInset
                    }
                }
                
                let itemSize = CGSize(width: combinedSize.width, height: itemNodeLayout.minSize.height)
                let itemFrame = CGRect(origin: nextItemOrigin, size: itemSize)
                itemTransition.updateFrame(node: item.node, frame: itemFrame, beginWithCurrentState: true)
                
                itemNodeLayout.apply(itemSize, itemTransition)
                nextItemOrigin.y += itemSize.height
                
                if self.highlightedItemNode === item {
                    highlightedItemFrame = itemFrame
                }
            }
            
            if let tip = self.tip {
                let tipNode: InnerTextSelectionTipContainerNode
                var tipTransition = transition
                if let current = self.tipNode {
                    tipNode = current
                } else {
                    tipTransition = .immediate
                    tipNode = InnerTextSelectionTipContainerNode(presentationData: presentationData, tip: tip, isInline: true)
                    self.addSubnode(tipNode)
                    self.tipNode = tipNode
                    let getController = self.getController
                    tipNode.requestDismiss = { completion in
                        getController()?.dismiss(completion: completion)
                    }
                }
                
                let tipSeparatorNode: ContextControllerActionsListSeparatorItemNode
                if let current = self.tipSeparatorNode {
                    tipSeparatorNode = current
                } else {
                    tipSeparatorNode = ContextControllerActionsListSeparatorItemNode()
                    self.addSubnode(tipSeparatorNode)
                    self.tipSeparatorNode = tipSeparatorNode
                }
                
                let (tipSeparatorMinSize, tipSeparatorApply) = tipSeparatorNode.update(presentationData: presentationData, constrainedSize: CGSize(width: combinedSize.width, height: 10.0))
                let tipSeparatorSize = CGSize(width: combinedSize.width, height: tipSeparatorMinSize.height)
                tipSeparatorApply(tipSeparatorSize, tipTransition)
                let tipSeparatorFrame = CGRect(origin: nextItemOrigin, size: tipSeparatorSize)
                tipTransition.updateFrame(node: tipSeparatorNode, frame: tipSeparatorFrame)
                nextItemOrigin.y += tipSeparatorSize.height
                combinedSize.height += tipSeparatorSize.height
                
                let tipSize = tipNode.updateLayout(widthClass: .compact, presentation: .inline, width: combinedSize.width, transition: tipTransition)
                let tipFrame = CGRect(origin: nextItemOrigin, size: tipSize)
                tipNode.setActualSize(size: tipFrame.size, transition: tipTransition)
                tipTransition.updateFrame(node: tipNode, frame: tipFrame)
                nextItemOrigin.y += tipSize.height
                combinedSize.height += tipSize.height
            } else {
                if let tipSeparatorNode = self.tipSeparatorNode {
                    tipSeparatorNode.removeFromSupernode()
                    self.tipSeparatorNode = nil
                }
                if let tipNode = self.tipNode {
                    tipNode.removeFromSupernode()
                    self.tipNode = nil
                }
            }
            
            if let highlightedItemFrame {
                self.highlightedItemBackgroundView.backgroundColor = presentationData.theme.overallDarkAppearance ? UIColor.white : UIColor.black
                self.highlightedItemBackgroundView.setMonochromaticEffect(tintColor: self.highlightedItemBackgroundView.backgroundColor)
                
                var highlightTransition = ComponentTransition(transition)
                var animateIn = false
                if self.highlightedItemBackgroundView.alpha == 0.0 {
                    if self.highlightedItemBackgroundView.layer.animation(forKey: "opacity") == nil {
                        highlightTransition = .immediate
                    }
                    animateIn = true
                }
                let highlightFrame = CGRect(origin: CGPoint(x: 10.0, y: highlightedItemFrame.minY), size: CGSize(width: combinedSize.width - 10.0 * 2.0, height: highlightedItemFrame.height))
                highlightTransition.setFrame(view: self.highlightedItemBackgroundView, frame: highlightFrame)
                highlightTransition.setCornerRadius(layer: self.highlightedItemBackgroundView.layer, cornerRadius: min(20.0, highlightFrame.height * 0.5))
                if animateIn {
                    var alphaTransition = transition
                    if transition.isAnimated {
                        alphaTransition = .animated(duration: 0.2, curve: .easeInOut)
                    }
                    ComponentTransition(alphaTransition).setAlpha(view: self.highlightedItemBackgroundView, alpha: 0.1)
                }
            } else if self.highlightedItemBackgroundView.alpha != 0.0 {
                ComponentTransition(transition).setAlpha(view: self.highlightedItemBackgroundView, alpha: 0.0)
            }
            
            return (combinedSize, combinedSize.height)
        }
        
        func highlightGestureShouldBegin(location: CGPoint) -> Bool {
            for itemNode in self.itemNodes {
                if itemNode.node.frame.contains(location) {
                    if !itemNode.node.canBeHighlighted() {
                        return false
                    }
                    break
                }
            }
            if let tipNode = self.tipNode {
                if tipNode.frame.contains(location) {
                    return false
                }
            }
            return true
        }
        
        func highlightGestureMoved(location: CGPoint) {
            var highlightedItemNode: Item?
            for itemNode in self.itemNodes {
                if itemNode.node.frame.contains(location) {
                    if itemNode.node.canBeHighlighted() {
                        highlightedItemNode = itemNode
                    }
                    break
                }
            }
            if self.highlightedItemNode !== highlightedItemNode {
                self.highlightedItemNode?.node.updateIsHighlighted(isHighlighted: false)
                highlightedItemNode?.node.updateIsHighlighted(isHighlighted: true)
                
                self.highlightedItemNode = highlightedItemNode
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                self.hapticFeedback?.tap()
                
                self.update(transition: .animated(duration: 0.16, curve: .easeInOut))
            }
        }
        
        func highlightGestureFinished(performAction: Bool) {
            if let highlightedItemNode = self.highlightedItemNode {
                self.highlightedItemNode = nil
                highlightedItemNode.node.updateIsHighlighted(isHighlighted: false)
                if performAction {
                    highlightedItemNode.node.performAction()
                }
                
                self.update(transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
        
        func decreaseHighlightedIndex() {
            let previousHighlightedItemNode: Item? = self.highlightedItemNode
            if let highlightedItemNode = self.highlightedItemNode, let index = self.itemNodes.firstIndex(where: { $0 === highlightedItemNode }) {
                self.highlightedItemNode = self.itemNodes[max(0, index - 1)]
            } else {
                self.highlightedItemNode = self.itemNodes.first
            }
            
            if previousHighlightedItemNode !== self.highlightedItemNode {
                previousHighlightedItemNode?.node.updateIsHighlighted(isHighlighted: false)
                self.highlightedItemNode?.node.updateIsHighlighted(isHighlighted: true)
            }
        }
        
        func increaseHighlightedIndex() {
            let previousHighlightedItemNode: Item? = self.highlightedItemNode
            if let highlightedItemNode = self.highlightedItemNode, let index = self.itemNodes.firstIndex(where: { $0 === highlightedItemNode }) {
                self.highlightedItemNode = self.itemNodes[min(self.itemNodes.count - 1, index + 1)]
            } else {
                self.highlightedItemNode = self.itemNodes.first
            }
            
            if previousHighlightedItemNode !== self.highlightedItemNode {
                previousHighlightedItemNode?.node.updateIsHighlighted(isHighlighted: false)
                self.highlightedItemNode?.node.updateIsHighlighted(isHighlighted: true)
            }
        }
    }
    
    public let id: AnyHashable?
    public let items: [ContextMenuItem]
    public let reactionItems: ContextControllerReactionItems?
    public let previewReaction: ContextControllerPreviewReaction?
    public let tip: ContextController.Tip?
    public let tipSignal: Signal<ContextController.Tip?, NoError>?
    public let dismissed: (() -> Void)?
    
    public init(
        id: AnyHashable?,
        items: [ContextMenuItem],
        reactionItems: ContextControllerReactionItems?,
        previewReaction: ContextControllerPreviewReaction?,
        tip: ContextController.Tip?,
        tipSignal: Signal<ContextController.Tip?, NoError>?,
        dismissed: (() -> Void)?
    ) {
        self.id = id
        self.items = items
        self.reactionItems = reactionItems
        self.previewReaction = previewReaction
        self.tip = tip
        self.tipSignal = tipSignal
        self.dismissed = dismissed
    }
    
    public func node(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode {
        return Node(
            context: context,
            getController: getController,
            requestDismiss: requestDismiss,
            requestUpdate: requestUpdate,
            items: self.items,
            tip: self.tip,
            tipSignal: self.tipSignal
        )
    }
}

final class ContextControllerActionsCustomStackItem: ContextControllerActionsStackItem {
    private final class Node: ASDisplayNode, ContextControllerActionsStackItemNode {
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let contentNode: ContextControllerItemsNode
        
        init(
            content: ContextControllerItemsContent,
            getController: @escaping () -> ContextControllerProtocol?,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
        ) {
            self.requestUpdate = requestUpdate
            self.contentNode = content.node(requestUpdate: { transition in
                requestUpdate(transition)
            }, requestUpdateApparentHeight: { transition in
                requestUpdateApparentHeight(transition)
            })
            
            super.init()
            
            self.addSubnode(self.contentNode)
        }
        
        var wantsFullWidth: Bool {
            return true
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            additionalBottomInset: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            let contentLayout = self.contentNode.update(
                presentationData: presentationData,
                constrainedWidth: constrainedSize.width,
                maxHeight: constrainedSize.height,
                bottomInset: additionalBottomInset,
                transition: transition
            )
            transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: contentLayout.cleanSize), beginWithCurrentState: true)
            
            return (contentLayout.cleanSize, contentLayout.apparentHeight)
        }
        
        func highlightGestureShouldBegin(location: CGPoint) -> Bool {
            return true
        }
        
        func highlightGestureMoved(location: CGPoint) {
        }
        
        func highlightGestureFinished(performAction: Bool) {
        }
        
        func decreaseHighlightedIndex() {
        }
        
        func increaseHighlightedIndex() {
        }
    }
    
    let id: AnyHashable?
    private let content: ContextControllerItemsContent
    let reactionItems: ContextControllerReactionItems?
    let previewReaction: ContextControllerPreviewReaction?
    let tip: ContextController.Tip?
    let tipSignal: Signal<ContextController.Tip?, NoError>?
    let dismissed: (() -> Void)?
    
    init(
        id: AnyHashable?,
        content: ContextControllerItemsContent,
        reactionItems: ContextControllerReactionItems?,
        previewReaction: ContextControllerPreviewReaction?,
        tip: ContextController.Tip?,
        tipSignal: Signal<ContextController.Tip?, NoError>?,
        dismissed: (() -> Void)?
    ) {
        self.id = id
        self.content = content
        self.reactionItems = reactionItems
        self.previewReaction = previewReaction
        self.tip = tip
        self.tipSignal = tipSignal
        self.dismissed = dismissed
    }
    
    func node(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode {
        return Node(
            content: self.content,
            getController: getController,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight
        )
    }
}

func makeContextControllerActionsStackItem(items: ContextController.Items) -> [ContextControllerActionsStackItem] {
    var reactionItems: ContextControllerReactionItems?
    if let context = items.context, let animationCache = items.animationCache, !items.reactionItems.isEmpty {
        reactionItems = ContextControllerReactionItems(
            context: context,
            reactionItems: items.reactionItems,
            selectedReactionItems: items.selectedReactionItems,
            reactionsTitle: items.reactionsTitle,
            reactionsLocked: items.reactionsLocked,
            animationCache: animationCache,
            alwaysAllowPremiumReactions: items.alwaysAllowPremiumReactions,
            allPresetReactionsAreAvailable: items.allPresetReactionsAreAvailable,
            getEmojiContent: items.getEmojiContent
        )
    }
    var previewReaction: ContextControllerPreviewReaction?
    if let context = items.context, let file = items.previewReaction {
        previewReaction = ContextControllerPreviewReaction(context: context, file: file)
    }
    switch items.content {
    case let .list(listItems):
        return [ContextControllerActionsListStackItem(id: items.id, items: listItems, reactionItems: reactionItems, previewReaction: previewReaction, tip: items.tip, tipSignal: items.tipSignal, dismissed: items.dismissed)]
    case let .twoLists(listItems1, listItems2):
        return [ContextControllerActionsListStackItem(id: items.id, items: listItems1, reactionItems: nil, previewReaction: nil, tip: nil, tipSignal: nil, dismissed: items.dismissed), ContextControllerActionsListStackItem(id: nil, items: listItems2, reactionItems: nil, previewReaction: nil, tip: nil, tipSignal: nil, dismissed: nil)]
    case let .custom(customContent):
        return [ContextControllerActionsCustomStackItem(id: items.id, content: customContent, reactionItems: reactionItems, previewReaction: previewReaction, tip: items.tip, tipSignal: items.tipSignal, dismissed: items.dismissed)]
    }
}

private final class ItemSelectionRecognizer: UIGestureRecognizer {
    var shouldBegin: ((CGPoint) -> Bool)?
    
    private var initialLocation: CGPoint?
    private var currentLocation: CGPoint?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }
    
    public override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let location = touches.first?.location(in: self.view), let shouldBegin = self.shouldBegin, !shouldBegin(location) {
            self.state = .failed
            return
        }
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
        self.currentLocation = self.initialLocation
        
        self.state = .began
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        self.currentLocation = touches.first?.location(in: self.view)
        
        self.state = .changed
    }
    
    public func translation(in: UIView?) -> CGPoint {
        if let initialLocation = self.initialLocation, let currentLocation = self.currentLocation {
            return CGPoint(x: currentLocation.x - initialLocation.x, y: currentLocation.y - initialLocation.y)
        }
        return CGPoint()
    }
}

public final class ContextControllerActionsStackNodeImpl: ASDisplayNode, ContextControllerActionsStackNode {
    final class NavigationContainer: ASDisplayNode, ASGestureRecognizerDelegate {
        let backgroundContainer: GlassBackgroundContainerView
        let backgroundContainerInset: CGFloat
        let backgroundView: GlassBackgroundView
        var sourceExtractableContainer: ContextExtractableContainer?
        let contentContainer: UIView
        
        var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
        var requestPop: (() -> Void)?
        var transitionFraction: CGFloat = 0.0
        
        private var panRecognizer: InteractiveTransitionGestureRecognizer?
        
        var isNavigationEnabled: Bool = false {
            didSet {
                self.panRecognizer?.isEnabled = self.isNavigationEnabled
            }
        }
        
        override init() {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            
            self.contentContainer = UIView()
            self.contentContainer.clipsToBounds = true
            self.backgroundView.contentView.addSubview(self.contentContainer)
            
            self.backgroundContainerInset = 32.0
            
            super.init()
            
            self.view.addSubview(self.backgroundContainer)
            
            let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let strongSelf = self else {
                    return []
                }
                let _ = strongSelf
                return [.right]
            })
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            self.view.addGestureRecognizer(panRecognizer)
            self.panRecognizer = panRecognizer
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
                return false
            }
            if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.transitionFraction = 0.0
            case .changed:
                let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
                let transitionFraction = max(0.0, min(1.0, distanceFactor))
                if self.transitionFraction != transitionFraction {
                    self.transitionFraction = transitionFraction
                    self.requestUpdate?(.immediate)
                }
            case .ended, .cancelled:
                let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
                let transitionFraction = max(0.0, min(1.0, distanceFactor))
                if transitionFraction > 0.2 {
                    self.transitionFraction = 0.0
                    self.requestPop?()
                } else {
                    self.transitionFraction = 0.0
                    self.requestUpdate?(.animated(duration: 0.45, curve: .spring))
                }
            default:
                break
            }
        }
        
        func animateIn(fromExtractableContainer extractableContainer: ContextExtractableContainer, transition: ComponentTransition) {
            let normalState = extractableContainer.normalState
            let sourceSize = normalState.size
            let normalCornerRadius: CGFloat = normalState.cornerRadius
            
            let currentSize = self.contentContainer.bounds.size
            
            self.sourceExtractableContainer = extractableContainer
            self.backgroundView.isHidden = true
            
            self.backgroundContainer.contentView.addSubview(extractableContainer.extractableContentView)
            for subview in extractableContainer.extractableContentView.subviews {
                if let subview = subview as? GlassBackgroundView {
                    //TODO:release
                    subview.contentView.addSubview(self.contentContainer)
                    break
                }
            }
            
            self.sourceExtractableContainer = nil
            self.contentContainer.frame = CGRect(origin: CGPoint(), size: sourceSize)
            self.contentContainer.layer.cornerRadius = normalCornerRadius
            
            extractableContainer.extractableContentView.frame = CGRect(origin: CGPoint(x: (currentSize.width - sourceSize.width) * 0.5, y: (currentSize.height - sourceSize.height) * 0.5), size: sourceSize).offsetBy(dx: self.backgroundContainerInset, dy: self.backgroundContainerInset)
            transition.setFrame(view: extractableContainer.extractableContentView, frame: CGRect(origin: CGPoint(x: self.backgroundContainerInset, y: self.backgroundContainerInset), size: currentSize))
            transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: currentSize))
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: 30.0)
            self.contentContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            
            extractableContainer.updateState(state: .extracted(size: sourceSize, cornerRadius: normalCornerRadius, state: .animatedOut), transition: .transition(.immediate), completion: nil)
            let mappedTransition: ContextExtractableContainer.Transition
            if case let .curve(duration, curve) = transition.animation, case let .bounce(stiffness, damping) = curve {
                mappedTransition = .spring(duration: duration, stiffness: stiffness, damping: damping)
            } else {
                mappedTransition = .transition(transition.containedViewLayoutTransition)
            }
            extractableContainer.updateState(state: .extracted(size: currentSize, cornerRadius: 30.0, state: .animatedIn), transition: mappedTransition, completion: nil)
        }
        
        func animateOut(toExtractableContainer extractableContainer: ContextExtractableContainer, transition: ComponentTransition) {
            let normalState = extractableContainer.normalState
            let normalSize = normalState.size
            let normalCornerRadius: CGFloat = normalState.cornerRadius
            
            let currentSize = self.contentContainer.bounds.size
            
            transition.setFrame(view: extractableContainer.extractableContentView, frame: CGRect(origin: CGPoint(x: self.backgroundContainerInset, y: self.backgroundContainerInset), size: normalSize).offsetBy(dx: (currentSize.width - normalSize.width) * 0.5, dy: (currentSize.height - normalSize.height) * 0.5))
            
            transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: normalSize))
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: normalCornerRadius)
            transition.setAlpha(view: self.contentContainer, alpha: 0.0)
            
            let mappedTransition: ContextExtractableContainer.Transition
            if case let .curve(duration, curve) = transition.animation, case let .bounce(stiffness, damping) = curve {
                mappedTransition = .spring(duration: duration, stiffness: stiffness, damping: damping)
            } else {
                mappedTransition = .transition(transition.containedViewLayoutTransition)
            }
            extractableContainer.updateState(state: .extracted(size: normalSize, cornerRadius: normalCornerRadius, state: .animatedOut), transition: mappedTransition, completion: nil)
        }
        
        func didAnimateOut(toExtractableContainer extractableContainer: ContextExtractableContainer) {
            extractableContainer.addSubview(extractableContainer.extractableContentView)
            extractableContainer.updateState(state: .normal, transition: .transition(.immediate), completion: nil)
        }
        
        func update(presentationData: PresentationData, presentation: Presentation, size: CGSize, transition: ContainedViewLayoutTransition) {
            let transition = ComponentTransition(transition)
            
            transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: size))
            
            let backgroundContainerFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -self.backgroundContainerInset, dy: -self.backgroundContainerInset)
            
            if self.backgroundContainer.bounds.size != backgroundContainerFrame.size {
                self.backgroundContainer.update(size: backgroundContainerFrame.size, isDark: presentationData.theme.overallDarkAppearance, transition: transition)
                transition.setFrame(view: self.backgroundContainer, frame: backgroundContainerFrame)
            }
            
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: min(30.0, size.height * 0.5))
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: self.backgroundContainerInset, y: self.backgroundContainerInset), size: size))
            self.backgroundView.update(size: size, cornerRadius: min(30.0, size.height * 0.5), isDark: presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            
            if let sourceExtractableContainer = self.sourceExtractableContainer {
                transition.setFrame(view: sourceExtractableContainer.extractableContentView, frame: CGRect(origin: CGPoint(), size: size))
                sourceExtractableContainer.updateState(state: .extracted(size: size, cornerRadius: min(30.0, size.height * 0.5), state: .animatedIn), transition: .transition(transition.containedViewLayoutTransition), completion: nil)
            }
        }
    }
    
    final class ItemContainer: ASDisplayNode {
        let getController: () -> ContextControllerProtocol?
        let requestUpdate: (ContainedViewLayoutTransition) -> Void
        let item: ContextControllerActionsStackItem
        let node: ContextControllerActionsStackItemNode
        let dimNode: ASDisplayNode
        var tip: ContextController.Tip?
        let tipSignal: Signal<ContextController.Tip?, NoError>?
        var tipNode: InnerTextSelectionTipContainerNode?
        let reactionItems: ContextControllerReactionItems?
        let previewReaction: ContextControllerPreviewReaction?
        let itemDismissed: (() -> Void)?
        var storedScrollingState: CGFloat?
        let positionLock: CGFloat?
        
        private var tipDisposable: Disposable?
        
        init(
            context: AccountContext?,
            getController: @escaping () -> ContextControllerProtocol?,
            requestDismiss: @escaping (ContextMenuActionResult) -> Void,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            item: ContextControllerActionsStackItem,
            tip: ContextController.Tip?,
            tipSignal: Signal<ContextController.Tip?, NoError>?,
            reactionItems: ContextControllerReactionItems?,
            previewReaction: ContextControllerPreviewReaction?,
            itemDismissed: (() -> Void)?,
            positionLock: CGFloat?
        ) {
            self.getController = getController
            self.requestUpdate = requestUpdate
            self.item = item
            self.node = item.node(
                context: context,
                getController: getController,
                requestDismiss: requestDismiss,
                requestUpdate: requestUpdate,
                requestUpdateApparentHeight: requestUpdateApparentHeight
            )
            
            self.dimNode = ASDisplayNode()
            self.dimNode.isUserInteractionEnabled = false
            self.dimNode.alpha = 0.0
            
            self.reactionItems = reactionItems
            self.previewReaction = previewReaction
            self.itemDismissed = itemDismissed
            self.positionLock = positionLock
            
            self.tip = tip
            self.tipSignal = tipSignal
            
            super.init()
            
            self.clipsToBounds = true
            
            self.addSubnode(self.node)
            self.addSubnode(self.dimNode)
            
            if let tipSignal = tipSignal {
                self.tipDisposable = (tipSignal
                |> deliverOnMainQueue).start(next: { [weak self] tip in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.tip = tip
                    requestUpdate(.immediate)
                }).strict()
            }
        }
        
        deinit {
            self.tipDisposable?.dispose()
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            additionalBottomInset: CGFloat,
            transitionFraction: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            let (size, apparentHeight) = self.node.update(
                presentationData: presentationData,
                constrainedSize: constrainedSize,
                standardMinWidth: standardMinWidth,
                standardMaxWidth: standardMaxWidth,
                additionalBottomInset: additionalBottomInset,
                transition: transition
            )
            
            let maxScaleOffset: CGFloat = 10.0
            let scaleOffset: CGFloat = 0.0 * transitionFraction + maxScaleOffset * (1.0 - transitionFraction)
            let scale: CGFloat = (size.width - scaleOffset) / size.width
            let yOffset: CGFloat = size.height * (1.0 - scale)
            let transitionOffset = (1.0 - transitionFraction) * size.width / 2.0
            transition.updatePosition(node: self.node, position: CGPoint(x: size.width / 2.0 + scaleOffset / 2.0 + transitionOffset, y: size.height / 2.0 - yOffset / 2.0), beginWithCurrentState: true)
            transition.updateBounds(node: self.node, bounds: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            transition.updateTransformScale(node: self.node, scale: scale, beginWithCurrentState: true)
            
            return (size, apparentHeight)
        }
        
        func updateTip(presentationData: PresentationData, presentation: ContextControllerActionsStackNode.Presentation, width: CGFloat, transition: ContainedViewLayoutTransition) -> (node: InnerTextSelectionTipContainerNode, height: CGFloat)? {
            if self.item is ContextControllerActionsListStackItem {
                return nil
            }
            
            if let tip = self.tip {
                var updatedTransition = transition
                if let tipNode = self.tipNode, tipNode.tip == tip {
                } else {
                    let previousTipNode = self.tipNode
                    updatedTransition = .immediate
                    let tipNode = InnerTextSelectionTipContainerNode(presentationData: presentationData, tip: tip, isInline: false)
                    tipNode.requestDismiss = { [weak self] completion in
                        self?.getController()?.dismiss(completion: completion)
                    }
                    self.tipNode = tipNode
                    
                    if let previousTipNode = previousTipNode {
                        previousTipNode.animateTransitionInside(other: tipNode)
                        previousTipNode.removeFromSupernode()
                        
                        tipNode.animateContentIn()
                    }
                }
                
                if let tipNode = self.tipNode {
                    let size = tipNode.updateLayout(widthClass: .compact, presentation: presentation, width: width, transition: updatedTransition)
                    return (tipNode, size.height)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        func updateDimNode(presentationData: PresentationData, size: CGSize, transitionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
            self.dimNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            transition.updateAlpha(node: self.dimNode, alpha: 1.0 - transitionFraction, beginWithCurrentState: true)
        }
        
        func highlightGestureShouldBegin(at location: CGPoint) -> Bool {
            return self.node.highlightGestureShouldBegin(location: self.view.convert(location, to: self.node.view))
        }
        
        func highlightGestureMoved(location: CGPoint) {
            if let tipNode = self.tipNode {
                let tipLocation = self.view.convert(location, to: tipNode.view)
                tipNode.highlightGestureMoved(location: tipLocation)
            }
            self.node.highlightGestureMoved(location: self.view.convert(location, to: self.node.view))
        }
        
        func highlightGestureFinished(performAction: Bool) {
            if let tipNode = self.tipNode {
                tipNode.highlightGestureFinished(performAction: performAction)
            }
            self.node.highlightGestureFinished(performAction: performAction)
        }
        
        func decreaseHighlightedIndex() {
            self.node.decreaseHighlightedIndex()
        }
        
        func increaseHighlightedIndex() {
            self.node.increaseHighlightedIndex()
        }
    }
    
    private let context: AccountContext?
    private let getController: () -> ContextControllerProtocol?
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestUpdate: (ContainedViewLayoutTransition) -> Void
    
    private let navigationContainer: NavigationContainer
    private var itemContainers: [ItemContainer] = []
    private var dismissingItemContainers: [(container: ItemContainer, isPopped: Bool)] = []
    
    private var selectionPanGesture: ItemSelectionRecognizer?
    
    public var topReactionItems: ContextControllerReactionItems? {
        return self.itemContainers.last?.reactionItems
    }
    
    public var topPreviewReaction: ContextControllerPreviewReaction? {
        return self.itemContainers.last?.previewReaction
    }
    
    public var topPositionLock: CGFloat? {
        return self.itemContainers.last?.positionLock
    }
    
    public var storedScrollingState: CGFloat? {
        return self.itemContainers.last?.storedScrollingState
    }
    
    public init(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void
    ) {
        self.context = context
        self.getController = getController
        self.requestDismiss = requestDismiss
        self.requestUpdate = requestUpdate
        
        self.navigationContainer = NavigationContainer()
        
        super.init()
        
        self.addSubnode(self.navigationContainer)
        
        self.navigationContainer.requestUpdate = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.requestUpdate(transition)
        }
        
        self.navigationContainer.requestPop = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pop()
        }
        
        let selectionPanGesture = ItemSelectionRecognizer(target: self, action: #selector(self.panGesture(_:)))
        selectionPanGesture.shouldBegin = { [weak self] point in
            guard let self, let topItemContainer = self.itemContainers.last else {
                return false
            }
            
            if topItemContainer.item is ContextControllerActionsCustomStackItem {
                return false
            }
            if !topItemContainer.highlightGestureShouldBegin(at: self.view.convert(point, to: topItemContainer.view)) {
                return false
            }
            
            return true
        }
        self.selectionPanGesture = selectionPanGesture
        self.view.addGestureRecognizer(selectionPanGesture)
        selectionPanGesture.isEnabled = false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            let location = recognizer.location(in: self.view)
            self.highlightGestureMoved(location: location)
        case .ended:
            self.highlightGestureFinished(performAction: true)
        case .cancelled:
            self.highlightGestureFinished(performAction: false)
        default:
            break
        }
    }
    
    public func replace(item: ContextControllerActionsStackItem, animated: Bool?) {
        if let item = item as? ContextControllerActionsListStackItem, let topContainer = self.itemContainers.first, let topItem = topContainer.item as? ContextControllerActionsListStackItem, let topId = topItem.id, let id = item.id, topId == id, item.items.count == topItem.items.count {
            if let topNode = topContainer.node as? ContextControllerActionsListStackItem.Node {
                var matches = true
                for i in 0 ..< item.items.count {
                    switch item.items[i] {
                    case .action:
                        if case .action = topItem.items[i] {
                        } else {
                            matches = false
                        }
                    case .custom:
                        if case .custom = topItem.items[i] {
                        } else {
                            matches = false
                        }
                    case .separator:
                        if case .separator = topItem.items[i] {
                        } else {
                            matches = false
                        }
                    }
                }
                
                if matches {
                    topNode.updateItems(items: item.items)
                    self.requestUpdate(.animated(duration: 0.3, curve: .spring))
                    return
                }
            }
        }
        
        var resolvedAnimated = false
        if let animated {
            resolvedAnimated = animated
        } else {
            if let id = item.id, let lastId = self.itemContainers.last?.item.id {
                if id != lastId {
                    resolvedAnimated = true
                }
            }
        }
        
        for itemContainer in self.itemContainers {
            if resolvedAnimated {
                self.dismissingItemContainers.append((itemContainer, false))
            } else {
                itemContainer.tipNode?.removeFromSupernode()
                itemContainer.removeFromSupernode()
            }
        }
        self.itemContainers.removeAll()
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        self.push(item: item, currentScrollingState: nil, positionLock: nil, animated: resolvedAnimated)
    }
    
    public func push(item: ContextControllerActionsStackItem, currentScrollingState: CGFloat?, positionLock: CGFloat?, animated: Bool) {
        if let itemContainer = self.itemContainers.last {
            itemContainer.storedScrollingState = currentScrollingState
        }
        let itemContainer = ItemContainer(
            context: self.context,
            getController: self.getController,
            requestDismiss: self.requestDismiss,
            requestUpdate: self.requestUpdate,
            requestUpdateApparentHeight: { [weak self] transition in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdate(transition)
            },
            item: item,
            tip: item.tip,
            tipSignal: item.tipSignal,
            reactionItems: item.reactionItems,
            previewReaction: item.previewReaction,
            itemDismissed: item.dismissed,
            positionLock: positionLock
        )
        self.itemContainers.append(itemContainer)
        self.navigationContainer.contentContainer.addSubview(itemContainer.view)
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: self.itemContainers.count == 1 ? 0.3 : 0.45, curve: .spring)
        } else {
            transition = .immediate
        }
        self.requestUpdate(transition)
    }
    
    public func clearStoredScrollingState() {
        self.itemContainers.last?.storedScrollingState = nil
    }
    
    public func pop() {
        if self.itemContainers.count == 1 {
            //dismiss
        } else {
            let itemContainer = self.itemContainers[self.itemContainers.count - 1]
            self.itemContainers.remove(at: self.itemContainers.count - 1)
            self.dismissingItemContainers.append((itemContainer, true))
            
            itemContainer.itemDismissed?()
        }
        
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
        self.requestUpdate(transition)
    }
    
    public func update(
        presentationData: PresentationData,
        constrainedSize: CGSize,
        presentation: Presentation,
        transition: ContainedViewLayoutTransition
    ) -> CGSize {
        let tipSpacing: CGFloat = 10.0
        
        let animateAppearingContainers = transition.isAnimated && !self.dismissingItemContainers.isEmpty
        
        struct TipLayout {
            var tipNode: InnerTextSelectionTipContainerNode
            var tipHeight: CGFloat
        }
        
        struct ItemLayout {
            var size: CGSize
            var apparentHeight: CGFloat
            var transitionFraction: CGFloat
            var alphaTransitionFraction: CGFloat
            var itemTransition: ContainedViewLayoutTransition
            var animateAppearingContainer: Bool
            var tip: TipLayout?
        }
        
        var topItemSize = CGSize()
        var itemLayouts: [ItemLayout] = []
        for i in 0 ..< self.itemContainers.count {
            let itemContainer = self.itemContainers[i]
            
            var animateAppearingContainer = false
            var itemContainerTransition = transition
            if itemContainer.bounds.isEmpty {
                itemContainerTransition = .immediate
                animateAppearingContainer = i == self.itemContainers.count - 1 && animateAppearingContainers || self.itemContainers.count > 1
            }
            
            let itemConstrainedHeight: CGFloat = constrainedSize.height
            
            let transitionFraction: CGFloat
            let alphaTransitionFraction: CGFloat
            if i == self.itemContainers.count - 1 {
                transitionFraction = self.navigationContainer.transitionFraction
                alphaTransitionFraction = 1.0
            } else if i == self.itemContainers.count - 2 {
                transitionFraction = self.navigationContainer.transitionFraction - 1.0
                alphaTransitionFraction = self.navigationContainer.transitionFraction
            } else {
                transitionFraction = 0.0
                alphaTransitionFraction = 0.0
            }
            
            var tip: TipLayout?
            
            let itemContainerConstrainedSize: CGSize
            let standardMinWidth: CGFloat
            let standardMaxWidth: CGFloat
            let additionalBottomInset: CGFloat
            
            if itemContainer.node.wantsFullWidth {
                itemContainerConstrainedSize = CGSize(width: constrainedSize.width, height: itemConstrainedHeight)
                standardMaxWidth = 240.0
                standardMinWidth = standardMaxWidth
                
                if let (tipNode, tipHeight) = itemContainer.updateTip(presentationData: presentationData, presentation: presentation, width: standardMaxWidth, transition: itemContainerTransition) {
                    tip = TipLayout(tipNode: tipNode, tipHeight: tipHeight)
                    additionalBottomInset = tipHeight + 10.0
                } else {
                    additionalBottomInset = 0.0
                }
            } else {
                itemContainerConstrainedSize = CGSize(width: constrainedSize.width, height: itemConstrainedHeight)
                standardMinWidth = 220.0
                standardMaxWidth = 240.0
                additionalBottomInset = 0.0
            }
            
            let itemSize = itemContainer.update(
                presentationData: presentationData,
                constrainedSize: itemContainerConstrainedSize,
                standardMinWidth: standardMinWidth,
                standardMaxWidth: standardMaxWidth,
                additionalBottomInset: additionalBottomInset,
                transitionFraction: alphaTransitionFraction,
                transition: itemContainerTransition
            )
            if i == self.itemContainers.count - 1 {
                topItemSize = itemSize.size
            }
            
            if !itemContainer.node.wantsFullWidth {
                if let (tipNode, tipHeight) = itemContainer.updateTip(presentationData: presentationData, presentation: presentation, width: itemSize.size.width, transition: itemContainerTransition) {
                    tip = TipLayout(tipNode: tipNode, tipHeight: tipHeight)
                }
            }
            
            itemLayouts.append(ItemLayout(
                size: itemSize.size,
                apparentHeight: itemSize.apparentHeight,
                transitionFraction: transitionFraction,
                alphaTransitionFraction: alphaTransitionFraction,
                itemTransition: itemContainerTransition,
                animateAppearingContainer: animateAppearingContainer,
                tip: tip
            ))
        }
        
        let topItemApparentHeight: CGFloat
        let topItemWidth: CGFloat
        if itemLayouts.isEmpty {
            topItemApparentHeight = 0.0
            topItemWidth = 0.0
        } else if itemLayouts.count == 1 {
            topItemApparentHeight = itemLayouts[0].apparentHeight
            topItemWidth = itemLayouts[0].size.width
        } else {
            let lastItemLayout = itemLayouts[itemLayouts.count - 1]
            let previousItemLayout = itemLayouts[itemLayouts.count - 2]
            let transitionFraction = self.navigationContainer.transitionFraction
            
            topItemApparentHeight = lastItemLayout.apparentHeight * (1.0 - transitionFraction) + previousItemLayout.apparentHeight * transitionFraction
            topItemWidth = lastItemLayout.size.width * (1.0 - transitionFraction) + previousItemLayout.size.width * transitionFraction
        }
        
        let navigationContainerFrame: CGRect
        if topItemApparentHeight > 0.0 {
            navigationContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: topItemWidth, height: max(14 * 2.0, topItemApparentHeight)))
        } else {
            navigationContainerFrame = .zero
        }
        let previousNavigationContainerFrame = self.navigationContainer.frame
        transition.updateFrame(node: self.navigationContainer, frame: navigationContainerFrame, beginWithCurrentState: true)
        if !navigationContainerFrame.isEmpty {
            self.navigationContainer.update(presentationData: presentationData, presentation: presentation, size: navigationContainerFrame.size, transition: transition)
        }
        
        for i in 0 ..< self.itemContainers.count {
            let xOffset: CGFloat
            if itemLayouts[i].transitionFraction < 0.0 {
                xOffset = itemLayouts[i].transitionFraction * itemLayouts[i].size.width
            } else {
                if i != 0 {
                    xOffset = itemLayouts[i].transitionFraction * itemLayouts[i - 1].size.width
                } else {
                    xOffset = itemLayouts[i].transitionFraction * topItemWidth
                }
            }
            let itemFrame = CGRect(origin: CGPoint(x: xOffset, y: 0.0), size: CGSize(width: itemLayouts[i].size.width, height: navigationContainerFrame.height))
            
            itemLayouts[i].itemTransition.updateFrame(node: self.itemContainers[i], frame: itemFrame, beginWithCurrentState: true)
            if itemLayouts[i].animateAppearingContainer {
                transition.animatePositionAdditive(node: self.itemContainers[i], offset: CGPoint(x: itemFrame.width, y: 0.0))
            }
            
            self.itemContainers[i].updateDimNode(presentationData: presentationData, size: CGSize(width: itemLayouts[i].size.width, height: navigationContainerFrame.size.height), transitionFraction: itemLayouts[i].alphaTransitionFraction, transition: transition)
            
            if let tip = itemLayouts[i].tip {
                let tipTransition = transition
                var animateTipIn = false
                if tip.tipNode.supernode == nil {
                    self.addSubnode(tip.tipNode)
                    animateTipIn = transition.isAnimated
                    let tipFrame = CGRect(origin: CGPoint(x: previousNavigationContainerFrame.minX, y: previousNavigationContainerFrame.maxY + tipSpacing), size: CGSize(width: itemLayouts[i].size.width, height: tip.tipHeight))
                    tip.tipNode.frame = tipFrame
                    tip.tipNode.setActualSize(size: tipFrame.size, transition: .immediate)
                }
                
                let tipAlpha: CGFloat = itemLayouts[i].alphaTransitionFraction
                
                let tipFrame = CGRect(origin: CGPoint(x: navigationContainerFrame.minX, y: navigationContainerFrame.maxY + tipSpacing), size: CGSize(width: itemLayouts[i].size.width, height: tip.tipHeight))
                tipTransition.updateFrame(node: tip.tipNode, frame: tipFrame, beginWithCurrentState: true)
                
                tip.tipNode.setActualSize(size: tip.tipNode.bounds.size, transition: tipTransition)
                
                if animateTipIn {
                    tip.tipNode.alpha = 0.0
                    ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: tip.tipNode.view, alpha: 1.0)
                } else {
                    ComponentTransition(tipTransition).setAlpha(view: tip.tipNode.view, alpha: tipAlpha)
                }
                
                if i == self.itemContainers.count - 1 {
                    topItemSize.height += tipSpacing + tip.tipHeight
                }
            }
        }
        
        for (itemContainer, isPopped) in self.dismissingItemContainers {
            var position = itemContainer.position
            if isPopped {
                position.x = itemContainer.bounds.width / 2.0 + topItemWidth
            } else {
                position.x = itemContainer.bounds.width / 2.0 - topItemWidth
            }
            transition.updatePosition(node: itemContainer, position: position, completion: { [weak itemContainer] _ in
                itemContainer?.removeFromSupernode()
            })
            if let tipNode = itemContainer.tipNode {
                let tipFrame = CGRect(origin: CGPoint(x: navigationContainerFrame.minX, y: navigationContainerFrame.maxY + tipSpacing), size: tipNode.frame.size)
                ComponentTransition(transition).setFrame(view: tipNode.view, frame: tipFrame)
                
                ComponentTransition(transition).setAlpha(view: tipNode.view, alpha: 0.01, completion: { [weak tipNode] _ in
                    tipNode?.removeFromSupernode()
                })
            }
        }
        self.dismissingItemContainers.removeAll()
        
        return CGSize(width: topItemWidth, height: topItemSize.height)
    }
    
    public func highlightGestureMoved(location: CGPoint) {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.highlightGestureMoved(location: self.view.convert(location, to: topItemContainer.view))
        }
    }
    
    public func highlightGestureFinished(performAction: Bool) {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.highlightGestureFinished(performAction: performAction)
        }
    }
    
    public func decreaseHighlightedIndex() {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.decreaseHighlightedIndex()
        }
    }
    
    public func increaseHighlightedIndex() {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.increaseHighlightedIndex()
        }
    }
    
    public func updatePanSelection(isEnabled: Bool) {
        if let selectionPanGesture = self.selectionPanGesture {
            selectionPanGesture.isEnabled = isEnabled
        }
    }
    
    public func animateIn() {
        for itemContainer in self.itemContainers {
            if let tipNode = itemContainer.tipNode {
                tipNode.animateIn()
            }
        }
    }
    
    func animateIn(fromExtractableContainer extractableContainer: ContextExtractableContainer, transition: ComponentTransition) {
        self.navigationContainer.animateIn(fromExtractableContainer: extractableContainer, transition: transition)
    }
    
    func animateOut(toExtractableContainer extractableContainer: ContextExtractableContainer, transition: ComponentTransition) {
        self.navigationContainer.animateOut(toExtractableContainer: extractableContainer, transition: transition)
    }
    
    func didAnimateOut(toExtractableContainer extractableContainer: ContextExtractableContainer) {
        self.navigationContainer.didAnimateOut(toExtractableContainer: extractableContainer)
    }
}
