import Foundation
import AsyncDisplayKit
import Display

private final class PeerMediaCollectionModeSelectionCaseNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    fileprivate let mode: PeerMediaCollectionMode
    private let selected: () -> Void
    
    private let button: HighlightTrackingButton
    private let selectionBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let checkmarkView: UIImageView
    
    var isSelected = false {
        didSet {
            if self.isSelected != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: titleForPeerMediaCollectionMode(self.mode, strings: self.strings), font: Font.regular(17.0), textColor: isSelected ? self.theme.list.itemAccentColor : self.theme.list.itemPrimaryTextColor)
                self.checkmarkView.isHidden = !self.isSelected
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, mode: PeerMediaCollectionMode, selected: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.selected = selected
        
        self.button = HighlightTrackingButton()
        
        self.selectionBackgroundNode = ASDisplayNode()
        self.selectionBackgroundNode.backgroundColor = self.theme.list.itemHighlightedBackgroundColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.theme.list.itemSeparatorColor
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.checkmarkView = UIImageView(image: PresentationResourcesItemList.checkIconImage(self.theme))
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        
        self.selectionBackgroundNode.alpha = 0.0
        self.addSubnode(self.selectionBackgroundNode)
        
        self.titleNode.attributedText = NSAttributedString(string: titleForPeerMediaCollectionMode(mode, strings: self.strings), font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor)
        self.addSubnode(self.titleNode)
        
        self.checkmarkView.isHidden = true
        self.view.addSubview(self.checkmarkView)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.selectionBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.selectionBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.selectionBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    strongSelf.selectionBackgroundNode.layer.opacity = 0.0
                }
            }
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
        self.view.addSubview(self.button)
    }
    
    func updateFrames(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: self.button.layer, frame: CGRect(origin: CGPoint(), size: size))
        
        let leftInset: CGFloat = 15.0
        
        transition.updateFrame(node: self.selectionBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: -UIScreenPixel), size: CGSize(width: size.width - leftInset, height: UIScreenPixel)))
        
        let titleSize = self.titleNode.measure(CGSize(width: size.width - leftInset - 44.0, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize))
        
        let checkmarkSize = self.checkmarkView.bounds.size
        transition.updateFrame(layer: self.checkmarkView.layer, frame: CGRect(origin: CGPoint(x: size.width - checkmarkSize.width - 14.0, y: floor((size.height - checkmarkSize.height) / 2.0)), size: checkmarkSize))
    }
    
    @objc func buttonPressed() {
        self.selected()
    }
}

final class PeerMediaCollectionModeSelectionNode: ASDisplayNode {
    private let dimNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    
    private var caseNodes: [PeerMediaCollectionModeSelectionCaseNode] = []
    
    var selectedMode: ((PeerMediaCollectionMode) -> Void)?
    var dismiss: (() -> Void)?
    
    var mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState {
        didSet {
            for caseNode in self.caseNodes {
                caseNode.isSelected = self.mediaCollectionInterfaceState.mode == caseNode.mode
            }
        }
    }
    
    init(mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState) {
        self.mediaCollectionInterfaceState = mediaCollectionInterfaceState
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.mediaCollectionInterfaceState.theme.list.itemBackgroundColor
    
        super.init()
        
        let modes: [PeerMediaCollectionMode] = [.photoOrVideo, .file, .webpage, .music]
        let selected: (PeerMediaCollectionMode) -> Void = { [weak self] mode in
            if let selectedMode = self?.selectedMode {
                selectedMode(mode)
            }
        }
        self.caseNodes = modes.map { mode in
            return PeerMediaCollectionModeSelectionCaseNode(theme: self.mediaCollectionInterfaceState.theme, strings: self.mediaCollectionInterfaceState.strings, mode: mode, selected: {
                selected(mode)
            })
        }
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.backgroundNode)
        
        for caseNode in self.caseNodes {
            self.addSubnode(caseNode)
        }
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let backgrounNodePosition = self.backgroundNode.layer.position
        self.backgroundNode.layer.animatePosition(from: CGPoint(x: backgrounNodePosition.x, y: backgrounNodePosition.y - self.backgroundNode.bounds.size.height), to: backgrounNodePosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        
        for caseNode in self.caseNodes {
            let caseNodePosition = caseNode.layer.position
            caseNode.layer.animatePosition(from: CGPoint(x: caseNodePosition.x, y: caseNodePosition.y - self.backgroundNode.bounds.size.height), to: caseNodePosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        let backgrounNodePosition = self.backgroundNode.layer.position
        self.backgroundNode.layer.animatePosition(from: backgrounNodePosition, to: CGPoint(x: backgrounNodePosition.x, y: backgrounNodePosition.y - self.backgroundNode.bounds.size.height), duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        
        for caseNode in self.caseNodes {
            let caseNodePosition = caseNode.layer.position
            caseNode.layer.animatePosition(from: caseNodePosition, to: CGPoint(x: caseNodePosition.x, y: caseNodePosition.y - self.backgroundNode.bounds.size.height), duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        
        var nextCaseNodeOrigin = CGPoint(x: 0.0, y: navigationBarHeight)
        for caseNode in self.caseNodes {
            transition.updateFrame(node: caseNode, frame: CGRect(origin: nextCaseNodeOrigin, size: CGSize(width: layout.size.width, height: 44.0)))
            caseNode.updateFrames(size: CGSize(width: layout.size.width, height: 44.0), transition: transition)
            nextCaseNodeOrigin.y += 44.0
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: CGFloat(self.caseNodes.count) * 44.0)))
    }
    
    @objc func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let dismiss = self.dismiss {
                dismiss()
            }
        }
    }
}
