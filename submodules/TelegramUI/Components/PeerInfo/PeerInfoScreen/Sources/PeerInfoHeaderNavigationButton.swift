import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import ManagedAnimationNode
import Display

private enum MoreIconNodeState: Equatable {
    case more
    case search
    case moreToSearch(Float)
}

private final class MoreIconNode: ManagedAnimationNode {
    private let duration: Double = 0.21
    private var iconState: MoreIconNodeState = .more
    
    init() {
        super.init(size: CGSize(width: 30.0, height: 30.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_moretosearch"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
    }
        
    func play() {
        if case .more = self.iconState {
            self.trackTo(item: ManagedAnimationItem(source: .local("anim_moredots"), frames: .range(startFrame: 0, endFrame: 46), duration: 0.76))
        }
    }
    
    func enqueueState(_ state: MoreIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        let source = ManagedAnimationSource.local("anim_moretosearch")
        
        let totalLength: Int = 90
        if animated {
            switch previousState {
                case .more:
                    switch state {
                        case .more:
                            break
                        case .search:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(progress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: frame), duration: duration))
                    }
                case .search:
                    switch state {
                        case .more:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case .search:
                            break
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double((1.0 - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: frame), duration: duration))
                    }
                case let .moreToSearch(currentProgress):
                    let currentFrame = Int(currentProgress * Float(totalLength))
                    switch state {
                        case .more:
                            let duration = self.duration * Double(currentProgress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: 0), duration: duration))
                        case .search:
                            let duration = self.duration * (1.0 - Double(currentProgress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: totalLength), duration: duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(abs(currentProgress - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: frame), duration: duration))
                    }
            }
        } else {
            switch state {
                case .more:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
                case .search:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                case let .moreToSearch(progress):
                    let frame = Int(progress * Float(totalLength))
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: frame, endFrame: frame), duration: 0.0))
            }
        }
    }
}

final class PeerInfoHeaderNavigationButton: HighlightableButtonNode {
    let containerNode: ContextControllerSourceNode
    let contextSourceNode: ContextReferenceContentNode
    private let regularTextNode: ImmediateTextNode
    private let whiteTextNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private var animationNode: MoreIconNode?
    
    private var key: PeerInfoHeaderNavigationButtonKey?
    private var theme: PresentationTheme?
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                if case .qrCode = self.key, let theme = self.theme {
                    self.iconNode.image = self.isWhite ? generateTintedImage(image: PresentationResourcesRootController.navigationQrCodeIcon(theme), color: .white) : PresentationResourcesRootController.navigationQrCodeIcon(theme)
                } else if case .postStory = self.key, let theme = self.theme {
                    self.iconNode.image = self.isWhite ? generateTintedImage(image: PresentationResourcesRootController.navigationPostStoryIcon(theme), color: .white) : PresentationResourcesRootController.navigationPostStoryIcon(theme)
                }
                
