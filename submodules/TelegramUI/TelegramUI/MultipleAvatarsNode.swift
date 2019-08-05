import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 13.0)!

final class MultipleAvatarsNode: ASDisplayNode {
    private var nodes: [(Peer, AvatarNode)] = []
    
    static func asyncLayout(_ current: MultipleAvatarsNode?) -> (Account, PresentationTheme, [Peer], CGSize) -> (Bool) -> MultipleAvatarsNode {
        let currentNodes: [(Peer, AvatarNode)] = current?.nodes ?? []
        return { account, theme, peers, size in
            var node: MultipleAvatarsNode
            if let current = current {
                node = current
            } else {
                node = MultipleAvatarsNode()
            }
            
            var resultNodes: [(Peer, AvatarNode)] = []
            for peer in peers {
                var found = false
                inner: for (currentPeer, currentNode) in currentNodes {
                    if currentPeer.id == peer.id {
                        resultNodes.append((peer, currentNode))
                        found = true
                        break inner
                    }
                }
                if !found {
                    resultNodes.append((peer, AvatarNode(font: avatarFont)))
                }
                if resultNodes.count == 4 {
                    break
                }
            }
            
            return { animated in
                let partitionSize = floor(size.width / 2.0)
                let singleSize = partitionSize - 1.0
                
                var index = 0
                for (peer, avatarNode) in resultNodes {
                    let xPosition: CGFloat = index % 2 == 0 ? 0.0 : size.width - singleSize
                    let yPosition = index / 2 == 0 ? 0.0 : size.height - singleSize
                    let avatarFrame = CGRect(origin: CGPoint(x: xPosition, y: yPosition), size: CGSize(width: singleSize, height: singleSize))
                    if avatarNode.supernode == nil {
                        node.addSubnode(avatarNode)
                        avatarNode.frame = avatarFrame
                        if animated {
                            avatarNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
                            avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        let distance = CGPoint(x: avatarNode.frame.midX - avatarFrame.midX, y: avatarNode.frame.midY - avatarFrame.midY)
                        avatarNode.frame = avatarFrame
                        if animated {
                            avatarNode.layer.animatePosition(from: distance, to: CGPoint(), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, additive: true)
                        }
                    }
                    avatarNode.setPeer(account: account, theme: theme, peer: peer)
                    index += 1
                }
                index += 1
                for (_, currentNode) in node.nodes {
                    var found = false
                    inner: for (_, resultNode) in resultNodes {
                        if currentNode === resultNode {
                            found = true
                            break inner
                        }
                    }
                    if !found {
                        if animated {
                            currentNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.2, removeOnCompletion: false)
                            currentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak currentNode] _ in
                                currentNode?.removeFromSupernode()
                            })
                        } else {
                            currentNode.removeFromSupernode()
                        }
                    }
                }
                node.nodes = resultNodes
                
                return node
            }
        }
    }
}
