import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AnimatedStickerNode
import AppBundle
import SolidRoundedButtonNode
import ActivityIndicator

final class ChatListEmptyNode: ASDisplayNode {
    let isFilter: Bool
    private(set) var isLoading: Bool
    private let textNode: ImmediateTextNode
    private let animationNode: AnimatedStickerNode
    private let buttonNode: SolidRoundedButtonNode
    private let activityIndicator: ActivityIndicator
    
    private var animationSize: CGSize = CGSize()
    
    private var validLayout: CGSize?
    
    init(isFilter: Bool, isLoading: Bool, theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.isFilter = isFilter
        self.isLoading = isLoading
        
        self.animationNode = AnimatedStickerNode()
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .center
        self.textNode.lineSpacing = 0.1
        
        self.buttonNode = SolidRoundedButtonNode(title: isFilter ? strings.ChatList_EmptyChatListEditFilter : strings.ChatList_EmptyChatListNewMessage, theme: SolidRoundedButtonTheme(backgroundColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 1.0, false))
        
        super.init()
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.activityIndicator)
        
        let animationName: String
        if isFilter {
            animationName = "ChatListFilterEmpty"
        } else {
            animationName = "ChatListEmpty"
        }
        if let path = getAppBundle().path(forResource: animationName, ofType: "tgs") {
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 248, height: 248, playbackMode: .once, mode: .direct)
            self.animationSize = CGSize(width: 124.0, height: 124.0)
            self.animationNode.visibility = true
        }
        
        self.buttonNode.pressed = {
            action()
        }
        
        self.animationNode.isHidden = self.isLoading
        self.textNode.isHidden = self.isLoading
        self.buttonNode.isHidden = self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        let string = NSMutableAttributedString(string: self.isFilter ? strings.ChatList_EmptyChatFilterList : strings.ChatList_EmptyChatList, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = string
        
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor))
        
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
        self.buttonNode.isHidden = self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height - 50.0) / 2.0)), size: indicatorSize))
        
        let animationSpacing: CGFloat = 10.0
        let buttonSpacing: CGFloat = 24.0
        let buttonSideInset: CGFloat = 16.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height))
        
        let buttonWidth = min(size.width - buttonSideInset * 2.0, 280.0)
        let buttonSize = CGSize(width: buttonWidth, height: 50.0)
        
        let contentHeight = self.animationSize.height + animationSpacing + textSize.height + buttonSpacing + buttonSize.height
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
        let buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: textFrame.maxY + buttonSpacing), size: buttonSize)
        
        if !self.animationSize.width.isZero {
            self.animationNode.updateLayout(size: self.animationSize)
            transition.updateFrame(node: self.animationNode, frame: animationFrame)
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view.hitTest(self.view.convert(point, to: self.buttonNode.view), with: event)
        }
        return nil
    }
}
