import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore

final class HashtagSearchControllerNode: ASDisplayNode {
    let listNode: ListView
    
    private let account: Account
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    var navigationBar: NavigationBar?
    
    init(account: Account) {
        self.account = account
        self.listNode = ListView()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = .white
        
        self.listNode.isHidden = true
        self.addSubnode(self.listNode)
    }
    
    func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let options = ListViewDeleteAndInsertOptions()
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if displayingResults != !strongSelf.listNode.isHidden {
                        if strongSelf.listNode.isHidden {
                            strongSelf.listNode.isHidden = false
                            strongSelf.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                }
            })
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                case .easeInOut:
                    break
                case .spring:
                    curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
}
