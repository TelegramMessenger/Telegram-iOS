import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent

enum PeerInfoHeaderNavigationButtonKey {
    case back
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
    case searchWithTags
    case standaloneSearch
    case editPhoto
    case editVideo
    case more
    case sort
    case qrCode
    case moreSearchSort
    case postStory
}

struct PeerInfoHeaderNavigationButtonSpec: Hashable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

final class PeerInfoHeaderNavigationButtonContainerNode: SparseNode {
    private var presentationData: PresentationData?
    
    private let backgroundContainer: GlassBackgroundContainerView
    let leftButtonsBackground: GlassContextExtractableContainer
    let rightButtonsBackground: GlassContextExtractableContainer
    private let leftButtonsContainer: UIView
    private let rightButtonsContainer: UIView
    
    private(set) var leftButtonNodes: [PeerInfoHeaderNavigationButtonSpec: PeerInfoHeaderNavigationButton] = [:]
    private(set) var rightButtonNodes: [PeerInfoHeaderNavigationButtonSpec: PeerInfoHeaderNavigationButton] = [:]
    
    private var currentLeftButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    private var currentRightButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    
    private var backgroundContentColor: UIColor = .clear
    private var isOverColoredContents: Bool = false
    private var contentsColor: UIColor = .white
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey, ContextReferenceContentNode?, ContextGesture?) -> Void)?
    
    override init() {
        self.backgroundContainer = GlassBackgroundContainerView()
        self.leftButtonsBackground = GlassContextExtractableContainer()
        self.rightButtonsBackground = GlassContextExtractableContainer()
        
        self.leftButtonsContainer = UIView()
        self.leftButtonsContainer.clipsToBounds = true
        self.rightButtonsContainer = UIView()
        self.rightButtonsContainer.clipsToBounds = true
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
        self.backgroundContainer.contentView.addSubview(self.leftButtonsBackground)
        self.backgroundContainer.contentView.addSubview(self.rightButtonsBackground)
        
        self.leftButtonsBackground.contentView.addSubview(self.leftButtonsContainer)
        self.rightButtonsBackground.contentView.addSubview(self.rightButtonsContainer)
    }
    
    func updateContentsColor(backgroundContentColor: UIColor, contentsColor: UIColor, isOverColoredContents: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundContentColor = backgroundContentColor
        self.isOverColoredContents = isOverColoredContents
        self.contentsColor = contentsColor
        
        guard let presentationData = self.presentationData else {
            return
        }
        
        let normalButtonContentsColor: UIColor = self.isOverColoredContents ? .white :  presentationData.theme.chat.inputPanel.panelControlColor
        let expandedButtonContentsColor: UIColor = presentationData.theme.chat.inputPanel.panelControlColor
        
        for (spec, button) in self.leftButtonNodes {
            button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
        }
        
        for spec in self.currentRightButtons {
            guard let button = self.rightButtonNodes[spec] else {
                continue
            }
            button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
        }
        for (spec, button) in self.rightButtonNodes {
            if !self.currentRightButtons.contains(where: { $0 == spec }) {
                button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
            }
        }
        
        self.updateBackgroundColors(transition: ComponentTransition(transition))
    }
    
    func update(size: CGSize, presentationData: PresentationData, leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, shouldAnimateIn: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        
        let buttonHeight: CGFloat = 44.0
        
        let sideInset: CGFloat = 16.0
        
        var normalLeftButtonsWidth: CGFloat = 0.0
        var expandedLeftButtonsWidth: CGFloat = 0.0
        
        let maxBlur: CGFloat = 5.0
        
        let normalButtonContentsColor: UIColor = self.isOverColoredContents ? .white :  presentationData.theme.chat.inputPanel.panelControlColor
        let expandedButtonContentsColor: UIColor = presentationData.theme.chat.inputPanel.panelControlColor
        
        if self.currentLeftButtons != leftButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentLeftButtons = leftButtons
            
            for spec in leftButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                if let current = self.leftButtonNodes[spec] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.leftButtonNodes[spec] = buttonNode
                    self.leftButtonsContainer.addSubview(buttonNode.view)
                    buttonNode.action = { [weak self] _, gesture in
                        guard let strongSelf = self, let buttonNode = strongSelf.leftButtonNodes[spec] else {
                            return
                        }
                        strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                    }
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: buttonHeight)
                let buttonFrame = CGRect(origin: CGPoint(x: spec.isForExpandedView ? expandedLeftButtonsWidth : normalLeftButtonsWidth, y: 0.0), size: buttonSize)
                
                if spec.isForExpandedView {
                    expandedLeftButtonsWidth += buttonSize.width
                } else {
                    normalLeftButtonsWidth += buttonSize.width
                }
                let alphaFactor: CGFloat
                if case .back = spec.key {
                    alphaFactor = 1.0
                } else {
                    alphaFactor = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                }
                
                if wasAdded {
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    ComponentTransition.immediate.setBlur(layer: buttonNode.layer, radius: maxBlur)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: 0.0)
                    buttonNode.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: .immediate)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonSpec] = []
            for (spec, _) in self.leftButtonNodes {
                if !leftButtons.contains(where: { $0 == spec }) {
                    removeKeys.append(spec)
                }
            }
            for spec in removeKeys {
                if let buttonNode = self.leftButtonNodes.removeValue(forKey: spec) {
                    buttonNode.view.removeFromSuperview()
                }
            }
        } else {
            for spec in leftButtons.reversed() {
                if let buttonNode = self.leftButtonNodes[spec] {
                    let buttonSize = buttonNode.bounds.size
                    let buttonFrame = CGRect(origin: CGPoint(x: spec.isForExpandedView ? expandedLeftButtonsWidth : normalLeftButtonsWidth, y: 0.0), size: buttonSize)
                    if spec.isForExpandedView {
                        expandedLeftButtonsWidth += buttonSize.width
                    } else {
                        normalLeftButtonsWidth += buttonSize.width
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat
                    if case .back = spec.key {
                        alphaFactor = 1.0
                    } else {
                        alphaFactor = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    }
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(buttonTransition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
        }
        
        var normalRightButtonsWidth: CGFloat = 0.0
        var expandedRightButtonsWidth: CGFloat = 0.0
        
        if self.currentRightButtons != rightButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentRightButtons = rightButtons
            
            for spec in rightButtons {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                
                var key = spec.key
                if key == .more || key == .search || key == .sort {
                    key = .moreSearchSort
                }
                
                if let current = self.rightButtonNodes[spec] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.rightButtonNodes[spec] = buttonNode
                    self.rightButtonsContainer.addSubview(buttonNode.view)
                }
                buttonNode.action = { [weak self] _, gesture in
                    guard let strongSelf = self, let buttonNode = strongSelf.rightButtonNodes[spec] else {
                        return
                    }
                    strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: buttonHeight)
                let buttonFrame = CGRect(origin: CGPoint(x: spec.isForExpandedView ? expandedRightButtonsWidth : normalRightButtonsWidth, y: 0.0), size: buttonSize)
                if spec.isForExpandedView {
                    expandedRightButtonsWidth += buttonSize.width
                } else {
                    normalRightButtonsWidth += buttonSize.width
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: .immediate)
                    
                    if shouldAnimateIn {
                        if key == .moreSearchSort || key == .searchWithTags || key == .standaloneSearch {
                            buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    ComponentTransition.immediate.setBlur(layer: buttonNode.layer, radius: maxBlur)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonSpec] = []
            for (spec, _) in self.rightButtonNodes {
                if spec.key == .moreSearchSort {
                    if !rightButtons.contains(where: { $0.key == .more || $0.key == .search || $0.key == .sort }) {
                        removeKeys.append(spec)
                    }
                } else if !rightButtons.contains(where: { $0 == spec }) {
                    removeKeys.append(spec)
                }
            }
            for spec in removeKeys {
                if let buttonNode = self.rightButtonNodes.removeValue(forKey: spec) {
                    if spec.key == .moreSearchSort || spec.key == .searchWithTags || spec.key == .standaloneSearch {
                        buttonNode.layer.animateAlpha(from: buttonNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonNode] _ in
                            buttonNode?.view.removeFromSuperview()
                        })
                        buttonNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    } else {
                        buttonNode.view.removeFromSuperview()
                    }
                }
            }
        } else {
            for spec in rightButtons {
                var key = spec.key
                if key == .more || key == .search || key == .sort {
                    key = .moreSearchSort
                }
                
                if let buttonNode = self.rightButtonNodes[spec] {
                    let buttonSize = buttonNode.bounds.size
                    let buttonFrame = CGRect(origin: CGPoint(x: spec.isForExpandedView ? expandedRightButtonsWidth : normalRightButtonsWidth, y: 0.0), size: buttonSize)
                    if spec.isForExpandedView {
                        expandedRightButtonsWidth += buttonSize.width
                    } else {
                        normalRightButtonsWidth += buttonSize.width
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
        }
        self.presentationData = presentationData
        
        let buttonsY: CGFloat = floor((size.height - buttonHeight) * 0.5) + 2.0
        
        let leftButtonsWidth = (1.0 - expandFraction) * normalLeftButtonsWidth + expandFraction * expandedLeftButtonsWidth
        let rightButtonsWidth = (1.0 - expandFraction) * normalRightButtonsWidth + expandFraction * expandedRightButtonsWidth
        
        var leftButtonsFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonsY), size: CGSize(width: max(44.0, leftButtonsWidth), height: buttonHeight))
        if leftButtonsWidth < 44.0 {
            let leftFraction = leftButtonsWidth / 44.0
            leftButtonsFrame.origin.x = floorToScreenPixels(leftFraction * sideInset + (1.0 - leftFraction) * (-44.0))
        }
        var rightButtonsFrame = CGRect(origin: CGPoint(x: size.width - sideInset - rightButtonsWidth, y: buttonsY), size: CGSize(width: max(44.0, rightButtonsWidth), height: buttonHeight))
        if rightButtonsWidth < 44.0 {
            let rightFraction = rightButtonsWidth / 44.0
            rightButtonsFrame.origin.x = floorToScreenPixels(rightFraction * (size.width - sideInset - 44.0) + (1.0 - rightFraction) * size.width)
        }
        
        transition.updateFrame(view: self.leftButtonsBackground, frame: leftButtonsFrame)
        transition.updateFrame(view: self.leftButtonsContainer, frame: CGRect(origin: CGPoint(), size: leftButtonsFrame.size))
        self.leftButtonsContainer.layer.cornerRadius = leftButtonsFrame.height * 0.5
        
        transition.updateFrame(view: self.rightButtonsBackground, frame: rightButtonsFrame)
        transition.updateFrame(view: self.rightButtonsContainer, frame: CGRect(origin: CGPoint(), size: rightButtonsFrame.size))
        self.rightButtonsContainer.layer.cornerRadius = rightButtonsFrame.height * 0.5
        
        self.updateBackgroundColors(transition: ComponentTransition(transition))
    }
    
    private func updateBackgroundColors(transition: ComponentTransition) {
        guard let presentationData = self.presentationData else {
            return
        }
        
        let leftButtonsSize = self.leftButtonsBackground.bounds.size
        let rightButtonsSize = self.rightButtonsBackground.bounds.size
        
        let tintColor: GlassBackgroundView.TintColor
        let tintIsDark: Bool
        if self.isOverColoredContents {
            tintColor = .init(kind: .custom(style: .default, color: self.backgroundContentColor))
            tintIsDark = presentationData.theme.overallDarkAppearance
        } else {
            tintColor = .init(kind: .panel)
            tintIsDark = presentationData.theme.overallDarkAppearance
        }
        
        self.backgroundContainer.update(size: self.backgroundContainer.bounds.size, isDark: tintIsDark, transition: transition)
        
        self.rightButtonsBackground.update(size: rightButtonsSize, cornerRadius: rightButtonsSize.height * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, transition: transition)
        self.leftButtonsBackground.update(size: leftButtonsSize, cornerRadius: leftButtonsSize.height * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, transition: transition)
    }
}
