import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import SolidRoundedButtonNode
import ActivityIndicator
import AccountContext
import TelegramCore
import ComponentFlow
import ArchiveInfoScreen
import ComponentDisplayAdapters
import SwiftSignalKit
import ChatListHeaderComponent

final class ChatListEmptyNode: ASDisplayNode {
    enum Subject {
        case chats(hasArchive: Bool)
        case archive
        case filter(showEdit: Bool)
        case forum(hasGeneral: Bool)
    }
    private let action: () -> Void
    private let secondaryAction: () -> Void
    private let openArchiveSettings: () -> Void
    
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    let subject: Subject
    private(set) var isLoading: Bool
    private let textNode: ImmediateTextNode
    private let descriptionNode: ImmediateTextNode
    private let animationNode: AnimatedStickerNode
    private let buttonNode: SolidRoundedButtonNode
    private let secondaryButtonNode: HighlightableButtonNode
    private let activityIndicator: ActivityIndicator
    
    private var emptyArchive: ComponentView<Empty>?
    
    private var animationSize: CGSize = CGSize()
    private var buttonIsHidden: Bool
    
    private var validLayout: (size: CGSize, insets: UIEdgeInsets)?
    private var scrollingOffset: (navigationHeight: CGFloat, offset: CGFloat)?
    
    private var globalPrivacySettings: GlobalPrivacySettings = .default
    private var archiveSettingsDisposable: Disposable?
    
