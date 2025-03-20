import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display

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

struct PeerInfoHeaderNavigationButtonSpec: Equatable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

final class PeerInfoHeaderNavigationButtonContainerNode: SparseNode {
    private var presentationData: PresentationData?
    private(set) var leftButtonNodes: [PeerInfoHeaderNavigationButtonKey: PeerInfoHeaderNavigationButton] = [:]
    private(set) var rightButtonNodes: [PeerInfoHeaderNavigationButtonKey: PeerInfoHeaderNavigationButton] = [:]
    
    private var currentLeftButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    private var currentRightButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    
    private var backgroundContentColor: UIColor = .clear
    private var contentsColor: UIColor = .white
    private var canBeExpanded: Bool = false
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey, ContextReferenceContentNode?, ContextGesture?) -> Void)?
    
    func updateContentsColor(backgroundContentColor: UIColor, contentsColor: UIColor, canBeExpanded: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundContentColor = backgroundContentColor
        self.contentsColor = contentsColor
        self.canBeExpanded = canBeExpanded
        
        for (_, button) in self.leftButtonNodes {
            button.updateContentsColor(backgroundColor: self.backgroundContentColor, contentsColor: self.contentsColor, canBeExpanded: canBeExpanded, transition: transition)
            transition.updateSublayerTransformOffset(layer: button.layer, offset: CGPoint(x: canBeExpanded ? -8.0 : 0.0, y: 0.0))
        }
        
        var accumulatedRightButtonOffset: CGFloat = canBeExpanded ? 16.0 : 0.0
        for spec in self.currentRightButtons.reversed() {
            guard let button = self.rightButtonNodes[spec.key] else {
                continue
            }
            button.updateContentsColor(backgroundColor: self.backgroundContentColor, contentsColor: self.contentsColor, canBeExpanded: canBeExpanded, transition: transition)
            transition.updateSublayerTransformOffset(layer: button.layer, offset: CGPoint(x: accumulatedRightButtonOffset, y: 0.0))
            if self.backgroundContentColor.alpha != 0.0 {
                accumulatedRightButtonOffset -= 6.0
            }
        }
        for (key, button) in self.rightButtonNodes {
            if !self.currentRightButtons.contains(where: { $0.key == key }) {
                button.updateContentsColor(backgroundColor: self.backgroundContentColor, contentsColor: self.contentsColor, canBeExpanded: canBeExpanded, transition: transition)
                transition.updateSublayerTransformOffset(layer: button.layer, offset: CGPoint(x: 0.0, y: 0.0))
            }
        }
    }
    
    func update(size: CGSize, presentationData: PresentationData, leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, shouldAnimateIn: Bool, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 24.0
        
        let maximumExpandOffset: CGFloat = 14.0
        let expandOffset: CGFloat = -expandFraction * maximumExpandOffset
        
        if self.currentLeftButtons != leftButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentLeftButtons = leftButtons
            
            var nextRegularButtonOrigin = sideInset
            var nextExpandedButtonOrigin = sideInset
            for spec in leftButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                if let current = self.leftButtonNodes[spec.key] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.leftButtonNodes[spec.key] = buttonNode
                    self.addSubnode(buttonNode)
                    buttonNode.action = { [weak self] _, gesture in
                        guard let strongSelf = self, let buttonNode = strongSelf.leftButtonNodes[spec.key] else {
                            return
                        }
                        strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                    }
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: size.height)
                var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                
                let buttonY: CGFloat
                if case .back = spec.key {
                    buttonY = 0.0
                } else {
                    buttonY = expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)
                }
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: buttonY), size: buttonSize)
                
                nextButtonOrigin += buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
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
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    buttonNode.updateContentsColor(backgroundColor: self.backgroundContentColor, contentsColor: self.contentsColor, canBeExpanded: self.canBeExpanded, transition: .immediate)
                    
                    transition.updateSublayerTransformOffset(layer: buttonNode.layer, offset: CGPoint(x: canBeExpanded ? -8.0 : 0.0, y: 0.0))
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.leftButtonNodes {
                if !leftButtons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.leftButtonNodes.removeValue(forKey: key) {
                    buttonNode.removeFromSupernode()
                }
            }
        } else {
            var nextRegularButtonOrigin = sideInset
            var nextExpandedButtonOrigin = sideInset
            for spec in leftButtons.reversed() {
                if let buttonNode = self.leftButtonNodes[spec.key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonY: CGFloat
                    if case .back = spec.key {
                        buttonY = 0.0
                    } else {
                        buttonY = expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: buttonY), size: buttonSize)
                    nextButtonOrigin += buttonSize.width + 4.0
                    if spec.isForExpandedView {
                        nextExpandedButtonOrigin = nextButtonOrigin
                    } else {
                        nextRegularButtonOrigin = nextButtonOrigin
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
                }
            }
        }
        
        var accumulatedRightButtonOffset: CGFloat = self.canBeExpanded ? 16.0 : 0.0
        if self.currentRightButtons != rightButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentRightButtons = rightButtons
            
            var nextRegularButtonOrigin = size.width - sideInset - 8.0
            var nextExpandedButtonOrigin = size.width - sideInset - 8.0
            for spec in rightButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                
                var key = spec.key
                if key == .more || key == .search || key == .sort {
                    key = .moreSearchSort
                }
                
                if let current = self.rightButtonNodes[key] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.rightButtonNodes[key] = buttonNode
                    self.addSubnode(buttonNode)
                }
                buttonNode.action = { [weak self] _, gesture in
                    guard let strongSelf = self, let buttonNode = strongSelf.rightButtonNodes[key] else {
                        return
                    }
                    strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: size.height)
                var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                nextButtonOrigin -= buttonSize.width + 15.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.updateContentsColor(backgroundColor: self.backgroundContentColor, contentsColor: self.contentsColor, canBeExpanded: self.canBeExpanded, transition: .immediate)
                    
                    if shouldAnimateIn {
                        if key == .moreSearchSort || key == .searchWithTags || key == .standaloneSearch {
                            buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    
                    transition.updateSublayerTransformOffset(layer: buttonNode.layer, offset: CGPoint(x: accumulatedRightButtonOffset, y: 0.0))
                    if self.backgroundContentColor.alpha != 0.0 {
                        accumulatedRightButtonOffset -= 6.0
                    }
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.rightButtonNodes {
                if key == .moreSearchSort {
                    if !rightButtons.contains(where: { $0.key == .more || $0.key == .search || $0.key == .sort }) {
                        removeKeys.append(key)
                    }
                } else if !rightButtons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.rightButtonNodes.removeValue(forKey: key) {
                    if key == .moreSearchSort || key == .searchWithTags || key == .standaloneSearch {
                        buttonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonNode] _ in
                            buttonNode?.removeFromSupernode()
                        })
                        buttonNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    } else {
                        buttonNode.removeFromSupernode()
                    }
                }
            }
        } else {
            var nextRegularButtonOrigin = size.width - sideInset - 8.0
            var nextExpandedButtonOrigin = size.width - sideInset - 8.0
                        
            for spec in rightButtons.reversed() {
                var key = spec.key
                if key == .more || key == .search || key == .sort {
                    key = .moreSearchSort
                }
                
                if let buttonNode = self.rightButtonNodes[key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    nextButtonOrigin -= buttonSize.width + 15.0
                    if spec.isForExpandedView {
                        nextExpandedButtonOrigin = nextButtonOrigin
                    } else {
                        nextRegularButtonOrigin = nextButtonOrigin
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
        }
        self.presentationData = presentationData
    }
}
