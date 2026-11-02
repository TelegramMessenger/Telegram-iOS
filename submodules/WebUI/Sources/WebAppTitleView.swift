import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import EmojiStatusComponent
import AccountContext

public struct WebAppTitle: Equatable {
    public var title: String
    public var counter: String
    public var isVerified: Bool
    /// The bot's third-party verification icon (a custom emoji), drawn left of the title as in the chat header.
    public var verificationIconFileId: Int64?
    
    public init(title: String, counter: String, isVerified: Bool, verificationIconFileId: Int64? = nil) {
        self.title = title
        self.counter = counter
        self.isVerified = isVerified
        self.verificationIconFileId = verificationIconFileId
    }
}

public final class WebAppTitleView: UIView {
    private let context: AccountContext
    
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private var titleCredibilityIconView: ComponentHostView<Empty>?
    private var titleVerificationIconView: ComponentHostView<Empty>?
    
    public var title: WebAppTitle = WebAppTitle(title: "", counter: "", isVerified: false) {
        didSet {
            if self.title != oldValue {
                self.update()
            }
        }
    }
    
    public var theme: PresentationTheme {
        didSet {
            self.update()
        }
    }
    private let isAttachMenu: Bool
    
    private var primaryTextColor: UIColor?
    private var secondaryTextColor: UIColor?
    
    public func updateTextColors(primary: UIColor?, secondary: UIColor?, transition: ContainedViewLayoutTransition) {
        self.primaryTextColor = primary
        self.secondaryTextColor = secondary
        
        if case let .animated(duration, curve) = transition {
            if let snapshotView = self.snapshotContentTree() {
                snapshotView.frame = self.bounds
                self.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
                self.subtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        
        self.update()
    }
    
    private func update() {
        let primaryTextColor = self.primaryTextColor ?? self.theme.rootController.navigationBar.primaryTextColor
        let secondaryTextColor = self.secondaryTextColor ?? self.theme.rootController.navigationBar.secondaryTextColor
        self.titleNode.attributedText = NSAttributedString(string: self.title.title, font: Font.semibold(17.0), textColor: primaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.title.counter, font: Font.regular(13.0), textColor: secondaryTextColor)
        
        self.accessibilityLabel = self.title.title
        self.accessibilityValue = self.title.counter
        
        self.setNeedsLayout()
    }
    
    public init(context: AccountContext, theme: PresentationTheme, isAttachMenu: Bool) {
        self.context = context
        self.theme = theme
        self.isAttachMenu = isAttachMenu
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.truncationType = .end
        self.subtitleNode.isOpaque = false
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .header
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let spacing: CGFloat = 0.0
        
        // As the chat header's third-party verification icon: 20pt, 4pt before the title.
        let verificationIconSpacing: CGFloat = 4.0
        var verificationIconSize: CGSize?
        if let verificationIconFileId = self.title.verificationIconFileId {
            let titleVerificationIconView: ComponentHostView<Empty>
            if let current = self.titleVerificationIconView {
                titleVerificationIconView = current
            } else {
                titleVerificationIconView = ComponentHostView<Empty>()
                titleVerificationIconView.isUserInteractionEnabled = false
                self.titleVerificationIconView = titleVerificationIconView
                self.addSubview(titleVerificationIconView)
            }
            verificationIconSize = titleVerificationIconView.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    content: .animation(content: .customEmoji(fileId: verificationIconFileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: self.theme.list.mediaPlaceholderColor, themeColor: self.theme.list.itemAccentColor, loopMode: .count(2)),
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 20.0)
            )
        } else if let titleVerificationIconView = self.titleVerificationIconView {
            self.titleVerificationIconView = nil
            titleVerificationIconView.removeFromSuperview()
        }
        
        let credibilityIconSpacing: CGFloat = 2.0
        var credibilityIconSize: CGSize?
        if self.title.isVerified {
            let statusContent: EmojiStatusComponent.Content = .verified(fillColor: self.theme.list.itemCheckColors.fillColor, foregroundColor: self.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
            
            let titleCredibilityIconView: ComponentHostView<Empty>
            if let current = self.titleCredibilityIconView {
                titleCredibilityIconView = current
            } else {
                titleCredibilityIconView = ComponentHostView<Empty>()
                self.titleCredibilityIconView = titleCredibilityIconView
                self.addSubview(titleCredibilityIconView)
            }
            
            credibilityIconSize = titleCredibilityIconView.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    content: statusContent,
                    isVisibleForAnimations: true,
                    action: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 20.0)
            )
        }
        
        let leadingIconsWidth: CGFloat = verificationIconSize.flatMap { $0.width + verificationIconSpacing } ?? 0.0
        let trailingIconsWidth: CGFloat = credibilityIconSize.flatMap { $0.width + credibilityIconSpacing } ?? 0.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - leadingIconsWidth - trailingIconsWidth), height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: max(1.0, size.width), height: size.height))
        let combinedHeight = titleSize.height + subtitleSize.height + spacing
        
        let totalWidth = leadingIconsWidth + titleSize.width + trailingIconsWidth
        let topOffset = self.isAttachMenu ? 3.0 : 0.0
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalWidth) / 2.0) + leadingIconsWidth, y: topOffset + floorToScreenPixels((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        
        if let verificationIconSize, let titleVerificationIconView = self.titleVerificationIconView {
            titleVerificationIconView.frame = CGRect(origin: CGPoint(x: titleFrame.minX - verificationIconSpacing - verificationIconSize.width, y: floorToScreenPixels(titleFrame.midY - verificationIconSize.height / 2.0)), size: verificationIconSize)
        }
        if let credibilityIconSize, let titleCredibilityIconView = self.titleCredibilityIconView {
            titleCredibilityIconView.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + credibilityIconSpacing, y: topOffset + floorToScreenPixels(floorToScreenPixels((size.height - combinedHeight) / 2.0 + titleSize.height / 2.0) - credibilityIconSize.height / 2.0)), size: credibilityIconSize)
        }
        
        let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - subtitleSize.width) / 2.0), y: topOffset + floorToScreenPixels((size.height - combinedHeight) / 2.0) + titleSize.height + spacing), size: subtitleSize)
        self.subtitleNode.frame = subtitleFrame
    }
}
