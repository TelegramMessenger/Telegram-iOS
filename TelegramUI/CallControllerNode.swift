import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

import TelegramUIPrivateModule

final class CallControllerNode: ASDisplayNode {
    private let account: Account
    
    private let statusBar: StatusBar
    
    private var presentationData: PresentationData
    private var peer: Peer?
    
    private let containerNode: ASDisplayNode
    
    private let imageNode: TransformImageNode
    private let dimNode: ASDisplayNode
    private let backButtonArrowNode: ASImageNode
    private let backButtonNode: HighlightableButtonNode
    private let statusNode: CallControllerStatusNode
    private let buttonsNode: CallControllerButtonsNode
    private var keyPreviewNode: CallControllerKeyPreviewNode?
    
    private var keyTextData: (Data, String)?
    private let keyButtonNode: HighlightableButtonNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var isMuted: Bool = false {
        didSet {
            self.buttonsNode.isMuted = self.isMuted
        }
    }
    
    var speakerMode: Bool = false {
        didSet {
            self.buttonsNode.speakerMode = self.speakerMode
        }
    }
    
    var toggleMute: (() -> Void)?
    var toggleSpeaker: (() -> Void)?
    var acceptCall: (() -> Void)?
    var endCall: (() -> Void)?
    var back: (() -> Void)?
    var disissedInteractively: (() -> Void)?
    
    init(account: Account, presentationData: PresentationData, statusBar: StatusBar) {
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        
        self.containerNode = ASDisplayNode()
        
        self.imageNode = TransformImageNode()
        self.dimNode = ASDisplayNode()
        self.dimNode.isLayerBacked = true
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        
        self.backButtonArrowNode = ASImageNode()
        self.backButtonArrowNode.displayWithoutProcessing = true
        self.backButtonArrowNode.displaysAsynchronously = false
        self.backButtonArrowNode.image = NavigationBarTheme.generateBackArrowImage(color: .white)
        self.backButtonNode = HighlightableButtonNode()
        
        self.statusNode = CallControllerStatusNode()
        self.buttonsNode = CallControllerButtonsNode(strings: self.presentationData.strings)
        self.keyButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.containerNode.backgroundColor = .black
        
        self.addSubnode(self.containerNode)
        
        self.backButtonNode.setTitle(presentationData.strings.Common_Back, with: Font.regular(17.0), with: .white, for: [])
        self.backButtonNode.hitTestSlop = UIEdgeInsets(top: -8.0, left: -20.0, bottom: -8.0, right: -8.0)
        self.backButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backButtonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonArrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonNode.alpha = 0.4
                    strongSelf.backButtonArrowNode.alpha = 0.4
                } else {
                    strongSelf.backButtonNode.alpha = 1.0
                    strongSelf.backButtonArrowNode.alpha = 1.0
                    strongSelf.backButtonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.backButtonArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.dimNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.buttonsNode)
        self.containerNode.addSubnode(self.keyButtonNode)
        self.containerNode.addSubnode(self.backButtonArrowNode)
        self.containerNode.addSubnode(self.backButtonNode)
        
        self.buttonsNode.mute = { [weak self] in
            self?.toggleMute?()
        }
        
        self.buttonsNode.speaker = { [weak self] in
            self?.toggleSpeaker?()
        }
        
        self.buttonsNode.end = { [weak self] in
            self?.endCall?()
        }
        
        self.buttonsNode.accept = { [weak self] in
            self?.acceptCall?()
        }
        
