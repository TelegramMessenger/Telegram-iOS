import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer

final class GroupHeaderLayer: UIView {
    override static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    private let actionPressed: () -> Void
    private let performItemAction: (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void
    
    private let textLayer: SimpleLayer
    private let tintTextLayer: SimpleLayer
    
    private var subtitleLayer: SimpleLayer?
    private var tintSubtitleLayer: SimpleLayer?
    private var lockIconLayer: SimpleLayer?
    private var tintLockIconLayer: SimpleLayer?
    private var badgeLayer: SimpleLayer?
    private var tintBadgeLayer: SimpleLayer?
    private(set) var clearIconLayer: SimpleLayer?
    private var tintClearIconLayer: SimpleLayer?
    private var separatorLayer: SimpleLayer?
    private var tintSeparatorLayer: SimpleLayer?
    private var actionButton: GroupHeaderActionButton?
    
    private var groupEmbeddedView: GroupEmbeddedView?
    
    private var theme: PresentationTheme?
    
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    private var currentSubtitleLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    
    let tintContentLayer: SimpleLayer
    
    init(actionPressed: @escaping () -> Void, performItemAction: @escaping (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void) {
        self.actionPressed = actionPressed
        self.performItemAction = performItemAction
        
        self.textLayer = SimpleLayer()
        self.tintTextLayer = SimpleLayer()
        
        self.tintContentLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.textLayer)
        self.tintContentLayer.addSublayer(self.tintTextLayer)
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContentLayer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(
        context: AccountContext,
        theme: PresentationTheme,
        forceNeedsVibrancy: Bool,
        layoutType: EmojiPagerContentComponent.ItemLayoutType,
        hasTopSeparator: Bool,
        actionButtonTitle: String?,
        actionButtonIsCompact: Bool,
        title: String,
        subtitle: String?,
        badge: String?,
        isPremiumLocked: Bool,
        hasClear: Bool,
        embeddedItems: [EmojiPagerContentComponent.Item]?,
        isStickers: Bool,
        constrainedSize: CGSize,
        insets: UIEdgeInsets,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        attemptSynchronousLoad: Bool
    ) -> (size: CGSize, centralContentWidth: CGFloat) {
        var themeUpdated = false
        if self.theme !== theme {
            self.theme = theme
            themeUpdated = true
        }
                
        let needsVibrancy = !theme.overallDarkAppearance || forceNeedsVibrancy
        
        let textOffsetY: CGFloat
        if hasTopSeparator {
            textOffsetY = 9.0
        } else {
            textOffsetY = 0.0
        }
        
        let subtitleColor: UIColor
        if theme.overallDarkAppearance && forceNeedsVibrancy {
            subtitleColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.withMultipliedAlpha(0.2)
        } else {
            subtitleColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
        }
        
        let color: UIColor
        let needsTintText: Bool
        if subtitle != nil {
            color = theme.chat.inputPanel.primaryTextColor
            needsTintText = false
        } else {
            color = subtitleColor
            needsTintText = true
        }
        
        let titleHorizontalOffset: CGFloat
        if isPremiumLocked {
            titleHorizontalOffset = 10.0 + 2.0
        } else {
            titleHorizontalOffset = 0.0
        }
        
        var actionButtonSize: CGSize?
        if let actionButtonTitle = actionButtonTitle {
            let actionButton: GroupHeaderActionButton
            if let current = self.actionButton {
                actionButton = current
            } else {
                actionButton = GroupHeaderActionButton(pressed: self.actionPressed)
                self.actionButton = actionButton
                self.addSubview(actionButton)
                self.tintContentLayer.addSublayer(actionButton.tintContainerLayer)
            }
            
            actionButtonSize = actionButton.update(theme: theme, title: actionButtonTitle, compact: actionButtonIsCompact)
        } else {
            if let actionButton = self.actionButton {
                self.actionButton = nil
                actionButton.removeFromSuperview()
            }
        }
        
        var clearSize: CGSize = .zero
        var clearWidth: CGFloat = 0.0
        if hasClear {
            var updateImage = themeUpdated
            
            let clearIconLayer: SimpleLayer
            if let current = self.clearIconLayer {
                clearIconLayer = current
            } else {
                updateImage = true
                clearIconLayer = SimpleLayer()
                self.clearIconLayer = clearIconLayer
                self.layer.addSublayer(clearIconLayer)
            }
            let tintClearIconLayer: SimpleLayer
            if let current = self.tintClearIconLayer {
                tintClearIconLayer = current
            } else {
                updateImage = true
                tintClearIconLayer = SimpleLayer()
                self.tintClearIconLayer = tintClearIconLayer
                self.tintContentLayer.addSublayer(tintClearIconLayer)
            }
            
            tintClearIconLayer.isHidden = !needsVibrancy
            
            clearSize = clearIconLayer.bounds.size
            if updateImage, let image = PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme, color: subtitleColor) {
                clearSize = image.size
                clearIconLayer.contents = image.cgImage
            }
            if updateImage, let image = PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme, color: .black) {
                tintClearIconLayer.contents = image.cgImage
            }
                        
            tintClearIconLayer.frame = clearIconLayer.frame
            clearWidth = 4.0 + clearSize.width
        } else {
            if let clearIconLayer = self.clearIconLayer {
                self.clearIconLayer = nil
                clearIconLayer.removeFromSuperlayer()
            }
            if let tintClearIconLayer = self.tintClearIconLayer {
                self.tintClearIconLayer = nil
                tintClearIconLayer.removeFromSuperlayer()
            }
        }
        
        var textConstrainedWidth = constrainedSize.width - titleHorizontalOffset - 10.0
        if let actionButtonSize = actionButtonSize {
            if actionButtonIsCompact {
                textConstrainedWidth -= actionButtonSize.width * 2.0 + 10.0
            } else {
                textConstrainedWidth -= actionButtonSize.width + 10.0
            }
        }
        if clearWidth > 0.0 {
            textConstrainedWidth -= clearWidth + 8.0
        }
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == color, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let font: UIFont
            let stringValue: String
            if subtitle == nil {
                font = Font.medium(13.0)
                stringValue = title.uppercased()
            } else {
                font = Font.semibold(16.0)
                stringValue = title
            }
            let string = NSAttributedString(string: stringValue, font: font, textColor: color)
            let whiteString = NSAttributedString(string: stringValue, font: font, textColor: .black)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 18.0), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                //string.draw(in: stringBounds)
                string.draw(with: stringBounds, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.tintTextLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                whiteString.draw(with: stringBounds, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.tintTextLayer.isHidden = !needsVibrancy
            self.currentTextLayout = (title, color, textConstrainedWidth, textSize)
        }
              
        var badgeSize: CGSize = .zero
        if let badge {
            func generateBadgeImage(color: UIColor) -> UIImage? {
                let string = NSAttributedString(string: badge, font: Font.semibold(11.0), textColor: .white)
                let stringBounds = string.boundingRect(with: CGSize(width: 120, height: 18.0), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                
                let badgeSize = CGSize(width: stringBounds.width + 8.0, height: 16.0)
                return generateImage(badgeSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    context.setFillColor(color.cgColor)
                    context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: badgeSize), cornerRadius: badgeSize.height / 2.0).cgPath)
                    context.fillPath()
                    
                    context.setBlendMode(.clear)
                    
                    UIGraphicsPushContext(context)
                        
                    string.draw(with: CGRect(origin: CGPoint(x: floorToScreenPixels((badgeSize.width - stringBounds.size.width) / 2.0), y: floorToScreenPixels((badgeSize.height - stringBounds.size.height) / 2.0)), size: stringBounds.size), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                    
                    UIGraphicsPopContext()
                })
            }
            
