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

final class ChatListEmptyNode: ASDisplayNode {
    enum Subject {
        case chats
        case filter(showEdit: Bool)
        case forum
    }
    private let action: () -> Void
    private let secondaryAction: () -> Void
    
    let subject: Subject
    private(set) var isLoading: Bool
    private let textNode: ImmediateTextNode
    private let descriptionNode: ImmediateTextNode
    private let animationNode: AnimatedStickerNode
    private let buttonNode: SolidRoundedButtonNode
    private let secondaryButtonNode: HighlightableButtonNode
    private let activityIndicator: ActivityIndicator
    
    private var animationSize: CGSize = CGSize()
    private var buttonIsHidden: Bool
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, subject: Subject, isLoading: Bool, theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void, secondaryAction: @escaping () -> Void) {
        self.action = action
        self.secondaryAction = secondaryAction
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
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.secondaryButtonNode)
        self.addSubnode(self.activityIndicator)

        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.animationSize = CGSize(width: 124.0, height: 124.0)
        self.animationNode.visibility = true
        
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
        let text: String
        var descriptionText = ""
        let buttonText: String
        var secondaryButtonText = ""
        switch self.subject {
            case .chats:
                text = strings.ChatList_EmptyChatList
                buttonText = strings.ChatList_EmptyChatListNewMessage
            case .filter:
                text = strings.ChatList_EmptyChatListFilterTitle
                descriptionText = strings.ChatList_EmptyChatListFilterText
                buttonText = strings.ChatList_EmptyChatListEditFilter
            case .forum:
                text = strings.ChatList_EmptyTopicsTitle
                buttonText = strings.ChatList_EmptyTopicsCreate
                secondaryButtonText = strings.ChatList_EmptyTopicsShowAsMessages
        }
        let string = NSMutableAttributedString(string: text, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor)
        let descriptionString = NSAttributedString(string: descriptionText, font: Font.regular(14.0), textColor: theme.list.itemSecondaryTextColor)
       
        self.textNode.attributedText = string
        self.descriptionNode.attributedText = descriptionString
        
        self.buttonNode.title = buttonText
        self.secondaryButtonNode.setAttributedTitle(NSAttributedString(string: secondaryButtonText, font: Font.regular(17.0), textColor: theme.list.itemAccentColor), for: .normal)
        self.secondaryButtonNode.isHidden = secondaryButtonText.isEmpty
    
        self.activityIndicator.type = .custom(theme.list.itemAccentColor, 22.0, 1.0, false)
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
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
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height - 50.0) / 2.0)), size: indicatorSize))
        
        let animationSpacing: CGFloat = 24.0
        let descriptionSpacing: CGFloat = 8.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height))
        let descriptionSize = self.descriptionNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height))
                
        let buttonSideInset: CGFloat = 16.0
        let buttonWidth = size.width - buttonSideInset * 2.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let buttonSize = CGSize(width: buttonWidth, height: buttonHeight)
        
        let secondaryButtonSize = self.secondaryButtonNode.measure(CGSize(width: buttonWidth, height: .greatestFiniteMagnitude))
        
        let contentHeight = self.animationSize.height + animationSpacing + textSize.height + buttonSize.height
        var contentOffset: CGFloat = 0.0
        if size.height < contentHeight {
            contentOffset = -self.animationSize.height - animationSpacing + 44.0
            transition.updateAlpha(node: self.animationNode, alpha: 0.0)
        } else {
            contentOffset = -40.0
            transition.updateAlpha(node: self.animationNode, alpha: 1.0)
        }
        
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - self.animationSize.width) / 2.0), y: floor((size.height - contentHeight) / 2.0) + contentOffset), size: self.animationSize)
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: animationFrame.maxY + animationSpacing), size: textSize)
        let descriptionFrame = CGRect(origin: CGPoint(x: floor((size.width - descriptionSize.width) / 2.0), y: textFrame.maxY + descriptionSpacing), size: descriptionSize)
        
        if !self.animationSize.width.isZero {
            self.animationNode.updateLayout(size: self.animationSize)
            transition.updateFrame(node: self.animationNode, frame: animationFrame)
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.descriptionNode, frame: descriptionFrame)
        
        var bottomInset: CGFloat = 16.0
        
        let secondaryButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - secondaryButtonSize.width) / 2.0), y: size.height - secondaryButtonSize.height - bottomInset), size: secondaryButtonSize)
        transition.updateFrame(node: self.secondaryButtonNode, frame: secondaryButtonFrame)
        
        if secondaryButtonSize.height > 0.0 {
            bottomInset += secondaryButtonSize.height + 23.0
        }
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: size.height - buttonHeight - bottomInset), size: buttonSize)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view.hitTest(self.view.convert(point, to: self.buttonNode.view), with: event)
        }
        if self.secondaryButtonNode.frame.contains(point), !self.secondaryButtonNode.isHidden {
            return self.secondaryButtonNode.view.hitTest(self.view.convert(point, to: self.secondaryButtonNode.view), with: event)
        }
        if self.animationNode.frame.contains(point) {
            return self.animationNode.view.hitTest(self.view.convert(point, to: self.animationNode.view), with: event)
        }
        return nil
    }
}