        self.keyButtonNode.addTarget(self, action: #selector(self.keyPressed), forControlEvents: .touchUpInside)
        
        self.backButtonNode.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    func updatePeer(peer: Peer) {
        if !arePeersEqual(self.peer, peer) {
            self.peer = peer
            
            self.imageNode.setSignal(account: self.account, signal: chatAvatarGalleryPhoto(account: self.account, representations: peer.profileImageRepresentations, autoFetchFullSize: true))
            
            self.statusNode.title = peer.displayTitle
            
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }
    
    func updateCallState(_ callState: PresentationCallState) {
        let statusValue: CallControllerStatusValue
        switch callState {
            case .waiting, .connecting:
                statusValue = .text(self.presentationData.strings.Call_StatusConnecting)
            case let .requesting(ringing):
                if ringing {
                    statusValue = .text(self.presentationData.strings.Call_StatusRinging)
                } else {
                    statusValue = .text(self.presentationData.strings.Call_StatusRequesting)
                }
            case .terminating, .terminated:
                statusValue = .text(self.presentationData.strings.Call_StatusEnded)
            case .ringing:
                statusValue = .text(self.presentationData.strings.Call_StatusIncoming)
            case let .active(timestamp, keyVisualHash):
                let strings = self.presentationData.strings
                statusValue = .timer({ value in
                    return strings.Call_StatusOngoing(value).0
                }, timestamp)
                if self.keyTextData?.0 != keyVisualHash {
                    let text = stringForEmojiHashOfData(keyVisualHash, 4)!
                    self.keyTextData = (keyVisualHash, text)
                    
                    self.keyButtonNode.setAttributedTitle(NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: Font.regular(22.0), NSAttributedStringKey.kern: 2.5 as NSNumber]), for: [])
                    
                    let keyTextSize = self.keyButtonNode.measure(CGSize(width: 200.0, height: 200.0))
                    self.keyButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.keyButtonNode.frame = CGRect(origin: self.keyButtonNode.frame.origin, size: keyTextSize)
                    
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                }
        }
        switch callState {
            case .terminated, .terminating:
                if !self.statusNode.alpha.isEqual(to: 0.5) {
                    self.statusNode.alpha = 0.5
                    self.buttonsNode.alpha = 0.5
                    self.keyButtonNode.alpha = 0.5
                    self.backButtonArrowNode.alpha = 0.5
                    self.backButtonNode.alpha = 0.5
                    
                    self.statusNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                    self.buttonsNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                    self.keyButtonNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                }
            default:
                if !self.statusNode.alpha.isEqual(to: 1.0) {
                    self.statusNode.alpha = 1.0
                    self.buttonsNode.alpha = 1.0
                    self.keyButtonNode.alpha = 1.0
                    self.backButtonArrowNode.alpha = 1.0
                    self.backButtonNode.alpha = 1.0
                }
        }
        self.statusNode.status = statusValue
        
        switch callState {
            case .ringing:
                self.buttonsNode.updateMode(.incoming)
            default:
                self.buttonsNode.updateMode(.active(.speaker))
        }
    }
    
