import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import CheckNode
import AvatarNode
import PhotoResources
import SemanticStatusNode

private let extensionImageCache = Atomic<[UInt32: UIImage]>(value: [:])

private let redColors: (UInt32, UInt32) = (0xed6b7b, 0xe63f45)
private let greenColors: (UInt32, UInt32) = (0x99de6f, 0x5fb84f)
private let blueColors: (UInt32, UInt32) = (0x72d5fd, 0x2a9ef1)
private let yellowColors: (UInt32, UInt32) = (0xffa24b, 0xed705c)

private let extensionColorsMap: [String: (UInt32, UInt32)] = [
    "ppt": redColors,
    "pptx": redColors,
    "pdf": redColors,
    "key": redColors,
    
    "xls": greenColors,
    "xlsx": greenColors,
    "csv": greenColors,
    
    "zip": yellowColors,
    "rar": yellowColors,
    "gzip": yellowColors,
    "ai": yellowColors
]

private func generateExtensionImage(colors: (UInt32, UInt32)) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.saveGState()
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        let gradientColors = [UIColor(rgb: colors.0).cgColor, UIColor(rgb: colors.1).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.restoreGState()
        
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.2).cgColor)
        context.translateBy(x: 40.0 - 14.0, y: 0.0)
        let _ = try? drawSvgPath(context, path: "M-1,0 L14,0 L14,15 L14,14 C14,12.8954305 13.1045695,12 12,12 L4,12 C2.8954305,12 2,11.1045695 2,10 L2,2 C2,0.8954305 1.1045695,-2.02906125e-16 0,0 L-1,0 L-1,0 Z ")
    })
}

private func extensionImage(fileExtension: String?) -> UIImage? {
    let colors: (UInt32, UInt32)
    if let fileExtension = fileExtension {
        if let extensionColors = extensionColorsMap[fileExtension] {
            colors = extensionColors
        } else {
            colors = blueColors
        }
    } else {
        colors = blueColors
    }
    
    if let cachedImage = (extensionImageCache.with { dict in
        return dict[colors.0]
    }) {
        return cachedImage
    } else if let image = generateExtensionImage(colors: colors) {
        let _ = extensionImageCache.modify { dict in
            var dict = dict
            dict[colors.0] = image
            return dict
        }
        return image
    } else {
        return nil
    }
}
private let extensionFont = Font.with(size: 15.0, design: .round, weight: .bold)
private let mediumExtensionFont = Font.with(size: 14.0, design: .round, weight: .bold)
private let smallExtensionFont = Font.with(size: 12.0, design: .round, weight: .bold)

private final class FileListItemComponent: Component {
    enum Icon: Equatable {
        case fileExtension(String)
        case media(Media, TelegramMediaImageRepresentation)
        case audio
        