            let badgeLayer: SimpleLayer
            if let current = self.badgeLayer {
                badgeLayer = current
            } else {
                badgeLayer = SimpleLayer()
                self.badgeLayer = badgeLayer
                self.layer.addSublayer(badgeLayer)
                
                if let image = generateBadgeImage(color: color.withMultipliedAlpha(0.66)) {
                    badgeLayer.contents = image.cgImage
                    badgeLayer.bounds = CGRect(origin: .zero, size: image.size)
                }
            }
            badgeSize = badgeLayer.bounds.size
            
            let tintBadgeLayer: SimpleLayer
            if let current = self.tintBadgeLayer {
                tintBadgeLayer = current
            } else {
                tintBadgeLayer = SimpleLayer()
                self.tintBadgeLayer = tintBadgeLayer
                self.tintContentLayer.addSublayer(tintBadgeLayer)
                
                if let image = generateBadgeImage(color: .black) {
                    tintBadgeLayer.contents = image.cgImage
                }
            }
        } else {
            if let badgeLayer = self.badgeLayer {
                self.badgeLayer = nil
                badgeLayer.removeFromSuperlayer()
            }
            if let tintBadgeLayer = self.tintBadgeLayer {
                self.tintBadgeLayer = nil
                tintBadgeLayer.removeFromSuperlayer()
            }
        }
        
        let textFrame: CGRect
        if subtitle == nil {
            textFrame = CGRect(origin: CGPoint(x: titleHorizontalOffset + floor((constrainedSize.width - titleHorizontalOffset - (textSize.width + badgeSize.width)) / 2.0), y: textOffsetY), size: textSize)
        } else {
            textFrame = CGRect(origin: CGPoint(x: titleHorizontalOffset, y: textOffsetY), size: textSize)
        }
        self.textLayer.frame = textFrame
        self.tintTextLayer.frame = textFrame
        self.tintTextLayer.isHidden = !needsTintText
        
        if let badgeLayer = self.badgeLayer, let tintBadgeLayer = self.tintBadgeLayer {
            badgeLayer.frame = CGRect(origin: CGPoint(x: textFrame.maxX + 4.0, y: 0.0), size: badgeLayer.frame.size)
            tintBadgeLayer.frame = badgeLayer.frame
        }
        
        if isPremiumLocked {
            let lockIconLayer: SimpleLayer
            if let current = self.lockIconLayer {
                lockIconLayer = current
            } else {
                lockIconLayer = SimpleLayer()
                self.lockIconLayer = lockIconLayer
                self.layer.addSublayer(lockIconLayer)
            }
            if let image = PresentationResourcesChat.chatEntityKeyboardLock(theme, color: color) {
                let imageSize = image.size
                lockIconLayer.contents = image.cgImage
                lockIconLayer.frame = CGRect(origin: CGPoint(x: textFrame.minX - imageSize.width - 3.0, y: 2.0 + UIScreenPixel), size: imageSize)
            } else {
                lockIconLayer.contents = nil
            }
            
            let tintLockIconLayer: SimpleLayer
            if let current = self.tintLockIconLayer {
                tintLockIconLayer = current
            } else {
                tintLockIconLayer = SimpleLayer()
                self.tintLockIconLayer = tintLockIconLayer
                self.tintContentLayer.addSublayer(tintLockIconLayer)
            }
            if let image = PresentationResourcesChat.chatEntityKeyboardLock(theme, color: .black) {
                tintLockIconLayer.contents = image.cgImage
                tintLockIconLayer.frame = lockIconLayer.frame
                tintLockIconLayer.isHidden = !needsVibrancy
            } else {
                tintLockIconLayer.contents = nil
            }
        } else {
            if let lockIconLayer = self.lockIconLayer {
                self.lockIconLayer = nil
                lockIconLayer.removeFromSuperlayer()
            }
            if let tintLockIconLayer = self.tintLockIconLayer {
                self.tintLockIconLayer = nil
                tintLockIconLayer.removeFromSuperlayer()
            }
        }
        
        let subtitleSize: CGSize
        if let subtitle = subtitle {
            var updateSubtitleContents: UIImage?
            var updateTintSubtitleContents: UIImage?
            if let currentSubtitleLayout = self.currentSubtitleLayout, currentSubtitleLayout.string == subtitle, currentSubtitleLayout.color == subtitleColor, currentSubtitleLayout.constrainedWidth == textConstrainedWidth {
                subtitleSize = currentSubtitleLayout.size
            } else {
                let string = NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: subtitleColor)
                let whiteString = NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: .black)
                let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                subtitleSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
                updateSubtitleContents = generateImage(subtitleSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    string.draw(in: stringBounds)
                    
                    UIGraphicsPopContext()
                })
                updateTintSubtitleContents = generateImage(subtitleSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    whiteString.draw(in: stringBounds)
                    
                    UIGraphicsPopContext()
                })
                self.currentSubtitleLayout = (subtitle, subtitleColor, textConstrainedWidth, subtitleSize)
            }
            
            let subtitleLayer: SimpleLayer
            if let current = self.subtitleLayer {
                subtitleLayer = current
            } else {
                subtitleLayer = SimpleLayer()
                self.subtitleLayer = subtitleLayer
                self.layer.addSublayer(subtitleLayer)
            }
            
            if let updateSubtitleContents = updateSubtitleContents {
                subtitleLayer.contents = updateSubtitleContents.cgImage
            }
            
            let tintSubtitleLayer: SimpleLayer
            if let current = self.tintSubtitleLayer {
                tintSubtitleLayer = current
            } else {
                tintSubtitleLayer = SimpleLayer()
                self.tintSubtitleLayer = tintSubtitleLayer
                self.tintContentLayer.addSublayer(tintSubtitleLayer)
            }
            tintSubtitleLayer.isHidden = !needsVibrancy
            
            if let updateTintSubtitleContents = updateTintSubtitleContents {
                tintSubtitleLayer.contents = updateTintSubtitleContents.cgImage
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: 0.0, y: textFrame.maxY + 1.0), size: subtitleSize)
            subtitleLayer.frame = subtitleFrame
            tintSubtitleLayer.frame = subtitleFrame
        } else {
            subtitleSize = CGSize()
            if let subtitleLayer = self.subtitleLayer {
                self.subtitleLayer = nil
                subtitleLayer.removeFromSuperlayer()
            }
            if let tintSubtitleLayer = self.tintSubtitleLayer {
                self.tintSubtitleLayer = nil
                tintSubtitleLayer.removeFromSuperlayer()
            }
        }
        
        self.clearIconLayer?.frame = CGRect(origin: CGPoint(x: constrainedSize.width - clearSize.width, y: floorToScreenPixels((textSize.height - clearSize.height) / 2.0)), size: clearSize)
        
        var size: CGSize
        size = CGSize(width: constrainedSize.width, height: constrainedSize.height)
        
        if let embeddedItems = embeddedItems {
            let groupEmbeddedView: GroupEmbeddedView
            if let current = self.groupEmbeddedView {
                groupEmbeddedView = current
            } else {
                groupEmbeddedView = GroupEmbeddedView(performItemAction: self.performItemAction)
                self.groupEmbeddedView = groupEmbeddedView
                self.addSubview(groupEmbeddedView)
            }
            
            let groupEmbeddedViewSize = CGSize(width: constrainedSize.width + insets.left + insets.right, height: 36.0)
            groupEmbeddedView.frame = CGRect(origin: CGPoint(x: -insets.left, y: size.height -  groupEmbeddedViewSize.height), size: groupEmbeddedViewSize)
            groupEmbeddedView.update(
                context: context,
                theme: theme,
                insets: insets,
                size: groupEmbeddedViewSize,
                items: embeddedItems,
                isStickers: isStickers,
                cache: cache,
                renderer: renderer,
                attemptSynchronousLoad: attemptSynchronousLoad
            )
        } else {
            if let groupEmbeddedView = self.groupEmbeddedView {
                self.groupEmbeddedView = nil
                groupEmbeddedView.removeFromSuperview()
            }
        }
        
        if let actionButtonSize = actionButtonSize, let actionButton = self.actionButton {
            let actionButtonFrame = CGRect(origin: CGPoint(x: size.width - actionButtonSize.width, y: textFrame.minY + (actionButtonIsCompact ? 0.0 : 3.0)), size: actionButtonSize)
            actionButton.bounds = CGRect(origin: CGPoint(), size: actionButtonFrame.size)
            actionButton.center = actionButtonFrame.center
        }
        
        if hasTopSeparator {
            let separatorLayer: SimpleLayer
            if let current = self.separatorLayer {
                separatorLayer = current
            } else {
                separatorLayer = SimpleLayer()
                self.separatorLayer = separatorLayer
                self.layer.addSublayer(separatorLayer)
            }
            separatorLayer.backgroundColor = subtitleColor.cgColor
            separatorLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel))
            
            let tintSeparatorLayer: SimpleLayer
            if let current = self.tintSeparatorLayer {
                tintSeparatorLayer = current
            } else {
                tintSeparatorLayer = SimpleLayer()
                self.tintSeparatorLayer = tintSeparatorLayer
                self.tintContentLayer.addSublayer(tintSeparatorLayer)
            }
            tintSeparatorLayer.backgroundColor = UIColor.black.cgColor
            tintSeparatorLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel))
            
            tintSeparatorLayer.isHidden = !needsVibrancy
        } else {
            if let separatorLayer = self.separatorLayer {
                self.separatorLayer = separatorLayer
                separatorLayer.removeFromSuperlayer()
            }
            if let tintSeparatorLayer = self.tintSeparatorLayer {
                self.tintSeparatorLayer = tintSeparatorLayer
                tintSeparatorLayer.removeFromSuperlayer()
            }
        }
        
        return (size, titleHorizontalOffset + textSize.width + clearWidth)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    func tapGesture(point: CGPoint) -> Bool {
        if let groupEmbeddedView = self.groupEmbeddedView {
            return groupEmbeddedView.tapGesture(point: self.convert(point, to: groupEmbeddedView))
        } else {
            return false
        }
    }
}