                self.regularTextNode.isHidden = self.isWhite
                self.whiteTextNode.isHidden = !self.isWhite
                self.animationNode?.view.tintColor = self.isWhite ? .white : self.theme?.list.itemAccentColor
                self.animationNode?.imageNode.layer.layerTintColor = self.isWhite ? UIColor.white.cgColor : self.theme?.list.itemAccentColor.cgColor
            }
        }
    }
    
    var action: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init() {
        self.contextSourceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.regularTextNode = ImmediateTextNode()
        self.whiteTextNode = ImmediateTextNode()
        self.whiteTextNode.isHidden = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init(pointerStyle: .insetRectangle(-8.0, 2.0))
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.regularTextNode)
        self.contextSourceNode.addSubnode(self.whiteTextNode)
        self.contextSourceNode.addSubnode(self.iconNode)

        self.addSubnode(self.containerNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.action?(strongSelf.contextSourceNode, gesture)
        }
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        self.animationNode?.play()
        self.action?(self.contextSourceNode, nil)
    }
    
    func update(key: PeerInfoHeaderNavigationButtonKey, presentationData: PresentationData, height: CGFloat) -> CGSize {
        let textSize: CGSize
        let isFirstTime = self.key == nil
        if self.key != key || self.theme !== presentationData.theme {
            self.key = key
            self.theme = presentationData.theme
            
            let text: String
            var accessibilityText: String
            var icon: UIImage?
            var isBold = false
            var isGestureEnabled = false
            var isAnimation = false
            var animationState: MoreIconNodeState = .more
            switch key {
                case .edit:
                    text = presentationData.strings.Common_Edit
                    accessibilityText = text
                case .done, .cancel, .selectionDone:
                    text = presentationData.strings.Common_Done
                    accessibilityText = text
                    isBold = true
                case .select:
                    text = presentationData.strings.Common_Select
                    accessibilityText = text
                case .search:
                    text = ""
                    accessibilityText = presentationData.strings.Common_Search
                    icon = nil// PresentationResourcesRootController.navigationCompactSearchIcon(presentationData.theme)
                    isAnimation = true
                    animationState = .search
                case .editPhoto:
                    text = presentationData.strings.Settings_EditPhoto
                    accessibilityText = text
                case .editVideo:
                    text = presentationData.strings.Settings_EditVideo
                    accessibilityText = text
                case .more:
                    text = ""
                    accessibilityText = presentationData.strings.Common_More
                    icon = nil// PresentationResourcesRootController.navigationMoreCircledIcon(presentationData.theme)
                    isGestureEnabled = true
                    isAnimation = true
                    animationState = .more
                case .qrCode:
                    text = ""
                    accessibilityText = presentationData.strings.PeerInfo_QRCode_Title
                    icon = PresentationResourcesRootController.navigationQrCodeIcon(presentationData.theme)
                case .moreToSearch:
                    text = ""
                    accessibilityText = ""
                case .postStory:
                    text = ""
                    accessibilityText = presentationData.strings.Story_Privacy_PostStory
                    icon = PresentationResourcesRootController.navigationPostStoryIcon(presentationData.theme)
            }
            self.accessibilityLabel = accessibilityText
            self.containerNode.isGestureEnabled = isGestureEnabled
            
            let font: UIFont = isBold ? Font.semibold(17.0) : Font.regular(17.0)
            
            self.regularTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: presentationData.theme.rootController.navigationBar.accentTextColor)
            self.whiteTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: .white)
            self.iconNode.image = icon
            
            if isAnimation {
                self.iconNode.isHidden = true
                let animationNode: MoreIconNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    animationNode = MoreIconNode()
                    self.animationNode = animationNode
                    self.contextSourceNode.addSubnode(animationNode)
                }
                animationNode.customColor = .white
                animationNode.imageNode.layer.layerTintColor = self.isWhite ? UIColor.white.cgColor : presentationData.theme.rootController.navigationBar.accentTextColor.cgColor
                animationNode.enqueueState(animationState, animated: !isFirstTime)
            } else {
                self.iconNode.isHidden = false
                if let current = self.animationNode {
                    self.animationNode = nil
                    current.removeFromSupernode()
                }
            }
            
            textSize = self.regularTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            let _ = self.whiteTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        } else {
            textSize = self.regularTextNode.bounds.size
        }
        
        let inset: CGFloat = 0.0
        
        let textFrame = CGRect(origin: CGPoint(x: inset, y: floor((height - textSize.height) / 2.0)), size: textSize)
        self.regularTextNode.frame = textFrame
        self.whiteTextNode.frame = textFrame
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 30.0, height: 30.0)
            
            animationNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - animationSize.height) / 2.0)), size: animationSize)
            
            let size = CGSize(width: animationSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        } else if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - image.size.height) / 2.0)), size: image.size)
            
            let size = CGSize(width: image.size.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        } else {
            let size = CGSize(width: textSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        }
    }
}
