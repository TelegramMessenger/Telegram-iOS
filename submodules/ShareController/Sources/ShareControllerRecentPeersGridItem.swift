import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatListSearchRecentPeersNode
import AccountContext

final class ShareControllerRecentPeersGridItem: GridItem {
    let environment: ShareControllerEnvironment
    let context: ShareControllerAccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let controllerInteraction: ShareControllerInteraction
    
    let section: GridSection? = nil
    let fillsRowWithHeight: (CGFloat, Bool)? = (102.0, true)
    
    init(environment: ShareControllerEnvironment, context: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ShareControllerInteraction) {
        self.environment = environment
        self.context = context
        self.theme = theme
        self.strings = strings
        self.controllerInteraction = controllerInteraction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ShareControllerRecentPeersGridItemNode()
        node.controllerInteraction = self.controllerInteraction
        node.setup(environment: self.environment, context: self.context, theme: self.theme, strings: self.strings)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerRecentPeersGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(environment: self.environment, context: self.context, theme: self.theme, strings: self.strings)
    }
}

final class ShareControllerRecentPeersGridItemNode: GridItemNode {
    private var currentState: (ShareControllerAccountContext, PresentationTheme, PresentationStrings)?
    
    var controllerInteraction: ShareControllerInteraction?
    
    private var peersNode: ChatListSearchRecentPeersNode?
    
    override init() {
        super.init()
    }
    
    func setup(environment: ShareControllerEnvironment, context: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        if self.currentState == nil || self.currentState!.0 !== context || self.currentState!.1 !== theme {
            let peersNode: ChatListSearchRecentPeersNode
            if let currentPeersNode = self.peersNode {
                peersNode = currentPeersNode
                peersNode.updateThemeAndStrings(theme: theme, strings: strings)
            } else {
                peersNode = ChatListSearchRecentPeersNode(
                    accountPeerId: context.accountPeerId,
                    postbox: context.stateManager.postbox,
                    network: context.stateManager.network,
                    energyUsageSettings: environment.energyUsageSettings,
                    contentSettings: context.contentSettings,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    resolveInlineStickers: context.resolveInlineStickers,
                    theme: theme,
                    mode: .actionSheet,
                    strings: strings,
                    peerSelected: { [weak self] peer in
                        self?.controllerInteraction?.togglePeer(EngineRenderedPeer(peer: peer), true)
                    },
                    peerContextAction: { _, _, gesture, _ in gesture?.cancel() },
                    isPeerSelected: { [weak self] peerId in
                        return self?.controllerInteraction?.selectedPeerIds.contains(peerId) ?? false
                    },
                    share: true
                )
                self.peersNode = peersNode
                self.addSubnode(peersNode)
            }
            
            self.currentState = (context, theme, strings)
        }
        self.updateSelection(animated: false)
    }
    
    func updateSelection(animated: Bool) {
        self.peersNode?.updateSelectedPeers(animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.peersNode?.frame = CGRect(origin: CGPoint(x: -8.0, y: 0.0), size: CGSize(width: bounds.width + 8.0, height: bounds.height))
        self.peersNode?.updateLayout(size: bounds.size, leftInset: 0.0, rightInset: 0.0)
    }
}
