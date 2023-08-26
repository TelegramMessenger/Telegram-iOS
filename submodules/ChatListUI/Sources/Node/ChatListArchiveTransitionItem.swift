import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AnimationUI
import ComponentFlow
import TelegramPresentationData

public struct ArchiveAnimationParams: Equatable {
    public let scrollOffset: CGFloat
    public let storiesFraction: CGFloat
    public let expandedHeight: CGFloat
    
    public static var empty: ArchiveAnimationParams{
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero)
    }
}

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
        
        static func degreesToRadians(_ x: CGFloat) -> CGFloat {
            return .pi * x / 180.0
        }
    }
    
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientComponent: RoundedRectangle
    var gradientContainerView: ComponentHostView<Empty>?
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowContainerNode: ASDisplayNode
    let arrowAnimationNode: AnimationNode //20x20
    let arrowImageNode: ASImageNode
    let animation: TransitionAnimation
    
    required override init() {
        self.backgroundNode = ASDisplayNode()
//        self.backgroundNode.isLayerBacked = true
//        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.backgroundColor = .clear
        
        self.gradientContainerNode = ASDisplayNode()
        self.animation = .init(state: .swipeDownInit, scrollOffset: .zero, storiesFraction: .zero)
        self.titleNode = ASTextNode()
//        self.titleNode.isLayerBacked = true
        
        self.gradientComponent = RoundedRectangle(colors: [UIColor(hexString: "#A9AFB7")!,
                                                           UIColor(hexString: "#D3D4DA")!],
                                                  cornerRadius: 0,
                                                  gradientDirection: .horizontal)

        self.arrowBackgroundNode = ASDisplayNode()
        self.arrowBackgroundNode.backgroundColor = .white.withAlphaComponent(0.4)
                
        self.arrowContainerNode = ASDisplayNode()
        self.arrowImageNode = ASImageNode()
        self.arrowImageNode.image = UIImage(bundleImageName: "Chat List/Archive/IconArrow")
        
        let mixedBackgroundColor = UIColor(hexString: "#A9AFB7")!.mixedWith(.white, alpha: 0.4)
        self.arrowAnimationNode = AnimationNode(animation: "anim_arrow_to_archive", colors: [
            "Arrow 1.Arrow 1.Stroke 1": mixedBackgroundColor,
            "Arrow 2.Arrow 2.Stroke 1": mixedBackgroundColor,
            "Cap.cap2.Fill 1": .white,
            "Cap.cap1.Fill 1": .white,
            "Box.box1.Fill 1": .white
        ], scale: 0.11)
        self.arrowAnimationNode.backgroundColor = .clear
        self.arrowAnimationNode.isUserInteractionEnabled = false
        
        super.init()
        self.addSubnode(self.gradientContainerNode)
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.titleNode)
        self.backgroundNode.addSubnode(self.arrowBackgroundNode)
        self.arrowBackgroundNode.addSubnode(self.arrowContainerNode)
        self.arrowContainerNode.addSubnode(self.arrowImageNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, params: ArchiveAnimationParams, presentationData: ChatListPresentationData) {
        let frame = CGRect(origin: .zero, size: size)
        print("frame: \(frame)")
        if self.gradientContainerView == nil {
            self.gradientContainerView = ComponentHostView<Empty>()
            self.gradientContainerNode.view.addSubview(self.gradientContainerView!)
        }

        let _ = self.gradientContainerView?.update(
            transition: .immediate,
            component: AnyComponent(self.gradientComponent),
            environment: {},
            containerSize: size
        )
        
        transition.updateFrame(node: self, frame: frame)
        transition.updateFrame(node: self.gradientContainerNode, frame: frame)
        transition.updateFrame(node: self.backgroundNode, frame: frame)
        if let gradientContainerView {
            transition.updateFrame(view: gradientContainerView, frame: frame)
        }
        let arrowBackgroundFrame = CGRect(x: 29, y: 10, width: 20, height: size.height - 20)
        let arrowFrame = CGRect(x: 0, y: arrowBackgroundFrame.height - 20, width: 20, height: 20)
        transition.updateFrame(node: self.arrowBackgroundNode, frame: arrowBackgroundFrame)
        transition.updateCornerRadius(node: self.arrowBackgroundNode, cornerRadius: arrowBackgroundFrame.width / 2, completion: nil)
//        if var size = self.arrowAnimationNode.preferredSize() {
//            let scale = 2.7//size.width / arrowBackgroundFrame.width
//            transition.updateTransformScale(layer: self.arrowBackgroundNode.layer, scale: scale) { [weak arrowNode] finished in
//                guard let arrowNode, finished else { return }
//                transition.updateTransformScale(layer: arrowNode.layer, scale: 1.0 / scale)
//            }
//            animationBackgroundNode.layer.animateScale(from: 1.0, to: 1.07, duration: 0.12, removeOnCompletion: false, completion: { [weak animationBackgroundNode] finished in
//                animationBackgroundNode?.layer.animateScale(from: 1.07, to: 1.0, duration: 0.12, removeOnCompletion: false)
//            })

//            print("size before: \(size)")
//            size = CGSize(width: ceil(arrowBackgroundFrame.width), height: ceil(arrowBackgroundFrame.width))
//            print("size after: \(size)")
//            size = CGSize(width: ceil(size.width), height: ceil(size.width))
//            let arrowFrame = CGRect(x: floor((arrowBackgroundFrame.width - size.width) / 2.0),
//                                    y: floor(arrowBackgroundFrame.height - size.height),
//                                    width: size.width, height: size.height)
//            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
//            self.arrowNode.play()
//            transition.updateTransformRotation(node: arrowAnimationNode, angle: TransitionAnimation.degreesToRadians(-180))
//
//            size = CGSize(width: ceil(size.width * scale), height: ceil(size.width * scale))
//
//            let arrowCenter = (size.height / scale)/2
//            let scaledArrowCenter = size.height / 2
//            let difference = scaledArrowCenter - arrowCenter
//
//            let arrowFrame = CGRect(x: floor((arrowBackgroundFrame.width - size.width) / 2.0),
//                                    y: floor(arrowBackgroundFrame.height - size.height/scale - difference),
//                                    width: size.width, height: size.height)
//            transition.updateFrame(node: arrowAnimationNode, frame: arrowFrame)
//        }

//        transition.updateFrame(node: self.arrowNode, frame: CGRect(x: .zero, y: arrowBackgroundFrame.height - arrowBackgroundFrame.width, width: arrowBackgroundFrame.width, height: arrowBackgroundFrame.width))
        
        transition.updateFrame(node: self.arrowContainerNode, frame: arrowFrame)
        transition.updateFrame(node: self.arrowImageNode, frame: self.arrowContainerNode.bounds)
        self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
            .foregroundColor: UIColor.white,
            .font: Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
        ])

        let textLayout = self.titleNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: size.width - 120, height: 25)))
        
        transition.updateFrame(node: titleNode, frame: CGRect(x: (size.width - textLayout.size.width) / 2,
                                                              y: size.height - textLayout.size.height - 10,
                                                              width: textLayout.size.width,
                                                              height: textLayout.size.height))
        
    }
}
    