        static func ==(lhs: Icon, rhs: Icon) -> Bool {
            switch lhs {
            case let .fileExtension(value):
                if case .fileExtension(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .media(media, representation):
                if case let .media(rhsMedia, rhsRepresentation) = rhs {
                    if media.id != rhsMedia.id {
                        return false
                    }
                    if representation != rhsRepresentation {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case .audio:
                if case .audio = rhs {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let messageId: EngineMessage.Id
    let title: String
    let subtitle: String
    let label: String
    let icon: Icon
    let sideInset: CGFloat
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (EngineMessage.Id) -> Void
    let contextAction: (EngineMessage.Id, ContextExtractedContentContainingView, ContextGesture) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        messageId: EngineMessage.Id,
        title: String,
        subtitle: String,
        label: String,
        icon: Icon,
        sideInset: CGFloat,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping (EngineMessage.Id) -> Void,
        contextAction: @escaping (EngineMessage.Id, ContextExtractedContentContainingView, ContextGesture) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.messageId = messageId
        self.title = title
        self.subtitle = subtitle
        self.label = label
        self.icon = icon
        self.sideInset = sideInset
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
        self.contextAction = contextAction
    }
    
    static func ==(lhs: FileListItemComponent, rhs: FileListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    final class View: ContextControllerSourceView {
        private let extractedContainerView: ContextExtractedContentContainingView
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        
        private var iconView: UIImageView?
        private var iconText: ComponentView<Empty>?
        
        private var iconImageNode: TransformImageNode?
        
        private var semanticStatusNode: SemanticStatusNode?
        
        private var checkLayer: CheckLayer?
        
        private var isExtractedToContextMenu: Bool = false
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        private var component: FileListItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerButton = HighlightTrackingButton()
            
            self.separatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.addSubview(self.extractedContainerView)
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.extractedContainerView.contentView.addSubview(self.containerButton)
            
            self.extractedContainerView.isExtractedToContextPreviewUpdated = { [weak self] value in
                guard let self, let component = self.component else {
                    return
                }
                self.containerButton.clipsToBounds = value
                self.containerButton.backgroundColor = value ? component.theme.list.plainBackgroundColor : nil
                self.containerButton.layer.cornerRadius = value ? 10.0 : 0.0
            }
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, transition in
                guard let self else {
                    return
                }
                self.isExtractedToContextMenu = value
                
                let mappedTransition: ComponentTransition
                if value {
                    mappedTransition = ComponentTransition(transition)
                } else {
                    mappedTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                self.state?.updated(transition: mappedTransition)
            }
            
            self.containerButton.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted, case .none = component.selectionState {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    gesture.cancel()
                    return
                }
                component.contextAction(component.messageId, self.extractedContainerView, gesture)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.messageId)
        }
        
        func update(component: FileListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            var hasSelectionUpdated = false
            if let previousComponent = self.component {
                switch previousComponent.selectionState {
                case .none:
                    if case .none = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                case .editing:
                    if case .editing = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                }
            }
            
            self.component = component
            self.state = state
            
            let contextInset: CGFloat = self.isExtractedToContextMenu ? 12.0 : 0.0
            
            let spacing: CGFloat = 1.0
            let height: CGFloat = 52.0
            let verticalInset: CGFloat = 1.0
            var leftInset: CGFloat = 62.0 + component.sideInset
            var iconLeftInset: CGFloat = component.sideInset
            
            if case let .editing(isSelected) = component.selectionState {
                leftInset += 48.0
                iconLeftInset += 48.0
                
                let checkSize: CGFloat = 22.0
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        checkLayer.theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    checkLayer = CheckLayer(theme: CheckNodeTheme(theme: component.theme, style: .plain))
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: component.sideInset + 20.0, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let rightInset: CGFloat = contextInset * 2.0 + 16.0 + component.sideInset
            
            if case let .fileExtension(text) = component.icon {
                let iconView: UIImageView
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    self.iconView = iconView
                    self.containerButton.addSubview(iconView)
                }
                
                let iconText: ComponentView<Empty>
                if let current = self.iconText {
                    iconText = current
                } else {
                    iconText = ComponentView()
                    self.iconText = iconText
                }
                
                if themeUpdated {
                    iconView.image = extensionImage(fileExtension: "mp3")
                }
                if let image = iconView.image {
                    let iconFrame = CGRect(origin: CGPoint(x: iconLeftInset + floor((leftInset - iconLeftInset - image.size.width) / 2.0), y: floor((height - verticalInset * 2.0 - image.size.height) / 2.0)), size: image.size)
                    transition.setFrame(view: iconView, frame: iconFrame)
                    
                    let iconTextSize = iconText.update(
                        transition: .immediate,
                        component: AnyComponent(Text(
                            text: text,
                            font: text.count > 3 ? mediumExtensionFont : extensionFont,
                            color: .white
                        )),
                        environment: {},
                        containerSize: CGSize(width: iconFrame.width - 4.0, height: 100.0)
                    )
                    if let iconTextView = iconText.view {
                        if iconTextView.superview == nil {
                            self.containerButton.addSubview(iconTextView)
                        }
                        transition.setFrame(view: iconTextView, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((iconFrame.width - iconTextSize.width) / 2.0), y: iconFrame.maxY - iconTextSize.height - 4.0), size: iconTextSize))
                    }
                }
            } else {
                if let iconView = self.iconView {
                    self.iconView = nil
                    iconView.removeFromSuperview()
                }
                if let iconText = self.iconText {
                    self.iconText = nil
                    iconText.view?.removeFromSuperview()
                }
            }
            
            if case let .media(media, representation) = component.icon {
                var resetImage = false
                
                let iconImageNode: TransformImageNode
                if let current = self.iconImageNode {
                    iconImageNode = current
                } else {
                    resetImage = true
                    
                    iconImageNode = TransformImageNode()
                    self.iconImageNode = iconImageNode
                    self.containerButton.addSubview(iconImageNode.view)
                }
                
                let iconSize = CGSize(width: 40.0, height: 40.0)
                let imageSize: CGSize = representation.dimensions.cgSize
                
                if resetImage {
                    if let file = media as? TelegramMediaFile {
                        iconImageNode.setSignal(chatWebpageSnippetFile(
                            account: component.context.account,
                            userLocation: .peer(component.messageId.peerId),
                            mediaReference: FileMediaReference.standalone(media: file).abstract,
                            representation: representation,
                            automaticFetch: false
                        ))
                    } else if let image = media as? TelegramMediaImage {
                        iconImageNode.setSignal(mediaGridMessagePhoto(
                            account: component.context.account,
                            userLocation: .peer(component.messageId.peerId),
                            photoReference: ImageMediaReference.standalone(media: image),
                            automaticFetch: false
                        ))
                    }
                }
                
                let iconFrame = CGRect(origin: CGPoint(x: iconLeftInset + floor((leftInset - iconLeftInset - iconSize.width) / 2.0), y: floor((height - verticalInset * 2.0 - iconSize.height) / 2.0)), size: iconSize)
                transition.setFrame(view: iconImageNode.view, frame: iconFrame)
                
                let iconImageLayout = iconImageNode.asyncLayout()
                let iconImageApply = iconImageLayout(TransformImageArguments(
                    corners: ImageCorners(radius: 8.0),
                    imageSize: imageSize,
                    boundingSize: iconSize,
                    intrinsicInsets: UIEdgeInsets()
                ))
                iconImageApply()
            } else {
                if let iconImageNode = self.iconImageNode {
                    self.iconImageNode = nil
                    iconImageNode.view.removeFromSuperview()
                }
            }
            
            if case .audio = component.icon {
                let semanticStatusNode: SemanticStatusNode
                if let current = self.semanticStatusNode {
                    semanticStatusNode = current
                } else {
                    semanticStatusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white)
                    self.semanticStatusNode = semanticStatusNode
                    self.containerButton.addSubview(semanticStatusNode.view)
                }
                
                let iconSize = CGSize(width: 40.0, height: 40.0)
                let iconFrame = CGRect(origin: CGPoint(x: iconLeftInset + floor((leftInset - iconLeftInset - iconSize.width) / 2.0), y: floor((height - verticalInset * 2.0 - iconSize.height) / 2.0)), size: iconSize)
                transition.setFrame(view: semanticStatusNode.view, frame: iconFrame)
                
                semanticStatusNode.backgroundNodeColor = component.theme.list.itemCheckColors.fillColor
                semanticStatusNode.foregroundNodeColor = component.theme.list.itemCheckColors.foregroundColor
                semanticStatusNode.overlayForegroundNodeColor = .white
                semanticStatusNode.transitionToState(.play)
            } else {
                if let semanticStatusNode = self.semanticStatusNode {
                    self.semanticStatusNode = nil
                    semanticStatusNode.view.removeFromSuperview()
                }
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(16.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - labelSize.width - 4.0, height: 100.0)
            )
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.subtitle, font: Font.regular(14.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - labelSize.width - 4.0, height: 100.0)
            )
            
            let contentHeight = titleSize.height + spacing + subtitleSize.height
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalInset * 2.0 - contentHeight) / 2.0)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + spacing), size: subtitleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
                
