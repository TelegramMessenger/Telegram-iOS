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
    private let action: () -> Void
    
    let isFilter: Bool
    private(set) var isLoading: Bool
    private let textNode: ImmediateTextNode
    private let descriptionNode: ImmediateTextNode
    private let animationNode: AnimatedStickerNode
    private let buttonTextNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    private let activityIndicator: ActivityIndicator
    
    private var animationSize: CGSize = CGSize()
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, isFilter: Bool, isLoading: Bool, theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.action = action
        self.isFilter = isFilter
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
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.buttonTextNode = ImmediateTextNode()
        self.buttonTextNode.displaysAsynchronously = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 1.0, false))
        
        super.init()
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.buttonTextNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.activityIndicator)
        
        let animationName: String
        if isFilter {
            animationName = "ChatListFilterEmpty"
        } else {
            animationName = "ChatListEmpty"
        }
        
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.animationSize = CGSize(width: 124.0, height: 124.0)
        self.animationNode.visibility = true
        
        self.animationNode.isHidden = self.isLoading
        self.textNode.isHidden = self.isLoading
        self.descriptionNode.isHidden = self.isLoading
        self.buttonNode.isHidden = self.isLoading
        self.buttonTextNode.isHidden = self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
        
        self.buttonNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -10.0, bottom: -10.0, right: -10.0)
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonTextNode.alpha = 0.4
                } else {
                    strongSelf.buttonTextNode.alpha = 1.0
                    strongSelf.buttonTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
    }
    
    @objc private func buttonPressed() {
        self.action()
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
        let string = NSMutableAttributedString(string: self.isFilter ? strings.ChatList_EmptyChatListFilterTitle : strings.ChatList_EmptyChatList, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor)
        let descriptionString: NSAttributedString
        if self.isFilter {
            descriptionString = NSAttributedString(string: strings.ChatList_EmptyChatListFilterText, font: Font.regular(14.0), textColor: theme.list.itemSecondaryTextColor)
        } else {
            descriptionString = NSAttributedString()
        }
        self.textNode.attributedText = string
        self.descriptionNode.attributedText = descriptionString
        
        self.buttonTextNode.attributedText = NSAttributedString(string: isFilter ? strings.ChatList_EmptyChatListEditFilter : strings.ChatList_EmptyChatListNewMessage, font: Font.regular(17.0), textColor: theme.list.itemAccentColor)
        
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
        self.buttonNode.isHidden = self.isLoading
        self.buttonTextNode.isHidden = self.isLoading
        self.activityIndicator.isHidden = !self.isLoading
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height - 50.0) / 2.0)), size: indicatorSize))
        
        let animationSpacing: CGFloat = 24.0
        let descriptionSpacing: CGFloat = 8.0
        let buttonSpacing: CGFloat = 24.0
        let buttonSideInset: CGFloat = 16.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height))
        let descriptionSize = self.descriptionNode.updateLayout(CGSize(width: size.width - 40.0, height: size.height))
        
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
        let descpriptionFrame = CGRect(origin: CGPoint(x: floor((size.width - descriptionSize.width) / 2.0), y: textFrame.maxY + descriptionSpacing), size: descriptionSize)
        let bottomTextEdge: CGFloat = descpriptionFrame.width.isZero ? textFrame.maxY : descpriptionFrame.maxY
        
        if !self.animationSize.width.isZero {
            self.animationNode.updateLayout(size: self.animationSize)
            transition.updateFrame(node: self.animationNode, frame: animationFrame)
        }
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.descriptionNode, frame: descpriptionFrame)
        
        let buttonTextSize = self.buttonTextNode.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonTextSize.width) / 2.0), y: bottomTextEdge + buttonSpacing), size: buttonTextSize)
        
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonTextNode, frame: buttonFrame)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view.hitTest(self.view.convert(point, to: self.buttonNode.view), with: event)
        }
        if self.animationNode.frame.contains(point) {
            return self.animationNode.view.hitTest(self.view.convert(point, to: self.animationNode.view), with: event)
        }
        return nil
    }
}
