import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import MultilineTextComponent

private let titleFont = Font.semibold(17.0)
private let dateFont = Font.regular(12.0)

public final class GalleryTitleView: UIView, NavigationBarTitleView {
    public final class Content: Equatable {
        let message: EngineMessage
        let title: String?
        let action: (() -> Void)?
        
        public init(message: EngineMessage, title: String?, action: (() -> Void)?) {
            self.message = message
            self.title = title
            self.action = action
        }
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            if lhs.message != rhs.message {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            return true
        }
    }
    
    private let context: AccountContext
    private let presentationData: PresentationData
    
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    
    private let titleBackgroundContainer: GlassBackgroundContainerView
    private let titleBackground: GlassBackgroundView
    private let title = ComponentView<Empty>()
    
    private var content: Content?
    private var titleString: String?
    
    public var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    
    private var interactionTimer: Foundation.Timer?
    
    public init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        
        self.authorNameNode = ASTextNode()
        self.authorNameNode.isUserInteractionEnabled = false
        self.authorNameNode.displaysAsynchronously = false
        self.authorNameNode.maximumNumberOfLines = 1
        
        self.dateNode = ASTextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        self.dateNode.maximumNumberOfLines = 1
        
        self.titleBackgroundContainer = GlassBackgroundContainerView()
        self.titleBackground = GlassBackgroundView()
        
        self.titleBackgroundContainer.contentView.addSubview(self.titleBackground)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundContainer)
        
        self.backgroundView.contentView.addSubview(self.authorNameNode.view)
        self.backgroundView.contentView.addSubview(self.dateNode.view)
        
        self.backgroundContainer.isHidden = true
        
        self.addSubview(self.titleBackgroundContainer)
        self.titleBackgroundContainer.alpha = 0.0
        
        self.backgroundView.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.interactionTimer?.invalidate()
    }
    
    @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.content?.action?()
        }
    }
    
    public func setContent(content: Content?) {
        self.content = content
        
        self.backgroundContainer.isHidden = self.content == nil
        
        if let content {
            let authorNameText = stringForFullAuthorName(message: content.message, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, accountPeerId: self.context.account.peerId).first ?? ""
            let dateText = humanReadableStringForTimestamp(strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, timestamp: content.message.timestamp).string
            
            self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
            self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: UIColor(white: 1.0, alpha: 0.5))
        }
        
        self.titleString = content?.title
        
        if !self.bounds.isEmpty {
            let _ = self.updateLayout(availableSize: self.bounds.size, transition: .immediate)
        }
    }
    
    public func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = availableSize
        
        let leftInset: CGFloat = 8.0 + 14.0
        let rightInset: CGFloat = 8.0 + 14.0
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0 - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0), height: CGFloat.greatestFiniteMagnitude))
        
        var backgroundSize = CGSize(width: 0.0, height: 44.0)
        
        if authorNameSize.height.isZero {
            backgroundSize.width = dateSize.width
        } else {
            backgroundSize.width = max(authorNameSize.width, dateSize.width)
        }
        backgroundSize.width = max(150.0, backgroundSize.width)
        backgroundSize.width += 14.0 * 2.0
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((backgroundSize.width - dateSize.width) / 2.0), y: floor((backgroundSize.height - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 2.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((backgroundSize.width - authorNameSize.width) / 2.0), y: floor((backgroundSize.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((backgroundSize.width - dateSize.width) / 2.0), y: floor((backgroundSize.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: floor((size.width - backgroundSize.width) * 0.5), y: floor((size.height - backgroundSize.height) * 0.5)), size: backgroundSize)
        
        self.backgroundContainer.update(size: backgroundFrame.size, isDark: true, transition: ComponentTransition(transition))
        ComponentTransition(transition).setFrame(view: self.backgroundContainer, frame: backgroundFrame)
        
        ComponentTransition(transition).setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        self.backgroundView.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: self.content?.action != nil, transition: ComponentTransition(transition))
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: self.titleString ?? "", font: Font.semibold(12.0), textColor: .white))
            )),
            environment: {},
            containerSize: CGSize(width: 200.0, height: 100.0)
        )
        let titleInset: CGFloat = 12.0
        let titleBackgroundSize = CGSize(width: titleInset * 2.0 + titleSize.width, height: 24.0)
        let titleBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleBackgroundSize.width) * 0.5), y: availableSize.height + 2.0), size: titleBackgroundSize)
        let titleFrame = titleSize.centered(in: CGRect(origin: CGPoint(), size: titleBackgroundSize))
        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.titleBackground.contentView.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        do {
            let transition = ComponentTransition.immediate
            transition.setFrame(view: self.titleBackgroundContainer, frame: titleBackgroundFrame)
            self.titleBackgroundContainer.update(size: titleBackgroundSize, isDark: true, transition: transition)
            
            transition.setFrame(view: self.titleBackground, frame: CGRect(origin: CGPoint(), size: titleBackgroundSize))
            self.titleBackground.update(size: titleBackgroundSize, cornerRadius: titleBackgroundSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: transition)
            
            self.titleBackgroundContainer.isHidden = !(self.titleString != nil && self.titleString != "")
        }
        
        return availableSize
    }
    
    public func animateLayoutTransition() {
    }
    
    public func updateIsInteracting(isInteracting: Bool) {
        if isInteracting {
            self.interactionTimer?.invalidate()
            self.interactionTimer = nil
            
            ComponentTransition.easeInOut(duration: 0.2).animateView {
                self.titleBackgroundContainer.alpha = 1.0
            }
        } else {
            self.interactionTimer?.invalidate()
            self.interactionTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { [weak self] _ in
                guard let self else {
                    return
                }
                ComponentTransition.easeInOut(duration: 0.2).animateView {
                    self.titleBackgroundContainer.alpha = 0.0
                }
            })
        }
    }
}