    init(context: AccountContext, subject: Subject, isLoading: Bool, theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void, secondaryAction: @escaping () -> Void, openArchiveSettings: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        
        self.action = action
        self.secondaryAction = secondaryAction
        self.openArchiveSettings = openArchiveSettings
        self.subject = subject
        self.isLoading = isLoading
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .center
        self.textNode.lineSpacing = 0.1
        
        self.descriptionNode = ImmediateTextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.maximumNumberOfLines = 0
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.textAlignment = .center
        self.descriptionNode.lineSpacing = 0.1
        
        var gloss = true
        if case .filter = subject {
            gloss = false
        } else if case .chats(true) = subject {
            gloss = false
        }
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), cornerRadius: 11.0, gloss: gloss)
        
        self.secondaryButtonNode = HighlightableButtonNode()
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 1.0, false))
        
        var buttonIsHidden = false
        let animationName: String
        if case let .filter(showEdit) = subject {
            animationName = "ChatListFilterEmpty"
            buttonIsHidden = !showEdit
        } else {
            animationName = "ChatListEmpty"
        }
        self.buttonIsHidden = buttonIsHidden
        
        super.init()
        
        self.animationSize = CGSize(width: 124.0, height: 124.0)
        
        if case .archive = subject {
        } else {
            self.addSubnode(self.animationNode)
            self.addSubnode(self.textNode)
            self.addSubnode(self.descriptionNode)
            self.addSubnode(self.buttonNode)
            self.addSubnode(self.secondaryButtonNode)
            self.addSubnode(self.activityIndicator)
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animationNode.visibility = true
        }
        
        self.animationNode.isHidden = self.isLoading
        self.textNode.isHidden = self.isLoading
        self.descriptionNode.isHidden = self.isLoading
        self.buttonNode.isHidden = self.buttonIsHidden || self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
        
        self.buttonNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -10.0, bottom: -10.0, right: -10.0)
        self.buttonNode.pressed = { [weak self] in
            self?.buttonPressed()
        }
        
        self.secondaryButtonNode.addTarget(self, action: #selector(self.secondaryButtonPressed), forControlEvents: .touchUpInside)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
        
        if case .archive = subject {
            let _ = self.context.engine.privacy.updateGlobalPrivacySettings().start()
            
            self.archiveSettingsDisposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Configuration.GlobalPrivacy()
            )
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self else {
                    return
                }
                self.globalPrivacySettings = settings
                if let (size, insets) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, transition: .immediate)
                }
            })
        }
    }
    
    deinit {
        self.archiveSettingsDisposable?.dispose()
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
    
    @objc private func secondaryButtonPressed() {
        self.secondaryAction()
    }
    
    @objc private func animationTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if !self.animationNode.isPlaying {
                self.animationNode.play(firstFrame: false, fromIndex: nil)
            }
        }
    }
    
    func restartAnimation() {
        self.animationNode.play(firstFrame: false, fromIndex: nil)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        let text: String
        var descriptionText = ""
        let buttonText: String?
        switch self.subject {
            case let .chats(hasArchive):
                text = hasArchive ? strings.ChatList_EmptyChatListWithArchive : strings.ChatList_EmptyChatList
                buttonText = strings.ChatList_EmptyChatListNewMessage
            case .archive:
                text = strings.ChatList_EmptyChatList
                buttonText = nil
            case .filter:
                text = strings.ChatList_EmptyChatListFilterTitle
                descriptionText = strings.ChatList_EmptyChatListFilterText
                buttonText = strings.ChatList_EmptyChatListEditFilter
            case .forum:
                text = strings.ChatList_EmptyTopicsTitle
                buttonText = strings.ChatList_EmptyTopicsCreate
                descriptionText = strings.ChatList_EmptyTopicsDescription
        }
        let string = NSMutableAttributedString(string: text, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor)
        let descriptionString = NSAttributedString(string: descriptionText, font: Font.regular(14.0), textColor: theme.list.itemSecondaryTextColor)
       
        self.textNode.attributedText = string
        self.descriptionNode.attributedText = descriptionString
        
        if let buttonText {
            self.buttonNode.title = buttonText
            self.buttonNode.isHidden = false
        } else {
            self.buttonNode.isHidden = true
        }
    
        self.activityIndicator.type = .custom(theme.list.itemAccentColor, 22.0, 1.0, false)
        
        if let (size, insets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, transition: .immediate)
            
            if let scrollingOffset = self.scrollingOffset {
                self.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: .immediate)
            }
        }
    }
    
    func updateIsLoading(_ isLoading: Bool) {
        if self.isLoading == isLoading {
            return
        }
        self.isLoading = isLoading
        self.animationNode.isHidden = self.isLoading
        self.textNode.isHidden = self.isLoading
        self.descriptionNode.isHidden = self.isLoading
        self.buttonNode.isHidden = self.buttonIsHidden || self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets)
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: insets.top + floor((size.height - insets.top - insets.bottom - indicatorSize.height - 50.0) / 2.0)), size: indicatorSize))
        
        let animationSpacing: CGFloat = 24.0
        let descriptionSpacing: CGFloat = 8.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height - insets.top - insets.bottom))
        let descriptionSize = self.descriptionNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height - insets.top - insets.bottom))
                
        let buttonSideInset: CGFloat = 32.0
        let buttonWidth = min(270.0, size.width - buttonSideInset * 2.0)
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let buttonSize = CGSize(width: buttonWidth, height: buttonHeight)
        
        let secondaryButtonSize = self.secondaryButtonNode.measure(CGSize(width: buttonWidth, height: .greatestFiniteMagnitude))
        
        var threshold: CGFloat = 0.0
        if case .forum = self.subject {
            threshold = 80.0
        }
        
        let contentHeight = self.animationSize.height + animationSpacing + textSize.height + buttonSize.height
        var contentOffset: CGFloat = 0.0
        if size.height - insets.top - insets.bottom < contentHeight + threshold {
            contentOffset = -self.animationSize.height - animationSpacing + 44.0
            transition.updateAlpha(node: self.animationNode, alpha: 0.0)
        } else {
            contentOffset = -40.0
            transition.updateAlpha(node: self.animationNode, alpha: 1.0)
        }
        
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - self.animationSize.width) / 2.0), y: insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0) + contentOffset), size: self.animationSize)
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: animationFrame.maxY + animationSpacing), size: textSize)
        let descriptionFrame = CGRect(origin: CGPoint(x: floor((size.width - descriptionSize.width) / 2.0), y: textFrame.maxY + descriptionSpacing), size: descriptionSize)
        
        if !self.animationSize.width.isZero {
            self.animationNode.updateLayout(size: self.animationSize)
            transition.updateFrame(node: self.animationNode, frame: animationFrame)
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.descriptionNode, frame: descriptionFrame)
        
        var bottomInset: CGFloat = 16.0
        
        let secondaryButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - secondaryButtonSize.width) / 2.0), y: size.height - insets.bottom - secondaryButtonSize.height - bottomInset), size: secondaryButtonSize)
        transition.updateFrame(node: self.secondaryButtonNode, frame: secondaryButtonFrame)
        
        if secondaryButtonSize.height > 0.0 {
            bottomInset += secondaryButtonSize.height + 23.0
        }
        
        let buttonFrame: CGRect
        if case .forum = self.subject {
            buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: descriptionFrame.maxY + 20.0), size: buttonSize)
        } else {
            buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: size.height - insets.bottom - buttonHeight - bottomInset), size: buttonSize)
        }
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
    }
    
    func updateScrollingOffset(navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.scrollingOffset = (navigationHeight, offset)
        
        guard let (size, _) = self.validLayout else {
            return
        }
        
        if case .archive = self.subject {
            let emptyArchive: ComponentView<Empty>
            if let current = self.emptyArchive {
                emptyArchive = current
            } else {
                emptyArchive = ComponentView()
                self.emptyArchive = emptyArchive
            }
            let emptyArchiveSize = emptyArchive.update(
                transition: Transition(transition),
                component: AnyComponent(ArchiveInfoContentComponent(
                    theme: self.theme,
                    strings: self.strings,
                    settings: self.globalPrivacySettings,
                    openSettings: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openArchiveSettings()
                    }
                )),
                environment: {
                },
                containerSize: CGSize(width: size.width, height: 10000.0)
            )
            if let emptyArchiveView = emptyArchive.view {
                if emptyArchiveView.superview == nil {
                    self.view.addSubview(emptyArchiveView)
                }
                
                let cancelledOutHeight: CGFloat = max(0.0, ChatListNavigationBar.searchScrollHeight - offset)
                let visibleNavigationHeight: CGFloat = navigationHeight - ChatListNavigationBar.searchScrollHeight + cancelledOutHeight
                
                let additionalOffset = min(0.0, -offset + ChatListNavigationBar.searchScrollHeight)
                
                var archiveFrame = CGRect(origin: CGPoint(x: 0.0, y: visibleNavigationHeight + floorToScreenPixels((size.height - visibleNavigationHeight - emptyArchiveSize.height - 50.0) * 0.5)), size: emptyArchiveSize)
                archiveFrame.origin.y = max(archiveFrame.origin.y, visibleNavigationHeight + 20.0)
                
                if size.height - visibleNavigationHeight - emptyArchiveSize.height - 20.0 < 0.0 {
                    archiveFrame.origin.y += additionalOffset
                }
                
                transition.updateFrame(view: emptyArchiveView, frame: archiveFrame)
            }
        } else if let emptyArchive = self.emptyArchive {
            self.emptyArchive = nil
            emptyArchive.view?.removeFromSuperview()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view.hitTest(self.view.convert(point, to: self.buttonNode.view), with: event)
        }
        if self.secondaryButtonNode.frame.contains(point), !self.secondaryButtonNode.isHidden {
            return self.secondaryButtonNode.view.hitTest(self.view.convert(point, to: self.secondaryButtonNode.view), with: event)
        }
        if let emptyArchiveView = self.emptyArchive?.view {
            if let result = emptyArchiveView.hitTest(self.view.convert(point, to: emptyArchiveView), with: event) {
                return result
            }
        }
        return nil
    }
}
