import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle
import ContextUI

private let closeImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Close"), color: .black)
private let settingsImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings"), color: .black)

private func navigationBarContentNode(for state: BrowserState, currentContentNode: BrowserNavigationBarContentNode?, layoutMetrics: LayoutMetrics, theme: BrowserNavigationBarTheme, strings: PresentationStrings, interaction: BrowserInteraction?) -> BrowserNavigationBarContentNode? {
    if let _ = state.search {
        if let currentContentNode = currentContentNode as? BrowserNavigationBarSearchContentNode {
            currentContentNode.updateState(state)
            return currentContentNode
        } else {
            return BrowserNavigationBarSearchContentNode(theme: theme, strings: strings, state: state, interaction: interaction)
        }
    }
    return nil
}

final class BrowserNavigationBarTheme {
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let primaryTextColor: UIColor
    let loadingProgressColor: UIColor
    let readingProgressColor: UIColor
    let buttonColor: UIColor
    let disabledButtonColor: UIColor
    let searchBarFieldColor: UIColor
    let searchBarTextColor: UIColor
    let searchBarPlaceholderColor: UIColor
    let searchBarIconColor: UIColor
    let searchBarClearColor: UIColor
    let searchBarKeyboardColor: PresentationThemeKeyboardColor
    
    init(backgroundColor: UIColor, separatorColor: UIColor, primaryTextColor: UIColor, loadingProgressColor: UIColor, readingProgressColor: UIColor, buttonColor: UIColor, disabledButtonColor: UIColor, searchBarFieldColor: UIColor, searchBarTextColor: UIColor, searchBarPlaceholderColor: UIColor, searchBarIconColor: UIColor, searchBarClearColor: UIColor, searchBarKeyboardColor: PresentationThemeKeyboardColor) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.primaryTextColor = primaryTextColor
        self.loadingProgressColor = loadingProgressColor
        self.readingProgressColor = readingProgressColor
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.searchBarFieldColor = searchBarFieldColor
        self.searchBarTextColor = searchBarTextColor
        self.searchBarPlaceholderColor = searchBarPlaceholderColor
        self.searchBarIconColor = searchBarIconColor
        self.searchBarClearColor = searchBarClearColor
        self.searchBarKeyboardColor = searchBarKeyboardColor
    }
}

protocol BrowserNavigationBarContentNode: ASDisplayNode {
    init(theme: BrowserNavigationBarTheme, strings: PresentationStrings, state: BrowserState, interaction: BrowserInteraction?)
    func updateState(_ state: BrowserState)
    func updateTheme(_ theme: BrowserNavigationBarTheme)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

private final class BrowserLoadingProgressNode: ASDisplayNode {
    private var theme: BrowserNavigationBarTheme
    
    private let foregroundNode: ASDisplayNode
    
    init(theme: BrowserNavigationBarTheme) {
        self.theme = theme
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.backgroundColor = theme.loadingProgressColor
        
        super.init()
        
        self.addSubnode(self.foregroundNode)
    }
    
    func updateTheme(_ theme: BrowserNavigationBarTheme) {
        self.theme = theme
        
        self.foregroundNode.backgroundColor = theme.loadingProgressColor
    }
    
    private var _progress: CGFloat = 0.0
    func updateProgress(_ progress: CGFloat, animated: Bool = false) {
        if self._progress == progress && animated {
            return
        }
        
        var animated = animated
        if (progress < self._progress && animated) {
            animated = false
        }
        
        let size = self.bounds.size
        
        self._progress = progress
        
        let transition: ContainedViewLayoutTransition
        if animated && progress > 0.0 {
            transition = .animated(duration: 0.7, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let alpaTransition: ContainedViewLayoutTransition
        if animated {
            alpaTransition = .animated(duration: 0.3, curve: .easeInOut)
        } else {
            alpaTransition = .immediate
        }
        
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width * progress, height: size.height))
        
        let alpha: CGFloat = progress < 0.001 || progress > 0.999 ? 0.0 : 1.0
        alpaTransition.updateAlpha(node: self.foregroundNode, alpha: alpha)
    }
}

var browserNavigationBarHeight: CGFloat = 56.0
var browserNavigationBarCollapsedHeight: CGFloat = 24.0

final class BrowserNavigationBar: ASDisplayNode {
    private var theme: BrowserNavigationBarTheme
    private var strings: PresentationStrings
    private var state: BrowserState
    var interaction: BrowserInteraction?
    
