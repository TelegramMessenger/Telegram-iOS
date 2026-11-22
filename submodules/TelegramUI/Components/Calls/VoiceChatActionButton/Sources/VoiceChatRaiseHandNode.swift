import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AnimationUI
import AppBundle

public final class VoiceChatRaiseHandNode: ASDisplayNode {
    private let animationNode: AnimationNode
    private let color: UIColor?
    private var playedOnce = false
    
    public init(color: UIColor?) {
        self.color = color
        if let color = color, let url = getAppBundle().url(forResource: "anim_hand1", withExtension: "json"), let data = try? Data(contentsOf: url) {
            self.animationNode = AnimationNode(animationData: transformedWithColors(data: data, colors: [(UIColor(rgb: 0xffffff), color)]))
        } else {
            self.animationNode = AnimationNode(animation: "anim_hand1", colors: nil, scale: 0.5)
        }
        super.init()
        self.addSubnode(self.animationNode)
    }
    
    public func playRandomAnimation() {
        guard self.playedOnce else {
            self.playedOnce = true
            self.animationNode.play()
            return
        }
        
        guard !self.animationNode.isPlaying else {
            self.animationNode.completion = { [weak self] in
                self?.playRandomAnimation()
            }
            return
        }
        
        self.animationNode.completion = nil
        if let animationName = ["anim_hand1", "anim_hand2", "anim_hand3", "anim_hand4"].randomElement() {
            if let color = color, let url = getAppBundle().url(forResource: animationName, withExtension: "json"), let data = try? Data(contentsOf: url) {
                self.animationNode.setAnimation(data: transformedWithColors(data: data, colors: [(UIColor(rgb: 0xffffff), color)]))
            } else {
                self.animationNode.setAnimation(name: animationName)
            }
            self.animationNode.play()
        }
    }
    
    override public func layout() {
        super.layout()
        self.animationNode.frame = self.bounds
    }
}
