import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramVoip
import TelegramAudio
import AccountContext

public final class GroupCallController: ViewController {
    private final class Node: ViewControllerTracingNode {
        private let context: AccountContext
        private let presentationData: PresentationData
        
        private var callContext: GroupCallContext?
        private var callDisposable: Disposable?
        private var memberCountDisposable: Disposable?
        private var isMutedDisposable: Disposable?
        private let audioSessionActive = Promise<Bool>(false)
        
        private var memberCount: Int = 0
        private let memberCountNode: ImmediateTextNode
        
        private var isMuted: Bool = false
        private let isMutedNode: ImmediateTextNode
        private let muteButton: HighlightableButtonNode
        
        private var validLayout: ContainerViewLayout?
        
        init(context: AccountContext) {
            self.context = context
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.memberCountNode = ImmediateTextNode()
            self.isMutedNode = ImmediateTextNode()
            
            self.muteButton = HighlightableButtonNode()
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.memberCountNode)
            
            self.muteButton.addSubnode(self.isMutedNode)
            self.addSubnode(self.muteButton)
            
            let audioSessionActive = self.audioSessionActive
            self.callDisposable = self.context.sharedContext.mediaManager.audioSession.push(audioSessionType: .voiceCall, manualActivate: { audioSessionControl in
                audioSessionControl.activate({ _ in })
                audioSessionActive.set(.single(true))
            }, deactivate: {
                return Signal { subscriber in
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
            }, availableOutputsChanged: { _, _ in
            })
            
            let callContext = GroupCallContext(audioSessionActive: self.audioSessionActive.get())
            self.callContext = callContext
            
            self.memberCountDisposable = (callContext.memberCount
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.memberCount = value
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            })
            
            self.isMutedDisposable = (callContext.isMuted
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isMuted = value
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            })
            
            self.muteButton.addTarget(self, action: #selector(self.muteButtonPressed), forControlEvents: .touchUpInside)
        }
        
        deinit {
            self.callDisposable?.dispose()
            self.memberCountDisposable?.dispose()
        }
        
        @objc private func muteButtonPressed() {
            self.callContext?.toggleIsMuted()
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            self.memberCountNode.attributedText = NSAttributedString(string: "Members: \(self.memberCount)", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            
            self.isMutedNode.attributedText = NSAttributedString(string: self.isMuted ? "Unmute" : "Mute", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
            
            let textSize = self.memberCountNode.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: 100.0))
            let isMutedSize = self.isMutedNode.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: 100.0))
            
            let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: floor((layout.size.height - textSize.width) / 2.0)), size: textSize)
            transition.updateFrameAdditiveToCenter(node: self.memberCountNode, frame: textFrame)
            
            let isMutedFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - isMutedSize.width) / 2.0), y: textFrame.maxY + 12.0), size: isMutedSize)
            transition.updateFrame(node: self.muteButton, frame: isMutedFrame)
            self.isMutedNode.frame = CGRect(origin: CGPoint(), size: isMutedFrame.size)
        }
    }
    
    private let context: AccountContext
    private let presentationData: PresentationData
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
