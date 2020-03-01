import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator
import AppBundle

final class PeerMediaCollectionEmptyNode: ASDisplayNode {
    private let mode: PeerMediaCollectionMode
    
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private let activityIndicator: ActivityIndicator
    
    var isLoading: Bool = false {
        didSet {
            if self.isLoading != oldValue {
                if self.isLoading {
                    self.iconNode.isHidden = true
                    self.textNode.isHidden = true
                    self.addSubnode(self.activityIndicator)
                } else {
                    self.iconNode.isHidden = false
                    self.textNode.isHidden = false
                    self.activityIndicator.removeFromSupernode()
                }
            }
        }
    }
    
    init(mode: PeerMediaCollectionMode, theme: PresentationTheme, strings: PresentationStrings) {
        self.mode = mode
        self.theme = theme
        self.strings = strings
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.isHidden = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.list.itemSecondaryTextColor, 22.0, 2.0, false), speed: .regular)
        
        let icon: UIImage?
        let text: NSAttributedString
        switch mode {
            case .photoOrVideo:
                icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/ImagesAndVideo")?.precomposed()
                let string1 = NSAttributedString(string: strings.SharedMedia_EmptyTitle, font: Font.medium(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                let string2 = NSAttributedString(string: "\n\n\(strings.SharedMedia_EmptyText)", font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                let string = NSMutableAttributedString()
                string.append(string1)
                string.append(string2)
                text = string
            case .file:
                icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Files")?.precomposed()
                text = NSAttributedString(string: strings.SharedMedia_EmptyFilesText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
            case .webpage:
                icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Links")?.precomposed()
                text = NSAttributedString(string: strings.SharedMedia_EmptyLinksText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
            case .music:
                icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Music")?.precomposed()
                text = NSAttributedString(string: strings.SharedMedia_EmptyMusicText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
        }
        self.iconNode.image = icon
        self.textNode.attributedText = text
        
        super.init()
        
        self.backgroundColor = theme.list.plainBackgroundColor
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition, interfaceState: PeerMediaCollectionInterfaceState) {
        let displayRect = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            self.backgroundColor = theme.list.plainBackgroundColor
            let icon: UIImage?
            let text: NSAttributedString
            switch mode {
                case .photoOrVideo:
                    icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/ImagesAndVideo")?.precomposed()
                    let string1 = NSAttributedString(string: strings.SharedMedia_EmptyTitle, font: Font.medium(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                    let string2 = NSAttributedString(string: "\n\n\(strings.SharedMedia_EmptyText)", font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                    let string = NSMutableAttributedString()
                    string.append(string1)
                    string.append(string2)
                    text = string
                case .file:
                    icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Files")?.precomposed()
                    text = NSAttributedString(string: strings.SharedMedia_EmptyFilesText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                case .webpage:
                    icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Links")?.precomposed()
                    text = NSAttributedString(string: strings.SharedMedia_EmptyLinksText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
                case .music:
                    icon = UIImage(bundleImageName: "Media Grid/Empty List Placeholders/Music")?.precomposed()
                    text = NSAttributedString(string: strings.SharedMedia_EmptyMusicText, font: Font.regular(16.0), textColor: theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
            }
            self.iconNode.image = icon
            self.textNode.attributedText = text
            activityIndicator.type = .custom(theme.list.itemSecondaryTextColor, 22.0, 2.0, false)
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 20.0, height: size.height))
        
        if let image = self.iconNode.image {
            let imageSpacing: CGFloat = 22.0
            let contentHeight = image.size.height + imageSpacing + textSize.height
            var contentRect = CGRect(origin: CGPoint(x: displayRect.minX, y: displayRect.minY + floor((displayRect.height - contentHeight) / 2.0)), size: CGSize(width: displayRect.width, height: contentHeight))
            contentRect.origin.y = max(displayRect.minY + 39.0, floor(contentRect.origin.y - contentRect.height * 0.0))
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - image.size.width) / 2.0), y: contentRect.minY), size: image.size))
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: contentRect.maxY - textSize.height), size: textSize))
        }
        
        let activitySize = self.activityIndicator.measure(size)
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - activitySize.width) / 2.0), y: displayRect.minY + floor((displayRect.height - activitySize.height) / 2.0)), size: activitySize))
    }
}
