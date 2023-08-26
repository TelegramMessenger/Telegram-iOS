import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AnimationUI
import ComponentFlow
import TelegramPresentationData

class ChatListArchiveTransitionNode: ASDisplayNode {
    
    struct TransitionAnimation {
        enum State {
            case swipeDownInit
            case swipeDownDisappear
            case releaseAppear
            case releaseDisappear
            case swipeDownAppear
            case transitionToArchive
        }
        
        var state: State
        var scrollOffset: CGFloat
        var storiesFraction: CGFloat
    }
    
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientComponent: RoundedRectangle
    let gradientContainerView: ComponentHostView<Empty>
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowNode: AnimationNode //20x20
    let animation: TransitionAnimation
    
    required override init() {
        self.backgroundNode = ASDisplayNode()
//        self.backgroundNode.isLayerBacked = true
//        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.backgroundColor = .clear
        
        self.gradientContainerNode = ASDisplayNode()
        self.gradientContainerView = ComponentHostView<Empty>()
        
        self.gradientComponent = RoundedRectangle(colors: [UIColor(hexString: "#A9AFB7")!,
                                                           UIColor(hexString: "#D3D4DA")!],
                                                  cornerRadius: 0,
                                                  gradientDirection: .horizontal)
        self.animation = .init(state: .swipeDownInit, scrollOffset: .zero, storiesFraction: .zero)
        self.titleNode = ASTextNode()
//        self.titleNode.isLayerBacked = true
        
        self.arrowBackgroundNode = ASDisplayNode()
//        self.arrowBackgroundNode.isLayerBacked = true
        self.arrowBackgroundNode.backgroundColor = .white.withAlphaComponent(0.4)
        
        //"cap2.Fill 1": .blue
        
        self.arrowNode = AnimationNode(animation: "anim_arrow_to_archive", colors: ["archiveicon 3.Arrow 1.Arrow 1.Stroke 1": UIColor.clear, "archiveicon 3.Arrow 2.Stroke 1": .clear], scale: 0.1)
        self.arrowNode.isUserInteractionEnabled = false
        
        super.init()
        self.addSubnode(self.gradientContainerNode)
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.titleNode)
        self.backgroundNode.addSubnode(self.arrowBackgroundNode)
        self.arrowBackgroundNode.addSubnode(self.arrowNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.gradientContainerNode.view.addSubview(self.gradientContainerView)
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, storiesFraction: CGFloat, scrollOffset: CGFloat, presentationData: ChatListPresentationData) {
        let frame = CGRect(origin: .zero, size: size)
        print("frame: \(frame)")
        let _ = self.gradientContainerView.update(
            transition: .immediate,
            component: AnyComponent(self.gradientComponent),
            environment: {},
            containerSize: size
        )
        
        transition.updateFrame(node: self, frame: frame)
        transition.updateFrame(node: self.gradientContainerNode, frame: frame)
        transition.updateFrame(node: self.backgroundNode, frame: frame)
        transition.updateFrame(view: self.gradientContainerView, frame: frame)
        let arrowBackgroundFrame = CGRect(x: 29, y: 10, width: 20, height: size.height - 20)
        transition.updateFrame(node: self.arrowBackgroundNode, frame: arrowBackgroundFrame)
        transition.updateCornerRadius(node: self.arrowBackgroundNode, cornerRadius: arrowBackgroundFrame.width / 2, completion: nil)
        if var size = self.arrowNode.preferredSize() {
            size = CGSize(width: ceil(size.width), height: ceil(size.height))
            self.arrowNode.frame = CGRect(x: floor((self.bounds.width - size.width) / 2.0), y: floor((self.bounds.height - size.height) / 2.0) + 1.0, width: size.width, height: size.height)
            self.arrowNode.play()
        }

        transition.updateFrame(node: self.arrowNode, frame: CGRect(x: .zero, y: arrowBackgroundFrame.height - arrowBackgroundFrame.width, width: arrowBackgroundFrame.width, height: arrowBackgroundFrame.width))
        self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17)
        ])

        let textLayout = self.titleNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: size.width - 120, height: 25)))
        
        transition.updateFrame(node: titleNode, frame: CGRect(x: (size.width - textLayout.size.width) / 2,
                                                              y: size.height - textLayout.size.height - 10,
                                                              width: textLayout.size.width,
                                                              height: textLayout.size.height))
        
    }
}