                if let previousTitleFrame, let previousTitleContents, previousTitleFrame.size != titleSize {
                    previousTitleContents.frame = CGRect(origin: previousTitleFrame.origin, size: previousTitleFrame.size)
                    self.containerButton.addSubview(previousTitleContents)
                    
                    transition.setFrame(view: previousTitleContents, frame: CGRect(origin: titleFrame.origin, size: previousTitleFrame.size))
                    transition.setAlpha(view: previousTitleContents, alpha: 0.0, completion: { [weak previousTitleContents] _ in
                        previousTitleContents?.removeFromSuperview()
                    })
                    transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                }
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    subtitleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize))
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + ((component.hasNext) ? UIScreenPixel : 0.0)))
            
            let resultBounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.extractedContainerView, frame: resultBounds)
            transition.setFrame(view: self.extractedContainerView.contentView, frame: resultBounds)
            self.extractedContainerView.contentRect = resultBounds
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class StorageFileListPanelComponent: Component {    
    typealias EnvironmentType = StorageUsagePanelEnvironment
    
    final class Item: Equatable {
        let message: Message
        let size: Int64
        
        init(
            message: Message,
            size: Int64
        ) {
            self.message = message
            self.size = size
        }
        
        static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.message.id != rhs.message.id {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    final class Items: Equatable {
        let items: [Item]
        
        init(items: [Item]) {
            self.items = items
        }
        
        static func ==(lhs: Items, rhs: Items) -> Bool {
            if lhs === rhs {
                return true
            }
            return lhs.items == rhs.items
        }
    }
    
    let context: AccountContext
    let items: Items?
    let selectionState: StorageUsageScreenComponent.SelectionState?
    let action: (EngineMessage.Id) -> Void
    let contextAction: (EngineMessage.Id, ContextExtractedContentContainingView, ContextGesture) -> Void

    init(
        context: AccountContext,
        items: Items?,
        selectionState: StorageUsageScreenComponent.SelectionState?,
        action: @escaping (EngineMessage.Id) -> Void,
        contextAction: @escaping (EngineMessage.Id, ContextExtractedContentContainingView, ContextGesture) -> Void
    ) {
        self.context = context
        self.items = items
        self.selectionState = selectionState
        self.action = action
        self.contextAction = contextAction
    }
    
    static func ==(lhs: StorageFileListPanelComponent, rhs: StorageFileListPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        let containerInsets: UIEdgeInsets
        let containerWidth: CGFloat
        let itemHeight: CGFloat
        let itemCount: Int
        
        let contentHeight: CGFloat
        
        init(
            containerInsets: UIEdgeInsets,
            containerWidth: CGFloat,
            itemHeight: CGFloat,
            itemCount: Int
        ) {
            self.containerInsets = containerInsets
            self.containerWidth = containerWidth
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            
            self.contentHeight = containerInsets.top + containerInsets.bottom + CGFloat(itemCount) * itemHeight
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -self.containerInsets.top)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemHeight)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemHeight)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: 0.0, y: self.containerInsets.top + CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerWidth, height: self.itemHeight))
        }
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private let measureItem = ComponentView<Empty>()
        private var visibleItems: [EngineMessage.Id: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        
        private var component: StorageFileListPanelComponent?
        private var environment: StorageUsagePanelEnvironment?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollViewImpl()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            cancelContextGestures(view: scrollView)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let items = component.items, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
            
            let dataSizeFormatting = DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")
            
            var validIds = Set<EngineMessage.Id>()
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= items.items.count {
                        continue
                    }
                    let item = items.items[index]
                    let id = item.message.id
                    validIds.insert(id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.visibleItems[id] {
                        itemView = current
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.visibleItems[id] = itemView
                    }
                    
                    let itemSelectionState: FileListItemComponent.SelectionState
                    if let selectionState = component.selectionState {
                        itemSelectionState = .editing(isSelected: selectionState.selectedMessages.contains(id))
                    } else {
                        itemSelectionState = .none
                    }
                    
                    var isAudio: Bool = false
                    var isVoice: Bool = false
                    
                    let _ = isAudio
                    let _ = isVoice
                    
                    var title: String = environment.strings.Message_File
                    
                    var subtitle = stringForFullDate(timestamp: item.message.timestamp, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)
                    
                    var extensionIconValue: String?
                    var imageIconValue: FileListItemComponent.Icon?
                    
                    for media in item.message.media {
                        if let file = media as? TelegramMediaFile {
                            let isInstantVideo = file.isInstantVideo
                            
                            for attribute in file.attributes {
                                if case let .Audio(voice, duration, titleValue, performer, _) = attribute {
                                    let _ = duration
                                    
                                    isAudio = true
                                    isVoice = voice
                                    
                                    title = titleValue ?? (file.fileName ?? "Unknown Track")
                                    
                                    if let performer = performer {
                                        subtitle = performer
                                        //descriptionString = "\(stringForDuration(Int32(duration))) • \(performer)"
                                    }
                                    
                                    if !voice {
                                        if file.fileName?.lowercased().hasSuffix(".ogg") == true {
                                            //iconImage = .albumArt(file, SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: "", performer: "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: "", performer: "", isThumbnail: false)))
                                        } else {
                                            //iconImage = .albumArt(file, SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: false)))
                                        }
                                    } else {
                                        title = environment.strings.Message_Audio
                                    }
                                }
                            }
                            
                            if isInstantVideo || isVoice {
                                /*var authorName: String
                                if let author = message.forwardInfo?.author {
                                    if author.id == item.context.account.peerId {
                                        authorName = item.presentationData.strings.DialogList_You
                                    } else {
                                        authorName = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                    }
                                } else if let signature = message.forwardInfo?.authorSignature {
                                    authorName = signature
                                } else if let author = message.author {
                                    if author.id == item.context.account.peerId {
                                        authorName = item.presentationData.strings.DialogList_You
                                    } else {
                                        authorName = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                    }
                                } else {
                                    authorName = " "
                                }
                                
                                if item.isGlobalSearchResult || item.isDownloadList {
                                    let authorString = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
                                    if authorString.count > 1 {
                                        globalAuthorTitle = authorString.last ?? ""
                                    }
                                    authorName = authorString.first ?? ""
                                }
                                
                                titleText = NSAttributedString(string: authorName, font: audioTitleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                let dateString = stringForFullDate(timestamp: message.timestamp, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat)
                                var descriptionString: String = ""
                                if let duration = file.duration {
                                    if item.isGlobalSearchResult || item.isDownloadList || !item.displayFileInfo {
                                        descriptionString = stringForDuration(Int32(duration))
                                    } else {
                                        descriptionString = "\(stringForDuration(Int32(duration))) • \(dateString)"
                                    }
                                } else {
                                    if !(item.isGlobalSearchResult || item.isDownloadList) {
                                        descriptionString = dateString
                                    }
                                }
                                
                                descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                                iconImage = .roundVideo(file)*/
                            } else if !isAudio {
                                var fileName: String = file.fileName ?? environment.strings.Message_File
                                if file.isVideo {
                                    fileName = environment.strings.Message_Video
                                }
                                title = fileName
                                
                                var fileExtension: String?
                                if let range = fileName.range(of: ".", options: [.backwards]) {
                                    fileExtension = fileName[range.upperBound...].lowercased()
                                }
                                extensionIconValue = fileExtension
                                
                                if let representation = smallestImageRepresentation(file.previewRepresentations) {
                                    imageIconValue = .media(file, representation)
                                }
                            }
                        } else if let image = media as? TelegramMediaImage {
                            title = environment.strings.Message_Photo
                            
                            if let representation = largestImageRepresentation(image.representations) {
                                imageIconValue = .media(image, representation)
                            }
                        }
                    }
                    
                    var icon: FileListItemComponent.Icon = .fileExtension(" ")
                    if let imageIconValue {
                        icon = imageIconValue
                    } else if isAudio {
                        icon = .audio
                    } else if let extensionIconValue {
                        icon = .fileExtension(extensionIconValue)
                    }
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(FileListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            messageId: item.message.id,
                            title: title,
                            subtitle: subtitle,
                            label: dataSizeString(item.size, formatting: dataSizeFormatting),
                            icon: icon,
                            sideInset: environment.containerInsets.left,
                            selectionState: itemSelectionState,
                            hasNext: index != items.items.count - 1,
                            action: component.action,
                            contextAction: component.contextAction
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerWidth, height: itemLayout.itemHeight)
                    )
                    let itemFrame = itemLayout.itemFrame(for: index)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removeIds: [EngineMessage.Id] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func update(component: StorageFileListPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[StorageUsagePanelEnvironment.self].value
            self.environment = environment
            
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(FileListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    messageId: EngineMessage.Id(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(0)), namespace: 0, id: 0),
                    title: "ABCDEF",
                    subtitle: "ABCDEF",
                    label: "1000",
                    icon: .fileExtension("file"),
                    sideInset: environment.containerInsets.left,
                    selectionState: .none,
                    hasNext: false,
                    action: { _ in
                    },
                    contextAction: { _, _, _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            let itemLayout = ItemLayout(
                containerInsets: environment.containerInsets,
                containerWidth: availableSize.width,
                itemHeight: measureItemSize.height,
                itemCount: component.items?.items.count ?? 0
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            var scrollBounds = self.scrollView.bounds
            scrollBounds.size = availableSize
            if !environment.isScrollable {
                scrollBounds.origin = CGPoint()
            }
            transition.setBounds(view: self.scrollView, bounds: scrollBounds)
            self.scrollView.isScrollEnabled = environment.isScrollable
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.verticalScrollIndicatorInsets = environment.containerInsets
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
