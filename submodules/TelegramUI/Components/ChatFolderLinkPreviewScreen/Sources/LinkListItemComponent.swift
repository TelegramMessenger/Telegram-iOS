import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramCore
import CheckNode

func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}

final class LinkListItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    let theme: PresentationTheme
    let sideInset: CGFloat
    let title: String
    let link: ExportedChatFolderLink
    let label: String
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (ExportedChatFolderLink) -> Void
    let contextAction: (ExportedChatFolderLink, ContextExtractedContentContainingView, ContextGesture) -> Void
    
    init(
        theme: PresentationTheme,
        sideInset: CGFloat,
        title: String,
        link: ExportedChatFolderLink,
        label: String,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping (ExportedChatFolderLink) -> Void,
        contextAction: @escaping (ExportedChatFolderLink, ContextExtractedContentContainingView, ContextGesture) -> Void
    ) {
        self.theme = theme
        self.sideInset = sideInset
        self.title = title
        self.link = link
        self.label = label
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
        self.contextAction = contextAction
    }
    
    static func ==(lhs: LinkListItemComponent, rhs: LinkListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        if lhs.label != rhs.label {
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
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let iconView: UIImageView
        private let iconBackgroundView: UIImageView
        
        private var checkLayer: CheckLayer?
        
        private var isExtractedToContextMenu: Bool = false
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        private var component: LinkListItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerButton = HighlightTrackingButton()
            
            self.iconView = UIImageView()
            self.iconBackgroundView = UIImageView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.addSubview(self.extractedContainerView)
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.extractedContainerView.contentView.addSubview(self.containerButton)
            
            self.containerButton.addSubview(self.iconBackgroundView)
            self.containerButton.addSubview(self.iconView)
            
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
                
                let mappedTransition: Transition
                if value {
                    mappedTransition = Transition(transition)
                } else {
                    mappedTransition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
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
                component.contextAction(component.link, self.extractedContainerView, gesture)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.link)
        }
        
        func update(component: LinkListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            let contextInset: CGFloat = self.isExtractedToContextMenu ? 12.0 : 0.0
            
            let height: CGFloat = 60.0
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
            
            if themeUpdated {
                self.iconBackgroundView.image = generateFilledCircleImage(diameter: 40.0, color: component.theme.list.itemCheckColors.fillColor)
                self.iconView.image = UIImage(bundleImageName: "Chat/Context Menu/Link")?.withRenderingMode(.alwaysTemplate)
                self.iconView.tintColor = component.theme.list.itemCheckColors.foregroundColor
            }
            
            if let iconImage = self.iconView.image {
                transition.setFrame(view: self.iconBackgroundView, frame: CGRect(origin: CGPoint(x: iconLeftInset + floor((leftInset - iconLeftInset - 40.0) * 0.5), y: floor((height - 40.0) * 0.5)), size: CGSize(width: 40.0, height: 40.0)))
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: iconLeftInset + floor((leftInset - iconLeftInset - iconImage.size.width) * 0.5), y: floor((height - iconImage.size.height) * 0.5)), size: iconImage.size))
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.regular(14.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleSpacing: CGFloat = 1.0
            
            let contentHeight: CGFloat = titleSize.height + titleSpacing + labelSize.height
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalInset * 2.0 - contentHeight) / 2.0)), size: titleSize)
            let labelFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: labelSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    titleView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    labelView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(labelView)
                }
                transition.setPosition(view: labelView, position: labelFrame.origin)
                labelView.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

