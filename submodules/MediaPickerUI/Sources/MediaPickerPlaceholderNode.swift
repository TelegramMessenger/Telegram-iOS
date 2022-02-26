import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode
import PresentationDataUtils

final class MediaPickerPlaceholderNode: ASDisplayNode {
    enum Content {
        case intro
        case bannedSendMedia(String)
    }
    
    private let content: Content
    
    private var animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    private var validLayout: ContainerViewLayout?
    
    private var cameraButtonNode: HighlightTrackingButtonNode
    private var cameraTextNode: ImmediateTextNode
    private var cameraIconNode: ASImageNode
    
    var settingsPressed: () -> Void = {}
    var cameraPressed: () -> Void = {}
    
    init(content: Content) {
        self.content = content
        
        let name: String
        let playbackMode: AnimatedStickerPlaybackMode
        switch content {
            case .intro:
                name = "Photos"
                playbackMode = .loop
            case .bannedSendMedia:
                name = "Banned"
                playbackMode = .once
        }
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: name), width: 320, height: 320, playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.textAlignment = .center
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 12.0, gloss: true)
        
        self.cameraButtonNode = HighlightTrackingButtonNode()
        self.cameraButtonNode.alpha = 0.0
        self.cameraButtonNode.isUserInteractionEnabled = false
        
        self.cameraTextNode = ImmediateTextNode()
        self.cameraTextNode.isUserInteractionEnabled = false
        
        self.cameraIconNode = ASImageNode()
        self.cameraIconNode.displaysAsynchronously = false
        self.cameraIconNode.isUserInteractionEnabled = false
         
        super.init()
                
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        
        if case .intro = self.content {
            self.addSubnode(self.titleNode)
            self.addSubnode(self.buttonNode)
            
            self.addSubnode(self.cameraButtonNode)
            self.cameraButtonNode.addSubnode(self.cameraTextNode)
            self.cameraButtonNode.addSubnode(self.cameraIconNode)
            
            self.cameraButtonNode.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.cameraTextNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.cameraTextNode.alpha = 0.4
                        strongSelf.cameraIconNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.cameraIconNode.alpha = 0.4
                    } else {
                        strongSelf.cameraTextNode.alpha = 1.0
                        strongSelf.cameraTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                        strongSelf.cameraIconNode.alpha = 1.0
                        strongSelf.cameraIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.cameraButtonNode.addTarget(self, action: #selector(self.cameraButtonPressed), forControlEvents: .touchUpInside)
            
            self.buttonNode.pressed = { [weak self] in
                self?.settingsPressed()
            }
        }
    }
    
    @objc private func cameraButtonPressed() {
        self.cameraPressed()
    }
    
    private var theme: PresentationTheme?
    func update(layout: ContainerViewLayout, theme: PresentationTheme, strings: PresentationStrings, hasCamera: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        let themeUpdated = self.theme != theme
        self.theme = theme
        
        var imageSize = CGSize(width: 144.0, height: 144.0)
        var insets = layout.insets(options: [])
        if layout.size.width == 460.0 {
            insets.top += -60.0
            imageSize = CGSize(width: 112.0, height: 112.0)
        } else {
            insets.top += -160.0
        }
        
        let imageSpacing: CGFloat = 12.0
        let textSpacing: CGFloat = 12.0
        let buttonSpacing: CGFloat = 15.0
        let cameraSpacing: CGFloat = 13.0
        
        let imageHeight = layout.size.width < layout.size.height ? imageSize.height + imageSpacing : 0.0
        
        if themeUpdated {
            self.buttonNode.updateTheme(SolidRoundedButtonTheme(theme: theme))
            self.cameraIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/OpenCamera"), color: theme.list.itemAccentColor)
        }
        self.buttonNode.title = strings.Attachment_OpenSettings
        let buttonWidth: CGFloat = 248.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        
        let title: String
        let text: String
        switch self.content {
            case .intro:
                title = strings.Attachment_MediaAccessTitle
                text = strings.Attachment_MediaAccessText
            case let .bannedSendMedia(banDescription):
                title = ""
                text = banDescription
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        self.cameraTextNode.attributedText = NSAttributedString(string: strings.Attachment_OpenCamera, font: Font.regular(17.0), textColor: theme.list.itemAccentColor, paragraphAlignment: .center)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 40.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 40.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        let cameraSize = self.cameraTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 70.0, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        
        let totalHeight = imageHeight + titleSize.height + textSpacing + textSize.height + buttonSpacing + buttonHeight + cameraSpacing + cameraSize.height
        let topOffset = insets.top + floor((layout.size.height - insets.top - insets.bottom - totalHeight) / 2.0)
        
        transition.updateAlpha(node: self.animationNode, alpha: imageHeight > 0.0 ? 1.0 : 0.0)
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: topOffset), size: imageSize))
        self.animationNode.updateLayout(size: imageSize)
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - titleSize.width - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: topOffset + imageHeight), size: titleSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - textSize.width - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: self.titleNode.frame.maxY + textSpacing), size: textSize))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - buttonWidth - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: self.textNode.frame.maxY + buttonSpacing), size: CGSize(width: buttonWidth, height: buttonHeight)))

        if let image = self.cameraIconNode.image {
            let cameraTotalSize = CGSize(width: cameraSize.width + image.size.width + 10.0, height: 44.0)
            transition.updateFrame(node: self.cameraIconNode, frame: CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((cameraTotalSize.height - image.size.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.cameraTextNode, frame: CGRect(origin: CGPoint(x: cameraTotalSize.width - cameraSize.width, y: floorToScreenPixels((cameraTotalSize.height - cameraSize.height) / 2.0)), size: cameraSize))
            
            transition.updateFrame(node: self.cameraButtonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - cameraTotalSize.width - layout.safeInsets.left - layout.safeInsets.right) / 2.0), y: self.buttonNode.frame.maxY + cameraSpacing), size: cameraTotalSize))
        }
        
        self.cameraButtonNode.isUserInteractionEnabled = hasCamera
        transition.updateAlpha(node: self.cameraButtonNode, alpha: hasCamera ? 1.0 : 0.0)
    }
}