    func animateIn() {
        var bounds = self.bounds
        bounds.origin = CGPoint()
        self.bounds = bounds
        self.layer.removeAnimation(forKey: "bounds")
        self.statusBar.layer.removeAnimation(forKey: "opacity")
        self.containerNode.layer.removeAnimation(forKey: "opacity")
        self.containerNode.layer.removeAnimation(forKey: "scale")
        self.statusBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.containerNode.layer.animateScale(from: 1.04, to: 1.0, duration: 0.3)
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.statusBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateScale(from: 1.0, to: 1.04, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        if let keyPreviewNode = self.keyPreviewNode {
            transition.updateFrame(node: keyPreviewNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            keyPreviewNode.updateLayout(size: layout.size, transition: .immediate)
        }
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: 640.0, height: 640.0).aspectFilled(layout.size), boundingSize: layout.size, intrinsicInsets: UIEdgeInsets())
        let apply = self.imageNode.asyncLayout()(arguments)
        apply()
        
        let backSize = self.backButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        if let image = self.backButtonArrowNode.image {
            transition.updateFrame(node: self.backButtonArrowNode, frame: CGRect(origin: CGPoint(x: 10.0, y: 31.0), size: image.size))
        }
        transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: 29.0, y: 31.0), size: backSize))
        
        let statusOffset: CGFloat
        if layout.metrics.widthClass == .regular && layout.metrics.heightClass == .regular {
            if layout.size.height.isEqual(to: 1366.0) {
                statusOffset = 160.0
            } else {
                statusOffset = 120.0
            }
        } else {
            if layout.size.height.isEqual(to: 736.0) {
                statusOffset = 80.0
            } else if layout.size.width.isEqual(to: 320.0) {
                statusOffset = 60.0
            } else {
                statusOffset = 64.0
            }
        }
        
        let buttonsHeight: CGFloat = 75.0
        let buttonsOffset: CGFloat
        if layout.size.width.isEqual(to: 320.0) {
            if layout.size.height.isEqual(to: 480.0) {
                buttonsOffset = 53.0
            } else {
                buttonsOffset = 63.0
            }
        } else {
            buttonsOffset = 83.0
        }
        
        let statusHeight = self.statusNode.updateLayout(constrainedWidth: layout.size.width, transition: transition)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusOffset), size: CGSize(width: layout.size.width, height: statusHeight)))
        
        self.buttonsNode.updateLayout(constrainedWidth: layout.size.width, transition: transition)
        transition.updateFrame(node: self.buttonsNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - (buttonsOffset - 40.0) - buttonsHeight), size: CGSize(width: layout.size.width, height: buttonsHeight)))
        
        let keyTextSize = self.keyButtonNode.frame.size
        transition.updateFrame(node: self.keyButtonNode, frame: CGRect(origin: CGPoint(x: layout.size.width - keyTextSize.width - 8.0, y: 28.0), size: keyTextSize))
    }
    
    @objc func keyPressed() {
        if self.keyPreviewNode == nil, let keyText = self.keyTextData?.1, let peer = self.peer {
            let keyPreviewNode = CallControllerKeyPreviewNode(keyText: keyText, infoText: self.presentationData.strings.Call_EmojiDescription(peer.compactDisplayTitle).0, dismiss: { [weak self] in
                if let _ = self?.keyPreviewNode {
                    self?.backPressed()
                }
            })
            self.containerNode.insertSubnode(keyPreviewNode, aboveSubnode: self.dimNode)
            self.keyPreviewNode = keyPreviewNode
            
            if let (validLayout, _) = self.validLayout {
                keyPreviewNode.updateLayout(size: validLayout.size, transition: .immediate)
                
                self.keyButtonNode.isHidden = true
                keyPreviewNode.animateIn(from: self.keyButtonNode.frame, fromNode: self.keyButtonNode)
            }
        }
    }
    
    @objc func backPressed() {
        if let keyPreviewNode = self.keyPreviewNode {
            self.keyPreviewNode = nil
            keyPreviewNode.animateOut(to: self.keyButtonNode.frame, toNode: self.keyButtonNode, completion: { [weak self, weak keyPreviewNode] in
                self?.keyButtonNode.isHidden = false
                keyPreviewNode?.removeFromSupernode()
            })
        } else {
            self.back?()
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .changed:
                let offset = recognizer.translation(in: self.view).y
                var bounds = self.bounds
                bounds.origin.y = -offset
                self.bounds = bounds
            case .ended:
                let velocity = recognizer.velocity(in: self.view).y
                if abs(velocity) < 100.0 {
                    var bounds = self.bounds
                    let previous = bounds
                    bounds.origin = CGPoint()
                    self.bounds = bounds
                    self.layer.animateBounds(from: previous, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                } else {
                    var bounds = self.bounds
                    let previous = bounds
                    bounds.origin = CGPoint(x: 0.0, y: velocity > 0.0 ? -bounds.height: bounds.height)
                    self.bounds = bounds
                    self.layer.animateBounds(from: previous, to: bounds, duration: 0.15, timingFunction: kCAMediaTimingFunctionEaseOut, completion: { [weak self] _ in
                        self?.disissedInteractively?()
                    })
                }
            case .cancelled:
                var bounds = self.bounds
                let previous = bounds
                bounds.origin = CGPoint()
                self.bounds = bounds
                self.layer.animateBounds(from: previous, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            default:
                break
        }
    }
}