    private let containerNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let readingProgressNode: ASDisplayNode
    private let loadingProgressNode: BrowserLoadingProgressNode
    
    private let closeButton: HighlightableButtonNode
    private let closeIconNode: ASImageNode
    private let closeIconSmallNode: ASImageNode
    let contextSourceNode: ContextExtractedContentContainingNode
    private let backButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let shareButton: HighlightableButtonNode
    private let minimizeButton: HighlightableButtonNode
    private let settingsButton: HighlightableButtonNode
    private let titleNode: ImmediateTextNode
    private let scrollToTopButton: HighlightableButtonNode
    private var contentNode: BrowserNavigationBarContentNode?
       
    private let intrinsicSettingsSize: CGSize
    private let intrinsicSmallSettingsSize: CGSize
    
    private var validLayout: (CGSize, UIEdgeInsets, LayoutMetrics, CGFloat, CGFloat)?
              
    private var title: (String, Bool) = ("", false) {
        didSet {
            self.updateTitle()
        }
    }
    private func updateTitle() {
       if let (size, insets, layoutMetrics, readingProgress, collapseTransition) = self.validLayout {
        self.titleNode.attributedText = NSAttributedString(string: self.title.0, font: Font.with(size: 17.0, design: self.title.1 ? .serif : .regular, weight: .bold), textColor: self.theme.primaryTextColor, paragraphAlignment: .center)
            let sideInset: CGFloat = 56.0
            self.titleNode.transform = CATransform3DIdentity
            let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - insets.left - insets.right - sideInset * 2.0, height: size.height))
            self.titleNode.frame = CGRect(origin: CGPoint(x: (size.width - titleSize.width) / 2.0, y: size.height - 30.0), size: titleSize)
            
