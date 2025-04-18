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
    case sort
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
        
        var source: ManagedAnimationSource = .local("anim_moretosearch")
        
        let totalLength: Int = 90
        if animated {
            switch previousState {
                case .more:
                    switch state {
                        case .more:
                            break
                        case .search:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case .sort:
                            source = .local("anim_moretosort_l")
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
                        case .sort:
                            source = .local("anim_sorttosearch")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double((1.0 - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: frame), duration: duration))
                    }
                case .sort:
                    switch state {
                        case .more:
                            source = .local("anim_moretosort_l")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case .search:
                            source = .local("anim_sorttosearch")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case .sort:
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
                        case .sort:
                            break
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
                case .sort:
                    source = .local("anim_moretosort_l")
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
    private let textNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private let backIconLayer: SimpleShapeLayer
    private var animationNode: MoreIconNode?
    private let backgroundNode: NavigationBackgroundNode
    
    private var key: PeerInfoHeaderNavigationButtonKey?
    
    private var contentsColor: UIColor = .white
    private var canBeExpanded: Bool = false
    
    var action: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init() {
        self.contextSourceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.textNode = ImmediateTextNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.backIconLayer = SimpleShapeLayer()
        self.backIconLayer.lineWidth = 3.0
        self.backIconLayer.lineCap = .round
        self.backIconLayer.lineJoin = .round
        self.backIconLayer.strokeColor = UIColor.white.cgColor
        self.backIconLayer.fillColor = nil
        self.backIconLayer.isHidden = true
        self.backIconLayer.path = try? convertSvgPath("M10.5,2 L1.5,11 L10.5,20 ")
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: true)
        
        super.init(pointerStyle: .insetRectangle(-8.0, 2.0))
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.backgroundNode)
        self.contextSourceNode.addSubnode(self.textNode)
        self.contextSourceNode.addSubnode(self.iconNode)
        self.contextSourceNode.layer.addSublayer(self.backIconLayer)

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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var boundingRect = self.bounds
        if self.textNode.alpha != 0.0 {
            boundingRect = boundingRect.union(self.textNode.frame)
        }
        boundingRect = boundingRect.insetBy(dx: -8.0, dy: -4.0)
        if boundingRect.contains(point) {
            return super.hitTest(self.bounds.center, with: event)
        } else {
            return nil
        }
    }
    
    func updateContentsColor(backgroundColor: UIColor, contentsColor: UIColor, canBeExpanded: Bool, transition: ContainedViewLayoutTransition) {
        self.contentsColor = contentsColor
        self.canBeExpanded = canBeExpanded
        
        self.backgroundNode.updateColor(color: backgroundColor, transition: transition)
        
        transition.updateTintColor(layer: self.textNode.layer, color: self.contentsColor)
        transition.updateTintColor(view: self.iconNode.view, color: self.contentsColor)
        transition.updateStrokeColor(layer: self.backIconLayer, strokeColor: self.contentsColor)
        
        switch self.key {
        case .back:
            transition.updateAlpha(layer: self.textNode.layer, alpha: canBeExpanded ? 1.0 : 0.0)
            transition.updateTransformScale(node: self.textNode, scale: canBeExpanded ? 1.0 : 0.001)
            
            var iconTransform = CATransform3DIdentity
            iconTransform = CATransform3DScale(iconTransform, canBeExpanded ? 1.0 : 0.8, canBeExpanded ? 1.0 : 0.8, 1.0)
            iconTransform = CATransform3DTranslate(iconTransform, canBeExpanded ? -7.0 : 0.0, 0.0, 0.0)
            transition.updateTransform(node: self.iconNode, transform: CATransform3DGetAffineTransform(iconTransform))
            
            transition.updateTransform(layer: self.backIconLayer, transform: CATransform3DGetAffineTransform(iconTransform))
            transition.updateLineWidth(layer: self.backIconLayer, lineWidth: canBeExpanded ? 3.0 : 2.075)
        default:
            break
        }
        
        if let animationNode = self.animationNode {
            transition.updateTintColor(layer: animationNode.imageNode.layer, color: self.contentsColor)
        }
    }
    
    func update(key: PeerInfoHeaderNavigationButtonKey, presentationData: PresentationData, height: CGFloat) -> CGSize {
        let transition: ContainedViewLayoutTransition = .immediate
        
        var iconOffset = CGPoint()
        switch key {
        case .back:
            iconOffset = CGPoint(x: -1.0, y: 0.0)
        default:
            break
        }
        
        let textSize: CGSize
        let isFirstTime = self.key == nil
        if self.key != key {
            self.key = key
            
            let text: String
            var accessibilityText: String
            var icon: UIImage?
            var isBold = false
            var isGestureEnabled = false
            var isAnimation = false
            var animationState: MoreIconNodeState = .more
            switch key {
            case .back:
                text = presentationData.strings.Common_Back
                accessibilityText = presentationData.strings.Common_Back
                icon = NavigationBar.backArrowImage(color: .white)
            case .edit:
                text = presentationData.strings.Common_Edit
                accessibilityText = text
            case .cancel:
                text = presentationData.strings.Common_Cancel
                accessibilityText = text
                isBold = false
            case .done, .selectionDone:
                text = presentationData.strings.Common_Done
                accessibilityText = text
                isBold = true
            case .select:
                text = presentationData.strings.Common_Select
                accessibilityText = text
            case .search:
                text = ""
                accessibilityText = presentationData.strings.Common_Search
                icon = nil
                isAnimation = true
                animationState = .search
            case .standaloneSearch:
                text = ""
                accessibilityText = presentationData.strings.Common_Search
                icon = PresentationResourcesRootController.navigationCompactSearchWhiteIcon(presentationData.theme)
            case .searchWithTags:
                text = ""
                accessibilityText = presentationData.strings.Common_Search
                icon = PresentationResourcesRootController.navigationCompactTagsSearchWhiteIcon(presentationData.theme)
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
            case .moreSearchSort:
                text = ""
                accessibilityText = ""
            case .postStory:
                text = ""
                accessibilityText = presentationData.strings.Story_Privacy_PostStory
                icon = PresentationResourcesRootController.navigationPostStoryIcon(presentationData.theme)
            case .sort:
                text = ""
                accessibilityText = presentationData.strings.Common_More
                icon = PresentationResourcesRootController.navigationSortIcon(presentationData.theme)
                isAnimation = true
                animationState = .sort
            }
            self.accessibilityLabel = accessibilityText
            self.containerNode.isGestureEnabled = isGestureEnabled
            
            let font: UIFont = isBold ? Font.semibold(17.0) : Font.regular(17.0)
            
            self.textNode.attributedText = NSAttributedString(string: text, font: font, textColor: .white)
            transition.updateTintColor(layer: self.textNode.layer, color: self.contentsColor)
            self.iconNode.image = icon
            transition.updateTintColor(view: self.iconNode.view, color: self.contentsColor)
            
            if isAnimation {
                self.iconNode.isHidden = true
                let animationNode: MoreIconNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    animationNode = MoreIconNode()
                    self.animationNode = animationNode
                    self.contextSourceNode.addSubnode(animationNode)
                    animationNode.imageNode.layer.layerTintColor = self.contentsColor.cgColor
                    animationNode.customColor = .white
                }
                transition.updateTintColor(layer: animationNode.imageNode.layer, color: self.contentsColor)
                animationNode.enqueueState(animationState, animated: !isFirstTime)
            } else {
                self.iconNode.isHidden = false
                if let current = self.animationNode {
                    self.animationNode = nil
                    current.removeFromSupernode()
                }
            }
            
            textSize = self.textNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        } else {
            textSize = self.textNode.bounds.size
        }
        
        let inset: CGFloat = 0.0
        var textInset: CGFloat = 0.0
        switch key {
        case .back:
            textInset += 11.0
        default:
            break
        }
        
        let resultSize: CGSize
        
        let textFrame = CGRect(origin: CGPoint(x: inset + textInset, y: floor((height - textSize.height) / 2.0)), size: textSize)
        self.textNode.position = textFrame.center
        self.textNode.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 30.0, height: 30.0)
            
            animationNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - animationSize.height) / 2.0)), size: animationSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
            
            let size = CGSize(width: animationSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            resultSize = size
        } else if let image = self.iconNode.image {
            let iconFrame = CGRect(origin: CGPoint(x: inset, y: floor((height - image.size.height) / 2.0)), size: image.size).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
            self.iconNode.position = iconFrame.center
            self.iconNode.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            
            if case .back = key {
                self.backIconLayer.position = iconFrame.center
                self.backIconLayer.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
                
                self.iconNode.isHidden = true
                self.backIconLayer.isHidden = false
            } else {
                self.iconNode.isHidden = false
                self.backIconLayer.isHidden = true
            }
            
            let size = CGSize(width: image.size.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            resultSize = size
        } else {
            let size = CGSize(width: textSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            resultSize = size
        }
        
        let diameter: CGFloat = 32.0
        let backgroundWidth: CGFloat
        if self.iconNode.image != nil || self.animationNode != nil {
            backgroundWidth = diameter
        } else {
            backgroundWidth = max(diameter, resultSize.width + 12.0 * 2.0)
        }
        let backgroundFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - backgroundWidth) * 0.5), y: floor((resultSize.height - diameter) * 0.5)), size: CGSize(width: backgroundWidth, height: diameter))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: diameter * 0.5, transition: transition)
        
        self.hitTestSlop = UIEdgeInsets(top: -2.0, left: -12.0, bottom: -2.0, right: -12.0)
        
        return resultSize
    }
}
