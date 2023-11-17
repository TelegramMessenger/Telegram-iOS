import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display

enum PeerInfoHeaderNavigationButtonKey {
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
    case editPhoto
    case editVideo
    case more
    case qrCode
    case moreToSearch
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
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                for (_, buttonNode) in self.leftButtonNodes {
                    buttonNode.isWhite = self.isWhite
                }
                for (_, buttonNode) in self.rightButtonNodes {
                    buttonNode.isWhite = self.isWhite
                }
            }
        }
    }
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey, ContextReferenceContentNode?, ContextGesture?) -> Void)?
    
    func update(size: CGSize, presentationData: PresentationData, leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        let maximumExpandOffset: CGFloat = 14.0
        let expandOffset: CGFloat = -expandFraction * maximumExpandOffset
        
        if self.currentLeftButtons != leftButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentLeftButtons = leftButtons
            
            var nextRegularButtonOrigin = 16.0
            var nextExpandedButtonOrigin = 16.0
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
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                nextButtonOrigin += buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    
                    buttonNode.isWhite = self.isWhite
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
            var nextRegularButtonOrigin = 16.0
            var nextExpandedButtonOrigin = 16.0
            for spec in leftButtons.reversed() {
                if let buttonNode = self.leftButtonNodes[spec.key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    nextButtonOrigin += buttonSize.width + 4.0
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
        
        if self.currentRightButtons != rightButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentRightButtons = rightButtons
            
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
            for spec in rightButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                
                var key = spec.key
                if key == .more || key == .search {
                    key = .moreToSearch
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
                var buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                if case .postStory = spec.key {
                    buttonFrame.origin.x -= 12.0
                }
                nextButtonOrigin -= buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.isWhite = self.isWhite
                    
                    if key == .moreToSearch {
                        buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    }
                    
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.rightButtonNodes {
                if key == .moreToSearch {
                    if !rightButtons.contains(where: { $0.key == .more || $0.key == .search }) {
                        removeKeys.append(key)
                    }
                } else if !rightButtons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.rightButtonNodes.removeValue(forKey: key) {
                    if key == .moreToSearch {
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
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
                        
            for spec in rightButtons.reversed() {
                var key = spec.key
                if key == .more || key == .search {
                    key = .moreToSearch
                }
                
                if let buttonNode = self.rightButtonNodes[key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    var buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    if case .postStory = spec.key {
                        buttonFrame.origin.x -= 12.0
                    }
                    nextButtonOrigin -= buttonSize.width + 4.0
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