            self.updateLayout(size: size, insets: insets, layoutMetrics: layoutMetrics, readingProgress: readingProgress, collapseTransition: collapseTransition, transition: .immediate)
        }
    }
       
    var close: (() -> Void)?
    var openSettings: (() -> Void)?
    var scrollToTop: (() -> Void)?
    
    init(theme: BrowserNavigationBarTheme, strings: PresentationStrings, state: BrowserState) {
        self.theme = theme
        self.strings = strings
        self.state = state
        
        self.containerNode = ASDisplayNode()

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.separatorColor
        
        self.readingProgressNode = ASDisplayNode()
        self.readingProgressNode.isLayerBacked = true
        self.readingProgressNode.backgroundColor = theme.readingProgressColor
             
        self.closeButton = HighlightableButtonNode()
        self.closeButton.allowsGroupOpacity = true
        self.closeIconNode = ASImageNode()
        self.closeIconNode.displaysAsynchronously = false
        self.closeIconNode.displayWithoutProcessing = true
        self.closeIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Close"), color: theme.buttonColor)
        self.closeIconSmallNode = ASImageNode()
        self.closeIconSmallNode.displaysAsynchronously = false
        self.closeIconSmallNode.displayWithoutProcessing = true
        self.closeIconSmallNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/CloseSmall"), color: theme.buttonColor)
        self.closeIconSmallNode.alpha = 0.0
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        
        self.settingsButton = HighlightableButtonNode()
        self.settingsButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings"), color: theme.buttonColor), for: [])
        self.intrinsicSettingsSize = CGSize(width: browserNavigationBarHeight, height: browserNavigationBarHeight)
        self.intrinsicSmallSettingsSize = CGSize(width: browserNavigationBarCollapsedHeight, height: browserNavigationBarCollapsedHeight)
        self.settingsButton.frame = CGRect(origin: CGPoint(), size: self.intrinsicSettingsSize)
        
        self.backButton = HighlightableButtonNode()
        self.backButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Back"), color: theme.buttonColor), for: [])
        self.backButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Back"), color: theme.disabledButtonColor), for: [.disabled])
        self.forwardButton = HighlightableButtonNode()
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Forward"), color: theme.buttonColor), for: [])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Forward"), color: theme.disabledButtonColor), for: [.disabled])
        self.shareButton = HighlightableButtonNode()
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.buttonColor), for: [])
        self.minimizeButton = HighlightableButtonNode()
        self.minimizeButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Minimize"), color: theme.buttonColor), for: [])
                    
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        self.titleNode.maximumNumberOfLines = 1
        
        self.scrollToTopButton = HighlightableButtonNode()
        
        self.loadingProgressNode = BrowserLoadingProgressNode(theme: theme)
             
        super.init()
             
        self.clipsToBounds = true
        self.containerNode.backgroundColor = theme.backgroundColor
                 
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.readingProgressNode)
        self.containerNode.addSubnode(self.closeButton)
        self.closeButton.addSubnode(self.closeIconNode)
        self.closeButton.addSubnode(self.closeIconSmallNode)
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.settingsButton)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.scrollToTopButton)
        self.containerNode.addSubnode(self.loadingProgressNode)
        self.containerNode.addSubnode(self.separatorNode)
             
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
        self.settingsButton.addTarget(self, action: #selector(self.settingsPressed), forControlEvents: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTopPressed), forControlEvents: .touchUpInside)
        
        self.title = (state.content?.title ?? "", state.content?.isInstant ?? false)
    }
    
    func updateState(_ state: BrowserState) {
        self.state = state
        
        if let (size, insets, layoutMetrics, readingProgress, collapseTransition) = self.validLayout {
            self.updateLayout(size: size, insets: insets, layoutMetrics: layoutMetrics, readingProgress: readingProgress, collapseTransition: collapseTransition, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        self.title = (state.content?.title ?? "", state.content?.isInstant ?? false)
        self.loadingProgressNode.updateProgress(CGFloat(state.content?.estimatedProgress ?? 0.0), animated: true)
    }
    
    func updateTheme(_ theme: BrowserNavigationBarTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.containerNode.backgroundColor = theme.backgroundColor
        self.separatorNode.backgroundColor = theme.separatorColor
        self.closeIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Close"), color: theme.buttonColor)
        self.closeIconSmallNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/CloseSmall"), color: theme.buttonColor)
        self.settingsButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings"), color: theme.buttonColor), for: [])
        self.readingProgressNode.backgroundColor = theme.readingProgressColor
        self.loadingProgressNode.updateTheme(theme)
        self.updateTitle()
    }
    
    @objc private func closePressed() {
        self.close?()
    }
    
    @objc private func settingsPressed() {
        self.openSettings?()
    }

    @objc private func scrollToTopPressed() {
        self.scrollToTop?()
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, layoutMetrics: LayoutMetrics, readingProgress: CGFloat, collapseTransition: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, insets, layoutMetrics, readingProgress, collapseTransition)
        
        var dismissedContentNode: ASDisplayNode?
        var immediatelyLayoutContentNodeAndAnimateAppearance = false
        if let contentNode = navigationBarContentNode(for: self.state, currentContentNode: self.contentNode, layoutMetrics: layoutMetrics, theme: self.theme, strings: self.strings, interaction: self.interaction) {
            if contentNode !== self.contentNode {
                dismissedContentNode = self.contentNode
                immediatelyLayoutContentNodeAndAnimateAppearance = true
                self.containerNode.insertSubnode(contentNode, belowSubnode: self.separatorNode)
                self.contentNode = contentNode
            }
        } else {
            dismissedContentNode = self.contentNode
            self.contentNode = nil
        }
        
        let expandTransition = 1.0 - collapseTransition
        
        let maxBarHeight: CGFloat
        let minBarHeight: CGFloat
        if insets.top.isZero {
            maxBarHeight = browserNavigationBarHeight
            minBarHeight = browserNavigationBarCollapsedHeight
        } else {
            maxBarHeight = insets.top + 44.0
            minBarHeight = insets.top + browserNavigationBarCollapsedHeight
        }
        
        let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: -(maxBarHeight - minBarHeight) * collapseTransition), size: size)
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        
        transition.updateFrame(node: self.readingProgressNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: floorToScreenPixels(size.width * readingProgress), height: size.height)))
                
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: size.height)))
        if let image = self.closeIconNode.image {
            let closeIconSize = image.size

            let arrowHeight: CGFloat
            if expandTransition < 1.0 {
                arrowHeight = floor(12.0 * expandTransition + 18.0)
            } else {
                arrowHeight = 30.0
            }
            let scaledIconSize = CGSize(width: closeIconSize.width * arrowHeight / closeIconSize.height, height: arrowHeight)
            let arrowOffset = floor(9.0 * expandTransition + 3.0)
            transition.updateFrame(node: self.closeIconNode, frame: CGRect(origin: CGPoint(x: insets.left + 8.0, y: size.height - arrowHeight - arrowOffset), size: scaledIconSize))
        }
        
        let offsetScaleTransition: CGFloat
        let buttonScaleTransition: CGFloat
        if expandTransition < 1.0 {
            offsetScaleTransition = expandTransition
            buttonScaleTransition = ((expandTransition * self.intrinsicSettingsSize.height) + ((1.0 - expandTransition) * self.intrinsicSmallSettingsSize.height)) / self.intrinsicSettingsSize.height
        } else {
            offsetScaleTransition = 1.0
            buttonScaleTransition = 1.0
        }
        
        let alphaTransition = min(1.0, offsetScaleTransition * offsetScaleTransition)
                
        let maxSettingsOffset = floor(self.intrinsicSettingsSize.height / 2.0)
        let minSettingsOffset = floor(self.intrinsicSmallSettingsSize.height / 2.0)
        let settingsOffset = expandTransition * maxSettingsOffset + (1.0 - expandTransition) * minSettingsOffset
        
        transition.updateTransformScale(node: self.titleNode, scale: 0.65 + expandTransition * 0.35)
        transition.updatePosition(node: self.titleNode, position: CGPoint(x: size.width / 2.0, y: size.height - settingsOffset))
        
        self.contextSourceNode.frame = CGRect(origin: CGPoint(x: size.width - 56.0, y: 0.0), size: CGSize(width: 56.0, height: 56.0))
        
        transition.updateTransformScale(node: self.settingsButton, scale: buttonScaleTransition)
        transition.updatePosition(node: self.settingsButton, position: CGPoint(x: 56.0 - insets.right - buttonScaleTransition * self.intrinsicSettingsSize.width / 2.0, y: size.height - settingsOffset))
        transition.updateAlpha(node: self.settingsButton, alpha: alphaTransition)
        
        transition.updateFrame(node: self.scrollToTopButton, frame: CGRect(origin: CGPoint(x: insets.left + 64.0, y: 0.0), size: CGSize(width: size.width - insets.left - insets.right - 64.0 * 2.0, height: size.height)))
        
        let loadingProgressHeight: CGFloat = 2.0
        transition.updateFrame(node: self.loadingProgressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - loadingProgressHeight - UIScreenPixel), size: CGSize(width: size.width, height: loadingProgressHeight)))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let constrainedSize = CGSize(width: size.width, height: size.height)
        
        if let contentNode = self.contentNode {
            let contentNodeFrame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: constrainedSize)
            contentNode.updateLayout(size: constrainedSize, transition: transition)
            
            if immediatelyLayoutContentNodeAndAnimateAppearance {
                contentNode.alpha = 0.0
            }
            
            transition.updateFrame(node: contentNode, frame: contentNodeFrame)
            transition.updateAlpha(node: contentNode, alpha: 1.0)
        }
        
        if let dismissedContentNode = dismissedContentNode {
            var alphaCompleted = false
            let frameCompleted = true
            let completed = { [weak self, weak dismissedContentNode] in
                if let strongSelf = self, let dismissedContentNode = dismissedContentNode, strongSelf.contentNode === dismissedContentNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedContentNode?.removeFromSupernode()
                }
            }
            
            transition.updateAlpha(node: dismissedContentNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
        }
        
        if !hadValidLayout {
            self.updateTitle()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.isDescendant(of: self.containerNode.view) || result == self.containerNode.view {
            return result
        }
        return nil
    }
}
